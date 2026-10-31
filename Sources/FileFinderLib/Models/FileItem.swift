import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let fileExtension: String
    public let fileSize: Int64
    public let formattedSize: String
    public let modificationDate: Date
    public let creationDate: Date
    public let category: ShelfCategory
    public let origin: DownloadOrigin
    public let originURL: URL?

    public init(
        url: URL,
        name: String? = nil,
        fileSize: Int64 = 0,
        modificationDate: Date = Date(),
        creationDate: Date = Date(),
        category: ShelfCategory = .documents,
        origin: DownloadOrigin = .unknown,
        originURL: URL? = nil
    ) {
        self.id = url
        self.url = url
        self.name = name ?? url.deletingPathExtension().lastPathComponent
        self.fileExtension = url.pathExtension.uppercased()
        self.fileSize = fileSize
        self.formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.category = category
        self.origin = origin
        self.originURL = originURL
    }

    public var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modificationDate, relativeTo: Date())
    }

    /// Full file name on disk including path extension (e.g., "resume.pdf")
    public var fullName: String {
        url.lastPathComponent
    }

    /// Returns either the full file name with extension or the base name according to user setting
    public func displayName(showExtension: Bool) -> String {
        showExtension ? fullName : name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(modificationDate)
    }

    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url && lhs.modificationDate == rhs.modificationDate
    }
}
