import SwiftUI
@preconcurrency import AppKit

/// Observable state managing search input, results, and active keyboard index for Quick Search
@MainActor
public final class QuickSearchState: ObservableObject, @unchecked Sendable {
    public static let shared = QuickSearchState()

    @Published public var query: String = ""
    @Published public var selectedIndex: Int = 0
    @Published public var results: [FileItem] = []
    private var searchTask: Task<Void, Never>?

    public init() {}

    /// Resets the search state to a completely fresh, empty list
    public func reset() {
        searchTask?.cancel()
        self.query = ""
        self.selectedIndex = 0
        self.results = []
    }

    /// Reactive lazy update: filters matching files with debouncing and off-main-thread scoring
    public func updateSearch(query newQuery: String, viewModel: ScannerViewModel?) {
        searchTask?.cancel()

        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.results = []
            self.selectedIndex = 0
            return
        }

        let allFiles = viewModel?.allFiles ?? []
        let ocrMap = viewModel?.ocrTextByFileURL ?? [:]

        searchTask = Task.detached(priority: .userInitiated) { [weak self, trimmed, allFiles, ocrMap] in
            // 70ms debounce to allow fluid typing without blocking the main thread
            try? await Task.sleep(nanoseconds: 70_000_000)
            if Task.isCancelled { return }

            let parsed = NLQueryParser.parse(trimmed)
            if Task.isCancelled { return }

            var candidateScores: [URL: (file: FileItem, score: Double)] = [:]

            // 1. Fast in-memory matching with precomputed relevance score
            for file in allFiles {
                if Task.isCancelled { return }
                let ocr = ocrMap[file.url]
                let score = SearchRelevanceScorer.score(file: file, query: trimmed, ocrText: ocr, parsedFilter: parsed.filter)
                if score > 0 {
                    candidateScores[file.url] = (file, score)
                }
            }

            // 2. Persistent SQLite index fallback
            if !Task.isCancelled {
                let sqliteResults = SQLiteIndexService.shared.searchFilesSync(matching: trimmed, limit: 60)
                for file in sqliteResults {
                    if Task.isCancelled { return }
                    let ocr = ocrMap[file.url]
                    let score = SearchRelevanceScorer.score(file: file, query: trimmed, ocrText: ocr, parsedFilter: parsed.filter)
                    if score > 0 {
                        if let existing = candidateScores[file.url] {
                            if score > existing.score {
                                candidateScores[file.url] = (file, score)
                            }
                        } else {
                            candidateScores[file.url] = (file, score)
                        }
                    }
                }
            }

            if Task.isCancelled { return }

            // 3. Sort by precomputed score
            let sorted = candidateScores.values.sorted {
                if abs($0.score - $1.score) > 0.001 {
                    return $0.score > $1.score
                }
                return $0.file.modificationDate > $1.file.modificationDate
            }
            let finalResults = Array(sorted.prefix(40).map(\.file))

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self = self, !Task.isCancelled else { return }
                self.results = finalResults
                if self.selectedIndex >= self.results.count {
                    self.selectedIndex = max(0, self.results.count - 1)
                }
            }
        }
    }
}

/// Floating HUD style NSPanel controller for global quick search (summoned via ⇧⌘Space)
@MainActor
public final class QuickSearchPanelController: NSObject, @unchecked Sendable {
    public static let shared = QuickSearchPanelController()

    private var panel: NSPanel?
    private var localEventMonitor: Any?
    public weak var viewModel: ScannerViewModel?

    private override init() {
        super.init()
        setupEventMonitor()
    }

    /// Toggles the visibility of the Quick Search HUD
    public func toggle(with viewModel: ScannerViewModel? = nil) {
        if let vm = viewModel {
            self.viewModel = vm
        }

        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show(with: self.viewModel)
        }
    }

    /// Displays the centered, non-activating floating HUD panel starting with an empty query
    public func show(with viewModel: ScannerViewModel? = nil) {
        if let vm = viewModel {
            self.viewModel = vm
        }

        // Ensure state starts fresh with an empty search list
        QuickSearchState.shared.reset()

        if panel == nil {
            let hudPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            hudPanel.isFloatingPanel = true
            hudPanel.level = .floating
            hudPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            hudPanel.titleVisibility = .hidden
            hudPanel.titlebarAppearsTransparent = true
            hudPanel.isMovableByWindowBackground = true
            hudPanel.isOpaque = false
            hudPanel.backgroundColor = .clear
            hudPanel.hasShadow = true
            self.panel = hudPanel
        }

        guard let panel = self.panel else { return }

        // Host QuickSearchView with shared state
        let contentView = QuickSearchView(
            state: QuickSearchState.shared,
            viewModel: self.viewModel,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dismisses the Quick Search HUD panel and clears the search state
    public func hide() {
        panel?.orderOut(nil)
        QuickSearchState.shared.reset()
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Sets up local event monitor for ⇧⌘Space hotkey
    private func setupEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Shift + Command + Space (keyCode 49 is Space)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .shift] && event.keyCode == 49 {
                self?.toggle()
                return nil // consume event
            }
            return event
        }
    }
}

/// Floating HUD View for quick search matching files with keyboard navigation
public struct QuickSearchView: View {
    @ObservedObject public var state: QuickSearchState
    public weak var viewModel: ScannerViewModel?
    public let onClose: () -> Void

    @FocusState private var isFieldFocused: Bool

    public init(state: QuickSearchState = QuickSearchState.shared, viewModel: ScannerViewModel? = nil, onClose: @escaping () -> Void) {
        self.state = state
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)

                TextField("Quick Search files, \"pdfs from last week\", dmg...", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .rounded))
                    .focused($isFieldFocused)
                    .onSubmit {
                        handleReturnKey(reveal: NSEvent.modifierFlags.contains(.command))
                    }

                if !state.query.isEmpty {
                    Button {
                        state.reset()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Global HUD shortcut badge
                Text("⇧⌘Space")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))

            Divider().opacity(0.3)

            // Results List
            if state.query.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty state when opened: prompt user to start typing
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("Type to start searching files & smart filters")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Supports natural queries like \"dmg from last week\" or \"screenshots > 5MB\"")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.results.isEmpty {
                // Query typed but no matches found
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("No matching files found for \"\(state.query)\"")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Live updated matching results
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(state.results.enumerated()), id: \.element.id) { index, item in
                                QuickSearchResultRow(
                                    item: item,
                                    isSelected: index == state.selectedIndex,
                                    showExtension: viewModel?.showFileExtensions ?? false,
                                    onSelect: {
                                        state.selectedIndex = index
                                    },
                                    onOpen: {
                                        openFile(item)
                                    },
                                    onPreview: {
                                        QuickLookManager.shared.show(url: item.url)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .id(state.query)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                    .onChange(of: state.selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < state.results.count {
                            proxy.scrollTo(state.results[newIndex].id, anchor: .center)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Bottom Navigation Hints Strip
            HStack(spacing: 16) {
                hintItem(symbol: "↑↓", text: "Navigate")
                hintItem(symbol: "Space", text: "Preview")
                hintItem(symbol: "↵", text: "Open")
                hintItem(symbol: "⌘↵", text: "Reveal")
                hintItem(symbol: "Esc", text: "Dismiss")

                Spacer()

                if !state.results.isEmpty {
                    Text("\(state.results.count) results")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        }
        .frame(width: 620, height: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.22), radius: 24, y: 12)
        .onAppear {
            isFieldFocused = true
        }
        .onChange(of: state.query) { _, newQuery in
            state.updateSearch(query: newQuery, viewModel: viewModel)
        }
        // Keyboard navigation interceptors
        .onKeyPress(.upArrow) {
            if state.selectedIndex > 0 {
                state.selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let maxIndex = max(0, state.results.count - 1)
            if state.selectedIndex < maxIndex {
                state.selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.space) {
            if state.query.isEmpty || NSEvent.modifierFlags.contains(.option) {
                previewSelectedItem()
                return .handled
            }
            return .ignored
        }
    }

    private func hintItem(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
        }
    }

    private func previewSelectedItem() {
        guard state.selectedIndex >= 0 && state.selectedIndex < state.results.count else { return }
        QuickLookManager.shared.show(url: state.results[state.selectedIndex].url)
    }

    private func handleReturnKey(reveal: Bool) {
        guard state.selectedIndex >= 0 && state.selectedIndex < state.results.count else { return }
        let item = state.results[state.selectedIndex]
        if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        } else {
            NSWorkspace.shared.open(item.url)
        }
        onClose()
    }

    private func openFile(_ item: FileItem) {
        NSWorkspace.shared.open(item.url)
        onClose()
    }
}

/// A row inside the Quick Search results list
private struct QuickSearchResultRow: View {
    let item: FileItem
    let isSelected: Bool
    var showExtension: Bool = false
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onPreview: () -> Void

    @State private var icon: NSImage? = nil

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if item.url.path.hasPrefix(home) {
            return "~" + item.url.path.dropFirst(home.count)
        }
        return item.url.path
    }

    var body: some View {
        HStack(spacing: 10) {
            // File Icon
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
            }

            // Name & Path
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName(showExtension: showExtension))
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Category badge
                    Text(item.category.displayTitle)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())

                    if !item.fileExtension.isEmpty {
                        Text(item.fileExtension)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(displayPath)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            // Size & Preview action
            Text(item.formattedSize)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)

            Button {
                onPreview()
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Quick Look")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.16)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onOpen()
        }
        .task(id: item.url) {
            icon = NSWorkspace.shared.icon(forFile: item.url.path)
        }
    }
}
