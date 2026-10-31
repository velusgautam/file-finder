import Foundation

public enum SortOption: String, CaseIterable, Identifiable, Sendable {
    case relevance    = "Relevance"
    case dateModified = "Date Modified"
    case dateCreated  = "Date Created"
    case name         = "Name"
    case size         = "Size"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .relevance:    return "sparkles"
        case .dateModified: return "calendar"
        case .dateCreated:  return "clock"
        case .name:         return "textformat"
        case .size:         return "internaldrive"
        }
    }
}

public enum SortOrder: String, CaseIterable, Identifiable, Sendable {
    case descending = "Descending"
    case ascending  = "Ascending"

    public var id: String { rawValue }

    public mutating func toggle() {
        self = (self == .ascending) ? .descending : .ascending
    }

    public var iconName: String {
        self == .descending ? "arrow.down" : "arrow.up"
    }
}

public enum SizeFilter: String, CaseIterable, Identifiable, Sendable {
    case all    = "All Sizes"
    case small  = "< 1 MB"
    case medium = "1 MB – 50 MB"
    case large  = "> 50 MB"

    public var id: String { rawValue }

    public func matches(fileSize: Int64) -> Bool {
        switch self {
        case .all:
            return true
        case .small:
            return fileSize < 1 * 1024 * 1024
        case .medium:
            return fileSize >= 1 * 1024 * 1024 && fileSize <= 50 * 1024 * 1024
        case .large:
            return fileSize > 50 * 1024 * 1024
        }
    }
}

public enum DateFilter: String, CaseIterable, Identifiable, Sendable {
    case all       = "All Dates"
    case today     = "Today"
    case pastWeek  = "Past 7 Days"
    case pastMonth = "Past 30 Days"
    case pastYear  = "Past Year"

    public var id: String { rawValue }

    public func matches(date: Date) -> Bool {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        switch self {
        case .all:
            return true
        case .today:
            return Calendar.current.isDateInToday(date)
        case .pastWeek:
            return interval >= -86400 && interval <= 7 * 86400
        case .pastMonth:
            return interval >= -86400 && interval <= 30 * 86400
        case .pastYear:
            return interval >= -86400 && interval <= 365 * 86400
        }
    }
}
