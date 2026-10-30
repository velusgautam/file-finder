import Foundation

public struct DateRange: Hashable, Sendable {
    public let start: Date?
    public let end: Date?

    public init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool {
        if let start, date < start { return false }
        if let end, date > end { return false }
        return true
    }
}

public struct FileSizeConstraint: Hashable, Sendable {
    public let minBytes: Int64?
    public let maxBytes: Int64?

    public init(minBytes: Int64? = nil, maxBytes: Int64? = nil) {
        self.minBytes = minBytes
        self.maxBytes = maxBytes
    }

    public func matches(_ size: Int64) -> Bool {
        if let minBytes, size < minBytes { return false }
        if let maxBytes, size > maxBytes { return false }
        return true
    }
}

public enum FilterChipType: Hashable, Sendable {
    case category(ShelfCategory)
    case origin(DownloadOrigin)
    case dateRange(DateRange)
    case fileSize(FileSizeConstraint)
    case fileExtension(String)
    case screenshot
    case keyword(String)
}

public struct FilterChip: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let iconSystemName: String?
    public let type: FilterChipType

    public init(id: String = UUID().uuidString, title: String, iconSystemName: String? = nil, type: FilterChipType) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
        self.type = type
    }
}
