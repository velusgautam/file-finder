import Foundation

/// Represents a user-saved natural language or keyword search query
public struct SavedSearch: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var query: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, query: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.query = query
        self.createdAt = createdAt
    }

    /// Evaluates if a given FileItem matches this saved search query using NLQueryParser and SearchFilter
    public func matches(file: FileItem, ocrText: String? = nil) -> Bool {
        let parsed = NLQueryParser.parse(query)
        let (matches, _) = parsed.filter.matchEvaluation(for: file, ocrText: ocrText)
        return matches
    }
}

/// Store for persisting saved searches in UserDefaults
public final class SavedSearchStore: @unchecked Sendable {
    public static let shared = SavedSearchStore()
    private let key = "filefinder_saved_searches"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public static let defaultSearches: [SavedSearch] = [
        SavedSearch(name: "Recent PDFs", query: "type:pdf from:last-week"),
        SavedSearch(name: "Large Screenshots", query: "screenshots > 5MB"),
        SavedSearch(name: "Disk Images & Installers", query: "dmg pkg iso")
    ]

    public func loadSavedSearches() -> [SavedSearch] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedSearch].self, from: data) else {
            return Self.defaultSearches
        }
        return decoded
    }

    public func saveSavedSearches(_ searches: [SavedSearch]) {
        if let encoded = try? JSONEncoder().encode(searches) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    public func addSavedSearch(_ search: SavedSearch) {
        var current = loadSavedSearches()
        current.append(search)
        saveSavedSearches(current)
    }

    public func removeSavedSearch(id: UUID) {
        var current = loadSavedSearches()
        current.removeAll { $0.id == id }
        saveSavedSearches(current)
    }

    public func resetToDefaults() -> [SavedSearch] {
        saveSavedSearches(Self.defaultSearches)
        return Self.defaultSearches
    }
}
