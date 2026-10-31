import SwiftUI
@preconcurrency import AppKit

/// Standardized right-click context menu for FileCardView and FileListView
public struct FileContextMenuView: View {
    public let item: FileItem
    public let onTrash: (FileItem) -> Void
    public let onQuickLook: ((FileItem) -> Void)?

    public init(
        item: FileItem,
        onTrash: @escaping (FileItem) -> Void,
        onQuickLook: ((FileItem) -> Void)? = nil
    ) {
        self.item = item
        self.onTrash = onTrash
        self.onQuickLook = onQuickLook
    }

    private var isImageItem: Bool {
        let ext = item.fileExtension.lowercased()
        return item.category == .images || CleanUpRulesEngine.imageExtensions.contains(ext)
    }

    private var availableAppURLs: [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: item.url)
    }

    public var body: some View {
        Group {
            // 1. Quick Look
            Button {
                if let onQuickLook = onQuickLook {
                    onQuickLook(item)
                } else {
                    QuickLookManager.shared.show(url: item.url)
                }
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
            .keyboardShortcut(.space, modifiers: [])

            // 2. Open
            Button {
                NSWorkspace.shared.open(item.url)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .keyboardShortcut(.defaultAction)

            // 3. Open With... submenu
            openWithSubmenu

            // 4. Show in Finder
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            // 5. Copy File
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([item.url as NSURL])
            } label: {
                Label("Copy File", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)

            // 6. Copy Path
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "link")
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            // 7. Copy Text from Image (OCR if image item)
            if isImageItem {
                Button {
                    Task {
                        if let cached = await OCREngine.shared.cachedText(for: item.url, modificationDate: item.modificationDate) {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(cached, forType: .string)
                        } else if let recognized = await OCREngine.shared.recognizeText(for: item.url, modificationDate: item.modificationDate) {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(recognized, forType: .string)
                        }
                    }
                } label: {
                    Label("Copy Text from Image", systemImage: "text.viewfinder")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            // Copy origin URL if available
            if let originURL = item.originURL {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(originURL.absoluteString, forType: .string)
                } label: {
                    Label("Copy Download Source URL", systemImage: "arrow.down.circle")
                }
            }

            Divider()

            // 8. Move to Trash
            Button(role: .destructive) {
                onTrash(item)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }

    @ViewBuilder
    private var openWithSubmenu: some View {
        let apps = availableAppURLs
        Menu("Open With...") {
            if apps.isEmpty {
                Button("Default Application") {
                    NSWorkspace.shared.open(item.url)
                }
            } else {
                ForEach(apps.prefix(8), id: \.self) { appURL in
                    let name = appURL.deletingPathExtension().lastPathComponent
                    Button(name) {
                        NSWorkspace.shared.open(
                            [item.url],
                            withApplicationAt: appURL,
                            configuration: NSWorkspace.OpenConfiguration()
                        )
                    }
                }
            }

            Divider()

            Button("Other...") {
                let panel = NSOpenPanel()
                panel.title = "Choose Application"
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                if panel.runModal() == .OK, let selectedAppURL = panel.url {
                    NSWorkspace.shared.open(
                        [item.url],
                        withApplicationAt: selectedAppURL,
                        configuration: NSWorkspace.OpenConfiguration()
                    )
                }
            }
        }
    }
}

public extension View {
    func fileContextMenu(
        for item: FileItem,
        onTrash: @escaping (FileItem) -> Void,
        onQuickLook: ((FileItem) -> Void)? = nil
    ) -> some View {
        self.contextMenu {
            FileContextMenuView(item: item, onTrash: onTrash, onQuickLook: onQuickLook)
        }
    }
}
