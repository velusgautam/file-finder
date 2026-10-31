import Testing
import Foundation
@testable import FileFinderLib

@Suite("Installed Applications Tests", .serialized)
struct ApplicationsTests {

    @Test("InstalledAppItem properties and formatted helpers")
    func testInstalledAppItemProperties() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let date = Date(timeIntervalSince1970: 1700000000)
        let item = InstalledAppItem(
            name: "Safari",
            url: url,
            bundleIdentifier: "com.apple.Safari",
            version: "18.0",
            fileSize: 15_500_000,
            modificationDate: date
        )

        #expect(item.id == url)
        #expect(item.name == "Safari")
        #expect(item.url == url)
        #expect(item.bundleIdentifier == "com.apple.Safari")
        #expect(item.version == "18.0")
        #expect(item.fileSize == 15_500_000)
        #expect(!item.formattedSize.isEmpty)
        #expect(!item.relativeDateString.isEmpty)

        let sameItem = InstalledAppItem(
            name: "Safari Different",
            url: url,
            bundleIdentifier: "com.apple.Safari"
        )
        #expect(item == sameItem)
        #expect(item.hashValue == sameItem.hashValue)
    }

    @Test("NavigationSection applications case")
    func testNavigationSectionApplications() {
        let section = NavigationSection.applications
        #expect(section.title == "Applications")
    }

    @Test("ApplicationsService mock directory scan and deduplication")
    func testApplicationsServiceDeduplication() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create Mock App A
        let appA = tempDir.appendingPathComponent("Alpha.app")
        let contentsA = appA.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsA, withIntermediateDirectories: true)
        let plistA = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>Alpha</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.alpha</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
        </dict>
        </plist>
        """
        try plistA.write(to: contentsA.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        let binA = contentsA.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: binA, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 1024).write(to: binA.appendingPathComponent("Alpha"))

        // Create Mock App B
        let appB = tempDir.appendingPathComponent("Beta.app")
        let contentsB = appB.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsB, withIntermediateDirectories: true)
        let plistB = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>Beta</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.beta</string>
            <key>CFBundleShortVersionString</key>
            <string>2.1.0</string>
        </dict>
        </plist>
        """
        try plistB.write(to: contentsB.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        // Create Duplicate App B with the same bundle ID
        let subDir = tempDir.appendingPathComponent("Utilities")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let dupAppB = subDir.appendingPathComponent("Beta Duplicate.app")
        let dupContentsB = dupAppB.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: dupContentsB, withIntermediateDirectories: true)
        try plistB.write(to: dupContentsB.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let service = ApplicationsService()
        let apps = await service.scanInstalledApplications(customSearchDirectories: [tempDir])

        // Alpha and Beta should be found, but duplicate Beta should be skipped!
        #expect(apps.count == 2)
        #expect(apps[0].name == "Alpha")
        #expect(apps[0].bundleIdentifier == "com.example.alpha")
        #expect(apps[0].version == "1.0.0")
        #expect(apps[0].fileSize >= 1024)

        #expect(apps[1].name == "Beta")
        #expect(apps[1].bundleIdentifier == "com.example.beta")
        #expect(apps[1].version == "2.1.0")
    }

    @Test("ApplicationsService real system applications scan")
    func testRealApplicationsScan() async {
        let service = ApplicationsService()
        let apps = await service.scanInstalledApplications()

        #expect(!apps.isEmpty)
        // Check alphabetical sorting
        for i in 0..<(apps.count - 1) {
            let cmp = apps[i].name.localizedCaseInsensitiveCompare(apps[i + 1].name)
            #expect(cmp != .orderedDescending, "Apps must be sorted alphabetically: \(apps[i].name) vs \(apps[i + 1].name)")
        }

        // Verify deduplication: no duplicate bundle IDs among non-empty bundle IDs
        var seenIDs = Set<String>()
        for app in apps where !app.bundleIdentifier.isEmpty {
            #expect(!seenIDs.contains(app.bundleIdentifier), "Duplicate bundle identifier found: \(app.bundleIdentifier)")
            seenIDs.insert(app.bundleIdentifier)
        }
    }

    @Test("ScannerViewModel application scanning and displayedApplications filtering")
    @MainActor
    func testScannerViewModelApplications() async {
        let vm = ScannerViewModel()
        #expect(vm.currentSection == .home)

        vm.currentSection = .applications
        #expect(vm.currentSection == .applications)
        #expect(vm.currentSection.title == "Applications")

        await vm.refreshApplications()
        #expect(vm.installedAppsCount == vm.installedApps.count)
        #expect(vm.installedAppsCount > 0)

        // Test search query filtering
        let firstAppName = vm.installedApps.first?.name ?? ""
        if !firstAppName.isEmpty {
            vm.searchQuery = String(firstAppName.prefix(3))
            let filtered = vm.displayedApplications
            #expect(!filtered.isEmpty)
            #expect(filtered.allSatisfy {
                $0.name.localizedCaseInsensitiveContains(vm.searchQuery) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(vm.searchQuery)
            })
            vm.searchQuery = ""
        }

        // Test sorting
        vm.selectedSortOption = .name
        vm.selectedSortOrder = .ascending
        let ascNames = vm.displayedApplications.map(\.name)
        vm.selectedSortOrder = .descending
        let descNames = vm.displayedApplications.map(\.name)
        #expect(ascNames == Array(descNames.reversed()))
    }
}
