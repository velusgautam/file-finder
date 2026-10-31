import Foundation

/// Engine responsible for evaluating and executing automated clean up rules
public final class CleanUpRulesEngine: @unchecked Sendable {
    public static let shared = CleanUpRulesEngine()

    public static let installerExtensions: Set<String> = ["dmg", "pkg", "iso"]
    public static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "tiff"]

    // UserDefaults keys
    public static let oldInstallersEnabledKey = "cleanup_rule_old_installers_enabled"
    public static let oldInstallersAutoRunKey = "cleanup_rule_old_installers_auto_run"
    public static let oldInstallersDaysKey = "cleanup_rule_old_installers_days"
    public static let screenshotsByMonthEnabledKey = "cleanup_rule_screenshots_by_month_enabled"
    public static let screenshotsAutoRunKey = "cleanup_rule_screenshots_auto_run"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Preferences

    public var isOldInstallersEnabled: Bool {
        get {
            if userDefaults.object(forKey: Self.oldInstallersEnabledKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: Self.oldInstallersEnabledKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.oldInstallersEnabledKey)
        }
    }

    public var isOldInstallersAutoRun: Bool {
        get {
            userDefaults.bool(forKey: Self.oldInstallersAutoRunKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.oldInstallersAutoRunKey)
        }
    }

    public var oldInstallersDaysThreshold: Int {
        get {
            let val = userDefaults.integer(forKey: Self.oldInstallersDaysKey)
            return val > 0 ? val : 30
        }
        set {
            userDefaults.set(newValue, forKey: Self.oldInstallersDaysKey)
        }
    }

    public var isScreenshotsByMonthEnabled: Bool {
        get {
            if userDefaults.object(forKey: Self.screenshotsByMonthEnabledKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: Self.screenshotsByMonthEnabledKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.screenshotsByMonthEnabledKey)
        }
    }

    public var isScreenshotsAutoRun: Bool {
        get {
            userDefaults.bool(forKey: Self.screenshotsAutoRunKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.screenshotsAutoRunKey)
        }
    }

    // MARK: - Evaluation Functions

    /// Evaluates which files qualify as old installers in Downloads older than the given days threshold
    public func evaluateOldInstallers(
        in files: [FileItem],
        olderThanDays: Int = 30,
        referenceDate: Date = Date(),
        filterByDownloadsLocation: Bool = true
    ) -> [FileItem] {
        let cutoffInterval: TimeInterval = Double(olderThanDays) * 86400.0
        let cutoffDate = referenceDate.addingTimeInterval(-cutoffInterval)

        return files.filter { item in
            // Must match installer file extensions (.dmg, .pkg, .iso)
            let ext = item.fileExtension.lowercased()
            guard Self.installerExtensions.contains(ext) else {
                return false
            }

            // Must be in Downloads folder if location filtering is enabled
            if filterByDownloadsLocation {
                let pathLower = item.url.path.lowercased()
                let inDownloads = pathLower.contains("/downloads/") || pathLower.hasSuffix("/downloads")
                guard inDownloads else {
                    return false
                }
            }

            // Must be older than cutoff date (using modification or creation date)
            let fileDate = item.modificationDate
            return fileDate <= cutoffDate
        }
    }

    /// Evaluates which files are screenshots on Desktop or Downloads needing organization
    public func evaluateScreenshotsToOrganize(
        in files: [FileItem],
        filterLocations: Bool = true
    ) -> [FileItem] {
        return files.filter { item in
            let ext = item.fileExtension.lowercased()
            guard Self.imageExtensions.contains(ext) else {
                return false
            }

            let pathLower = item.url.path.lowercased()
            // Do not re-organize files already placed inside a Screenshots/YYYY-MM/ folder
            if pathLower.contains("/screenshots/20") {
                return false
            }

            // Check location if required
            if filterLocations {
                let inDesktop = pathLower.contains("/desktop/") || pathLower.hasSuffix("/desktop")
                let inDownloads = pathLower.contains("/downloads/") || pathLower.hasSuffix("/downloads")
                guard inDesktop || inDownloads else {
                    return false
                }
            }

            // Check if name indicates screenshot
            let nameLower = item.name.lowercased()
            let isScreenshotName = nameLower.contains("screenshot") ||
                                  nameLower.contains("screen shot") ||
                                  nameLower.hasPrefix("capture")

            return isScreenshotName
        }
    }

    // MARK: - Execution

    /// Moves matched files to macOS Trash
    public func runOldInstallersCleanup(
        in files: [FileItem],
        olderThanDays: Int = 30,
        referenceDate: Date = Date(),
        filterByDownloadsLocation: Bool = true
    ) -> [URL] {
        let candidates = evaluateOldInstallers(
            in: files,
            olderThanDays: olderThanDays,
            referenceDate: referenceDate,
            filterByDownloadsLocation: filterByDownloadsLocation
        )

        var trashedURLs: [URL] = []
        for file in candidates {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                trashedURLs.append(file.url)
            } catch {
                print("CleanUpRulesEngine: Failed to trash \(file.url): \(error)")
            }
        }
        return trashedURLs
    }

    /// Organizes screenshots into Screenshots/YYYY-MM/ folders
    public func runScreenshotsOrganization(
        in files: [FileItem],
        targetBaseDirectory: URL? = nil,
        filterLocations: Bool = true
    ) -> [(source: URL, destination: URL)] {
        let candidates = evaluateScreenshotsToOrganize(in: files, filterLocations: filterLocations)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"

        var movedPairs: [(source: URL, destination: URL)] = []

        for item in candidates {
            let monthString = dateFormatter.string(from: item.modificationDate)
            let baseDir: URL
            if let targetBaseDirectory {
                baseDir = targetBaseDirectory
            } else {
                baseDir = item.url.deletingLastPathComponent()
            }

            let destinationFolder = baseDir
                .appendingPathComponent("Screenshots", isDirectory: true)
                .appendingPathComponent(monthString, isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                var destinationURL = destinationFolder.appendingPathComponent(item.url.lastPathComponent)

                // Handle file collision by appending unique timestamp/counter if needed
                if FileManager.default.fileExists(atPath: destinationURL.path) && destinationURL != item.url {
                    let baseName = item.url.deletingPathExtension().lastPathComponent
                    let ext = item.fileExtension
                    let uniqueName = "\(baseName)_\(Int(Date().timeIntervalSince1970)).\(ext)"
                    destinationURL = destinationFolder.appendingPathComponent(uniqueName)
                }

                if destinationURL != item.url {
                    try FileManager.default.moveItem(at: item.url, to: destinationURL)
                    movedPairs.append((source: item.url, destination: destinationURL))
                }
            } catch {
                print("CleanUpRulesEngine: Failed to organize screenshot \(item.url): \(error)")
            }
        }

        return movedPairs
    }
}
