import Foundation
import QuickLookUI
@preconcurrency import AppKit

@MainActor
public final class QuickLookManager: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    public static let shared = QuickLookManager()

    public private(set) var currentURL: URL? {
        didSet {
            nonisolatedCurrentURL = currentURL
        }
    }
    public var onVisibilityChanged: ((Bool) -> Void)?

    private nonisolated(unsafe) var nonisolatedCurrentURL: URL?

    private override init() {
        super.init()
    }

    public var isVisible: Bool {
        if QLPreviewPanel.sharedPreviewPanelExists() {
            return QLPreviewPanel.shared().isVisible
        }
        return false
    }

    /// Toggles the native macOS Quick Look panel for the specified URL
    public func toggleQuickLook(for url: URL?) {
        guard let url = url else {
            close()
            return
        }

        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible && currentURL == url {
            close()
        } else {
            show(url: url)
        }
    }

    /// Shows or brings to front the Quick Look preview panel for a file URL
    public func show(url: URL) {
        currentURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
        onVisibilityChanged?(true)
    }

    /// Updates the Quick Look preview in real time if it's currently visible
    public func updateSelection(_ url: URL?) {
        guard let url = url else {
            if isVisible {
                close()
            }
            return
        }

        currentURL = url
        if isVisible, let panel = QLPreviewPanel.shared() {
            panel.reloadData()
        }
    }

    /// Closes the Quick Look preview panel
    public func close() {
        currentURL = nil
        if QLPreviewPanel.sharedPreviewPanelExists() {
            let panel = QLPreviewPanel.shared()
            if panel?.isVisible == true {
                panel?.orderOut(nil)
            }
        }
        onVisibilityChanged?(false)
    }

    // MARK: - QLPreviewPanelDataSource

    public nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return nonisolatedCurrentURL != nil ? 1 : 0
    }

    public nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard let url = nonisolatedCurrentURL else { return nil }
        return url as NSURL
    }

    // MARK: - QLPreviewPanelDelegate

    public func windowWillClose(_ notification: Notification) {
        if let panel = notification.object as? QLPreviewPanel, panel == QLPreviewPanel.shared() {
            currentURL = nil
            onVisibilityChanged?(false)
        }
    }
}
