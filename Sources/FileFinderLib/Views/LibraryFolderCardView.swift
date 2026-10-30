import SwiftUI

public struct LibraryFolderCardView: View {
    public let category: ShelfCategory
    public let items: [FileItem]
    public let totalByteSize: Int64
    public let onSelect: () -> Void

    @State private var isHovered: Bool = false

    public init(
        category: ShelfCategory,
        items: [FileItem],
        totalByteSize: Int64? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.category = category
        self.items = items
        self.totalByteSize = totalByteSize ?? items.reduce(0) { $0 + $1.fileSize }
        self.onSelect = onSelect
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalByteSize, countStyle: .file)
    }

    public var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                // Background Folder Tab Shape
                FolderTabShape(tabWidthRatio: 0.44, tabHeight: 16, cornerRadius: 16)
                    .fill(ScandinavianTheme.folderColor(for: category))
                    .overlay(
                        FolderTabShape(tabWidthRatio: 0.44, tabHeight: 16, cornerRadius: 16)
                            .stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    // Top Row with 3-dots Context Menu
                    HStack {
                        Spacer()
                        Menu {
                            Button("Open in Finder") {
                                if let first = items.first {
                                    NSWorkspace.shared.activateFileViewerSelecting([first.url])
                                }
                            }
                            Button("Copy Summary") {
                                let summary = "\(category.displayTitle): \(items.count) items (\(formattedSize))"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(summary, forType: .string)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.8))
                                .frame(width: 28, height: 28)
                                .background(ScandinavianTheme.cardBackground)
                                .clipShape(Circle())
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.top, 14)
                    .padding(.trailing, 14)

                    // Title
                    Text(category.displayTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .padding(.top, 10)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 28)

                    // Bottom Row: Stacked Bubbles + Counts
                    HStack(alignment: .center, spacing: 12) {
                        StackedPreviewBubblesView(
                            items: items,
                            totalCount: items.count,
                            fallbackIcon: category.systemImage
                        )

                        Spacer()

                        Text("\(items.count) items · \(formattedSize)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            }
            .frame(height: 155)
            .shadow(
                color: isHovered ? Color.black.opacity(0.08) : Color.black.opacity(0.02),
                radius: isHovered ? 10 : 4,
                y: isHovered ? 4 : 2
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
