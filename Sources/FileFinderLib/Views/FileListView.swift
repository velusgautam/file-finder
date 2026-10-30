import SwiftUI
@preconcurrency import AppKit

public struct FileListView: View {
    public let folders: [FolderItem]
    public let items: [DisplayItem]
    @ObservedObject public var viewModel: ScannerViewModel
    public let onOpenFolder: ((FolderItem) -> Void)?
    public let onTrashFolder: ((FolderItem) -> Void)?
    public let onSelect: (FileItem) -> Void
    public let onTrash: (FileItem) -> Void

    public init(
        folders: [FolderItem] = [],
        items: [DisplayItem],
        viewModel: ScannerViewModel,
        onOpenFolder: ((FolderItem) -> Void)? = nil,
        onTrashFolder: ((FolderItem) -> Void)? = nil,
        onSelect: @escaping (FileItem) -> Void,
        onTrash: @escaping (FileItem) -> Void
    ) {
        self.folders = folders
        self.items = items
        self.viewModel = viewModel
        self.onOpenFolder = onOpenFolder
        self.onTrashFolder = onTrashFolder
        self.onSelect = onSelect
        self.onTrash = onTrash
    }

    private var sortedFolders: [FolderItem] {
        guard !folders.isEmpty else { return [] }
        let sorted: [FolderItem]
        switch viewModel.selectedSortOption {
        case .name:
            sorted = folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateModified:
            sorted = folders.sorted { $0.modificationDate < $1.modificationDate }
        case .size:
            sorted = folders.sorted { $0.itemCount < $1.itemCount }
        default:
            sorted = folders
        }
        return viewModel.selectedSortOrder == .ascending ? sorted : Array(sorted.reversed())
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Table Header Row
            HStack(spacing: 12) {
                // Name Column
                headerCell(title: "Name", option: .name, alignment: .leading)
                    .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

                // Date Modified Column
                headerCell(title: "Date Modified", option: .dateModified, alignment: .leading)
                    .frame(width: 140, alignment: .leading)

                // Size Column
                headerCell(title: "Size", option: .size, alignment: .trailing)
                    .frame(width: 85, alignment: .trailing)

                // Kind Column
                Text("Kind")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 95, alignment: .leading)

                // Source / Origin Column
                Text("Source")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
            .overlay(Divider().opacity(0.3), alignment: .bottom)

            if folders.isEmpty && items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("This Folder is Empty")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("No files or subfolders found in this directory.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                // Virtualized Scroll List
                ScrollView {
                    LazyVStack(spacing: 1) {
                        // Subfolders first (just like macOS Finder)
                        ForEach(sortedFolders) { folder in
                            FolderListRowView(
                                folder: folder,
                                onOpen: { onOpenFolder?(folder) },
                                onTrash: onTrashFolder != nil ? { onTrashFolder?(folder) } : nil
                            )
                        }

                        // Files second
                        ForEach(items) { displayItem in
                            let item = displayItem.item
                            let isSelected = viewModel.selectedFile?.url == item.url

                            FileListRowView(
                                item: item,
                                isOCRMatch: displayItem.isOCRMatch,
                                isSelected: isSelected,
                                onSelect: { onSelect(item) },
                                onTrash: { onTrash(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func headerCell(title: String, option: SortOption, alignment: Alignment) -> some View {
        Button {
            if viewModel.selectedSortOption == option {
                viewModel.selectedSortOrder.toggle()
            } else {
                viewModel.selectedSortOption = option
                viewModel.selectedSortOrder = .descending
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))

                if viewModel.selectedSortOption == option {
                    Image(systemName: viewModel.selectedSortOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .foregroundColor(viewModel.selectedSortOption == option ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
    }
}

/// Unified Finder-style list row for folders
public struct FolderListRowView: View {
    public let folder: FolderItem
    public let onOpen: () -> Void
    public let onTrash: (() -> Void)?

    @State private var isHovered: Bool = false

    public init(folder: FolderItem, onOpen: @escaping () -> Void, onTrash: (() -> Void)? = nil) {
        self.folder = folder
        self.onOpen = onOpen
        self.onTrash = onTrash
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon + Name
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.25, green: 0.60, blue: 0.95))
                    .frame(width: 20, height: 20)

                Text(folder.name)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            // Date Modified
            Text(folder.relativeDateString)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            // Size Column shows Item Count for folders
            Text(folder.formattedItemCount)
                .font(.system(size: 11.5, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 85, alignment: .trailing)

            // Kind
            Text("Folder")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 95, alignment: .leading)

            // Source / Origin
            HStack(spacing: 4) {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(isHovered ? 0.8 : 0.25))
            }
            .frame(width: 110, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onOpen()
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
                    onTrash()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
    }
}

/// Dedicated high-speed single table row with lazy thumbnail
public struct FileListRowView: View {
    public let item: FileItem
    public let isOCRMatch: Bool
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onTrash: () -> Void

    @State private var isHovered: Bool = false
    @State private var icon: NSImage? = nil

    public init(
        item: FileItem,
        isOCRMatch: Bool,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onTrash: @escaping () -> Void
    ) {
        self.item = item
        self.isOCRMatch = isOCRMatch
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onTrash = onTrash
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon + Name
            HStack(spacing: 8) {
                if let img = icon {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }

                Text(item.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if isOCRMatch {
                    Text("OCR")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundColor(.indigo)
                        .clipShape(Capsule())
                }

                if !item.fileExtension.isEmpty {
                    Text(item.fileExtension)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            // Date Modified
            Text(item.relativeDateString)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            // File Size
            Text(item.formattedSize)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 85, alignment: .trailing)

            // Kind
            Text(item.category.displayTitle)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 95, alignment: .leading)

            // Source / Origin
            HStack(spacing: 4) {
                if item.origin != .unknown {
                    Image(systemName: item.origin.iconSystemName)
                        .font(.system(size: 9))
                    Text(item.origin.displayName)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                } else {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .foregroundColor(item.origin != .unknown ? item.origin.tintColor : .secondary)
            .frame(width: 110, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .task(id: item.url) {
            icon = NSWorkspace.shared.icon(forFile: item.url.path)
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(item.url)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }

            if let originURL = item.originURL {
                Button("Copy Download Source URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(originURL.absoluteString, forType: .string)
                }
            }

            Divider()

            Button(role: .destructive) {
                onTrash()
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
}
