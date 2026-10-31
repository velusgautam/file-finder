import SwiftUI
@preconcurrency import AppKit

public struct FileCardView: View {
    public let item: FileItem
    public let isOCRMatch: Bool
    public let isSelected: Bool
    public let cardWidth: CGFloat
    public let showExtension: Bool
    public let selectedURLs: [URL]?
    public let onSelect: (() -> Void)?
    public let onTrash: ((FileItem) -> Void)?
    @State private var thumbnail: NSImage? = nil
    @State private var isHovered: Bool = false

    public init(
        item: FileItem,
        isOCRMatch: Bool = false,
        isSelected: Bool = false,
        cardWidth: CGFloat = 190,
        showExtension: Bool = false,
        selectedURLs: [URL]? = nil,
        onSelect: (() -> Void)? = nil,
        onTrash: ((FileItem) -> Void)? = nil
    ) {
        self.item = item
        self.isOCRMatch = isOCRMatch
        self.isSelected = isSelected
        self.cardWidth = cardWidth
        self.showExtension = showExtension
        self.selectedURLs = selectedURLs
        self.onSelect = onSelect
        self.onTrash = onTrash
    }

    private var thumbnailHeight: CGFloat {
        max(90, cardWidth * 0.65)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail Preview Container
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
                    .frame(height: thumbnailHeight)
                    .overlay {
                        if let image = thumbnail {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(4)
                        } else {
                            ProgressView()
                                .scaleEffect(0.65)
                        }
                    }

                // Origin & Extension Badges
                HStack(spacing: 4) {
                    if isOCRMatch {
                        HStack(spacing: 2) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 8, weight: .bold))
                            Text("OCR")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.indigo.opacity(0.6), lineWidth: 0.8))
                        .foregroundColor(.indigo)
                    }

                    if item.origin != .unknown && cardWidth >= 160 {
                        HStack(spacing: 2) {
                            Image(systemName: item.origin.iconSystemName)
                                .font(.system(size: 8, weight: .bold))
                            Text(item.origin.displayName)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(item.origin.tintColor.opacity(0.35), lineWidth: 0.8))
                        .foregroundColor(item.origin.tintColor)
                    }

                    if !item.fileExtension.isEmpty {
                        Text(item.fileExtension)
                            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(6)
            }

            // File Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(showExtension: showExtension))
                    .font(.system(size: cardWidth < 160 ? 11 : 12.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Text(item.formattedSize)
                    Text("•")
                    Text(item.relativeDateString)
                }
                .font(.system(size: cardWidth < 160 ? 9.5 : 10.5, weight: .regular))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(9)
        .frame(width: cardWidth)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : ScandinavianTheme.cardBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius)
                .stroke(
                    isSelected
                        ? Color.accentColor
                        : (isHovered ? Color.accentColor.opacity(0.35) : ScandinavianTheme.hairlineBorder),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected
                ? Color.accentColor.opacity(0.22)
                : (isHovered ? Color.black.opacity(0.08) : ScandinavianTheme.softShadow),
            radius: isHovered || isSelected ? 10 : 5,
            y: isHovered || isSelected ? 4 : 2
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .task(id: item.url) {
            thumbnail = await ThumbnailService.shared.thumbnail(for: item.url)
        }
        .onTapGesture {
            onSelect?()
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .onDrag {
            let urlsToDrag: [URL]
            if let selected = selectedURLs, selected.contains(item.url), selected.count > 1 {
                urlsToDrag = selected
            } else {
                urlsToDrag = [item.url]
            }
            return MultiSelectionHelper.createMultiFileItemProvider(for: item.url, selectedURLs: urlsToDrag)
        }
        .fileContextMenu(for: item, onTrash: { fileToTrash in
            if let onTrash = onTrash {
                onTrash(fileToTrash)
            } else {
                try? FileManager.default.trashItem(at: fileToTrash.url, resultingItemURL: nil)
            }
        })
    }
}
