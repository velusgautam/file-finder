import SwiftUI
@preconcurrency import AppKit

public struct DuplicateStackCardView: View {
    public let group: DuplicateGroup
    public let isSelected: Bool
    public let onSelect: () -> Void

    @State private var thumbnail: NSImage? = nil
    @State private var isHovered: Bool = false

    public init(group: DuplicateGroup, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.group = group
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    private var primaryFile: FileItem? {
        group.items.first
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Stacked Cards Layering Container
                ZStack {
                    // Layer 3 (if 3 or more copies)
                    if group.items.count >= 3 {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ScandinavianTheme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
                            .frame(height: 125)
                            .rotationEffect(.degrees(4))
                            .offset(x: 6, y: -6)
                            .opacity(0.6)
                    }

                    // Layer 2 (Duplicate Copy behind)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ScandinavianTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ScandinavianTheme.duplicatesBorder.opacity(0.8), lineWidth: 1)
                        )
                        .frame(height: 125)
                        .rotationEffect(.degrees(-3.5))
                        .offset(x: -5, y: -4)
                        .opacity(0.85)

                    // Layer 1 (Front Active Card)
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ScandinavianTheme.cardBackground)
                            .frame(height: 130)
                            .overlay {
                                if let img = thumbnail {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .padding(4)
                                } else {
                                    Image(systemName: primaryFile?.category.systemImage ?? "doc.on.doc")
                                        .font(.system(size: 32))
                                        .foregroundColor(ScandinavianTheme.duplicatesIcon.opacity(0.7))
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.accentColor : ScandinavianTheme.hairlineBorder, lineWidth: isSelected ? 2 : 1)
                            )

                        // Badges Overlay
                        HStack(spacing: 5) {
                            // "X Copies" Duplicate Badge
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("\(group.items.count) Copies")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ScandinavianTheme.duplicatesTint)
                            .foregroundColor(ScandinavianTheme.duplicatesIcon)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(ScandinavianTheme.duplicatesBorder, lineWidth: 0.8))

                            if let ext = primaryFile?.fileExtension, !ext.isEmpty {
                                Text(ext)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(.top, 6)

                // Metadata Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryFile?.name ?? "Duplicate File")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file))
                        Text("•")
                        Text("\(group.formattedWastedSize) wasted")
                            .foregroundColor(ScandinavianTheme.duplicatesIcon)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 2)
            }
            .padding(12)
            .frame(width: 200)
            .background(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : (isHovered ? ScandinavianTheme.duplicatesBorder : Color.clear), lineWidth: 1.2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .task(id: primaryFile?.url) {
            if let url = primaryFile?.url {
                thumbnail = await ThumbnailService.shared.thumbnail(for: url, size: CGSize(width: 320, height: 240))
            }
        }
    }
}
