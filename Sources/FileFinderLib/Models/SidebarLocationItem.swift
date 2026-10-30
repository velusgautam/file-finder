import Foundation

public struct SidebarLocationItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var url: URL
    public var iconSystemName: String
    public var isDefault: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: URL,
        iconSystemName: String = "folder.fill",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.iconSystemName = iconSystemName
        self.isDefault = isDefault
    }

    public static func defaultLocations() -> [SidebarLocationItem] {
        let fm = FileManager.default
        let username = NSUserName()
        let homeURL = fm.homeDirectoryForCurrentUser

        var items: [SidebarLocationItem] = []

        // User Home
        items.append(SidebarLocationItem(
            id: "default_user_home",
            name: username,
            url: homeURL,
            iconSystemName: "folder.fill",
            isDefault: true
        ))

        // Desktop
        if let url = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_desktop",
                name: "Desktop",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        // Documents
        if let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_documents",
                name: "Documents",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        // Downloads
        if let url = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_downloads",
                name: "Downloads",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        // Pictures
        if let url = fm.urls(for: .picturesDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_pictures",
                name: "Pictures",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        // Movies
        if let url = fm.urls(for: .moviesDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_movies",
                name: "Movies",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        // Music
        if let url = fm.urls(for: .musicDirectory, in: .userDomainMask).first {
            items.append(SidebarLocationItem(
                id: "default_music",
                name: "Music",
                url: url,
                iconSystemName: "folder.fill",
                isDefault: true
            ))
        }

        return items
    }
}

public final class SidebarLocationStore: Sendable {
    public static let shared = SidebarLocationStore()
    private let key = "filefinder_sidebar_locations_v2"

    private init() {}

    public func loadLocations() -> [SidebarLocationItem] {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([SidebarLocationItem].self, from: data),
           !list.isEmpty {
            return list
        }
        return SidebarLocationItem.defaultLocations()
    }

    public func saveLocations(_ locations: [SidebarLocationItem]) {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public func resetToDefaults() -> [SidebarLocationItem] {
        let defaults = SidebarLocationItem.defaultLocations()
        saveLocations(defaults)
        return defaults
    }
}
