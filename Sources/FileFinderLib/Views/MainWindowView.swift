import SwiftUI

public struct MainWindowView: View {
    @StateObject private var viewModel = ScannerViewModel()

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Collapsible Sidebar
            if viewModel.isSidebarVisible {
                HomySidebarView(viewModel: viewModel)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider().opacity(0.4)
            }

            // Main Content Area
            VStack(spacing: 0) {
                // Top Search & Status Bar
                topHeaderBar

                // Non-blocking background sync progress bar
                if viewModel.isLoading && !viewModel.allFiles.isEmpty {
                    BackgroundScanProgressStrip()
                } else {
                    Divider().opacity(0.4)
                }

                // Search Chips Bar (if searching or active filter chips)
                if !viewModel.searchQuery.isEmpty || !viewModel.activeChips.isEmpty {
                    SearchChipsBar(viewModel: viewModel)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)

                    Divider().opacity(0.3)
                }

                // Dynamic Body View
                ZStack {
                    if viewModel.isLoading && viewModel.allFiles.isEmpty {
                        // Beautiful Scandinavian initial loading view with progress bar
                        ScandinavianLoadingView(viewModel: viewModel)
                    } else if !viewModel.searchQuery.isEmpty {
                        // Search Results Grid with Filter & Sort Toolbar
                        VStack(spacing: 0) {
                            FilterSortToolbarView(viewModel: viewModel)
                            Divider().opacity(0.3)
                            searchResultsView
                        }
                    } else {
                        // Navigation Sections
                        switch viewModel.currentSection {
                        case .home:
                            HomeDashboardView(viewModel: viewModel)
                        case .downloadedFromOverview:
                            DownloadedFromOverviewView(viewModel: viewModel)
                        case .duplicates:
                            DuplicatesView(viewModel: viewModel)
                        case .location:
                            LocationDetailView(viewModel: viewModel)
                        case .applications:
                            ApplicationsView(viewModel: viewModel)
                        default:
                            sectionDetailView
                        }
                    }
                }
            }

            // Collapsible Right Detail Inspector
            if viewModel.isDetailInspectorVisible {
                Divider().opacity(0.4)

                RightDetailInspectorView(
                    item: viewModel.selectedFile,
                    viewModel: viewModel,
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isDetailInspectorVisible = false
                            viewModel.selectedDuplicateGroup = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(ScandinavianTheme.canvasBackground)
        .frame(minWidth: 1040, minHeight: 680)
    }

    // Top Header Bar
    private var topHeaderBar: some View {
        HStack(spacing: 16) {
            // Expand Sidebar Button when collapsed
            if !viewModel.isSidebarVisible {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.isSidebarVisible = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scaleAmount: 0.88))
                .pointerOnHover()
                .help("Show Sidebar")
            }

            // Search Pill
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField("Search, or try \"pdfs from last week\"...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointerOnHover()
                }

                // Keyboard Shortcut Keycap "⌘ F"
                HStack(spacing: 3) {
                    Text("⌘")
                        .font(.system(size: 10, weight: .bold))
                    Text("F")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(ScandinavianTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 0.8))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(ScandinavianTheme.searchBarBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
            .frame(maxWidth: 420)

            Spacer()

            // Non-intrusive Background Sync indicator
            if viewModel.isLoading && !viewModel.allFiles.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Scanning \(viewModel.scanCurrentFolder)... (\(viewModel.scanFilesCount))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 6)
            }

            // Background OCR indicator
            if viewModel.isOCRProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Indexing text (\(viewModel.ocrProcessedCount)/\(viewModel.ocrTotalCount))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 6)
            }

            // Library Size Label
            Text("Library size ")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            +
            Text(viewModel.formattedTotalSize)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))

            // Working Right Detail Inspector Toggle Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isDetailInspectorVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isDetailInspectorVisible ? .accentColor : .secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(scaleAmount: 0.88))
            .pointerOnHover()
            .help(viewModel.isDetailInspectorVisible ? "Hide Inspector" : "Show Inspector")
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    // Detail view for any shelf, clean up category, or custom location
    private var sectionDetailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Unified Filter & Sorting Toolbar
            FilterSortToolbarView(viewModel: viewModel)

            Divider().opacity(0.3)

            // File Grid or List View
            if viewModel.displayedItems.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No matching files")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("Try adjusting or resetting your filter criteria.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Button("Reset Filters") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                viewModel.resetFilters()
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 40)
                }
            } else {
                if viewModel.layoutMode == .grid {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: viewModel.gridIconSize, maximum: viewModel.gridIconSize + 40), spacing: 18)], spacing: 18) {
                            ForEach(viewModel.displayedItems) { item in
                                FileCardView(item: item.item, isOCRMatch: item.isOCRMatch, cardWidth: viewModel.gridIconSize) { fileToTrash in
                                    viewModel.trashFile(fileToTrash)
                                }
                                .pointerOnHover()
                                .onTapGesture {
                                    viewModel.selectedDuplicateGroup = nil
                                    viewModel.selectedFile = item.item
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.isDetailInspectorVisible = true
                                    }
                                }
                            }
                        }
                        .padding(28)
                    }
                } else {
                    FileListView(
                        items: viewModel.displayedItems,
                        viewModel: viewModel,
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
                }
            }
        }
    }

    // Search results view
    private var searchResultsView: some View {
        Group {
            if viewModel.displayedItems.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No matching files found")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Text("Try broadening your keywords or removing some filter chips.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 40)
                }
            } else {
                if viewModel.layoutMode == .grid {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: viewModel.gridIconSize, maximum: viewModel.gridIconSize + 40), spacing: 18)], spacing: 18) {
                            ForEach(viewModel.displayedItems) { item in
                                FileCardView(item: item.item, isOCRMatch: item.isOCRMatch, cardWidth: viewModel.gridIconSize) { fileToTrash in
                                    viewModel.trashFile(fileToTrash)
                                }
                                .pointerOnHover()
                                .onTapGesture {
                                    viewModel.selectedDuplicateGroup = nil
                                    viewModel.selectedFile = item.item
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.isDetailInspectorVisible = true
                                    }
                                }
                            }
                        }
                        .padding(28)
                    }
                } else {
                    FileListView(
                        items: viewModel.displayedItems,
                        viewModel: viewModel,
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
                }
            }
        }
    }
}
