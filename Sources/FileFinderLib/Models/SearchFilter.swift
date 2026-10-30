import Foundation

public struct SearchFilter: Equatable, Sendable {
    public var category: ShelfCategory? = nil
    public var origin: DownloadOrigin? = nil
    public var dateRange: DateRange? = nil
    public var sizeConstraint: FileSizeConstraint? = nil
    public var targetExtension: String? = nil
    public var onlyScreenshots: Bool = false
    public var keywords: [String] = []

    public init(
        category: ShelfCategory? = nil,
        origin: DownloadOrigin? = nil,
        dateRange: DateRange? = nil,
        sizeConstraint: FileSizeConstraint? = nil,
        targetExtension: String? = nil,
        onlyScreenshots: Bool = false,
        keywords: [String] = []
    ) {
        self.category = category
        self.origin = origin
        self.dateRange = dateRange
        self.sizeConstraint = sizeConstraint
        self.targetExtension = targetExtension
        self.onlyScreenshots = onlyScreenshots
        self.keywords = keywords
    }

    public var isEmpty: Bool {
        category == nil &&
        origin == nil &&
        dateRange == nil &&
        sizeConstraint == nil &&
        targetExtension == nil &&
        !onlyScreenshots &&
        keywords.isEmpty
    }

    /// Evaluates if an item matches the filter, and whether the match was triggered specifically by OCR text.
    public func matchEvaluation(for item: FileItem, ocrText: String?) -> (matches: Bool, matchedByOCR: Bool) {
        // 1. Category check
        if let category, item.category != category {
            return (false, false)
        }

        // 2. Origin check
        if let origin, item.origin != origin {
            return (false, false)
        }

        // 3. Date check
        if let dateRange, !dateRange.contains(item.modificationDate) {
            return (false, false)
        }

        // 4. Size check
        if let sizeConstraint, !sizeConstraint.matches(item.fileSize) {
            return (false, false)
        }

        // 5. File extension check (e.g. "pdf")
        if let targetExtension, item.fileExtension.lowercased() != targetExtension.lowercased() {
            return (false, false)
        }

        // 6. Screenshot filter check
        if onlyScreenshots {
            let isScreenshot = item.category == .images && Self.isScreenshotFileName(item.name)
            if !isScreenshot {
                return (false, false)
            }
        }

        // 7. Keywords check (filename, origin, extension, or OCR text)
        if keywords.isEmpty {
            return (true, false)
        }

        var matchedByOCR = false
        let lowerName = item.name.lowercased()
        let lowerExt = item.fileExtension.lowercased()
        let lowerOrigin = item.origin.displayName.lowercased()
        let lowerOCR = ocrText?.lowercased() ?? ""

        for kw in keywords {
            let term = kw.lowercased()
            let inName = lowerName.contains(term)
            let inExt = lowerExt.contains(term)
            let inOrigin = lowerOrigin.contains(term)
            let inOCR = !lowerOCR.isEmpty && lowerOCR.contains(term)

            if !(inName || inExt || inOrigin || inOCR) {
                return (false, false)
            }

            if inOCR && !inName && !inExt && !inOrigin {
                matchedByOCR = true
            }
        }

        return (true, matchedByOCR)
    }

    public static func isScreenshotFileName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("screenshot") ||
            lower.contains("screen shot") ||
            lower.contains("cleanshot") ||
            lower.contains("screen_shot") ||
            lower.contains("sc_") ||
            lower.contains("captura de pantalla") ||
            lower.hasPrefix("shot_") ||
            lower.hasPrefix("screencap")
    }
}
