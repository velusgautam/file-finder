import Foundation
import Combine
import AppKit
import SwiftUI

public struct DisplayItem: Identifiable, Sendable {
    public var id: URL { item.id }
    public let item: FileItem
    public let isOCRMatch: Bool

    public init(item: FileItem, isOCRMatch: Bool = false) {
        self.item = item
        self.isOCRMatch = isOCRMatch
    }
}

public struct OriginSummary: Identifiable, Sendable {
    public var id: DownloadOrigin { origin }
    public let origin: DownloadOrigin
    public let count: Int
    public let totalSize: Int64
    public let sampleItems: [FileItem]

    public init(origin: DownloadOrigin, count: Int, totalSize: Int64, sampleItems: [FileItem]) {
        self.origin = origin
        self.count = count
        self.totalSize = totalSize
        self.sampleItems = sampleItems
    }
}

public struct ScanProgress: Sendable {
    public var filesCount: Int
    public var totalBytes: Int64
    public var currentFolder: String
    public var isComplete: Bool

    public init(filesCount: Int = 0, totalBytes: Int64 = 0, currentFolder: String = "", isComplete: Bool = false) {
        self.filesCount = filesCount
        self.totalBytes = totalBytes
        self.currentFolder = currentFolder
        self.isComplete = isComplete
    }
}

@MainActor
public final class ScannerViewModel: ObservableObject {
    @Published public private(set) var shelves: [ShelfCategory: [FileItem]] = [:]
    @Published public private(set) var allFiles: [FileItem] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isInitialLoading: Bool = true

    // Real-time scan progress
    @Published public private(set) var scanFilesCount: Int = 0
    @Published public private(set) var scanTotalBytes: Int64 = 0
    @Published public private(set) var scanCurrentFolder: String = "Initializing..."
    @Published public private(set) var formattedScanBytes: String = "0 B"

    // Navigation, Inspector & Layout State
    @Published public var currentSection: NavigationSection = .home
    @Published public var selectedFile: FileItem? = nil {
        didSet {
            if let file = selectedFile {
                if !selectedFileSet.contains(file.url) {
                    selectedFileSet = [file.url]
                }
            }
            updateQuickLookIfVisible()
        }
    }
    @Published public var selectedFileSet: Set<URL> = []
    @Published public var selectedFolder: FolderItem? = nil
    @Published public var isQuickLookVisible: Bool = false
    @Published public var quickLookURL: URL? = nil
    @Published public var selectedDuplicateGroup: DuplicateGroup? = nil
    @Published public var isSidebarVisible: Bool = true
    @Published public var isDetailInspectorVisible: Bool = false

    // Filter & Sorting State (Active across all views)
    @Published public var layoutMode: ViewLayoutMode = .grid
    @Published public var gridIconSize: CGFloat = 145
    @Published public var selectedCategoryFilter: ShelfCategory? = nil
    @Published public var selectedOriginFilter: DownloadOrigin? = nil
    @Published public var selectedSortOption: SortOption = .dateModified
    @Published public var selectedSortOrder: SortOrder = .descending
    @Published public var selectedSizeFilter: SizeFilter = .all
    @Published public var selectedDateFilter: DateFilter = .all

    // Location Folder Browsing State
    @Published public private(set) var currentLocationRootURL: URL? = nil
    @Published public private(set) var currentLocationName: String = ""
    @Published public private(set) var currentFolderURL: URL? = nil
    @Published public private(set) var currentFolderSubfolders: [FolderItem] = []
    @Published public private(set) var currentFolderFiles: [FileItem] = []

    // Sidebar Order & Reordering State
    @Published public var sidebarSections: [SidebarSectionKind] = []
    @Published public var sidebarLocations: [SidebarLocationItem] = []
    @Published public var draggedLocation: SidebarLocationItem? = nil
    @Published public var draggedSection: SidebarSectionKind? = nil

    // Custom Locations (Backward-compatible)
    public var customLocations: [CustomLocation] {
        sidebarLocations.filter { !$0.isDefault }.map { CustomLocation(name: $0.name, url: $0.url) }
    }

    // Installed Applications
    @Published public private(set) var installedApps: [InstalledAppItem] = []
    public var installedAppsCount: Int {
        installedApps.count
    }

    // Duplicates
    @Published public private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published public private(set) var isDeduplicating: Bool = false

    // Search & NLP
    @Published public var searchQuery: String = "" {
        didSet {
            parseSearchQuery()
        }
    }
    @Published public private(set) var activeFilter: SearchFilter = SearchFilter()
    @Published public private(set) var activeChips: [FilterChip] = []

    // OCR State
    @Published public private(set) var ocrTextByFileURL: [URL: String] = [:]
    @Published public private(set) var isOCRProcessing: Bool = false
    @Published public private(set) var ocrProcessedCount: Int = 0
    @Published public private(set) var ocrTotalCount: Int = 0

    private let scanner = FileScannerService()
    private let applicationsService = ApplicationsService.shared
    private let cacheService = DirectoryCacheService.shared
    private let indexService = SQLiteIndexService.shared
    private var folderLoadTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?
    private var deduplicationTask: Task<Void, Never>?

    public init() {
        self.sidebarSections = SidebarSectionStore.shared.loadSections()
        self.sidebarLocations = SidebarLocationStore.shared.loadLocations()

        self.cacheService.onInvalidation = { [weak self] invalidatedURL in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let current = self.currentFolderURL?.standardizedFileURL,
                   current == invalidatedURL.standardizedFileURL || invalidatedURL.path.hasPrefix(current.path) {
                    self.loadCurrentFolderContents(forceRefresh: true)
                }
            }
        }

        QuickLookManager.shared.onVisibilityChanged = { [weak self] isVis in
            Task { @MainActor [weak self] in
                self?.isQuickLookVisible = isVis
                if !isVis {
                    self?.quickLookURL = nil
                }
            }
        }

        Task {
            await refresh()
        }
    }

    public func refresh() async {
        isLoading = true
        scanFilesCount = 0
        scanTotalBytes = 0
        scanCurrentFolder = "Starting scan..."
        formattedScanBytes = "0 B"

        var rootsToScan: [URL] = []
        for loc in sidebarLocations {
            rootsToScan.append(loc.url)
        }

        // Scan installed applications and directories concurrently
        async let appsTask = applicationsService.scanInstalledApplications()

        // Run multi-threaded parallel directory scan
        let (all, categorized) = await scanner.scanDirectoriesConcurrently(
            customRoots: rootsToScan.isEmpty ? nil : rootsToScan
        ) { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.scanFilesCount = progress.filesCount
                self.scanTotalBytes = progress.totalBytes
                self.scanCurrentFolder = progress.currentFolder
                self.formattedScanBytes = ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file)
            }
        }

        let scannedApps = await appsTask
        self.installedApps = scannedApps
        self.allFiles = all
        self.shelves = categorized
        self.isLoading = false
        self.isInitialLoading = false

        // Asynchronously persist scanned files in SQLite index
        Task.detached(priority: .utility) { [all] in
            try? await SQLiteIndexService.shared.upsert(files: all)
        }

        // Launch background multi-threaded duplicate detection without blocking the UI
        startBackgroundDeduplication(files: all)

        // Load cached OCR entries and index new images
        let cached = await OCREngine.shared.allCachedEntries()
        for (url, text) in cached {
            self.ocrTextByFileURL[url] = text
        }

        let imageItems = all.filter { OCREngine.supportedExtensions.contains($0.fileExtension.lowercased()) }
        let unindexed = imageItems.filter { self.ocrTextByFileURL[$0.url] == nil }

        if !unindexed.isEmpty {
            startOCRProcessing(items: unindexed)
        }
    }

    /// Explicitly refreshes the installed applications list
    public func refreshApplications() async {
        let apps = await applicationsService.scanInstalledApplications()
        self.installedApps = apps
    }

    private func startBackgroundDeduplication(files: [FileItem]) {
        deduplicationTask?.cancel()
        isDeduplicating = true
        deduplicationTask = Task.detached(priority: .userInitiated) { [weak self, files] in
            let dupes = await DeduplicationService.shared.findDuplicates(in: files)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.duplicateGroups = dupes
                self.isDeduplicating = false
            }
        }
    }

    private func startOCRProcessing(items: [FileItem]) {
        ocrTask?.cancel()
        isOCRProcessing = true
        ocrTotalCount = items.count
        ocrProcessedCount = 0

        ocrTask = Task.detached(priority: .utility) { [weak self, items] in
            await OCREngine.shared.processBatch(items: items, maxConcurrency: 3) { @MainActor [weak self] url, text in
                self?.recordOCRResult(url: url, text: text)
            }
            await self?.finishOCRProcessing()
        }
    }

    @MainActor
    public func recordOCRResult(url: URL, text: String) {
        self.ocrTextByFileURL[url] = text
        self.ocrProcessedCount += 1
        Task.detached(priority: .utility) {
            try? await SQLiteIndexService.shared.updateOCRText(text, for: url)
        }
    }

    @MainActor
    public func finishOCRProcessing() {
        self.isOCRProcessing = false
    }

    /// Moves a file to macOS Trash and removes it immediately from local state
    @MainActor
    public func trashFile(_ item: FileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.allFiles.removeAll { $0.url == item.url }
                self.currentFolderFiles.removeAll { $0.url == item.url }
                for cat in ShelfCategory.allCases {
                    self.shelves[cat]?.removeAll { $0.url == item.url }
                }
                self.ocrTextByFileURL.removeValue(forKey: item.url)
                self.selectedFileSet.remove(item.url)
                if self.selectedFile?.url == item.url {
                    self.selectedFile = nil
                }

                // Re-evaluate duplicate groups
                self.duplicateGroups = self.duplicateGroups.compactMap { group in
                    let remaining = group.items.filter { $0.url != item.url }
                    if remaining.count > 1 {
                        return DuplicateGroup(hash: group.hash, fileSize: group.fileSize, items: remaining)
                    }
                    return nil
                }
            }
            self.cacheService.invalidate(for: item.url.deletingLastPathComponent())
            Task.detached(priority: .utility) {
                try? await SQLiteIndexService.shared.delete(url: item.url)
            }
        } catch {
            print("Failed to move file to trash: \(error)")
        }
    }

    // Duplicate cleanup actions
    @MainActor
    public func trashDuplicateCopies(in group: DuplicateGroup) {
        for copy in group.duplicateCopies {
            trashFile(copy)
        }
        duplicateGroups.removeAll { $0.id == group.id }
    }

    @MainActor
    public func cleanAllDuplicateCopies() {
        for group in duplicateGroups {
            for copy in group.duplicateCopies {
                trashFile(copy)
            }
        }
        duplicateGroups.removeAll()
    }

    // Folder Trashing
    @MainActor
    public func trashFolder(_ folder: FolderItem) {
        do {
            try FileManager.default.trashItem(at: folder.url, resultingItemURL: nil)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.currentFolderSubfolders.removeAll { $0.url == folder.url }
            }
            self.cacheService.invalidate(for: folder.url)
            self.cacheService.invalidate(for: folder.url.deletingLastPathComponent())
            Task.detached(priority: .utility) {
                try? await SQLiteIndexService.shared.delete(url: folder.url)
                try? await SQLiteIndexService.shared.delete(parentPath: folder.url.path)
            }
        } catch {
            print("Failed to move folder to trash: \(error)")
        }
    }

    // Sidebar Location Management
    @MainActor
    public func addCustomLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add Location"
        panel.message = "Select folder to add to Locations"

        if panel.runModal() == .OK {
            for url in panel.urls {
                let name = url.lastPathComponent
                if !sidebarLocations.contains(where: { $0.url == url }) {
                    let loc = SidebarLocationItem(
                        name: name,
                        url: url,
                        iconSystemName: "folder.fill",
                        isDefault: false
                    )
                    sidebarLocations.append(loc)
                }
            }
            saveSidebarLocations()
            Task {
                await refresh()
            }
        }
    }

    @MainActor
    public func removeSidebarLocation(_ item: SidebarLocationItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarLocations.removeAll { $0.id == item.id }
        }
        saveSidebarLocations()
        if case .location(_, let url) = currentSection, url == item.url {
            currentSection = .home
        }
    }

    @MainActor
    public func trashLocationFolder(_ item: SidebarLocationItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            removeSidebarLocation(item)
            Task {
                await refresh()
            }
        } catch {
            print("Failed to trash location folder: \(error)")
        }
    }

    @MainActor
    public func reorderSidebarLocations(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            sidebarLocations.move(fromOffsets: source, toOffset: destination)
        }
        saveSidebarLocations()
    }

    @MainActor
    public func saveSidebarLocations() {
        SidebarLocationStore.shared.saveLocations(sidebarLocations)
    }

    @MainActor
    public func resetSidebarLocationsToDefaults() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            self.sidebarLocations = SidebarLocationStore.shared.resetToDefaults()
        }
        Task {
            await refresh()
        }
    }

    // Sidebar Section Reordering
    @MainActor
    public func reorderSidebarSections(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            sidebarSections.move(fromOffsets: source, toOffset: destination)
        }
        saveSidebarSections()
    }

    @MainActor
    public func saveSidebarSections() {
        SidebarSectionStore.shared.saveSections(sidebarSections)
    }

    @MainActor
    public func resetSidebarSectionsToDefaults() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            self.sidebarSections = SidebarSectionStore.shared.resetToDefaults()
        }
    }

    @MainActor
    public func removeCustomLocation(_ location: CustomLocation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarLocations.removeAll { $0.url == location.url }
        }
        saveSidebarLocations()
        Task {
            await refresh()
        }
    }

    // Location Folder Browsing
    @MainActor
    public func selectLocation(name: String, url: URL) {
        let stdURL = url.standardizedFileURL
        self.currentLocationName = name
        self.currentLocationRootURL = stdURL
        self.currentFolderURL = stdURL
        self.currentSection = .location(name: name, url: stdURL)
        loadCurrentFolderContents()
    }

    @MainActor
    public func navigateToFolder(_ url: URL) {
        self.currentFolderURL = url.standardizedFileURL
        loadCurrentFolderContents()
    }

    @MainActor
    public func navigateToBreadcrumb(_ url: URL) {
        self.currentFolderURL = url.standardizedFileURL
        loadCurrentFolderContents()
    }

    @MainActor
    public func navigateUp() {
        guard let current = currentFolderURL?.standardizedFileURL,
              let root = currentLocationRootURL?.standardizedFileURL,
              current.path != root.path else { return }
        let parent = current.deletingLastPathComponent().standardizedFileURL
        self.currentFolderURL = parent
        loadCurrentFolderContents()
    }

    public var canNavigateUp: Bool {
        guard let current = currentFolderURL?.standardizedFileURL,
              let root = currentLocationRootURL?.standardizedFileURL else { return false }
        return current.path != root.path
    }

    public var locationBreadcrumbs: [(name: String, url: URL)] {
        guard let root = currentLocationRootURL?.standardizedFileURL,
              let current = currentFolderURL?.standardizedFileURL else { return [] }

        var crumbs: [(name: String, url: URL)] = []
        var cursor = current

        while true {
            let name = (cursor.path == root.path) ? currentLocationName : cursor.lastPathComponent
            crumbs.insert((name: name, url: cursor), at: 0)
            if cursor.path == root.path || cursor.path == "/" {
                break
            }
            cursor = cursor.deletingLastPathComponent().standardizedFileURL
        }

        return crumbs
    }

    @MainActor
    public func loadCurrentFolderContents(forceRefresh: Bool = false) {
        guard let targetURL = currentFolderURL?.standardizedFileURL else { return }

        // 1. Instant 0ms LRU Cache Check
        if !forceRefresh, let cached = cacheService.get(for: targetURL) {
            self.currentFolderSubfolders = cached.subfolders
            self.currentFolderFiles = cached.files

            // Asynchronously refresh in the background from disk / SQLite and update cache seamlessly
            folderLoadTask?.cancel()
            folderLoadTask = Task.detached(priority: .userInitiated) { [weak self, targetURL] in
                let (folders, files) = Self.scanDirectory(at: targetURL)
                if Task.isCancelled { return }

                DirectoryCacheService.shared.set(subfolders: folders, files: files, for: targetURL)
                try? await SQLiteIndexService.shared.upsert(files: files)

                await MainActor.run { [weak self] in
                    guard let self = self, self.currentFolderURL?.standardizedFileURL == targetURL else { return }
                    if self.currentFolderSubfolders != folders {
                        self.currentFolderSubfolders = folders
                    }
                    if self.currentFolderFiles != files {
                        self.currentFolderFiles = files
                    }
                }
            }
            return
        }

        // 2. Cache miss: populate immediately and store in cache for 0ms future retrieval
        let (folders, files) = Self.scanDirectory(at: targetURL)
        self.currentFolderSubfolders = folders
        self.currentFolderFiles = files
        self.cacheService.set(subfolders: folders, files: files, for: targetURL)

        // Asynchronously update SQLite index
        folderLoadTask?.cancel()
        folderLoadTask = Task.detached(priority: .utility) { [files] in
            try? await SQLiteIndexService.shared.upsert(files: files)
        }
    }

    /// Shallow directory scan helper
    nonisolated public static func scanDirectory(at targetURL: URL) -> (subfolders: [FolderItem], files: [FileItem]) {
        let fm = FileManager()
        guard let urls = try? fm.contentsOfDirectory(
            at: targetURL,
            includingPropertiesForKeys: [
                .nameKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isRegularFileKey,
                .isDirectoryKey,
                .isPackageKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], [])
        }

        var folders: [FolderItem] = []
        var files: [FileItem] = []
        let downloadsURL = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isPackageKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ]) else { continue }

            let isPackage = values.isPackage ?? false

            if values.isDirectory == true && !isPackage {
                let childCount = (try? fm.contentsOfDirectory(atPath: url.path).count) ?? 0
                let modDate = values.contentModificationDate ?? Date()
                folders.append(FolderItem(
                    url: url,
                    name: url.lastPathComponent,
                    itemCount: childCount,
                    modificationDate: modDate
                ))
            } else if values.isRegularFile == true {
                let size = Int64(values.fileSize ?? 0)
                let modDate = values.contentModificationDate ?? Date()
                let createDate = values.creationDate ?? modDate

                let isDownloadsFolder = (downloadsURL != nil && url.path.hasPrefix(downloadsURL!.path))
                let isRecent = isDownloadsFolder && (Date().timeIntervalSince(modDate) < 30 * 86400)

                let (origin, originURL) = MetadataService.shared.extractOrigin(for: url)
                let itemCategory = ShelfCategory.category(for: url, isRecentDownload: isRecent)

                let item = FileItem(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    fileSize: size,
                    modificationDate: modDate,
                    creationDate: createDate,
                    category: itemCategory,
                    origin: origin,
                    originURL: originURL
                )
                files.append(item)
            }
        }

        let sortedFolders = folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (sortedFolders, files)
    }

    // Real Metrics
    public var totalFileCount: Int { allFiles.count }
    public var totalByteSize: Int64 { allFiles.reduce(0) { $0 + $1.fileSize } }
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
    }

    public var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }

    // Real Duplicates Metrics
    public var duplicateFiles: [FileItem] {
        duplicateGroups.flatMap(\.duplicateCopies)
    }
    public var duplicateTotalWastedBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
    }
    public var formattedDuplicateSize: String {
        ByteCountFormatter.string(fromByteCount: duplicateTotalWastedBytes, countStyle: .file)
    }

    // Real Forgotten Downloads (files in Downloads older than 30 days)
    public var forgottenDownloads: [FileItem] {
        allFiles.filter {
            $0.category == .recentDownloads || $0.url.path.contains("/Downloads")
        }.filter {
            Date().timeIntervalSince($0.modificationDate) > 30 * 86400
        }
    }
    public var forgottenDownloadsBytes: Int64 {
        forgottenDownloads.reduce(0) { $0 + $1.fileSize }
    }
    public var formattedForgottenDownloadsSize: String {
        ByteCountFormatter.string(fromByteCount: forgottenDownloadsBytes, countStyle: .file)
    }

    // Real Screenshots
    public var screenshots: [FileItem] {
        allFiles.filter {
            let name = $0.name.lowercased()
            return name.contains("screenshot") || name.contains("screen shot") || name.hasPrefix("cleanshot")
        }
    }
    public var oldScreenshots: [FileItem] {
        screenshots.filter { Date().timeIntervalSince($0.modificationDate) > 14 * 86400 }
    }
    public var oldScreenshotsBytes: Int64 {
        oldScreenshots.reduce(0) { $0 + $1.fileSize }
    }
    public var formattedOldScreenshotsSize: String {
        ByteCountFormatter.string(fromByteCount: oldScreenshotsBytes, countStyle: .file)
    }

    // Real Large Files (> 50 MB)
    public var largeFiles: [FileItem] {
        allFiles.filter { $0.fileSize > 50 * 1024 * 1024 }
    }
    public var largeFilesBytes: Int64 {
        largeFiles.reduce(0) { $0 + $1.fileSize }
    }
    public var formattedLargeFilesSize: String {
        ByteCountFormatter.string(fromByteCount: largeFilesBytes, countStyle: .file)
    }

    // Real Total Clean Up potential
    public var totalCleanupBytes: Int64 {
        duplicateTotalWastedBytes + forgottenDownloadsBytes + oldScreenshotsBytes
    }
    public var formattedCleanupTotal: String {
        ByteCountFormatter.string(fromByteCount: totalCleanupBytes, countStyle: .file)
    }

    // Real Download origins summary (Only real files with real origins!)
    public var downloadedFromSummaries: [OriginSummary] {
        let grouped = Dictionary(grouping: allFiles.filter { $0.origin != .unknown }, by: { $0.origin })
        return grouped.map { origin, items in
            OriginSummary(
                origin: origin,
                count: items.count,
                totalSize: items.reduce(0) { $0 + $1.fileSize },
                sampleItems: Array(items.prefix(3))
            )
        }.sorted { $0.count > $1.count }
    }

    // Search query parsing
    private func parseSearchQuery() {
        let result = NLQueryParser.parse(searchQuery)
        self.activeFilter = result.filter
        self.activeChips = result.chips
    }

    public func removeChip(_ chip: FilterChip) {
        var updated = searchQuery
        switch chip.type {
        case .screenshot:
            updated = removePattern(#"\bscreenshots?\b"#, from: updated)
        case .fileExtension(let ext):
            updated = removePattern(#"\b"# + NSRegularExpression.escapedPattern(for: ext) + #"s?\b"#, from: updated)
        case .origin(let origin):
            updated = removePattern(#"\b(?:from|via)\s+"# + NSRegularExpression.escapedPattern(for: origin.displayName.lowercased()) + #"\b"#, from: updated)
            if origin == .chrome {
                updated = removePattern(#"\b(?:from|via)\s+(?:google\s+)?chrome\b"#, from: updated)
            }
        case .category(let cat):
            updated = removePattern(#"\b"# + NSRegularExpression.escapedPattern(for: cat.rawValue) + #"\b"#, from: updated)
            let altWords = ["images", "photos", "videos", "documents", "docs", "code", "archives", "music", "audio"]
            for word in altWords {
                updated = removePattern(#"\b"# + word + #"\b"#, from: updated)
            }
        case .dateRange:
            let datePatterns = [
                #"\btoday\b"#,
                #"\byesterday\b"#,
                #"\bthis\s+week\b"#,
                #"\blast\s+week\b"#,
                #"\bthis\s+month\b"#,
                #"\blast\s+month\b"#,
                #"\bolder\s+than\s+\d+\s*(?:days?|weeks?|months?|years?)\b"#,
                #"\blast\s+\d+\s*(?:days?|weeks?|months?)\b"#
            ]
            for p in datePatterns {
                updated = removePattern(p, from: updated)
            }
        case .fileSize:
            let sizePatterns = [
                #"(?:>|over|more than|greater than)\s*\d+(?:\.\d+)?\s*(?:kb|mb|gb|b)?"#,
                #"(?:<|under|less than)\s*\d+(?:\.\d+)?\s*(?:kb|mb|gb|b)?"#,
                #"\blarge\b"#,
                #"\bsmall\b"#
            ]
            for p in sizePatterns {
                updated = removePattern(p, from: updated)
            }
        case .keyword(let kw):
            updated = removePattern(#"\b"# + NSRegularExpression.escapedPattern(for: kw) + #"\b"#, from: updated)
        }

        searchQuery = updated.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    public func toggleSuggestion(_ suggestion: SuggestionChipItem) {
        if isSuggestionActive(suggestion) {
            if let chip = activeChips.first(where: { chipsMatch($0, suggestion) }) {
                removeChip(chip)
            }
        } else {
            let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                searchQuery = suggestion.queryToken
            } else {
                searchQuery = trimmed + " " + suggestion.queryToken
            }
        }
    }

    public func clearAllFilters() {
        searchQuery = ""
        resetFilters()
    }

    private func isSuggestionActive(_ suggestion: SuggestionChipItem) -> Bool {
        return activeChips.contains { chipsMatch($0, suggestion) }
    }

    private func chipsMatch(_ chip: FilterChip, _ suggestion: SuggestionChipItem) -> Bool {
        switch (chip.type, suggestion.chipType) {
        case (.screenshot, .screenshot):
            return true
        case (.origin(let o1), .origin(let o2)):
            return o1 == o2
        case (.category(let c1), .category(let c2)):
            return c1 == c2
        case (.fileExtension(let e1), .fileExtension(let e2)):
            return e1.lowercased() == e2.lowercased()
        case (.fileSize, .fileSize):
            return chip.title == suggestion.title
        case (.dateRange, .dateRange):
            return chip.title == suggestion.title
        default:
            return false
        }
    }

    private func removePattern(_ pattern: String, from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    @MainActor
    public func resetFilters() {
        selectedCategoryFilter = nil
        selectedOriginFilter = nil
        selectedSizeFilter = .all
        selectedDateFilter = .all
        searchQuery = ""
        if case .downloadedFrom = currentSection {
            currentSection = .home
        }
    }

    public var hasActiveFilters: Bool {
        if selectedCategoryFilter != nil || selectedOriginFilter != nil || selectedSizeFilter != .all || selectedDateFilter != .all || !searchQuery.isEmpty {
            return true
        }
        if case .downloadedFrom = currentSection {
            return true
        }
        return false
    }

    public var activeFilterCount: Int {
        var count = 0
        if selectedCategoryFilter != nil { count += 1 }
        if selectedOriginFilter != nil { count += 1 }
        if selectedSizeFilter != .all { count += 1 }
        if selectedDateFilter != .all { count += 1 }
        if case .downloadedFrom = currentSection { count += 1 }
        return count
    }

    // Display items according to active navigation, filters, and sorting
    public var displayedItems: [DisplayItem] {
        var candidateFiles: [FileItem] = []

        switch currentSection {
        case .home:
            candidateFiles = allFiles
        case .recents:
            candidateFiles = shelves[.recentDownloads] ?? allFiles
        case .category(let cat):
            candidateFiles = shelves[cat] ?? []
        case .applications:
            candidateFiles = []
        case .largeFiles:
            candidateFiles = largeFiles
        case .screenshots:
            candidateFiles = screenshots
        case .duplicates:
            candidateFiles = duplicateFiles
        case .cleanUp:
            candidateFiles = duplicateFiles + forgottenDownloads + oldScreenshots
        case .downloadedFromOverview:
            candidateFiles = allFiles.filter { $0.origin != .unknown }
        case .downloadedFrom(let origin):
            candidateFiles = allFiles.filter { $0.origin == origin }
        case .location:
            candidateFiles = currentFolderFiles
        }

        // Apply Category Filter (if specified in toolbar filter dropdown)
        if let cat = selectedCategoryFilter {
            candidateFiles = candidateFiles.filter { $0.category == cat }
        }

        // Apply Origin Filter (if specified in toolbar filter dropdown)
        if let origin = selectedOriginFilter {
            candidateFiles = candidateFiles.filter { $0.origin == origin }
        }

        // Apply Size Filter
        if selectedSizeFilter != .all {
            candidateFiles = candidateFiles.filter { selectedSizeFilter.matches(fileSize: $0.fileSize) }
        }

        // Apply Date Filter
        if selectedDateFilter != .all {
            candidateFiles = candidateFiles.filter { selectedDateFilter.matches(date: $0.modificationDate) }
        }

        // Apply NLP / Keyword / OCR Filters
        var matchedItems: [DisplayItem] = []
        if activeFilter.isEmpty {
            matchedItems = candidateFiles.map { DisplayItem(item: $0, isOCRMatch: false) }
        } else {
            for item in candidateFiles {
                let ocr = ocrTextByFileURL[item.url]
                let (matches, matchedByOCR) = activeFilter.matchEvaluation(for: item, ocrText: ocr)
                if matches {
                    matchedItems.append(DisplayItem(item: item, isOCRMatch: matchedByOCR))
                }
            }
        }

        // Apply Sorting
        matchedItems.sort { (d1: DisplayItem, d2: DisplayItem) -> Bool in
            let f1 = d1.item
            let f2 = d2.item
            let isAscending = (selectedSortOrder == .ascending)

            switch selectedSortOption {
            case .dateModified:
                return isAscending ? f1.modificationDate < f2.modificationDate : f1.modificationDate > f2.modificationDate
            case .dateCreated:
                return isAscending ? f1.creationDate < f2.creationDate : f1.creationDate > f2.creationDate
            case .name:
                let cmp = f1.name.localizedCaseInsensitiveCompare(f2.name)
                return isAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .size:
                return isAscending ? f1.fileSize < f2.fileSize : f1.fileSize > f2.fileSize
            }
        }

        return matchedItems
    }

    public var displayedFiles: [FileItem] {
        displayedItems.map(\.item)
    }

    /// Filtered and sorted installed applications
    public var displayedApplications: [InstalledAppItem] {
        var apps = installedApps

        // Apply Search Query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            apps = apps.filter { app in
                app.name.lowercased().contains(query) ||
                app.bundleIdentifier.lowercased().contains(query)
            }
        }

        // Apply Size Filter
        if selectedSizeFilter != .all {
            apps = apps.filter { selectedSizeFilter.matches(fileSize: $0.fileSize) }
        }

        // Apply Date Filter
        if selectedDateFilter != .all {
            apps = apps.filter { selectedDateFilter.matches(date: $0.modificationDate) }
        }

        // Apply Sorting
        let isAscending = (selectedSortOrder == .ascending)
        apps.sort { a1, a2 in
            switch selectedSortOption {
            case .name:
                let cmp = a1.name.localizedCaseInsensitiveCompare(a2.name)
                return isAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .size:
                return isAscending ? a1.fileSize < a2.fileSize : a1.fileSize > a2.fileSize
            case .dateModified, .dateCreated:
                return isAscending ? a1.modificationDate < a2.modificationDate : a1.modificationDate > a2.modificationDate
            }
        }

        return apps
    }

    // Filtered & sorted duplicate groups for DuplicatesView
    public var displayedDuplicateGroups: [DuplicateGroup] {
        var groups = duplicateGroups

        // Filter by size
        if selectedSizeFilter != .all {
            groups = groups.filter { selectedSizeFilter.matches(fileSize: $0.fileSize) }
        }

        // Filter by category if set
        if let cat = selectedCategoryFilter {
            groups = groups.filter { group in
                group.items.contains { $0.category == cat }
            }
        }

        // Filter by origin if set
        if let origin = selectedOriginFilter {
            groups = groups.filter { group in
                group.items.contains { $0.origin == origin }
            }
        }

        // Sort groups
        let isAscending = (selectedSortOrder == .ascending)
        groups.sort { g1, g2 in
            switch selectedSortOption {
            case .size:
                return isAscending ? g1.wastedBytes < g2.wastedBytes : g1.wastedBytes > g2.wastedBytes
            case .name:
                let n1 = g1.original?.name ?? ""
                let n2 = g2.original?.name ?? ""
                let cmp = n1.localizedCaseInsensitiveCompare(n2)
                return isAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .dateModified, .dateCreated:
                let d1 = g1.original?.modificationDate ?? Date.distantPast
                let d2 = g2.original?.modificationDate ?? Date.distantPast
                return isAscending ? d1 < d2 : d1 > d2
            }
        }

        return groups
    }

    // MARK: - Native macOS Quick Look
    public func toggleQuickLook() {
        guard let file = selectedFile else {
            closeQuickLook()
            return
        }
        if isQuickLookVisible {
            closeQuickLook()
        } else {
            openQuickLook(for: file.url)
        }
    }

    public func openQuickLook(for url: URL) {
        quickLookURL = url
        isQuickLookVisible = true
        QuickLookManager.shared.show(url: url)
    }

    public func closeQuickLook() {
        quickLookURL = nil
        isQuickLookVisible = false
        QuickLookManager.shared.close()
    }

    public func updateQuickLookIfVisible() {
        if isQuickLookVisible || QuickLookManager.shared.isVisible {
            if let file = selectedFile {
                quickLookURL = file.url
                QuickLookManager.shared.updateSelection(file.url)
            } else {
                closeQuickLook()
            }
        }
    }

    // MARK: - Multi-File Selection
    public func handleFileClick(_ file: FileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            toggleFileSelection(file)
            // Do not open or force inspector during multi-selection
        } else if flags.contains(.shift) {
            selectFileRange(to: file)
            // Do not open or force inspector during range selection
        } else {
            selectSingleFile(file)
            selectedDuplicateGroup = nil
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isDetailInspectorVisible = true
            }
        }
    }

    public func selectSingleFile(_ file: FileItem) {
        selectedFolder = nil
        selectedFile = file
        selectedFileSet = [file.url]
    }

    public func toggleFileSelection(_ file: FileItem) {
        selectedFolder = nil
        MultiSelectionHelper.toggle(item: file.url, in: &selectedFileSet)
        if selectedFileSet.contains(file.url) {
            selectedFile = file
        } else {
            selectedFile = displayedFiles.first(where: { selectedFileSet.contains($0.url) })
        }
    }

    public func selectFileRange(to file: FileItem) {
        selectedFolder = nil
        let allItemURLs = displayedFiles.map { $0.url }
        let anchorURL = selectedFile?.url ?? file.url
        let rangeURLs = MultiSelectionHelper.rangeSelection(from: anchorURL, to: file.url, in: allItemURLs)
        selectedFileSet.formUnion(rangeURLs)
        selectedFile = file
    }

    public func selectSingleFolder(_ folder: FolderItem) {
        selectedFile = nil
        selectedFileSet.removeAll()
        selectedFolder = folder
        closeQuickLook()
    }

    public func clearSelection() {
        selectedFile = nil
        selectedFileSet.removeAll()
        selectedFolder = nil
        closeQuickLook()
    }

    // MARK: - Keyboard Navigation (Finder-Style)
    public func openCurrentSelection() {
        if let folder = selectedFolder {
            navigateToFolder(folder.url)
        } else if let file = selectedFile {
            NSWorkspace.shared.open(file.url)
        }
    }

    public func navigateSelection(direction: NavigationDirection, columnsCount: Int? = nil) {
        let cols: Int
        if layoutMode == .list {
            cols = 1
        } else {
            cols = columnsCount ?? max(1, Int(800 / (gridIconSize + 18)))
        }

        let folders = currentFolderSubfolders
        let files = displayedFiles

        if !folders.isEmpty || !files.isEmpty {
            navigateFolderAndFiles(direction: direction, columns: cols, folders: folders, files: files)
        } else if !displayedFiles.isEmpty {
            navigateOnlyFiles(direction: direction, columns: cols, files: displayedFiles)
        }
    }

    private func navigateOnlyFiles(direction: NavigationDirection, columns: Int, files: [FileItem]) {
        let currentIndex = files.firstIndex(where: { $0.url == selectedFile?.url })
        guard let newIndex = SelectionNavigator.navigate(
            from: currentIndex,
            direction: direction,
            totalCount: files.count,
            columns: columns
        ) else { return }

        let targetFile = files[newIndex]
        selectSingleFile(targetFile)
    }

    private func navigateFolderAndFiles(
        direction: NavigationDirection,
        columns: Int,
        folders: [FolderItem],
        files: [FileItem]
    ) {
        let folderCount = folders.count
        let fileCount = files.count
        let totalCount = folderCount + fileCount
        guard totalCount > 0 else { return }

        var currentIndex: Int? = nil
        if let folder = selectedFolder, let idx = folders.firstIndex(where: { $0.url == folder.url }) {
            currentIndex = idx
        } else if let file = selectedFile, let idx = files.firstIndex(where: { $0.url == file.url }) {
            currentIndex = folderCount + idx
        }

        guard let newIndex = SelectionNavigator.navigate(
            from: currentIndex,
            direction: direction,
            totalCount: totalCount,
            columns: columns
        ) else { return }

        if newIndex < folderCount {
            selectSingleFolder(folders[newIndex])
        } else {
            let fileIndex = newIndex - folderCount
            selectSingleFile(files[fileIndex])
        }
    }
}

public final class FileScannerService: Sendable {
    public init() {}

    /// High-performance multi-threaded directory scan using Swift Concurrency TaskGroups
    public func scanDirectoriesConcurrently(
        customRoots: [URL]? = nil,
        progressHandler: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> (all: [FileItem], categorized: [ShelfCategory: [FileItem]]) {
        let fileManager = FileManager.default
        let standardRoots: [URL]
        if let custom = customRoots {
            standardRoots = custom
        } else {
            standardRoots = [
                fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .musicDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
        }

        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first

        // Common directory names to skip for blazing speed and zero hang on developer caches
        let skippedDirectoryNames: Set<String> = [
            ".git", ".svn", ".hg", "node_modules", "DerivedData", "Pods",
            ".build", "build", "Caches", ".npm", ".cargo", ".rustup",
            ".cache", ".Trash", "Library"
        ]

        // Thread-safe progress accumulator
        actor ProgressCounter {
            private(set) var totalFiles: Int = 0
            private(set) var totalBytes: Int64 = 0

            func add(files: Int, bytes: Int64) -> (files: Int, bytes: Int64) {
                totalFiles += files
                totalBytes += bytes
                return (totalFiles, totalBytes)
            }
        }

        let progressCounter = ProgressCounter()

        // Scan all root directories in parallel across worker threads
        let collectedByRoot: [[FileItem]] = await withTaskGroup(of: [FileItem].self) { group in
            for root in standardRoots {
                group.addTask {
                    let fm = FileManager()
                    guard let enumerator = fm.enumerator(
                        at: root,
                        includingPropertiesForKeys: [
                            .nameKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .creationDateKey,
                            .isRegularFileKey,
                            .isDirectoryKey,
                            .isPackageKey
                        ],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { return [] }

                    var rootFiles: [FileItem] = []
                    var batchCount = 0
                    var batchBytes: Int64 = 0
                    let rootName = root.lastPathComponent

                    while let fileURL = enumerator.nextObject() as? URL {
                        // Max limit per root for instantaneous responsiveness
                        if rootFiles.count >= 4000 { break }

                        // Fast directory skip check
                        if let isDir = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == true {
                            if skippedDirectoryNames.contains(fileURL.lastPathComponent) {
                                enumerator.skipDescendants()
                                continue
                            }
                        }

                        guard let values = try? fileURL.resourceValues(forKeys: [
                            .isRegularFileKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .creationDateKey
                        ]), values.isRegularFile == true else {
                            continue
                        }

                        let size = Int64(values.fileSize ?? 0)
                        let modDate = values.contentModificationDate ?? Date()
                        let createDate = values.creationDate ?? modDate

                        let isDownloadsFolder = (downloadsURL != nil && fileURL.path.hasPrefix(downloadsURL!.path))
                        let isRecent = isDownloadsFolder && (Date().timeIntervalSince(modDate) < 30 * 86400)

                        let (origin, originURL) = MetadataService.shared.extractOrigin(for: fileURL)
                        let itemCategory = ShelfCategory.category(for: fileURL, isRecentDownload: isRecent)

                        let item = FileItem(
                            url: fileURL,
                            name: fileURL.deletingPathExtension().lastPathComponent,
                            fileSize: size,
                            modificationDate: modDate,
                            creationDate: createDate,
                            category: itemCategory,
                            origin: origin,
                            originURL: originURL
                        )

                        rootFiles.append(item)
                        batchCount += 1
                        batchBytes += size

                        // Stream progress periodically
                        if batchCount % 60 == 0 {
                            let (currentFiles, currentBytes) = await progressCounter.add(files: batchCount, bytes: batchBytes)
                            batchCount = 0
                            batchBytes = 0
                            progressHandler?(ScanProgress(
                                filesCount: currentFiles,
                                totalBytes: currentBytes,
                                currentFolder: rootName,
                                isComplete: false
                            ))
                        }
                    }

                    if batchCount > 0 {
                        let (currentFiles, currentBytes) = await progressCounter.add(files: batchCount, bytes: batchBytes)
                        progressHandler?(ScanProgress(
                            filesCount: currentFiles,
                            totalBytes: currentBytes,
                            currentFolder: rootName,
                            isComplete: false
                        ))
                    }

                    return rootFiles
                }
            }

            var results: [[FileItem]] = []
            for await files in group {
                results.append(files)
            }
            return results
        }

        // Merge and deduplicate by URL (in case custom location overlaps with standard root)
        var seenURLs: Set<URL> = []
        var allFiles: [FileItem] = []
        var categorized: [ShelfCategory: [FileItem]] = [:]

        for cat in ShelfCategory.allCases {
            categorized[cat] = []
        }

        for list in collectedByRoot {
            for item in list {
                if seenURLs.insert(item.url).inserted {
                    allFiles.append(item)
                    categorized[item.category]?.append(item)

                    // Also add recent downloads to recentDownloads shelf
                    let isDownloads = (downloadsURL != nil && item.url.path.hasPrefix(downloadsURL!.path))
                    let isRecent = isDownloads && (Date().timeIntervalSince(item.modificationDate) < 30 * 86400)
                    if isRecent && item.category != .recentDownloads {
                        categorized[.recentDownloads]?.append(item)
                    }
                }
            }
        }

        // Sort items by modification date
        for cat in ShelfCategory.allCases {
            categorized[cat]?.sort { $0.modificationDate > $1.modificationDate }
        }
        allFiles.sort { $0.modificationDate > $1.modificationDate }

        progressHandler?(ScanProgress(
            filesCount: allFiles.count,
            totalBytes: allFiles.reduce(0) { $0 + $1.fileSize },
            currentFolder: "Done",
            isComplete: true
        ))

        return (allFiles, categorized)
    }

    public func scanDirectories(customRoots: [URL]? = nil) async -> (all: [FileItem], categorized: [ShelfCategory: [FileItem]]) {
        return await scanDirectoriesConcurrently(customRoots: customRoots, progressHandler: nil)
    }
}
