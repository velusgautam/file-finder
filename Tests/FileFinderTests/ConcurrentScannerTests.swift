import Testing
import Foundation
@testable import FileFinderLib

@Suite("Concurrent Multithreaded Scanner Tests")
struct ConcurrentScannerTests {

    @Test("Scan multiple directories concurrently with streaming progress")
    func testConcurrentScanningWithCustomRoots() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempDirectory1 = base.appendingPathComponent("FolderA")
        let tempDirectory2 = base.appendingPathComponent("FolderB")

        try FileManager.default.createDirectory(at: tempDirectory1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDirectory2, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        // Populate test files
        for i in 1...5 {
            let fileA = tempDirectory1.appendingPathComponent("doc_\(i).pdf")
            try "Sample PDF content \(i)".write(to: fileA, atomically: true, encoding: .utf8)
        }

        for i in 1...3 {
            let fileB = tempDirectory2.appendingPathComponent("photo_\(i).png")
            try "Sample Image content \(i)".write(to: fileB, atomically: true, encoding: .utf8)
        }

        let scanner = FileScannerService()
        final class ProgressCollector: @unchecked Sendable {
            private let lock = NSLock()
            private var _events: [ScanProgress] = []
            var events: [ScanProgress] {
                lock.lock()
                defer { lock.unlock() }
                return _events
            }
            func record(_ p: ScanProgress) {
                lock.lock()
                defer { lock.unlock() }
                _events.append(p)
            }
        }
        let collector = ProgressCollector()

        let (all, categorized) = await scanner.scanDirectoriesConcurrently(
            customRoots: [tempDirectory1, tempDirectory2]
        ) { progress in
            collector.record(progress)
        }

        #expect(all.count >= 8)
        #expect(!categorized.isEmpty)

        // Verify documents are found
        let docs = categorized[.documents] ?? []
        #expect(docs.contains { $0.name.hasPrefix("doc_") })

        // Verify images are found
        let images = categorized[.images] ?? []
        #expect(images.contains { $0.name.hasPrefix("photo_") })

        let events = collector.events
        #expect(!events.isEmpty)
    }
}
