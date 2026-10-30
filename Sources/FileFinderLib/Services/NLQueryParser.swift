import Foundation

public struct NLQueryResult: Sendable {
    public let filter: SearchFilter
    public let chips: [FilterChip]
    public let remainingSearchText: String

    public init(filter: SearchFilter, chips: [FilterChip], remainingSearchText: String) {
        self.filter = filter
        self.chips = chips
        self.remainingSearchText = remainingSearchText
    }
}

public enum NLQueryParser {
    public static func parse(_ rawInput: String) -> NLQueryResult {
        var text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return NLQueryResult(filter: SearchFilter(), chips: [], remainingSearchText: "")
        }

        var filter = SearchFilter()
        var chips: [FilterChip] = []
        let calendar = Calendar.current
        let now = Date()

        // 1. Origin parsing ("from slack", "from chrome", "from safari", etc.)
        let originPatterns: [(regex: String, origin: DownloadOrigin, title: String)] = [
            (#"\b(?:from|via)\s+slack\b"#, .slack, "From Slack"),
            (#"\b(?:from|via)\s+(?:google\s+)?chrome\b"#, .chrome, "From Chrome"),
            (#"\b(?:from|via)\s+safari\b"#, .safari, "From Safari"),
            (#"\b(?:from|via)\s+chatgpt\b"#, .chatgpt, "From ChatGPT"),
            (#"\b(?:from|via)\s+discord\b"#, .discord, "From Discord"),
            (#"\b(?:from|via)\s+arc\b"#, .arc, "From Arc"),
            (#"\b(?:from|via)\s+(?:apple\s+)?mail\b"#, .mail, "From Mail"),
            (#"\b(?:from|via)\s+telegram\b"#, .telegram, "From Telegram"),
            (#"\b(?:from|via)\s+airdrop\b"#, .airdrop, "From AirDrop")
        ]

        for item in originPatterns {
            if let range = text.range(of: item.regex, options: [.regularExpression, .caseInsensitive]) {
                filter.origin = item.origin
                chips.append(FilterChip(title: item.title, iconSystemName: item.origin.iconSystemName, type: .origin(item.origin)))
                text.removeSubrange(range)
                break
            }
        }

        // 2. Date Range Parsing
        // "older than X (days|weeks|months|years)"
        let olderThanRegex = #"\bolder\s+than\s+(\d+)\s*(days?|weeks?|months?|years?)\b"#
        if let match = text.range(of: olderThanRegex, options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(text[match]).lowercased()
            let components = matchedStr.replacingOccurrences(of: "older than", with: "").trimmingCharacters(in: .whitespaces).split(separator: " ")
            if let countStr = components.first, let count = Int(countStr) {
                let unit = components.count > 1 ? String(components[1]) : "days"
                var comp = DateComponents()
                if unit.hasPrefix("year") { comp.year = -count }
                else if unit.hasPrefix("month") { comp.month = -count }
                else if unit.hasPrefix("week") { comp.day = -(count * 7) }
                else { comp.day = -count }

                if let cutoff = calendar.date(byAdding: comp, to: now) {
                    let range = DateRange(start: nil, end: cutoff)
                    filter.dateRange = range
                    chips.append(FilterChip(title: "Older than \(count) \(unit)", iconSystemName: "clock.arrow.circlepath", type: .dateRange(range)))
                }
            }
            text.removeSubrange(match)
        }

        // "last X (days|weeks|months)"
        let lastXRegex = #"\blast\s+(\d+)\s*(days?|weeks?|months?)\b"#
        if let match = text.range(of: lastXRegex, options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(text[match]).lowercased()
            let components = matchedStr.replacingOccurrences(of: "last", with: "").trimmingCharacters(in: .whitespaces).split(separator: " ")
            if let countStr = components.first, let count = Int(countStr) {
                let unit = components.count > 1 ? String(components[1]) : "days"
                var comp = DateComponents()
                if unit.hasPrefix("month") { comp.month = -count }
                else if unit.hasPrefix("week") { comp.day = -(count * 7) }
                else { comp.day = -count }

                if let start = calendar.date(byAdding: comp, to: now) {
                    let range = DateRange(start: start, end: nil)
                    filter.dateRange = range
                    chips.append(FilterChip(title: "Last \(count) \(unit)", iconSystemName: "calendar", type: .dateRange(range)))
                }
            }
            text.removeSubrange(match)
        }

        // Relative named dates
        let namedDates: [(regex: String, chipTitle: String, rangeBuilder: () -> DateRange)] = [
            (#"\btoday\b"#, "Today", {
                DateRange(start: calendar.startOfDay(for: now), end: nil)
            }),
            (#"\byesterday\b"#, "Yesterday", {
                let startOfToday = calendar.startOfDay(for: now)
                let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
                return DateRange(start: startOfYesterday, end: startOfToday)
            }),
            (#"\bthis\s+week\b"#, "This Week", {
                let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                return DateRange(start: startOfWeek, end: nil)
            }),
            (#"\blast\s+week\b"#, "Last Week", {
                let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? startOfThisWeek
                return DateRange(start: startOfLastWeek, end: startOfThisWeek)
            }),
            (#"\bthis\s+month\b"#, "This Month", {
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                return DateRange(start: startOfMonth, end: nil)
            }),
            (#"\blast\s+month\b"#, "Last Month", {
                let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
                return DateRange(start: startOfLastMonth, end: startOfThisMonth)
            })
        ]

        if filter.dateRange == nil {
            for item in namedDates {
                if let match = text.range(of: item.regex, options: [.regularExpression, .caseInsensitive]) {
                    let range = item.rangeBuilder()
                    filter.dateRange = range
                    chips.append(FilterChip(title: item.chipTitle, iconSystemName: "calendar", type: .dateRange(range)))
                    text.removeSubrange(match)
                    break
                }
            }
        }

        // 3. File Size Parsing
        // "> 50mb", "over 1gb", "more than 20mb"
        let greaterThanRegex = #"(?:>|over|more than|greater than)\s*(\d+(?:\.\d+)?)\s*(kb|mb|gb|b)?"#
        if let match = text.range(of: greaterThanRegex, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(text[match])
            if let constraint = parseSizeConstraint(from: matchedText, isGreaterThan: true) {
                filter.sizeConstraint = constraint
                let display = formatSizeChipTitle(matchedText, prefix: ">")
                chips.append(FilterChip(title: display, iconSystemName: "arrow.up.right", type: .fileSize(constraint)))
            }
            text.removeSubrange(match)
        }

        // "< 10mb", "under 5mb", "less than 100kb"
        let lessThanRegex = #"(?:<|under|less than)\s*(\d+(?:\.\d+)?)\s*(kb|mb|gb|b)?"#
        if filter.sizeConstraint == nil, let match = text.range(of: lessThanRegex, options: [.regularExpression, .caseInsensitive]) {
            let matchedText = String(text[match])
            if let constraint = parseSizeConstraint(from: matchedText, isGreaterThan: false) {
                filter.sizeConstraint = constraint
                let display = formatSizeChipTitle(matchedText, prefix: "<")
                chips.append(FilterChip(title: display, iconSystemName: "arrow.down.right", type: .fileSize(constraint)))
            }
            text.removeSubrange(match)
        }

        // Qualitative size ("large" >100MB, "small" <1MB)
        if filter.sizeConstraint == nil {
            if let match = text.range(of: #"\blarge\b"#, options: [.regularExpression, .caseInsensitive]) {
                let constraint = FileSizeConstraint(minBytes: 100 * 1024 * 1024, maxBytes: nil)
                filter.sizeConstraint = constraint
                chips.append(FilterChip(title: "Large (>100MB)", iconSystemName: "shippingbox", type: .fileSize(constraint)))
                text.removeSubrange(match)
            } else if let match = text.range(of: #"\bsmall\b"#, options: [.regularExpression, .caseInsensitive]) {
                let constraint = FileSizeConstraint(minBytes: nil, maxBytes: 1 * 1024 * 1024)
                filter.sizeConstraint = constraint
                chips.append(FilterChip(title: "Small (<1MB)", iconSystemName: "cube", type: .fileSize(constraint)))
                text.removeSubrange(match)
            }
        }

        // 4. File Types & Categories
        // Screenshots
        if let match = text.range(of: #"\bscreenshots?\b"#, options: [.regularExpression, .caseInsensitive]) {
            filter.category = .images
            filter.onlyScreenshots = true
            chips.append(FilterChip(title: "Screenshots", iconSystemName: "camera.viewfinder", type: .screenshot))
            text.removeSubrange(match)
        }

        // PDFs
        if let match = text.range(of: #"\bpdfs?\b"#, options: [.regularExpression, .caseInsensitive]) {
            filter.targetExtension = "pdf"
            chips.append(FilterChip(title: "PDFs", iconSystemName: "doc.text", type: .fileExtension("pdf")))
            text.removeSubrange(match)
        }

        // Other categories if not screenshots
        let categoryPatterns: [(regex: String, category: ShelfCategory, title: String)] = [
            (#"\b(?:images?|photos?|pictures?)\b"#, .images, "Images"),
            (#"\b(?:videos?|clips?|movies?)\b"#, .videos, "Videos"),
            (#"\b(?:documents?|docs?)\b"#, .documents, "Documents"),
            (#"\b(?:code|scripts?|sources?)\b"#, .code, "Code"),
            (#"\b(?:archives?|zips?|tarballs?)\b"#, .archives, "Archives"),
            (#"\b(?:music|audio|songs?|tracks?)\b"#, .audio, "Audio")
        ]

        if filter.category == nil && filter.targetExtension == nil {
            for item in categoryPatterns {
                if let match = text.range(of: item.regex, options: [.regularExpression, .caseInsensitive]) {
                    filter.category = item.category
                    chips.append(FilterChip(title: item.title, iconSystemName: item.category.systemImage, type: .category(item.category)))
                    text.removeSubrange(match)
                    break
                }
            }
        }

        // 5. Remaining words -> Raw keywords
        let cleanedRemaining = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !["and", "or", "in", "with", "the", "a", "an"].contains($0.lowercased()) }

        filter.keywords = cleanedRemaining
        let remainingString = cleanedRemaining.joined(separator: " ")

        return NLQueryResult(
            filter: filter,
            chips: chips,
            remainingSearchText: remainingString
        )
    }

    private static func parseSizeConstraint(from text: String, isGreaterThan: Bool) -> FileSizeConstraint? {
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(kb|mb|gb|b)?"#, options: [.caseInsensitive])
        guard let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard let numRange = Range(match.range(at: 1), in: text),
              let numValue = Double(text[numRange]) else {
            return nil
        }

        var multiplier: Double = 1024 * 1024 // Default to MB if unspecified
        if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: text) {
            let unitStr = text[unitRange].lowercased()
            switch unitStr {
            case "b": multiplier = 1
            case "kb": multiplier = 1024
            case "mb": multiplier = 1024 * 1024
            case "gb": multiplier = 1024 * 1024 * 1024
            default: multiplier = 1024 * 1024
            }
        }

        let bytes = Int64(numValue * multiplier)
        if isGreaterThan {
            return FileSizeConstraint(minBytes: bytes, maxBytes: nil)
        } else {
            return FileSizeConstraint(minBytes: nil, maxBytes: bytes)
        }
    }

    private static func formatSizeChipTitle(_ matchedText: String, prefix: String) -> String {
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(kb|mb|gb|b)?"#, options: [.caseInsensitive])
        if let match = regex?.firstMatch(in: matchedText, range: NSRange(matchedText.startIndex..., in: matchedText)),
           let numRange = Range(match.range(at: 1), in: matchedText) {
            let num = matchedText[numRange]
            var unit = "MB"
            if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: matchedText) {
                unit = matchedText[unitRange].uppercased()
            }
            return "\(prefix) \(num)\(unit)"
        }
        return matchedText.trimmingCharacters(in: .whitespaces)
    }
}
