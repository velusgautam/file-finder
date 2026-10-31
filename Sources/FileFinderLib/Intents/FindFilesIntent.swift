import AppIntents
import Foundation

/// App Intent for searching files by natural language or keyword query
public struct FindFilesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Find Files"
    public static let description: IntentDescription = IntentDescription("Searches files indexed by File Finder using a query string.")

    @Parameter(title: "Query", description: "Search query or natural language filter, e.g. 'type:pdf' or 'dmg'")
    public var query: String

    public init() {
        self.query = ""
    }

    public init(query: String) {
        self.query = query
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let parsed = NLQueryParser.parse(query)
        let scanner = FileScannerService()
        let scanResult = await scanner.scanDirectories()

        let matchedPaths = scanResult.all.filter { file in
            let (matches, _) = parsed.filter.matchEvaluation(for: file, ocrText: nil)
            return matches
        }.map { $0.url.path }

        return .result(value: matchedPaths)
    }
}
