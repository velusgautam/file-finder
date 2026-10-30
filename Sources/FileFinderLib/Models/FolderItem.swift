import Foundation

public struct FolderItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let itemCount: Int
    public let modificationDate: Date

    public init(url: URL, name: String, itemCount: Int, modificationDate: Date) {
        self.url = url
        self.name = name
        self.itemCount = itemCount
        self.modificationDate = modificationDate
    }

    public var formattedItemCount: String {
        if itemCount == 1 {
            return "1 item"
        }
        return "\(itemCount) items"
    }

    public var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modificationDate, relativeTo: Date())
    }
}
