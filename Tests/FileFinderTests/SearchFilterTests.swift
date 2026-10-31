import Testing
import Foundation
import ImageIO
import Vision
import SQLite3
@testable import FileFinderLib

@Suite("Natural Language Search & Filter Matching Tests")
struct SearchFilterTests {

    @Test("NLP query parser token extraction")
    func testNLQueryParser() {
        // 1. Screenshots query
        let query1 = NLQueryParser.parse("screenshots")
        #expect(query1.filter.onlyScreenshots)
        #expect(query1.chips.contains { $0.title == "Screenshots" })

        // 2. From Slack query
        let query2 = NLQueryParser.parse("from slack")
        #expect(query2.filter.origin == .slack)

        // 3. Extension query
        let query3 = NLQueryParser.parse("pdfs")
        #expect(query3.filter.targetExtension == "pdf")

        // 4. Large files query
        let query4 = NLQueryParser.parse("> 50mb")
        #expect(query4.filter.sizeConstraint != nil)
        #expect(query4.filter.sizeConstraint?.matches(60 * 1024 * 1024) == true)
        #expect(query4.filter.sizeConstraint?.matches(40 * 1024 * 1024) == false)
    }

    @Test("SearchFilter match evaluation with OCR")
    func testMatchEvaluation() {
        let now = Date()
        let item = FileItem(
            url: URL(fileURLWithPath: "/tmp/Q3_financial_report.pdf"),
            name: "Q3_financial_report",
            fileSize: 2 * 1024 * 1024,
            modificationDate: now,
            creationDate: now,
            category: .documents,
            origin: .slack,
            originURL: nil
        )

        // Keyword match in filename
        let filter1 = SearchFilter(keywords: ["financial"])
        let (matches1, _) = filter1.matchEvaluation(for: item, ocrText: nil)
        #expect(matches1)

        // Target extension match
        let filter2 = SearchFilter(targetExtension: "pdf")
        let (matches2, _) = filter2.matchEvaluation(for: item, ocrText: nil)
        #expect(matches2)

        // Negative extension match
        let filter3 = SearchFilter(targetExtension: "png")
        let (matches3, _) = filter3.matchEvaluation(for: item, ocrText: nil)
        #expect(!matches3)

        // OCR text match
        let filter4 = SearchFilter(keywords: ["confidential"])
        let (matches4NoOCR, _) = filter4.matchEvaluation(for: item, ocrText: nil)
        #expect(!matches4NoOCR)

        let (matches4WithOCR, ocrFlag) = filter4.matchEvaluation(for: item, ocrText: "This page is highly CONFIDENTIAL and proprietary")
        #expect(matches4WithOCR)
        #expect(ocrFlag)
    }

    @Test("FileItem displayName toggles extension visibility correctly")
    func testFileItemDisplayNameWithExtension() {
        let file = FileItem(
            url: URL(fileURLWithPath: "/Users/test/resume.pdf"),
            name: "resume",
            fileSize: 1024,
            modificationDate: Date(),
            creationDate: Date(),
            category: .documents,
            origin: .unknown
        )

        #expect(file.displayName(showExtension: false) == "resume")
        #expect(file.displayName(showExtension: true) == "resume.pdf")
        #expect(file.fullName == "resume.pdf")
    }

    @Test("ScannerViewModel toggleFileExtensions toggles state")
    @MainActor
    func testViewModelToggleFileExtensions() {
        let vm = ScannerViewModel()
        let initial = vm.showFileExtensions
        vm.toggleFileExtensions()
        #expect(vm.showFileExtensions == !initial)
        vm.toggleFileExtensions()
        #expect(vm.showFileExtensions == initial)
    }

    @Test("Relevance scoring ranks exact and prefix matches higher than unrelated or substring matches")
    func testRelevanceScoringRanking() {
        let now = Date()
        let exactMatch = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Documents/resume.pdf"),
            name: "resume",
            fileSize: 1024,
            modificationDate: now.addingTimeInterval(-86400 * 10), // 10 days ago
            creationDate: now.addingTimeInterval(-86400 * 10),
            category: .documents,
            origin: .unknown
        )

        let prefixMatch = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Documents/resume_v2.pdf"),
            name: "resume_v2",
            fileSize: 1024,
            modificationDate: now,
            creationDate: now,
            category: .documents,
            origin: .unknown
        )

        let wordMatch = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Documents/my-resume.pdf"),
            name: "my-resume",
            fileSize: 1024,
            modificationDate: now,
            creationDate: now,
            category: .documents,
            origin: .unknown
        )

        let irrelevantFile = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Projects/my-finder/dist/File-Finder.dmg"),
            name: "File-Finder",
            fileSize: 3800000,
            modificationDate: now, // touched 1 second ago
            creationDate: now,
            category: .archives,
            origin: .unknown
        )

        let scoreExact = SearchRelevanceScorer.score(file: exactMatch, query: "resume")
        let scorePrefix = SearchRelevanceScorer.score(file: prefixMatch, query: "resume")
        let scoreWord = SearchRelevanceScorer.score(file: wordMatch, query: "resume")
        let scoreIrrelevant = SearchRelevanceScorer.score(file: irrelevantFile, query: "resume")

        // Exact match score must be highest (~1000)
        #expect(scoreExact >= 1000.0)
        // Prefix match must be high (~700+)
        #expect(scorePrefix >= 700.0)
        // Word boundary match must be high (~500+)
        #expect(scoreWord >= 500.0)
        // Irrelevant file must score exactly 0.0 regardless of how recent it is!
        #expect(scoreIrrelevant == 0.0)

        // Exact match must outrank prefix match, and prefix match must outrank irrelevant
        #expect(scoreExact > scorePrefix)
        #expect(scorePrefix > scoreWord)
        #expect(scoreWord > scoreIrrelevant)
    }

    @Test("QuickSearchState orders top probable results first and excludes irrelevant files")
    @MainActor
    func testQuickSearchStateRelevanceOrdering() async {
        let now = Date()
        let resumeFile = FileItem(
            url: URL(fileURLWithPath: "/Users/test/resume.html"),
            name: "resume",
            fileSize: 5000,
            modificationDate: now.addingTimeInterval(-86400 * 5),
            creationDate: now.addingTimeInterval(-86400 * 5),
            category: .code,
            origin: .unknown
        )

        let drawerResume = FileItem(
            url: URL(fileURLWithPath: "/Users/test/13-drawer-resume.png"),
            name: "13-drawer-resume",
            fileSize: 200000,
            modificationDate: now.addingTimeInterval(-86400 * 2),
            creationDate: now.addingTimeInterval(-86400 * 2),
            category: .images,
            origin: .unknown
        )

        let irrelevantDMG = FileItem(
            url: URL(fileURLWithPath: "/Users/test/dist/File-Finder.dmg"),
            name: "File-Finder",
            fileSize: 4000000,
            modificationDate: now, // touched right now!
            creationDate: now,
            category: .archives,
            origin: .unknown
        )

        let scoreResume = SearchRelevanceScorer.score(file: resumeFile, query: "resume")
        let scoreDrawer = SearchRelevanceScorer.score(file: drawerResume, query: "resume")
        let scoreDMG = SearchRelevanceScorer.score(file: irrelevantDMG, query: "resume")

        #expect(scoreResume > scoreDrawer)
        #expect(scoreDrawer > scoreDMG)
        #expect(scoreDMG == 0.0)

        let state = QuickSearchState()
        let vm = ScannerViewModel()
        state.updateSearch(query: "resume", viewModel: vm)
        try? await Task.sleep(nanoseconds: 150_000_000)
        for result in state.results {
            #expect(!result.name.contains("File-Finder"))
        }
    }
}
