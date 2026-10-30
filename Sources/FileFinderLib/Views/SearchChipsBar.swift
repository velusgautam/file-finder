import SwiftUI

public struct SuggestionChipItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let iconSystemName: String
    public let queryToken: String
    public let chipType: FilterChipType

    public init(id: String = UUID().uuidString, title: String, iconSystemName: String, queryToken: String, chipType: FilterChipType) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
        self.queryToken = queryToken
        self.chipType = chipType
    }
}

public struct SearchChipsBar: View {
    @ObservedObject var viewModel: ScannerViewModel

    public static let suggestions: [SuggestionChipItem] = [
        SuggestionChipItem(title: "Screenshots", iconSystemName: "camera.viewfinder", queryToken: "screenshots", chipType: .screenshot),
        SuggestionChipItem(title: "From Slack", iconSystemName: "bubble.left.and.bubble.right", queryToken: "from slack", chipType: .origin(.slack)),
        SuggestionChipItem(title: "From Chrome", iconSystemName: "globe", queryToken: "from chrome", chipType: .origin(.chrome)),
        SuggestionChipItem(title: "PDFs", iconSystemName: "doc.text", queryToken: "pdfs", chipType: .fileExtension("pdf")),
        SuggestionChipItem(title: "This Week", iconSystemName: "calendar", queryToken: "this week", chipType: .dateRange(DateRange())),
        SuggestionChipItem(title: "Large (>50MB)", iconSystemName: "shippingbox", queryToken: "> 50mb", chipType: .fileSize(FileSizeConstraint(minBytes: 50 * 1024 * 1024))),
        SuggestionChipItem(title: "From AirDrop", iconSystemName: "antenna.radiowaves.left.and.right", queryToken: "from airdrop", chipType: .origin(.airdrop)),
        SuggestionChipItem(title: "Code", iconSystemName: "curlybraces", queryToken: "code", chipType: .category(.code))
    ]

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active Filter Chips (if any)
            if !viewModel.activeChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Active:")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.trailing, 2)

                        ForEach(viewModel.activeChips) { chip in
                            HStack(spacing: 5) {
                                if let icon = chip.iconSystemName {
                                    Image(systemName: icon)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                Text(chip.title)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))

                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        viewModel.removeChip(chip)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 2)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 0.8))
                        }

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                viewModel.clearAllFilters()
                            }
                        } label: {
                            Text("Clear all")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Quick Suggestions Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.suggestions, id: \.id) { suggestion in
                        let isActive = isSuggestionActive(suggestion)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                viewModel.toggleSuggestion(suggestion)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: suggestion.iconSystemName)
                                    .font(.system(size: 10, weight: .medium))
                                Text(suggestion.title)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isActive ? Color.accentColor.opacity(0.15) : ScandinavianTheme.cardBackground)
                            .foregroundColor(isActive ? Color.accentColor : Color.primary.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    isActive ? Color.accentColor.opacity(0.4) : ScandinavianTheme.hairlineBorder,
                                    lineWidth: 0.8
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func isSuggestionActive(_ suggestion: SuggestionChipItem) -> Bool {
        return viewModel.activeChips.contains { chip in
            switch (chip.type, suggestion.chipType) {
            case (.screenshot, .screenshot):
                return true
            case (.origin(let o1), .origin(let o2)):
                return o1 == o2
            case (.category(let c1), .category(let c2)):
                return c1 == c2
            case (.fileExtension(let e1), .fileExtension(let e2)):
                return e1.lowercased() == e2.lowercased()
            case (.fileSize, .fileSize):
                return chip.title == suggestion.title
            case (.dateRange, .dateRange):
                return chip.title == suggestion.title
            default:
                return false
            }
        }
    }
}
