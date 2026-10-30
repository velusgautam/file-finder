import SwiftUI

public enum CleanUpCardType {
    case duplicates
    case forgottenDownloads
    case oldScreenshots
    case largeFiles

    public var title: String {
        switch self {
        case .duplicates:         return "Duplicates"
        case .forgottenDownloads: return "Forgotten Downloads"
        case .oldScreenshots:     return "Old Screenshots"
        case .largeFiles:         return "Large Files"
        }
    }

    public var iconName: String {
        switch self {
        case .duplicates:         return "doc.on.doc"
        case .forgottenDownloads: return "arrow.down.circle"
        case .oldScreenshots:     return "camera.viewfinder"
        case .largeFiles:         return "circle.dashed"
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .duplicates:         return ScandinavianTheme.duplicatesTint
        case .forgottenDownloads: return ScandinavianTheme.forgottenDownloadsTint
        case .oldScreenshots:     return ScandinavianTheme.oldScreenshotsTint
        case .largeFiles:         return ScandinavianTheme.unusedAppsTint
        }
    }

    public var borderColor: Color {
        switch self {
        case .duplicates:         return ScandinavianTheme.duplicatesBorder
        case .forgottenDownloads: return ScandinavianTheme.forgottenDownloadsBorder
        case .oldScreenshots:     return ScandinavianTheme.oldScreenshotsBorder
        case .largeFiles:         return ScandinavianTheme.unusedAppsBorder
        }
    }

    public var iconColor: Color {
        switch self {
        case .duplicates:         return ScandinavianTheme.duplicatesIcon
        case .forgottenDownloads: return ScandinavianTheme.forgottenDownloadsIcon
        case .oldScreenshots:     return ScandinavianTheme.oldScreenshotsIcon
        case .largeFiles:         return ScandinavianTheme.unusedAppsIcon
        }
    }
}

public struct CleanUpCardView: View {
    public let type: CleanUpCardType
    public let formattedSize: String
    public let itemCount: Int
    public let sampleItems: [FileItem]
    public let onSelect: () -> Void

    @State private var isHovered: Bool = false

    public init(
        type: CleanUpCardType,
        formattedSize: String,
        itemCount: Int,
        sampleItems: [FileItem] = [],
        onSelect: @escaping () -> Void
    ) {
        self.type = type
        self.formattedSize = formattedSize
        self.itemCount = itemCount
        self.sampleItems = sampleItems
        self.onSelect = onSelect
    }

    private var subtitleText: String {
        switch type {
        case .duplicates:
            return "\(itemCount) extra copies >"
        case .forgottenDownloads:
            return "\(itemCount) items >"
        case .oldScreenshots:
            return "\(itemCount) items >"
        case .largeFiles:
            return "\(itemCount) items >"
        }
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Top row: Type Icon on left, stacked preview bubbles on right
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(type.iconColor.opacity(0.12))
                            .frame(width: 34, height: 34)

                        Image(systemName: type.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(type.iconColor)
                    }

                    Spacer()

                    StackedPreviewBubblesView(
                        items: sampleItems,
                        totalCount: itemCount,
                        fallbackIcon: type.iconName
                    )
                }

                Spacer(minLength: 16)

                // Bottom Content: Title, Giant Metric Number, Subtitle
                Text(type.title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)

                Text(formattedSize)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .padding(.top, 2)

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(type.borderColor, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? Color.black.opacity(0.08) : Color.black.opacity(0.02),
                radius: isHovered ? 8 : 3,
                y: isHovered ? 3 : 1
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
