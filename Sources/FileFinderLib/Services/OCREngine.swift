import Foundation
import Vision

public actor OCREngine {
    public static let shared = OCREngine()

    public static let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "webp", "tiff", "tif"
    ]

    private var memoryCache: [String: String] = [:]
    private let cacheFileURL: URL?
    private var isDirty: Bool = false

    public init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let fileURL: URL?
        if let cachesDir {
            let bundleCacheDir = cachesDir.appendingPathComponent("com.velugautam.MyFilesFinder", isDirectory: true)
            try? FileManager.default.createDirectory(at: bundleCacheDir, withIntermediateDirectories: true)
            fileURL = bundleCacheDir.appendingPathComponent("ocr_cache.json")
        } else {
            fileURL = nil
        }
        self.cacheFileURL = fileURL

        var initialCache: [String: String] = [:]
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            initialCache = decoded
        }
        self.memoryCache = initialCache
        self.isDirty = false
    }

    private func makeCacheKey(for url: URL, modificationDate: Date) -> String {
        return "\(url.path)|\(Int64(modificationDate.timeIntervalSince1970))"
    }

    public func cachedText(for url: URL, modificationDate: Date) -> String? {
        let key = makeCacheKey(for: url, modificationDate: modificationDate)
        return memoryCache[key]
    }

    public func allCachedEntries() -> [URL: String] {
        var results: [URL: String] = [:]
        for (key, text) in memoryCache {
            let components = key.split(separator: "|")
            if let path = components.first {
                let url = URL(fileURLWithPath: String(path))
                results[url] = text
            }
        }
        return results
    }

    /// Recognizes text in an image file. Uses cached result if available.
    public func recognizeText(for url: URL, modificationDate: Date) async -> String? {
        let key = makeCacheKey(for: url, modificationDate: modificationDate)
        if let cached = memoryCache[key] {
            return cached
        }

        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let recognized = performVisionOCR(url: url)
        if let recognized {
            memoryCache[key] = recognized
            isDirty = true
        }
        return recognized
    }

    /// Synchronously performs Vision text recognition isolated to the actor.
    private func performVisionOCR(url: URL) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        let handler = VNImageRequestHandler(url: url, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results, !observations.isEmpty else {
                return ""
            }

            let textSegments = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            return textSegments.joined(separator: " ")
        } catch {
            return nil
        }
    }

    /// Batch processes items with concurrency throttling to avoid CPU/memory pressure.
    public func processBatch(
        items: [FileItem],
        maxConcurrency: Int = 3,
        onProgress: (@Sendable @MainActor (URL, String) -> Void)? = nil
    ) async {
        let eligible = items.filter { Self.supportedExtensions.contains($0.fileExtension.lowercased()) }
        guard !eligible.isEmpty else { return }

        await withTaskGroup(of: (URL, String?)?.self) { group in
            var iterator = eligible.makeIterator()

            for _ in 0..<maxConcurrency {
                if let nextItem = iterator.next() {
                    group.addTask {
                        let text = await self.recognizeText(for: nextItem.url, modificationDate: nextItem.modificationDate)
                        return (nextItem.url, text)
                    }
                }
            }

            while let result = await group.next() {
                if let (url, text) = result, let text, !text.isEmpty {
                    if let onProgress {
                        await onProgress(url, text)
                    }
                }

                if let nextItem = iterator.next() {
                    group.addTask {
                        let text = await self.recognizeText(for: nextItem.url, modificationDate: nextItem.modificationDate)
                        return (nextItem.url, text)
                    }
                }
            }
        }

        saveCacheToDisk()
    }

    // MARK: - Disk Persistence

    public func saveCacheToDisk() {
        guard isDirty, let cacheFileURL else { return }
        do {
            let data = try JSONEncoder().encode(memoryCache)
            try data.write(to: cacheFileURL, options: .atomic)
            isDirty = false
        } catch {
            // Failed writing cache
        }
    }
}
