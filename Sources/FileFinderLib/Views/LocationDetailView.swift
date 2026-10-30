import SwiftUI

public struct LocationDetailView: View {
    @ObservedObject public var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: viewModel.gridIconSize, maximum: viewModel.gridIconSize + 40), spacing: 18)]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Unified Top Toolbar (Breadcrumbs & Controls)
            FilterSortToolbarView(viewModel: viewModel)

            Divider().opacity(0.3)

            // Main Content Area
            if viewModel.layoutMode == .list {
                // List Mode: Direct full-height table layout, unified folders + files (Finder style)
                FileListView(
                    folders: viewModel.currentFolderSubfolders,
                    items: viewModel.displayedItems,
                    viewModel: viewModel,
                    onOpenFolder: { folder in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.navigateToFolder(folder.url)
                        }
                    },
                    onTrashFolder: { folder in
                        viewModel.trashFolder(folder)
                    },
                    onSelect: { file in
                        viewModel.selectedDuplicateGroup = nil
                        viewModel.selectedFile = file
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isDetailInspectorVisible = true
                        }
                    },
                    onTrash: { file in
                        viewModel.trashFile(file)
                    }
                )
            } else {
                // Grid Mode: Scrollable grid with harmonized sizing for folders and files
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Empty folder state
                        if viewModel.currentFolderSubfolders.isEmpty && viewModel.displayedItems.isEmpty {
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
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .padding(.top, 40)
                        } else {
                            // 1. Folders Section (if any subfolders exist)
                            if !viewModel.currentFolderSubfolders.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Text("Folders")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(nsColor: .labelColor))

                                        Text("\(viewModel.currentFolderSubfolders.count)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                            .foregroundColor(.secondary)
                                    }

                                    LazyVGrid(columns: gridColumns, spacing: 18) {
                                        ForEach(viewModel.currentFolderSubfolders) { folder in
                                            FolderCardView(
                                                folder: folder,
                                                cardWidth: viewModel.gridIconSize,
                                                onOpen: {
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                        viewModel.navigateToFolder(folder.url)
                                                    }
                                                },
                                                onTrash: { folderToTrash in
                                                    viewModel.trashFolder(folderToTrash)
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            // 2. Files Section (if any files exist)
                            if !viewModel.displayedItems.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Text("Files")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(nsColor: .labelColor))

                                        Text("\(viewModel.displayedItems.count)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                            .foregroundColor(.secondary)
                                    }

                                    LazyVGrid(columns: gridColumns, spacing: 18) {
                                        ForEach(viewModel.displayedItems) { item in
                                            FileCardView(
                                                item: item.item,
                                                isOCRMatch: item.isOCRMatch,
                                                cardWidth: viewModel.gridIconSize
                                            ) { fileToTrash in
                                                viewModel.trashFile(fileToTrash)
                                            }
                                            .onTapGesture {
                                                viewModel.selectedDuplicateGroup = nil
                                                viewModel.selectedFile = item.item
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    viewModel.isDetailInspectorVisible = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}
