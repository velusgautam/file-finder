import Testing
import Foundation
@testable import FileFinderLib

@Suite("App Systems Tests (Clean Up Rules, Saved Searches & Shortcuts)", .serialized)
struct AppSystemsTests {

    // MARK: - Helper Methods

    private func makeFile(
        path: String,
        name: String,
        ext: String,
        size: Int64 = 1024 * 1024,
        daysAgo: Double = 0,
        category: ShelfCategory = .documents,
        origin: DownloadOrigin = .unknown
    ) -> FileItem {
        let referenceDate = Date(timeIntervalSince1970: 1730000000) // Fixed deterministic reference
        let modDate = referenceDate.addingTimeInterval(-daysAgo * 86400)
        let fullPath = "\(path)/\(name).\(ext)"
        let url = URL(fileURLWithPath: fullPath)

        return FileItem(
            url: url,
            name: "\(name).\(ext)",
            fileSize: size,
            modificationDate: modDate,
            creationDate: modDate,
            category: category,
            origin: origin,
            originURL: nil
        )
    }

    // MARK: - 1. Clean Up Rule: Old Installers Evaluation Tests

    @Test("Old installers evaluation respects installer extensions (.dmg, .pkg, .iso)")
    func testOldInstallersExtensions() {
        let engine = CleanUpRulesEngine.shared
        let refDate = Date(timeIntervalSince1970: 1730000000)

        let dmgFile = makeFile(path: "/Users/test/Downloads", name: "Xcode", ext: "dmg", daysAgo: 45)
        let pkgFile = makeFile(path: "/Users/test/Downloads", name: "Node", ext: "pkg", daysAgo: 35)
        let isoFile = makeFile(path: "/Users/test/Downloads", name: "Ubuntu", ext: "iso", daysAgo: 60)
        let pdfFile = makeFile(path: "/Users/test/Downloads", name: "Invoice", ext: "pdf", daysAgo: 50)
        let zipFile = makeFile(path: "/Users/test/Downloads", name: "Archive", ext: "zip", daysAgo: 50)

        let candidates = engine.evaluateOldInstallers(
            in: [dmgFile, pkgFile, isoFile, pdfFile, zipFile],
            olderThanDays: 30,
            referenceDate: refDate,
            filterByDownloadsLocation: true
        )

        let matchedNames = Set(candidates.map { $0.name })
        #expect(matchedNames.contains("Xcode.dmg"))
        #expect(matchedNames.contains("Node.pkg"))
        #expect(matchedNames.contains("Ubuntu.iso"))
        #expect(!matchedNames.contains("Invoice.pdf"))
        #expect(!matchedNames.contains("Archive.zip"))
        #expect(candidates.count == 3)
    }

    @Test("Old installers evaluation respects date thresholds")
    func testOldInstallersDateThreshold() {
        let engine = CleanUpRulesEngine.shared
        let refDate = Date(timeIntervalSince1970: 1730000000)

        let oldDmg = makeFile(path: "/Users/test/Downloads", name: "OldApp", ext: "dmg", daysAgo: 31)
        let freshDmg = makeFile(path: "/Users/test/Downloads", name: "FreshApp", ext: "dmg", daysAgo: 10)
        let exactly30DaysDmg = makeFile(path: "/Users/test/Downloads", name: "BorderApp", ext: "dmg", daysAgo: 30)

        // 30-day threshold
        let candidates30 = engine.evaluateOldInstallers(
            in: [oldDmg, freshDmg, exactly30DaysDmg],
            olderThanDays: 30,
            referenceDate: refDate,
            filterByDownloadsLocation: true
        )

        #expect(candidates30.contains { $0.name == "OldApp.dmg" })
        #expect(candidates30.contains { $0.name == "BorderApp.dmg" })
        #expect(!candidates30.contains { $0.name == "FreshApp.dmg" })

        // 14-day threshold
        let candidates14 = engine.evaluateOldInstallers(
            in: [oldDmg, freshDmg, exactly30DaysDmg],
            olderThanDays: 14,
            referenceDate: refDate,
            filterByDownloadsLocation: true
        )
        #expect(candidates14.count == 2)
    }

    @Test("Old installers evaluation respects folder location filtering")
    func testOldInstallersLocationFiltering() {
        let engine = CleanUpRulesEngine.shared
        let refDate = Date(timeIntervalSince1970: 1730000000)

        let downloadsDmg = makeFile(path: "/Users/test/Downloads", name: "SetupInDownloads", ext: "dmg", daysAgo: 40)
        let documentsDmg = makeFile(path: "/Users/test/Documents", name: "SetupInDocuments", ext: "dmg", daysAgo: 40)

        // With location filter enabled (Downloads only)
        let filtered = engine.evaluateOldInstallers(
            in: [downloadsDmg, documentsDmg],
            olderThanDays: 30,
            referenceDate: refDate,
            filterByDownloadsLocation: true
        )
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "SetupInDownloads.dmg")

        // Without location filter (any folder)
        let allFolders = engine.evaluateOldInstallers(
            in: [downloadsDmg, documentsDmg],
            olderThanDays: 30,
            referenceDate: refDate,
            filterByDownloadsLocation: false
        )
        #expect(allFolders.count == 2)
    }

    // MARK: - 2. Clean Up Rule: Screenshots Organization Tests

    @Test("Screenshots evaluation recognizes macOS screenshot patterns and skips organized files")
    func testScreenshotsEvaluation() {
        let engine = CleanUpRulesEngine.shared

        let desktopScreenshot = makeFile(path: "/Users/test/Desktop", name: "Screenshot 2026-10-01 at 12.00.00", ext: "png", category: .images)
        let downloadsScreenshot = makeFile(path: "/Users/test/Downloads", name: "Screen Shot 2026-09-15", ext: "jpg", category: .images)
        let regularPhoto = makeFile(path: "/Users/test/Desktop", name: "Vacation_Photo", ext: "png", category: .images)
        let nonImageText = makeFile(path: "/Users/test/Desktop", name: "Screenshot_Notes", ext: "txt", category: .documents)
        let alreadyOrganized = makeFile(path: "/Users/test/Desktop/Screenshots/2026-10", name: "Screenshot 2026-10-02", ext: "png", category: .images)

        let candidates = engine.evaluateScreenshotsToOrganize(
            in: [desktopScreenshot, downloadsScreenshot, regularPhoto, nonImageText, alreadyOrganized],
            filterLocations: true
        )

        let matchedNames = Set(candidates.map { $0.name })
        #expect(matchedNames.contains("Screenshot 2026-10-01 at 12.00.00.png"))
        #expect(matchedNames.contains("Screen Shot 2026-09-15.jpg"))
        #expect(!matchedNames.contains("Vacation_Photo.png"))
        #expect(!matchedNames.contains("Screenshot_Notes.txt"))
        #expect(!matchedNames.contains("Screenshot 2026-10-02.png"))
        #expect(candidates.count == 2)
    }

    // MARK: - 3. Saved Searches Model & Store Tests

    @Test("SavedSearch model JSON encoding and decoding")
    func testSavedSearchSerialization() throws {
        let original = SavedSearch(
            id: UUID(),
            name: "Financial PDFs",
            query: "type:pdf invoices",
            createdAt: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedSearch.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.query == original.query)
        #expect(abs(decoded.createdAt.timeIntervalSince1970 - original.createdAt.timeIntervalSince1970) < 0.001)
    }

    @Test("SavedSearch query match criteria evaluation")
    func testSavedSearchMatchEvaluation() {
        let pdfSearch = SavedSearch(name: "PDFs", query: "type:pdf")
        let screenshotSearch = SavedSearch(name: "Screenshots", query: "screenshots")
        let largeSearch = SavedSearch(name: "Large", query: "> 5MB")

        let pdfFile = makeFile(path: "/tmp", name: "Report", ext: "pdf", size: 2 * 1024 * 1024, category: .documents)
        let screenshotFile = makeFile(path: "/tmp", name: "Screenshot 2026-10-10", ext: "png", size: 1024 * 1024, category: .images)
        let largeFile = makeFile(path: "/tmp", name: "Video", ext: "mp4", size: 10 * 1024 * 1024, category: .videos)

        // PDF query
        #expect(pdfSearch.matches(file: pdfFile))
        #expect(!pdfSearch.matches(file: screenshotFile))

        // Screenshot query
        #expect(screenshotSearch.matches(file: screenshotFile))
        #expect(!screenshotSearch.matches(file: pdfFile))

        // Size query
        #expect(largeSearch.matches(file: largeFile))
        #expect(!largeSearch.matches(file: pdfFile))
    }

    @Test("SavedSearchStore persistence, addition, and removal")
    func testSavedSearchStoreOperations() {
        let testDefaults = UserDefaults(suiteName: "test_saved_searches_\(UUID().uuidString)")!
        let store = SavedSearchStore(userDefaults: testDefaults)

        // Defaults loaded when empty
        let initial = store.loadSavedSearches()
        #expect(!initial.isEmpty)

        // Add search
        let custom = SavedSearch(name: "My Custom Search", query: "type:zip > 50mb")
        store.addSavedSearch(custom)

        let afterAdd = store.loadSavedSearches()
        #expect(afterAdd.contains { $0.id == custom.id })

        // Remove search
        store.removeSavedSearch(id: custom.id)
        let afterRemove = store.loadSavedSearches()
        #expect(!afterRemove.contains { $0.id == custom.id })

        // Reset to defaults
        let reset = store.resetToDefaults()
        #expect(reset.count == SavedSearchStore.defaultSearches.count)
    }
}
