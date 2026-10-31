import Foundation

/// Pure deterministic relevance scoring engine for ranking search results
public enum SearchRelevanceScorer {

    /// Calculates a numerical relevance score for a given file against a user query and parsed filter.
    /// Returns 0.0 if the file does not match or is completely irrelevant.
    public static func score(
        file: FileItem,
        query: String,
        ocrText: String? = nil,
        parsedFilter: SearchFilter? = nil
    ) -> Double {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return 0.0 }

        // If a parsedFilter is provided and the file fails structural filter constraints (date, size, origin, category), return 0
        if let filter = parsedFilter {
            if let cat = filter.category, file.category != cat { return 0.0 }
            if let origin = filter.origin, file.origin != origin { return 0.0 }
            if let range = filter.dateRange, !range.contains(file.modificationDate) { return 0.0 }
            if let size = filter.sizeConstraint, !size.matches(file.fileSize) { return 0.0 }
            if let targetExt = filter.targetExtension, file.fileExtension.lowercased() != targetExt.lowercased() { return 0.0 }
            if filter.onlyScreenshots {
                let isScreenshot = file.category == .images && SearchFilter.isScreenshotFileName(file.name)
                if !isScreenshot { return 0.0 }
            }
        }

        let queryLower = trimmedQuery.lowercased()
        let nameLower = file.name.lowercased()
        let extLower = file.fileExtension.lowercased()
        let parentLower = file.url.deletingLastPathComponent().path.lowercased()
        let ocrLower = ocrText?.lowercased() ?? ""

        var totalScore = 0.0

        // 1. Exact Name Matches (Highest Priority)
        // Check exact match with or without extension
        let baseNameLower = file.url.deletingPathExtension().lastPathComponent.lowercased()
        if nameLower == queryLower || baseNameLower == queryLower {
            totalScore += 1000.0
        } else if nameLower.hasPrefix(queryLower) || baseNameLower.hasPrefix(queryLower) {
            // 2. Prefix Match
            totalScore += 700.0
        } else {
            // 3. Word Boundary Match (e.g., "my_resume.pdf" or "resume-2026.docx" or "ResumeFinal")
            let words = extractWords(from: nameLower)
            var hasWordPrefix = false
            var hasExactWord = false

            for word in words {
                if word == queryLower {
                    hasExactWord = true
                    break
                } else if word.hasPrefix(queryLower) {
                    hasWordPrefix = true
                }
            }

            if hasExactWord {
                totalScore += 600.0
            } else if hasWordPrefix {
                totalScore += 450.0
            } else if nameLower.contains(queryLower) {
                // 4. Substring Match inside filename
                totalScore += 300.0
            }
        }

        // 5. Multi-token keywords evaluation (e.g. "resume pdf" or "q3 financial report")
        let tokens = queryLower
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !["and", "or", "in", "with", "the", "a", "an"].contains($0) }

        if tokens.count > 1 {
            var allTokensMatched = true
            var tokenScore = 0.0

            for token in tokens {
                var tokenMatched = false

                if nameLower == token || baseNameLower == token {
                    tokenScore += 350.0
                    tokenMatched = true
                } else if nameLower.hasPrefix(token) {
                    tokenScore += 250.0
                    tokenMatched = true
                } else if nameLower.contains(token) {
                    tokenScore += 150.0
                    tokenMatched = true
                } else if extLower == token {
                    tokenScore += 100.0
                    tokenMatched = true
                } else if parentLower.contains(token) {
                    tokenScore += 50.0
                    tokenMatched = true
                } else if !ocrLower.isEmpty && ocrLower.contains(token) {
                    tokenScore += 40.0
                    tokenMatched = true
                }

                if !tokenMatched {
                    allTokensMatched = false
                    break
                }
            }

            if allTokensMatched {
                totalScore += tokenScore + 150.0 // Multi-token coordination bonus
            } else if totalScore == 0.0 {
                // If not all required tokens matched and single-string check didn't match, file is irrelevant
                return 0.0
            }
        }

        // 6. File extension exact match
        if extLower == queryLower {
            totalScore += 120.0
        }

        // 7. Directory / Parent path match
        if parentLower.contains(queryLower) {
            totalScore += 60.0
        }

        // 8. OCR text match (for images/scans)
        if !ocrLower.isEmpty {
            if ocrLower.contains(queryLower) {
                let ocrWords = extractWords(from: ocrLower)
                if ocrWords.contains(queryLower) {
                    totalScore += 90.0
                } else {
                    totalScore += 40.0
                }
            }
        }

        // If file matched nothing above, it's irrelevant
        if totalScore <= 0.0 {
            // One last fallback: if parsedFilter matched evaluation via keyword/chips
            if let filter = parsedFilter {
                let (matches, matchedByOCR) = filter.matchEvaluation(for: file, ocrText: ocrText)
                if matches {
                    totalScore += matchedByOCR ? 40.0 : 80.0
                }
            }
        }

        guard totalScore > 0.0 else { return 0.0 }

        // 9. Recency bonus (Tie-breaker only: up to +25 points so it never outranks a better name match)
        let now = Date()
        let ageInSeconds = now.timeIntervalSince(file.modificationDate)
        if ageInSeconds < 86400 { // < 24 hours
            totalScore += 25.0
        } else if ageInSeconds < 7 * 86400 { // < 7 days
            totalScore += 15.0
        } else if ageInSeconds < 30 * 86400 { // < 30 days
            totalScore += 8.0
        }

        return totalScore
    }

    /// Splits string into individual words by space, underscore, hyphen, dot, and camelCase
    private static func extractWords(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: " _-./\\+()[]{},:;")
        return text.components(separatedBy: separators).filter { !$0.isEmpty }
    }
}
