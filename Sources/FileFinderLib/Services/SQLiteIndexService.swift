import Foundation
import SQLite3

// MARK: - Indexed File Record

public struct IndexedFileRecord: Sendable, Equatable {
    public let url: URL
    public let name: String
    public let fileSize: Int64
    public let modificationDate: Date
    public let creationDate: Date
    public let category: ShelfCategory
    public let origin: DownloadOrigin
    public let originURL: URL?
    public let sha256: String?
    public let ocrText: String?
    public let parentPath: String

    public init(
        url: URL,
        name: String,
        fileSize: Int64,
        modificationDate: Date,
        creationDate: Date,
        category: ShelfCategory,
        origin: DownloadOrigin,
        originURL: URL?,
        sha256: String? = nil,
        ocrText: String? = nil,
        parentPath: String? = nil
    ) {
        let stdURL = url.standardizedFileURL
        self.url = stdURL
        self.name = name
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.category = category
        self.origin = origin
        self.originURL = originURL
        self.sha256 = sha256
        self.ocrText = ocrText
        self.parentPath = parentPath ?? stdURL.deletingLastPathComponent().path
    }

    public init(fileItem: FileItem, sha256: String? = nil, ocrText: String? = nil) {
        self.init(
            url: fileItem.url,
            name: fileItem.name,
            fileSize: fileItem.fileSize,
            modificationDate: fileItem.modificationDate,
            creationDate: fileItem.creationDate,
            category: fileItem.category,
            origin: fileItem.origin,
            originURL: fileItem.originURL,
            sha256: sha256,
            ocrText: ocrText
        )
    }

    public func toFileItem() -> FileItem {
        FileItem(
            url: url,
            name: name,
            fileSize: fileSize,
            modificationDate: modificationDate,
            creationDate: creationDate,
            category: category,
            origin: origin,
            originURL: originURL
        )
    }
}

// MARK: - SQLiteIndexService

public final class SQLiteIndexService: @unchecked Sendable {
    public static let shared = SQLiteIndexService()

    public let databaseURL: URL
    private let queue = DispatchQueue(label: "com.filefinder.sqliteindex", qos: .userInitiated)
    private var db: OpaquePointer?

    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(databaseURL: URL? = nil) {
        if let customURL = databaseURL {
            self.databaseURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("FileFinder", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.databaseURL = dir.appendingPathComponent("index.db")
        }

        queue.sync {
            self.openDatabase()
            self.createTables()
        }
    }

    deinit {
        queue.sync {
            if let db = self.db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    // MARK: - Database Lifecycle

    private func openDatabase() {
        let parentDir = databaseURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let path = databaseURL.path
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let errmsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            print("[SQLiteIndexService] Failed to open database at \(path): \(errmsg)")
            return
        }

        // High-performance WAL mode and memory settings
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size = -8000;", nil, nil, nil)
    }

    private func createTables() {
        guard let db = db else { return }

        let schema = """
        CREATE TABLE IF NOT EXISTS file_index (
            url TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            fileSize INTEGER NOT NULL,
            modificationDate REAL NOT NULL,
            creationDate REAL NOT NULL,
            category TEXT NOT NULL,
            origin TEXT NOT NULL,
            originURL TEXT,
            sha256 TEXT,
            ocrText TEXT,
            parentPath TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_file_index_parentPath ON file_index(parentPath);
        CREATE INDEX IF NOT EXISTS idx_file_index_name ON file_index(name);
        CREATE INDEX IF NOT EXISTS idx_file_index_category ON file_index(category);
        """

        var errorMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, schema, nil, nil, &errorMsg) != SQLITE_OK {
            if let errorMsg = errorMsg {
                print("[SQLiteIndexService] Error creating tables: \(String(cString: errorMsg))")
                sqlite3_free(errorMsg)
            }
        }
    }

    // MARK: - Internal Operations (Always execute within `queue`)

    private func performUpsert(records: [IndexedFileRecord]) throws {
        guard let db = db else { return }
        guard !records.isEmpty else { return }

        let sql = """
        INSERT INTO file_index (
            url, name, fileSize, modificationDate, creationDate, category, origin, originURL, sha256, ocrText, parentPath
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(url) DO UPDATE SET
            name = excluded.name,
            fileSize = excluded.fileSize,
            modificationDate = excluded.modificationDate,
            creationDate = excluded.creationDate,
            category = excluded.category,
            origin = excluded.origin,
            originURL = excluded.originURL,
            sha256 = coalesce(excluded.sha256, file_index.sha256),
            ocrText = coalesce(excluded.ocrText, file_index.ocrText),
            parentPath = excluded.parentPath;
        """

        sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw NSError(domain: "SQLiteIndexService", code: 1, userInfo: [NSLocalizedDescriptionKey: errmsg])
        }
        defer { sqlite3_finalize(stmt) }

        for rec in records {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)

            let urlPath = rec.url.standardizedFileURL.path
            sqlite3_bind_text(stmt, 1, urlPath, -1, Self.transientDestructor)
            sqlite3_bind_text(stmt, 2, rec.name, -1, Self.transientDestructor)
            sqlite3_bind_int64(stmt, 3, rec.fileSize)
            sqlite3_bind_double(stmt, 4, rec.modificationDate.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 5, rec.creationDate.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 6, rec.category.rawValue, -1, Self.transientDestructor)
            sqlite3_bind_text(stmt, 7, rec.origin.rawIdentifier, -1, Self.transientDestructor)

            if let origURL = rec.originURL {
                sqlite3_bind_text(stmt, 8, origURL.absoluteString, -1, Self.transientDestructor)
            } else {
                sqlite3_bind_null(stmt, 8)
            }

            if let sha = rec.sha256 {
                sqlite3_bind_text(stmt, 9, sha, -1, Self.transientDestructor)
            } else {
                sqlite3_bind_null(stmt, 9)
            }

            if let ocr = rec.ocrText {
                sqlite3_bind_text(stmt, 10, ocr, -1, Self.transientDestructor)
            } else {
                sqlite3_bind_null(stmt, 10)
            }

            sqlite3_bind_text(stmt, 11, rec.parentPath, -1, Self.transientDestructor)

            if sqlite3_step(stmt) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                print("[SQLiteIndexService] Failed to upsert record \(urlPath): \(errmsg)")
            }
        }

        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    private func performFetchRecords(parentPath: String) -> [IndexedFileRecord] {
        guard let db = db else { return [] }
        let stdParent = URL(fileURLWithPath: parentPath).standardizedFileURL.path
        let sql = """
        SELECT url, name, fileSize, modificationDate, creationDate, category, origin, originURL, sha256, ocrText, parentPath
        FROM file_index
        WHERE parentPath = ?
        ORDER BY name COLLATE NOCASE ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, stdParent, -1, Self.transientDestructor)

        var results: [IndexedFileRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = parseRecord(from: stmt!) {
                results.append(record)
            }
        }
        return results
    }

    private func performFetchRecord(url: URL) -> IndexedFileRecord? {
        guard let db = db else { return nil }
        let stdPath = url.standardizedFileURL.path
        let sql = """
        SELECT url, name, fileSize, modificationDate, creationDate, category, origin, originURL, sha256, ocrText, parentPath
        FROM file_index
        WHERE url = ?
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, stdPath, -1, Self.transientDestructor)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseRecord(from: stmt!)
        }
        return nil
    }

    private func performSearchRecords(matching query: String, limit: Int) -> [IndexedFileRecord] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let db = db, !cleanQuery.isEmpty else { return [] }
        let pattern = "%\(cleanQuery)%"
        let sql = """
        SELECT url, name, fileSize, modificationDate, creationDate, category, origin, originURL, sha256, ocrText, parentPath
        FROM file_index
        WHERE name LIKE ? OR ocrText LIKE ?
        ORDER BY
            CASE
                WHEN LOWER(name) = LOWER(?) THEN 1000
                WHEN LOWER(name) LIKE LOWER(?) || '%' THEN 700
                WHEN LOWER(name) LIKE '% ' || LOWER(?) || '%' OR LOWER(name) LIKE '%_' || LOWER(?) || '%' OR LOWER(name) LIKE '%-' || LOWER(?) || '%' THEN 500
                WHEN LOWER(name) LIKE '%' || LOWER(?) || '%' THEN 300
                ELSE 50
            END DESC,
            modificationDate DESC
        LIMIT ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, pattern, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 2, pattern, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 3, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 4, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 5, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 6, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 7, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 8, cleanQuery, -1, Self.transientDestructor)
        sqlite3_bind_int(stmt, 9, Int32(limit))

        var results: [IndexedFileRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = parseRecord(from: stmt!) {
                results.append(record)
            }
        }
        return results
    }

    private func performUpdateSHA256(_ hash: String, for url: URL) throws {
        guard let db = db else { return }
        let stdPath = url.standardizedFileURL.path
        let sql = "UPDATE file_index SET sha256 = ? WHERE url = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, hash, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 2, stdPath, -1, Self.transientDestructor)
        sqlite3_step(stmt)
    }

    private func performUpdateOCRText(_ text: String, for url: URL) throws {
        guard let db = db else { return }
        let stdPath = url.standardizedFileURL.path
        let sql = "UPDATE file_index SET ocrText = ? WHERE url = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, text, -1, Self.transientDestructor)
        sqlite3_bind_text(stmt, 2, stdPath, -1, Self.transientDestructor)
        sqlite3_step(stmt)
    }

    private func performDelete(url: URL) throws {
        guard let db = db else { return }
        let stdPath = url.standardizedFileURL.path
        let sql = "DELETE FROM file_index WHERE url = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, stdPath, -1, Self.transientDestructor)
        sqlite3_step(stmt)
    }

    private func performDelete(parentPath: String) throws {
        guard let db = db else { return }
        let stdParent = URL(fileURLWithPath: parentPath).standardizedFileURL.path
        let sql = "DELETE FROM file_index WHERE parentPath = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, stdParent, -1, Self.transientDestructor)
        sqlite3_step(stmt)
    }

    private func performClearAll() throws {
        guard let db = db else { return }
        sqlite3_exec(db, "DELETE FROM file_index;", nil, nil, nil)
    }

    private func performCount() -> Int {
        guard let db = db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM file_index;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    private func parseRecord(from stmt: OpaquePointer) -> IndexedFileRecord? {
        guard let urlCStr = sqlite3_column_text(stmt, 0) else { return nil }
        let urlPath = String(cString: urlCStr)
        let url = URL(fileURLWithPath: urlPath)

        let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? url.deletingPathExtension().lastPathComponent
        let fileSize = sqlite3_column_int64(stmt, 2)
        let modInterval = sqlite3_column_double(stmt, 3)
        let createInterval = sqlite3_column_double(stmt, 4)
        let modDate = Date(timeIntervalSince1970: modInterval)
        let createDate = Date(timeIntervalSince1970: createInterval)

        let categoryStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
        let category = ShelfCategory(rawValue: categoryStr) ?? .documents

        let originStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "unknown"
        let origin = DownloadOrigin.from(rawIdentifier: originStr)

        let originURL = sqlite3_column_text(stmt, 7).flatMap {
            let str = String(cString: $0)
            return str.isEmpty ? nil : URL(string: str)
        }

        let sha256 = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let ocrText = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        let parentPath = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? url.deletingLastPathComponent().path

        return IndexedFileRecord(
            url: url,
            name: name,
            fileSize: fileSize,
            modificationDate: modDate,
            creationDate: createDate,
            category: category,
            origin: origin,
            originURL: originURL,
            sha256: sha256,
            ocrText: ocrText,
            parentPath: parentPath
        )
    }

    // MARK: - Synchronous API (Thread-Safe)

    public func upsertSync(records: [IndexedFileRecord]) throws {
        try queue.sync {
            try self.performUpsert(records: records)
        }
    }

    public func upsertSync(files: [FileItem]) throws {
        let records = files.map { IndexedFileRecord(fileItem: $0) }
        try upsertSync(records: records)
    }

    public func upsertSync(file: FileItem, sha256: String? = nil, ocrText: String? = nil) throws {
        let record = IndexedFileRecord(fileItem: file, sha256: sha256, ocrText: ocrText)
        try upsertSync(records: [record])
    }

    public func fetchRecordsSync(parentPath: String) -> [IndexedFileRecord] {
        queue.sync {
            self.performFetchRecords(parentPath: parentPath)
        }
    }

    public func fetchFilesSync(parentPath: String) -> [FileItem] {
        fetchRecordsSync(parentPath: parentPath).map { $0.toFileItem() }
    }

    public func fetchRecordSync(url: URL) -> IndexedFileRecord? {
        queue.sync {
            self.performFetchRecord(url: url)
        }
    }

    public func fetchFileSync(url: URL) -> FileItem? {
        fetchRecordSync(url: url)?.toFileItem()
    }

    public func searchRecordsSync(matching query: String, limit: Int = 100) -> [IndexedFileRecord] {
        queue.sync {
            self.performSearchRecords(matching: query, limit: limit)
        }
    }

    public func searchFilesSync(matching query: String, limit: Int = 100) -> [FileItem] {
        searchRecordsSync(matching: query, limit: limit).map { $0.toFileItem() }
    }

    public func updateSHA256Sync(_ hash: String, for url: URL) throws {
        try queue.sync {
            try self.performUpdateSHA256(hash, for: url)
        }
    }

    public func updateOCRTextSync(_ text: String, for url: URL) throws {
        try queue.sync {
            try self.performUpdateOCRText(text, for: url)
        }
    }

    public func deleteSync(url: URL) throws {
        try queue.sync {
            try self.performDelete(url: url)
        }
    }

    public func deleteSync(parentPath: String) throws {
        try queue.sync {
            try self.performDelete(parentPath: parentPath)
        }
    }

    public func clearAllSync() throws {
        try queue.sync {
            try self.performClearAll()
        }
    }

    public func countSync() -> Int {
        queue.sync {
            self.performCount()
        }
    }

    // MARK: - Asynchronous Swift Concurrency API

    public func upsert(records: [IndexedFileRecord]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performUpsert(records: records)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func upsert(files: [FileItem]) async throws {
        let records = files.map { IndexedFileRecord(fileItem: $0) }
        try await upsert(records: records)
    }

    public func upsert(file: FileItem, sha256: String? = nil, ocrText: String? = nil) async throws {
        let record = IndexedFileRecord(fileItem: file, sha256: sha256, ocrText: ocrText)
        try await upsert(records: [record])
    }

    public func fetchRecords(parentPath: String) async -> [IndexedFileRecord] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performFetchRecords(parentPath: parentPath))
            }
        }
    }

    public func fetchFiles(parentPath: String) async -> [FileItem] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performFetchRecords(parentPath: parentPath).map { $0.toFileItem() })
            }
        }
    }

    public func fetchRecord(url: URL) async -> IndexedFileRecord? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performFetchRecord(url: url))
            }
        }
    }

    public func fetchFile(url: URL) async -> FileItem? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performFetchRecord(url: url)?.toFileItem())
            }
        }
    }

    public func searchRecords(matching query: String, limit: Int = 100) async -> [IndexedFileRecord] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performSearchRecords(matching: query, limit: limit))
            }
        }
    }

    public func searchFiles(matching query: String, limit: Int = 100) async -> [FileItem] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performSearchRecords(matching: query, limit: limit).map { $0.toFileItem() })
            }
        }
    }

    public func updateSHA256(_ hash: String, for url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performUpdateSHA256(hash, for: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func updateOCRText(_ text: String, for url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performUpdateOCRText(text, for: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func delete(url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performDelete(url: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func delete(parentPath: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performDelete(parentPath: parentPath)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func clearAll() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performClearAll()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func count() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.performCount())
            }
        }
    }
}
