import Foundation

public enum NavigationSection: Hashable, Sendable {
    case home
    case recents
    case category(ShelfCategory)
    case applications
    case largeFiles
    case screenshots
    case duplicates
    case cleanUp
    case downloadedFromOverview
    case downloadedFrom(DownloadOrigin)
    case location(name: String, url: URL)

    public var title: String {
        switch self {
        case .home:
            return "Home"
        case .recents:
            return "Recents"
        case .category(let cat):
            return cat.displayTitle
        case .applications:
            return "Applications"
        case .largeFiles:
            return "Large Files"
        case .screenshots:
            return "Screenshots"
        case .duplicates:
            return "Duplicates"
        case .cleanUp:
            return "Clean Up"
        case .downloadedFromOverview:
            return "Downloaded From"
        case .downloadedFrom(let origin):
            return "Downloaded from \(origin.displayName)"
        case .location(let name, _):
            return name
        }
    }
}
