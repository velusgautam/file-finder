import Foundation
@preconcurrency import AppKit
@preconcurrency import QuickLookThumbnailing

@MainActor
public final class ThumbnailService {
    public static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    public func thumbnail(for url: URL, size: CGSize = CGSize(width: 320, height: 240), scale: CGFloat = 2.0) async -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let nsImage = representation.nsImage
            cache.setObject(nsImage, forKey: key, cost: Int(size.width * size.height * 4))
            return nsImage
        } catch {
            let fallback = NSWorkspace.shared.icon(forFile: url.path)
            cache.setObject(fallback, forKey: key, cost: 4096)
            return fallback
        }
    }
}
