import Foundation
import UniformTypeIdentifiers
@preconcurrency import AppKit

public enum NavigationDirection: Sendable, Hashable {
    case left
    case right
    case up
    case down
}

public struct SelectionNavigator: Sendable {
    /// Calculate previous index (clamped to 0)
    public static func previousIndex(from currentIndex: Int?, totalCount: Int) -> Int? {
        guard totalCount > 0 else { return nil }
        guard let current = currentIndex else { return 0 }
        return max(0, current - 1)
    }

    /// Calculate next index (clamped to totalCount - 1)
    public static func nextIndex(from currentIndex: Int?, totalCount: Int) -> Int? {
        guard totalCount > 0 else { return nil }
        guard let current = currentIndex else { return 0 }
        return min(totalCount - 1, current + 1)
    }

    /// Calculate index above by jumping `columns` items up (clamped to 0)
    public static func indexAbove(from currentIndex: Int?, totalCount: Int, columns: Int) -> Int? {
        guard totalCount > 0 else { return nil }
        let step = max(1, columns)
        guard let current = currentIndex else { return 0 }
        return max(0, current - step)
    }

    /// Calculate index below by jumping `columns` items down (clamped to totalCount - 1)
    public static func indexBelow(from currentIndex: Int?, totalCount: Int, columns: Int) -> Int? {
        guard totalCount > 0 else { return nil }
        let step = max(1, columns)
        guard let current = currentIndex else { return 0 }
        return min(totalCount - 1, current + step)
    }

    /// Unified navigation step in a given direction
    public static func navigate(
        from currentIndex: Int?,
        direction: NavigationDirection,
        totalCount: Int,
        columns: Int = 1
    ) -> Int? {
        switch direction {
        case .left:
            return previousIndex(from: currentIndex, totalCount: totalCount)
        case .right:
            return nextIndex(from: currentIndex, totalCount: totalCount)
        case .up:
            return indexAbove(from: currentIndex, totalCount: totalCount, columns: columns)
        case .down:
            return indexBelow(from: currentIndex, totalCount: totalCount, columns: columns)
        }
    }
}

public struct MultiSelectionHelper: Sendable {
    /// Toggles an item in or out of the selection set.
    public static func toggle<T: Hashable>(item: T, in set: inout Set<T>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    /// Computes the range selection between an anchor item and a target item in an ordered array.
    public static func rangeSelection<T: Hashable>(
        from anchor: T?,
        to target: T,
        in items: [T]
    ) -> Set<T> {
        guard let anchor = anchor,
              let startIndex = items.firstIndex(of: anchor),
              let targetIndex = items.firstIndex(of: target) else {
            return [target]
        }
        let lower = min(startIndex, targetIndex)
        let upper = max(startIndex, targetIndex)
        return Set(items[lower...upper])
    }

    /// Creates standard `NSItemProvider` array for an array of file URLs
    public static func createItemProviders(for urls: [URL]) -> [NSItemProvider] {
        return urls.map { url in
            NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
        }
    }

    /// Creates an NSItemProvider for dragging that contains the primary file URL
    /// as well as the full list of selected file paths (compatible with Finder, Mail, Slack, Figma).
    public static func createMultiFileItemProvider(for primaryURL: URL, selectedURLs: [URL]) -> NSItemProvider {
        let provider = NSItemProvider(item: primaryURL as NSURL, typeIdentifier: UTType.fileURL.identifier)

        let allURLs = selectedURLs.contains(primaryURL) ? selectedURLs : [primaryURL] + selectedURLs
        let filePaths = allURLs.map { $0.path }

        // Register legacy filenames array so receiving apps like Finder/Terminal/Slack accept all dragged files
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: filePaths, format: .xml, options: 0) {
            provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
                completion(plistData, nil)
                return nil
            }
        }

        return provider
    }
}
