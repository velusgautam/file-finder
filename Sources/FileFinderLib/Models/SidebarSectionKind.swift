import Foundation

public enum SidebarSectionKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case library   = "library"
    case cleanUp   = "cleanUp"
    case locations = "locations"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .library:   return "Library"
        case .cleanUp:   return "Smart Shelves"
        case .locations: return "Locations"
        }
    }
}

public final class SidebarSectionStore: Sendable {
    public static let shared = SidebarSectionStore()
    private let key = "filefinder_sidebar_sections_order_v1"

    private init() {}

    public func loadSections() -> [SidebarSectionKind] {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([SidebarSectionKind].self, from: data),
           !list.isEmpty {
            // Ensure all current sections exist in case of new cases
            var result = list
            for section in SidebarSectionKind.allCases where !result.contains(section) {
                result.append(section)
            }
            return result
        }
        return [.library, .cleanUp, .locations]
    }

    public func saveSections(_ sections: [SidebarSectionKind]) {
        if let data = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public func resetToDefaults() -> [SidebarSectionKind] {
        let defaults: [SidebarSectionKind] = [.library, .cleanUp, .locations]
        saveSections(defaults)
        return defaults
    }
}
