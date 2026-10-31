import AppIntents
import Foundation

/// App Intent for retrieving the most recent file in the Downloads folder
public struct GetLatestDownloadIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Latest Download"
    public static let description: IntentDescription = IntentDescription("Retrieves the path of the most recent file in the Downloads folder.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return .result(value: nil)
        }

        let scanner = FileScannerService()
        let scanResult = await scanner.scanDirectories(customRoots: [downloadsURL])
        let sorted = scanResult.all.sorted { $0.modificationDate > $1.modificationDate }
        let latestPath = sorted.first?.url.path

        return .result(value: latestPath)
    }
}
