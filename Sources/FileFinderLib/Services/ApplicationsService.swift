import Foundation

public final class ApplicationsService: Sendable {
    public static let shared = ApplicationsService()

    public init() {}

    /// Scans standard macOS application directories for installed applications (.app bundles).
    /// Deduplicates applications by bundle identifier or canonical path and sorts alphabetically by name.
    public func scanInstalledApplications(customSearchDirectories: [URL]? = nil) async -> [InstalledAppItem] {
        let fileManager = FileManager.default

        let searchDirectories: [URL]
        if let custom = customSearchDirectories {
            searchDirectories = custom
        } else {
            searchDirectories = [
                URL(fileURLWithPath: "/Applications"),
                fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities"),
                URL(fileURLWithPath: "/Applications/Utilities")
            ]
        }

        // 1. Gather all candidate .app bundle URLs from the search directories
        var candidateAppURLs: [URL] = []
        for dir in searchDirectories {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for item in contents {
                if item.pathExtension.lowercased() == "app" {
                    candidateAppURLs.append(item)
                } else {
                    // Check one level down for nested apps (e.g. Utilities folders)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                        if let subcontents = try? fileManager.contentsOfDirectory(
                            at: item,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            for sub in subcontents where sub.pathExtension.lowercased() == "app" {
                                candidateAppURLs.append(sub)
                            }
                        }
                    }
                }
            }
        }

        // 2. Extract metadata and deduplicate by canonical path & bundle identifier
        struct PreParsedApp {
            let name: String
            let url: URL
            let resolvedURL: URL
            let bundleIdentifier: String
            let version: String
            let modificationDate: Date
        }

        var seenCanonicalPaths = Set<String>()
        var seenBundleIDs = Set<String>()
        var deduplicatedApps: [PreParsedApp] = []

        for url in candidateAppURLs {
            if Task.isCancelled { break }

            let resolvedURL = url.resolvingSymlinksInPath()
            let canonicalPath = resolvedURL.path
            if seenCanonicalPaths.contains(canonicalPath) {
                continue
            }

            let bundle = Bundle(url: url)

            let rawBundleID = bundle?.bundleIdentifier ?? (bundle?.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) ?? ""
            let bundleID = rawBundleID.trimmingCharacters(in: .whitespacesAndNewlines)

            if !bundleID.isEmpty && seenBundleIDs.contains(bundleID) {
                continue
            }

            seenCanonicalPaths.insert(canonicalPath)
            if !bundleID.isEmpty {
                seenBundleIDs.insert(bundleID)
            }

            // Extract display name
            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            let systemDisplayName = fileManager.displayName(atPath: url.path)
            let fallbackName = url.deletingPathExtension().lastPathComponent

            let cleanName: String
            if let displayName = displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanName = displayName
            } else if let bundleName = bundleName, !bundleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanName = bundleName
            } else if !systemDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanName = systemDisplayName
            } else {
                cleanName = fallbackName
            }

            // Extract version string
            let shortVersion = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let bundleVersion = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String

            let cleanVersion: String
            if let shortVersion = shortVersion, !shortVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanVersion = shortVersion
            } else if let bundleVersion = bundleVersion, !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cleanVersion = bundleVersion
            } else {
                cleanVersion = ""
            }

            // Extract modification date
            let resValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modDate = resValues?.contentModificationDate ?? Date()

            deduplicatedApps.append(
                PreParsedApp(
                    name: cleanName,
                    url: url,
                    resolvedURL: resolvedURL,
                    bundleIdentifier: bundleID,
                    version: cleanVersion,
                    modificationDate: modDate
                )
            )
        }

        // 3. Compute bundle sizes concurrently with TaskGroup
        let installedItems: [InstalledAppItem] = await withTaskGroup(of: InstalledAppItem.self) { group in
            for app in deduplicatedApps {
                group.addTask {
                    let size = ApplicationsService.calculateBundleSize(at: app.resolvedURL)
                    return InstalledAppItem(
                        name: app.name,
                        url: app.url,
                        bundleIdentifier: app.bundleIdentifier,
                        version: app.version,
                        fileSize: size,
                        modificationDate: app.modificationDate
                    )
                }
            }

            var results: [InstalledAppItem] = []
            for await item in group {
                results.append(item)
            }
            return results
        }

        // 4. Sort alphabetically by name
        return installedItems.sorted { a1, a2 in
            a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
        }
    }

    /// Computes the disk usage of an application bundle directory.
    public static func calculateBundleSize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) {
                totalSize += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return totalSize
    }
}
