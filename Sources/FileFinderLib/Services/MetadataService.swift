import Foundation
import Darwin

public final class MetadataService: Sendable {
    public static let shared = MetadataService()
    private init() {}

    public func extractWhereFroms(for url: URL) -> [String] {
        let xattrName = "com.apple.metadata:kMDItemWhereFroms"
        return url.withUnsafeFileSystemRepresentation { fileSystemPath in
            guard let path = fileSystemPath else { return [] }
            let bufferSize = getxattr(path, xattrName, nil, 0, 0, 0)
            guard bufferSize > 0 else { return [] }

            var data = Data(count: bufferSize)
            let readSize = data.withUnsafeMutableBytes { rawBuffer in
                getxattr(path, xattrName, rawBuffer.baseAddress, bufferSize, 0, 0)
            }
            guard readSize == bufferSize else { return [] }

            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String] {
                return plist
            }
            return []
        } ?? []
    }

    public func extractQuarantineAgent(for url: URL) -> String? {
        let xattrName = "com.apple.quarantine"
        return url.withUnsafeFileSystemRepresentation { fileSystemPath in
            guard let path = fileSystemPath else { return nil }
            let bufferSize = getxattr(path, xattrName, nil, 0, 0, 0)
            guard bufferSize > 0 else { return nil }

            var data = Data(count: bufferSize)
            let readSize = data.withUnsafeMutableBytes { rawBuffer in
                getxattr(path, xattrName, rawBuffer.baseAddress, bufferSize, 0, 0)
            }
            guard readSize == bufferSize else { return nil }
            guard let string = String(data: data, encoding: .utf8) else { return nil }

            // Quarantine format: flags;timestamp;agent_bundle_or_name;uuid
            let parts = string.components(separatedBy: ";")
            if parts.count >= 3 && !parts[2].isEmpty {
                return parts[2]
            }
            return nil
        }
    }

    public func extractOrigin(for url: URL) -> (origin: DownloadOrigin, originURL: URL?) {
        let whereFroms = extractWhereFroms(for: url)
        let agent = extractQuarantineAgent(for: url)
        let origin = DownloadOrigin.detect(quarantineAgent: agent, whereFromsURLs: whereFroms)
        let originURL = whereFroms.first.flatMap { URL(string: $0) }
        return (origin, originURL)
    }
}
