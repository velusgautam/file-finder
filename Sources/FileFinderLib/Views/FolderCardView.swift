import SwiftUI
@preconcurrency import AppKit

public struct FolderCardView: View {
    public let folder: FolderItem
    public let cardWidth: CGFloat
    public let onOpen: () -> Void
    public let onTrash: ((FolderItem) -> Void)?

    @State private var isHovered: Bool = false

    public init(
        folder: FolderItem,
        cardWidth: CGFloat = 185,
        onOpen: @escaping () -> Void,
        onTrash: ((FolderItem) -> Void)? = nil
    ) {
        self.folder = folder
        self.cardWidth = cardWidth
        self.onOpen = onOpen
        self.onTrash = onTrash
    }

    private var thumbnailHeight: CGFloat {
        max(90, cardWidth * 0.65)
    }

    private var iconSize: CGFloat {
        cardWidth < 160 ? 38 : (cardWidth < 200 ? 46 : 56)
    }

    public var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                // Folder Icon Preview Container
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.60, blue: 0.95).opacity(0.12),
                                    Color(red: 0.25, green: 0.60, blue: 0.95).opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: thumbnailHeight)
                        .overlay {
                            Image(systemName: "folder.fill")
                                .font(.system(size: iconSize))
                                .foregroundColor(Color(red: 0.25, green: 0.60, blue: 0.95))
                                .shadow(color: Color(red: 0.25, green: 0.60, blue: 0.95).opacity(0.25), radius: 6, y: 3)
                        }

                    // Top trailing badge / indicator
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.6)
                    .padding(6)
                }

                // Folder Metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: cardWidth < 160 ? 11 : 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(folder.formattedItemCount)
                        Text("•")
                        Text(folder.relativeDateString)
                    }
                    .font(.system(size: cardWidth < 160 ? 9.5 : 10.5, weight: .regular))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
            }
            .padding(9)
            .frame(width: cardWidth)
            .background(ScandinavianTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius)
                    .stroke(isHovered ? Color.accentColor.opacity(0.35) : ScandinavianTheme.hairlineBorder, lineWidth: 1)
            )
            .shadow(color: isHovered ? Color.black.opacity(0.08) : ScandinavianTheme.softShadow, radius: isHovered ? 12 : 5, y: isHovered ? 5 : 2)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") {
                onOpen()
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([folder.url])
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(folder.url.path, forType: .string)
            }

            if let onTrash = onTrash {
                Divider()

                Button(role: .destructive) {
                    onTrash(folder)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
    }
}
