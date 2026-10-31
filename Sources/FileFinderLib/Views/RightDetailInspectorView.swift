import SwiftUI
@preconcurrency import AppKit

public struct RightDetailInspectorView: View {
    public let item: FileItem?
    @ObservedObject public var viewModel: ScannerViewModel
    public let onClose: () -> Void

    @State private var previewImage: NSImage? = nil

    public init(item: FileItem?, viewModel: ScannerViewModel, onClose: @escaping () -> Void) {
        self.item = item
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inspector Header
            HStack {
                Text(viewModel.selectedDuplicateGroup != nil ? "Duplicate Details" : "Inspector")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider().opacity(0.4)

            if let group = viewModel.selectedDuplicateGroup {
                duplicateGroupDetailView(group: group)
            } else if let item = item {
                fileDetailsView(item: item)
            } else {
                librarySummaryView
            }
        }
        .frame(width: 310)
        .background(ScandinavianTheme.sidebarBackground)
    }

    // Duplicate Comparison View
    private func duplicateGroupDetailView(group: DuplicateGroup) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Large Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                        .frame(height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1)
                        )

                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(6)
                    } else {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 38))
                            .foregroundColor(ScandinavianTheme.duplicatesIcon)
                    }
                }
                .task(id: group.items.first?.url) {
                    if let first = group.items.first {
                        previewImage = await ThumbnailService.shared.thumbnail(for: first.url, size: CGSize(width: 500, height: 400))
                    }
                }

                // File Name & Wasted Size
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.items.first?.name ?? "Duplicate File")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text("\(group.items.count) Identical Copies")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ScandinavianTheme.duplicatesTint)
                            .foregroundColor(ScandinavianTheme.duplicatesIcon)
                            .clipShape(Capsule())

                        Text(group.formattedWastedSize + " wasted")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ScandinavianTheme.duplicatesIcon)
                    }
                }

                // Clean Copies Action
                Button {
                    viewModel.trashDuplicateCopies(in: group)
                    viewModel.selectedDuplicateGroup = nil
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Keep Original & Trash Copies")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(ScandinavianTheme.duplicatesIcon)

                Divider().opacity(0.4)

                // Detailed Copies Path List
                Text("All Locations on Disk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                VStack(spacing: 10) {
                    ForEach(group.items) { item in
                        let isOriginal = (item.url == group.original?.url)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(isOriginal ? "ORIGINAL" : "COPY")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isOriginal ? ScandinavianTheme.greenHighlight.opacity(0.15) : ScandinavianTheme.duplicatesIcon.opacity(0.15))
                                    .foregroundColor(isOriginal ? ScandinavianTheme.greenHighlight : ScandinavianTheme.duplicatesIcon)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Spacer()

                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "folder")
                                        Text("Reveal")
                                    }
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)

                                if !isOriginal {
                                    Button {
                                        viewModel.trashFile(item)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(item.url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(nsColor: .labelColor))
                                .lineLimit(3)
                                .truncationMode(.middle)

                            Text("Modified \(item.relativeDateString) • \(item.formattedSize)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isOriginal ? ScandinavianTheme.greenHighlight.opacity(0.3) : ScandinavianTheme.hairlineBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(18)
        }
    }

    // Detail view for a selected file
    private func fileDetailsView(item: FileItem) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Large Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                        .frame(height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1)
                        )

                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(6)
                    } else {
                        ProgressView()
                    }
                }
                .task(id: item.url) {
                    previewImage = await ThumbnailService.shared.thumbnail(for: item.url, size: CGSize(width: 500, height: 400))
                }

                // File Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName(showExtension: viewModel.showFileExtensions))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(item.fileExtension)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundColor(.secondary)

                        Text(item.category.displayTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Divider().opacity(0.4)

                // Metadata Table
                VStack(spacing: 10) {
                    metadataRow(label: "Size", value: "\(item.formattedSize) (\(item.fileSize) bytes)")
                    metadataRow(label: "Modified", value: item.relativeDateString)

                    if item.origin != .unknown {
                        HStack(alignment: .top) {
                            Text("Source")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)

                            HStack(spacing: 4) {
                                Image(systemName: item.origin.iconSystemName)
                                    .font(.system(size: 10))
                                Text(item.origin.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(item.origin.tintColor)

                            Spacer()
                        }

                        if let originURL = item.originURL {
                            HStack {
                                Text("Link")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                Text(originURL.host ?? originURL.absoluteString)
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                    .lineLimit(1)

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(originURL.absoluteString, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // File Location
                    HStack(alignment: .top) {
                        Text("Where")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Text(item.url.deletingLastPathComponent().path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        Spacer()
                    }
                }

                // OCR Text Section (if available)
                if let ocrText = viewModel.ocrTextByFileURL[item.url], !ocrText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Recognized Text", systemImage: "text.viewfinder")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.indigo)

                            Spacer()

                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(ocrText, forType: .string)
                            }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.plain)
                            .foregroundColor(.indigo)
                        }

                        Text(ocrText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Spacer(minLength: 20)

                // Actions
                VStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.open(item.url)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open File")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text("Reveal in Finder")
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        viewModel.trashFile(item)
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Move to Trash")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(nsColor: .labelColor))
                .lineLimit(1)

            Spacer()
        }
    }

    // Default inspector state when no file or duplicate group is selected
    private var librarySummaryView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library Summary")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                Text("Select any file or duplicate stack to inspect paths, sources, and details.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                summaryStat(title: "Total Files", value: "\(viewModel.totalFileCount)")
                summaryStat(title: "Total Size", value: viewModel.formattedTotalSize)
                summaryStat(title: "Duplicates Found", value: "\(viewModel.duplicateGroups.count) groups")
                summaryStat(title: "Wasted Space", value: viewModel.formattedDuplicateSize)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
        .padding(18)
    }

    private func summaryStat(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
        }
    }
}
