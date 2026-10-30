import Testing
import Foundation
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
}
