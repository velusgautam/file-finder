import Foundation

public struct CustomLocation: Identifiable, Codable, Hashable, Sendable {
    public var id: String { url.path }
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public final class CustomLocationStore: Sendable {
    public static let shared = CustomLocationStore()
    private let key = "my_finder_custom_locations_v1"

    private init() {}

    public func loadLocations() -> [CustomLocation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([CustomLocation].self, from: data) else {
            return []
        }
        return list
    }

    public func saveLocations(_ locations: [CustomLocation]) {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
