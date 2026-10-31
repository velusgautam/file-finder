import Foundation
import CoreServices
import os

// MARK: - Cached Directory Content

public struct CachedDirectoryContent: Sendable, Equatable {
    public let subfolders: [FolderItem]
    public let files: [FileItem]
    public let cachedAt: Date

    public init(subfolders: [FolderItem], files: [FileItem], cachedAt: Date = Date()) {
        self.subfolders = subfolders
        self.files = files
        self.cachedAt = cachedAt
    }
}

// MARK: - Directory Cache Service

public final class DirectoryCacheService: @unchecked Sendable {
    public static let shared = DirectoryCacheService()

    private final class Node {
        let key: URL
        var value: CachedDirectoryContent
        var prev: Node?
        var next: Node?

        init(key: URL, value: CachedDirectoryContent) {
            self.key = key
            self.value = value
        }
    }

    public let capacity: Int
    private var lock = os_unfair_lock()
    private var cache: [URL: Node] = [:]
    private var head: Node?
    private var tail: Node?

    private var monitor: DirectoryFSEventMonitor?
    public var onInvalidation: (@Sendable (URL) -> Void)?

    public init(capacity: Int = 100, enableFSEvents: Bool = true) {
        self.capacity = max(capacity, 1)
        if enableFSEvents {
            self.monitor = DirectoryFSEventMonitor { [weak self] changedURL in
                self?.handleDiskChange(at: changedURL)
            }
        }
    }

    // MARK: - LRU Cache Operations (O(1), 0ms Instant Retrieval)

    public func get(for url: URL) -> CachedDirectoryContent? {
        let key = url.standardizedFileURL
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard let node = cache[key] else {
            return nil
        }
        moveToHead(node)
        return node.value
    }

    public func set(subfolders: [FolderItem], files: [FileItem], for url: URL) {
        set(CachedDirectoryContent(subfolders: subfolders, files: files), for: url)
    }

    public func set(_ content: CachedDirectoryContent, for url: URL) {
        let key = url.standardizedFileURL
        var evictedKey: URL?

        os_unfair_lock_lock(&lock)
        if let existing = cache[key] {
            existing.value = content
            moveToHead(existing)
            os_unfair_lock_unlock(&lock)
        } else {
            let node = Node(key: key, value: content)
            cache[key] = node
            insertNodeAtHead(node)

            if cache.count > capacity {
                if let evicted = removeTail() {
                    cache.removeValue(forKey: evicted.key)
                    evictedKey = evicted.key
                }
            }
            os_unfair_lock_unlock(&lock)
        }

        // Register path with FSEvents monitor
        monitor?.watch(url: key)
        if let evicted = evictedKey {
            monitor?.unwatch(url: evicted)
        }
    }

    public func invalidate(for url: URL) {
        let key = url.standardizedFileURL
        os_unfair_lock_lock(&lock)
        if let node = cache.removeValue(forKey: key) {
            removeNode(node)
        }
        os_unfair_lock_unlock(&lock)

        monitor?.unwatch(url: key)
        onInvalidation?(key)
    }

    public func invalidateAll() {
        os_unfair_lock_lock(&lock)
        cache.removeAll()
        head = nil
        tail = nil
        os_unfair_lock_unlock(&lock)

        monitor?.unwatchAll()
    }

    public func contains(url: URL) -> Bool {
        let key = url.standardizedFileURL
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return cache[key] != nil
    }

    public var count: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return cache.count
    }

    public var allCachedURLs: [URL] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(cache.keys)
    }

    /// Simulates an OS disk event, invalidating matching cache entries and notifying observers
    public func simulateDiskChange(at url: URL) {
        handleDiskChange(at: url)
    }

    // MARK: - Disk Change Handling

    private func handleDiskChange(at changedURL: URL) {
        let changedPath = changedURL.standardizedFileURL.path
        var urlsToInvalidate: [URL] = []

        os_unfair_lock_lock(&lock)
        for (cachedURL, _) in cache {
            let cachedPath = cachedURL.path
            // Invalidate if directory modified directly, or any file inside it changed
            if cachedPath == changedPath || changedPath.hasPrefix(cachedPath) || cachedPath.hasPrefix(changedPath) {
                urlsToInvalidate.append(cachedURL)
            }
        }
        for url in urlsToInvalidate {
            if let node = cache.removeValue(forKey: url) {
                removeNode(node)
            }
        }
        os_unfair_lock_unlock(&lock)

        for url in urlsToInvalidate {
            monitor?.unwatch(url: url)
            onInvalidation?(url)
        }
    }

    // MARK: - Linked List Internals

    private func insertNodeAtHead(_ node: Node) {
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }
        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }
        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        removeNode(node)
        insertNodeAtHead(node)
    }

    private func removeTail() -> Node? {
        guard let currentTail = tail else { return nil }
        removeNode(currentTail)
        return currentTail
    }
}

// MARK: - Directory FSEvent Monitor

internal final class DirectoryFSEventMonitor: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.filefinder.fsevents", qos: .utility)
    private var watchedPaths: Set<String> = []
    private let callback: @Sendable (URL) -> Void

    init(callback: @escaping @Sendable (URL) -> Void) {
        self.callback = callback
    }

    func watch(url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let path = url.standardizedFileURL.path
            if self.watchedPaths.insert(path).inserted {
                self.restartStream()
            }
        }
    }

    func unwatch(url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let path = url.standardizedFileURL.path
            if self.watchedPaths.remove(path) != nil {
                self.restartStream()
            }
        }
    }

    func unwatchAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.watchedPaths.removeAll()
            self.stopStream()
        }
    }

    private func stopStream() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
    }

    private func restartStream() {
        stopStream()
        guard !watchedPaths.isEmpty else { return }

        let pathsArray = Array(watchedPaths) as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let fsCallback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<DirectoryFSEventMonitor>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            for path in paths {
                monitor.handlePathChange(path)
            }
        }

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsCallback,
            &context,
            pathsArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05,
            flags
        ) else {
            return
        }

        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func handlePathChange(_ path: String) {
        let changedURL = URL(fileURLWithPath: path).standardizedFileURL
        callback(changedURL)
    }

    deinit {
        stopStream()
    }
}
