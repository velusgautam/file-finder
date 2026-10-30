import Foundation
import CryptoKit

public struct DuplicateGroup: Identifiable, Sendable {
    public var id: String { hash }
    public let hash: String
    public let fileSize: Int64
    public let items: [FileItem] // All files sharing the exact same content

    public init(hash: String, fileSize: Int64, items: [FileItem]) {
        self.hash = hash
        self.fileSize = fileSize
        self.items = items
    }

    public var original: FileItem? {
        // Oldest creation date considered original; fallback to oldest modification date
        items.sorted {
            if $0.creationDate != $1.creationDate {
                return $0.creationDate < $1.creationDate
            }
            return $0.modificationDate < $1.modificationDate
        }.first
    }

    public var duplicateCopies: [FileItem] {
        guard let orig = original else { return [] }
        return items.filter { $0.url != orig.url }
    }

    public var wastedBytes: Int64 {
        Int64(max(items.count - 1, 0)) * fileSize
    }

    public var formattedWastedSize: String {
        ByteCountFormatter.string(fromByteCount: wastedBytes, countStyle: .file)
    }
}

public actor DeduplicationService {
    public static let shared = DeduplicationService()
    public init() {}

    /// Detects real byte-identical duplicates using multi-threaded concurrent hashing
    public func findDuplicates(in files: [FileItem]) async -> [DuplicateGroup] {
        // Pass 1: Group by exact file size > 0
        var sizeGroups: [Int64: [FileItem]] = [:]
        for file in files where file.fileSize > 0 {
            sizeGroups[file.fileSize, default: []].append(file)
        }

        // Keep only size collisions (files sharing the exact same byte count)
        let candidateGroups = sizeGroups.values.filter { $0.count > 1 }
        guard !candidateGroups.isEmpty else { return [] }

        // Pass 2: Concurrently hash all candidate items across worker threads using TaskGroup
        let candidateItems = candidateGroups.flatMap { $0 }
        let hashesByPath = await withTaskGroup(of: (URL, String?).self) { group in
            for item in candidateItems {
                group.addTask {
                    let h = self.computeSHA256(for: item.url)
                    return (item.url, h)
                }
            }

            var map: [URL: String] = [:]
            for await (url, hash) in group {
                if let hash = hash {
                    map[url] = hash
                }
            }
            return map
        }

        // Pass 3: Assemble duplicate groups where multiple files produce the identical hash
        var duplicateGroups: [DuplicateGroup] = []
        for group in candidateGroups {
            var hashBuckets: [String: [FileItem]] = [:]
            for item in group {
                if let hash = hashesByPath[item.url] {
                    hashBuckets[hash, default: []].append(item)
                }
            }

            for (hash, matchedFiles) in hashBuckets where matchedFiles.count > 1 {
                if let size = matchedFiles.first?.fileSize {
                    duplicateGroups.append(DuplicateGroup(hash: hash, fileSize: size, items: matchedFiles))
                }
            }
        }

        return duplicateGroups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    public nonisolated func computeSHA256(for url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: 1024 * 64) // 64KB chunks
                if data.isEmpty { return false }
                hasher.update(data: data)
                return true
            }) {}

            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
