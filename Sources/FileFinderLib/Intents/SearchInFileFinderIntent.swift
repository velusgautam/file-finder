import AppIntents
import Foundation
@preconcurrency import AppKit

/// App Intent for activating File Finder and initiating a search query
public struct SearchInFileFinderIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search in File Finder"
    public static let description: IntentDescription = IntentDescription("Activates File Finder and opens the search query.")
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Query", description: "Search query to activate")
    public var query: String

    public init() {
        self.query = ""
    }

    public init(query: String) {
        self.query = query
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: Notification.Name("FileFinderSearchRequested"),
            object: nil,
            userInfo: ["query": query]
        )
        return .result()
    }
}

/// AppShortcutsProvider registering Shortcuts.app voice and action phrases
public struct FileFinderShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindFilesIntent(),
            phrases: [
                "Find files in \(.applicationName)",
                "Search files in \(.applicationName)"
            ],
            shortTitle: "Find Files",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: GetLatestDownloadIntent(),
            phrases: [
                "Get latest download in \(.applicationName)",
                "Latest downloaded file in \(.applicationName)"
            ],
            shortTitle: "Latest Download",
            systemImageName: "arrow.down.circle"
        )
        AppShortcut(
            intent: SearchInFileFinderIntent(),
            phrases: [
                "Search in \(.applicationName)"
            ],
            shortTitle: "Search File Finder",
            systemImageName: "doc.text.magnifyingglass"
        )
    }
}
