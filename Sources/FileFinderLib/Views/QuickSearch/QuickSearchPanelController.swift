import SwiftUI
@preconcurrency import AppKit

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

    /// Displays the centered, non-activating floating HUD panel
    public func show(with viewModel: ScannerViewModel? = nil) {
        if let vm = viewModel {
            self.viewModel = vm
        }

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

        // Host QuickSearchView
        let contentView = QuickSearchView(
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

    /// Dismisses the Quick Search HUD panel
    public func hide() {
        panel?.orderOut(nil)
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
    public weak var viewModel: ScannerViewModel?
    public let onClose: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFieldFocused: Bool

    public init(viewModel: ScannerViewModel? = nil, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    private var matchedFiles: [FileItem] {
        guard let files = viewModel?.allFiles, !files.isEmpty else {
            return []
        }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Show first 20 recent files
            return Array(files.prefix(20))
        }

        let parsed = NLQueryParser.parse(trimmed)
        let filtered = files.filter { file in
            let (matches, _) = parsed.filter.matchEvaluation(for: file, ocrText: viewModel?.ocrTextByFileURL[file.url])
            return matches
        }

        return Array(filtered.prefix(30))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)

                TextField("Quick Search files, \"pdfs from last week\", dmg...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .rounded))
                    .focused($isFieldFocused)
                    .onSubmit {
                        handleReturnKey(reveal: NSEvent.modifierFlags.contains(.command))
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        selectedIndex = 0
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
            let results = matchedFiles
            if results.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(query.isEmpty ? "No files indexed yet" : "No matching files found")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                QuickSearchResultRow(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        selectedIndex = index
                                    },
                                    onOpen: {
                                        openFile(item)
                                    },
                                    onPreview: {
                                        QuickLookManager.shared.show(url: item.url)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
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

                if !results.isEmpty {
                    Text("\(results.count) results")
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
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        // Keyboard navigation interceptors
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let maxIndex = max(0, matchedFiles.count - 1)
            if selectedIndex < maxIndex {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.space) {
            // If field has no text, or space pressed with modifier or in navigation
            if query.isEmpty || NSEvent.modifierFlags.contains(.option) {
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
        let results = matchedFiles
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        QuickLookManager.shared.show(url: results[selectedIndex].url)
    }

    private func handleReturnKey(reveal: Bool) {
        let results = matchedFiles
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        let item = results[selectedIndex]
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
                    Text(item.name)
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
