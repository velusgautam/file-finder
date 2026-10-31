import Testing
import Foundation
@testable import FileFinderLib

@Suite("Snappy Database & 0ms LRU Cache Tests", .serialized)
struct DatabaseAndCacheTests {

    // MARK: - SQLite Index Tests

    @Test("SQLite index creation, batch upsert, and count")
    func testSQLiteIndexCreationAndUpsert() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_index.db")
        let indexService = SQLiteIndexService(databaseURL: dbURL)

        #expect(await indexService.count() == 0)

        let folderA = tempDir.appendingPathComponent("FolderA")
        try FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)

        let file1 = FileItem(
            url: folderA.appendingPathComponent("Document1.pdf"),
            name: "Document1",
            fileSize: 1024,
            modificationDate: Date(timeIntervalSince1970: 1700000000),
            creationDate: Date(timeIntervalSince1970: 1699990000),
            category: .documents,
            origin: .safari,
            originURL: URL(string: "https://apple.com/doc1.pdf")
        )

        let file2 = FileItem(
            url: folderA.appendingPathComponent("Photo1.png"),
            name: "Photo1",
            fileSize: 2048,
            modificationDate: Date(timeIntervalSince1970: 1700001000),
            creationDate: Date(timeIntervalSince1970: 1699991000),
            category: .images,
            origin: .chrome,
            originURL: nil
        )

        try await indexService.upsert(files: [file1, file2])

        let count = await indexService.count()
        #expect(count == 2)

        let fetched1 = await indexService.fetchFile(url: file1.url)
        #expect(fetched1 != nil)
        #expect(fetched1?.name == "Document1")
        #expect(fetched1?.fileSize == 1024)
        #expect(fetched1?.category == .documents)
        #expect(fetched1?.origin == .safari)
        #expect(fetched1?.originURL == URL(string: "https://apple.com/doc1.pdf"))
    }

    @Test("Fast parentPath indexed lookup")
    func testParentPathIndexedLookup() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_lookup.db")
        let indexService = SQLiteIndexService(databaseURL: dbURL)

        let folderA = tempDir.appendingPathComponent("FolderA")
        let folderB = tempDir.appendingPathComponent("FolderB")
        try FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)

        var batch: [FileItem] = []
        for i in 1...10 {
            let item = FileItem(
                url: folderA.appendingPathComponent("DocA_\(i).txt"),
                name: "DocA_\(i)",
                fileSize: Int64(i * 100),
                category: .documents
            )
            batch.append(item)
        }

        for i in 1...5 {
            let item = FileItem(
                url: folderB.appendingPathComponent("DocB_\(i).txt"),
                name: "DocB_\(i)",
                fileSize: Int64(i * 200),
                category: .code
            )
            batch.append(item)
        }

        try await indexService.upsert(files: batch)

        // Lookup FolderA files
        let folderAFiles = await indexService.fetchFiles(parentPath: folderA.path)
        #expect(folderAFiles.count == 10)
        #expect(folderAFiles.allSatisfy { $0.url.deletingLastPathComponent().standardizedFileURL.path == folderA.standardizedFileURL.path })

        // Lookup FolderB files
        let folderBFiles = await indexService.fetchFiles(parentPath: folderB.path)
        #expect(folderBFiles.count == 5)
        #expect(folderBFiles.allSatisfy { $0.url.deletingLastPathComponent().standardizedFileURL.path == folderB.standardizedFileURL.path })

        // Non-existent folder returns empty array instantly
        let emptyFiles = await indexService.fetchFiles(parentPath: tempDir.appendingPathComponent("Empty").path)
        #expect(emptyFiles.isEmpty)
    }

    @Test("SQLite conflict upsert preserves sha256 and ocrText with updates")
    func testUpsertConflictAndUpdates() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_updates.db")
        let indexService = SQLiteIndexService(databaseURL: dbURL)

        let fileURL = tempDir.appendingPathComponent("Invoice_2024.pdf")
        let item = FileItem(
            url: fileURL,
            name: "Invoice_2024",
            fileSize: 4096,
            category: .documents
        )

        try await indexService.upsert(file: item)

        // Update SHA256 and OCR text
        try await indexService.updateSHA256("sha256_mock_hash_value", for: fileURL)
        try await indexService.updateOCRText("Receipt Total: $149.99 Acme Corp Paid", for: fileURL)

        let record = await indexService.fetchRecord(url: fileURL)
        #expect(record?.sha256 == "sha256_mock_hash_value")
        #expect(record?.ocrText == "Receipt Total: $149.99 Acme Corp Paid")

        // Upsert file with updated size - sha256 and ocrText should be preserved!
        let updatedItem = FileItem(
            url: fileURL,
            name: "Invoice_2024",
            fileSize: 5120,
            category: .documents
        )
        try await indexService.upsert(file: updatedItem)

        let preservedRecord = await indexService.fetchRecord(url: fileURL)
        #expect(preservedRecord?.fileSize == 5120)
        #expect(preservedRecord?.sha256 == "sha256_mock_hash_value")
        #expect(preservedRecord?.ocrText == "Receipt Total: $149.99 Acme Corp Paid")

        // Search text matching OCR content
        let searchResults = await indexService.searchFiles(matching: "Acme")
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.url.path == fileURL.path)
    }

    @Test("SQLite file and parentPath deletions")
    func testSQLiteDeletions() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_del.db")
        let indexService = SQLiteIndexService(databaseURL: dbURL)

        let folder = tempDir.appendingPathComponent("Projects")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let item1 = FileItem(url: folder.appendingPathComponent("file1.txt"), name: "file1")
        let item2 = FileItem(url: folder.appendingPathComponent("file2.txt"), name: "file2")
        let item3 = FileItem(url: folder.appendingPathComponent("file3.txt"), name: "file3")

        try await indexService.upsert(files: [item1, item2, item3])
        #expect(await indexService.count() == 3)

        // Delete single file
        try await indexService.delete(url: item1.url)
        #expect(await indexService.count() == 2)
        #expect(await indexService.fetchFile(url: item1.url) == nil)

        // Delete by parentPath
        try await indexService.delete(parentPath: folder.path)
        #expect(await indexService.count() == 0)
    }

    // MARK: - Directory Cache Tests

    @Test("Directory LRU cache eviction and instant retrieval")
    func testLRUCacheEvictionAndRetrieval() throws {
        // Cache with capacity of 3
        let cache = DirectoryCacheService(capacity: 3, enableFSEvents: false)
        #expect(cache.count == 0)

        let dir1 = URL(fileURLWithPath: "/tmp/mock/folder1")
        let dir2 = URL(fileURLWithPath: "/tmp/mock/folder2")
        let dir3 = URL(fileURLWithPath: "/tmp/mock/folder3")
        let dir4 = URL(fileURLWithPath: "/tmp/mock/folder4")

        let file1 = FileItem(url: dir1.appendingPathComponent("a.txt"), name: "a")
        let file2 = FileItem(url: dir2.appendingPathComponent("b.txt"), name: "b")
        let file3 = FileItem(url: dir3.appendingPathComponent("c.txt"), name: "c")
        let file4 = FileItem(url: dir4.appendingPathComponent("d.txt"), name: "d")

        // 1. Initial empty cache miss returns nil
        #expect(cache.get(for: dir1) == nil)

        // 2. Populate 3 entries (reaches full capacity)
        cache.set(subfolders: [], files: [file1], for: dir1)
        cache.set(subfolders: [], files: [file2], for: dir2)
        cache.set(subfolders: [], files: [file3], for: dir3)

        #expect(cache.count == 3)

        // 3. Instant 0ms retrieval
        let start = DispatchTime.now()
        let retrieved = cache.get(for: dir1)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        #expect(retrieved != nil)
        #expect(retrieved?.files.first?.name == "a")
        // Retrieval takes microseconds (sub-millisecond)
        #expect(elapsed < 10_000_000)

        // Accessing dir1 moved it to MRU.
        // Current order from MRU to LRU: dir1, dir3, dir2.
        // 4. Adding dir4 should evict dir2 (the least recently used)!
        cache.set(subfolders: [], files: [file4], for: dir4)

        #expect(cache.count == 3)
        #expect(cache.get(for: dir2) == nil) // dir2 was evicted!
        #expect(cache.get(for: dir1) != nil) // dir1 retained!
        #expect(cache.get(for: dir3) != nil) // dir3 retained!
        #expect(cache.get(for: dir4) != nil) // dir4 present!
    }

    @Test("Cache manual invalidation and simulated disk change")
    func testCacheInvalidation() throws {
        let cache = DirectoryCacheService(capacity: 5, enableFSEvents: false)
        let dir = URL(fileURLWithPath: "/tmp/mock/watched_folder")
        let item = FileItem(url: dir.appendingPathComponent("test.txt"), name: "test")

        cache.set(subfolders: [], files: [item], for: dir)
        #expect(cache.contains(url: dir))

        // Manual invalidation
        cache.invalidate(for: dir)
        #expect(!cache.contains(url: dir))
        #expect(cache.get(for: dir) == nil)

        // Set again and test simulated disk change
        final class InvalidationBox: @unchecked Sendable {
            var url: URL?
        }
        let box = InvalidationBox()
        cache.onInvalidation = { url in
            box.url = url
        }

        cache.set(subfolders: [], files: [item], for: dir)
        #expect(cache.contains(url: dir))

        // File inside watched folder changes on disk
        cache.simulateDiskChange(at: dir.appendingPathComponent("test.txt"))
        #expect(!cache.contains(url: dir))
        #expect(box.url?.standardizedFileURL.path == dir.standardizedFileURL.path)
    }

    @Test("ScannerViewModel instant cache retrieval on folder navigation")
    @MainActor
    func testScannerViewModelCacheIntegration() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let rootURL = tempDir.appendingPathComponent("TestLocation")
        let subfolder = rootURL.appendingPathComponent("SubA")

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "Hello World".write(to: rootURL.appendingPathComponent("hello.txt"), atomically: true, encoding: .utf8)
        try "Sub File".write(to: subfolder.appendingPathComponent("nested.txt"), atomically: true, encoding: .utf8)

        let vm = ScannerViewModel()

        // 1. Initial selection populates and caches root
        vm.selectLocation(name: "TestLocation", url: rootURL)
        #expect(vm.currentFolderFiles.count == 1)
        #expect(vm.currentFolderSubfolders.count == 1)

        // Verify root is in cache
        #expect(DirectoryCacheService.shared.contains(url: rootURL))

        // 2. Navigate to subfolder
        vm.navigateToFolder(subfolder)
        #expect(vm.currentFolderFiles.count == 1)
        #expect(vm.currentFolderFiles.first?.name == "nested")
        #expect(DirectoryCacheService.shared.contains(url: subfolder))

        // 3. Navigate back to root: instant 0ms retrieval from cache!
        let start = DispatchTime.now()
        vm.navigateToBreadcrumb(rootURL)
        let durationNs = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds

        #expect(vm.currentFolderFiles.count == 1)
        #expect(vm.currentFolderFiles.first?.name == "hello")
        #expect(durationNs < 50_000_000) // Under 50ms (typically <0.1ms)
    }
}
