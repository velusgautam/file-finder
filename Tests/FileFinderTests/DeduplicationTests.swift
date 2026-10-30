import Testing
import Foundation
@testable import FileFinderLib

@Suite("Deduplication Engine Tests")
struct DeduplicationTests {

    @Test("Compute SHA256 of file")
    func testComputeSHA256() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("test_hash.txt")
        let content = "Antigravity Deduplication Engine Test Content"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let hash = DeduplicationService.shared.computeSHA256(for: fileURL)
        #expect(hash != nil)
        #expect(hash?.count == 64)
    }

    @Test("Detect duplicates and pick oldest as original")
    func testFindDuplicates() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let content1 = "Identical Payload 1234567890"
        let content2 = "Unique Payload ABCDEFGHIJKLMNOP"

        let file1 = tempDir.appendingPathComponent("copy1.txt")
        let file2 = tempDir.appendingPathComponent("copy2.txt")
        let file3 = tempDir.appendingPathComponent("unique.txt")

        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content1.write(to: file2, atomically: true, encoding: .utf8)
        try content2.write(to: file3, atomically: true, encoding: .utf8)

        let attr1 = try FileManager.default.attributesOfItem(atPath: file1.path)
        let attr2 = try FileManager.default.attributesOfItem(atPath: file2.path)
        let attr3 = try FileManager.default.attributesOfItem(atPath: file3.path)

        let size1 = Int64(attr1[.size] as? Int ?? 0)
        let size2 = Int64(attr2[.size] as? Int ?? 0)
        let size3 = Int64(attr3[.size] as? Int ?? 0)

        let now = Date()
        let item1 = FileItem(
            url: file1,
            name: "copy1",
            fileSize: size1,
            modificationDate: now.addingTimeInterval(-100),
            creationDate: now.addingTimeInterval(-200),
            category: .documents,
            origin: .chrome,
            originURL: nil
        )

        let item2 = FileItem(
            url: file2,
            name: "copy2",
            fileSize: size2,
            modificationDate: now,
            creationDate: now.addingTimeInterval(-50),
            category: .documents,
            origin: .chrome,
            originURL: nil
        )

        let item3 = FileItem(
            url: file3,
            name: "unique",
            fileSize: size3,
            modificationDate: now,
            creationDate: now,
            category: .documents,
            origin: .slack,
            originURL: nil
        )

        let dupes = await DeduplicationService.shared.findDuplicates(in: [item1, item2, item3])

        #expect(dupes.count == 1)
        if let group = dupes.first {
            #expect(group.items.count == 2)
            #expect(group.original?.url == item1.url)
            #expect(group.duplicateCopies.count == 1)
            #expect(group.duplicateCopies.first?.url == item2.url)
            #expect(group.wastedBytes == size1)
        }
    }
}
