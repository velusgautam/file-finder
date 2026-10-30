import SwiftUI

public struct DownloadedFromCardView: View {
    public let origin: DownloadOrigin
    public let count: Int
    public let totalByteSize: Int64
    public let sampleItems: [FileItem]
    public let onSelect: () -> Void

    @State private var isHovered: Bool = false

    public init(
        origin: DownloadOrigin,
        count: Int,
        totalByteSize: Int64,
        sampleItems: [FileItem] = [],
        onSelect: @escaping () -> Void
    ) {
        self.origin = origin
        self.count = count
        self.totalByteSize = totalByteSize
        self.sampleItems = sampleItems
        self.onSelect = onSelect
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Origin Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(origin.tintColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: origin.iconSystemName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(origin.tintColor)
                }

                // Metadata Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(origin.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)

                    Text("\(count) files · \(formattedSize)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Stacked thumbnail bubbles
                StackedPreviewBubblesView(
                    items: sampleItems,
                    totalCount: count,
                    fallbackIcon: origin.iconSystemName
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 260)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHovered ? origin.tintColor.opacity(0.3) : ScandinavianTheme.hairlineBorder, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? Color.black.opacity(0.06) : Color.black.opacity(0.02),
                radius: isHovered ? 6 : 2,
                y: isHovered ? 2 : 1
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
