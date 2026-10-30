import Foundation

public struct InstalledAppItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let name: String
    public let url: URL
    public let bundleIdentifier: String
    public let version: String
    public let fileSize: Int64
    public let modificationDate: Date

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    public var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modificationDate, relativeTo: Date())
    }

    public init(
        name: String,
        url: URL,
        bundleIdentifier: String = "",
        version: String = "",
        fileSize: Int64 = 0,
        modificationDate: Date = Date()
    ) {
        self.id = url
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.fileSize = fileSize
        self.modificationDate = modificationDate
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func == (lhs: InstalledAppItem, rhs: InstalledAppItem) -> Bool {
        lhs.url == rhs.url
    }
}
