import SwiftUI
@preconcurrency import AppKit

public struct MiniBubbleThumbnail: View {
    public let url: URL
    public let fallbackIcon: String
    @State private var image: NSImage? = nil

    public init(url: URL, fallbackIcon: String = "doc") {
        self.url = url
        self.fallbackIcon = fallbackIcon
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(ScandinavianTheme.bubbleBackground)
                .frame(width: 26, height: 26)

            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .overlay(Circle().stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
        .task(id: url) {
            image = await ThumbnailService.shared.thumbnail(for: url, size: CGSize(width: 48, height: 48))
        }
    }
}

public struct StackedPreviewBubblesView: View {
    public let items: [FileItem]
    public let totalCount: Int
    public let fallbackIcon: String

    public init(items: [FileItem], totalCount: Int, fallbackIcon: String = "doc") {
        self.items = items
        self.totalCount = totalCount
        self.fallbackIcon = fallbackIcon
    }

    public var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { index, item in
                MiniBubbleThumbnail(url: item.url, fallbackIcon: fallbackIcon)
                    .zIndex(Double(4 - index))
            }

            if totalCount > 3 {
                Text("+\(min(totalCount - 3, 99))")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(ScandinavianTheme.bubbleBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    .zIndex(0)
            }
        }
    }
}
