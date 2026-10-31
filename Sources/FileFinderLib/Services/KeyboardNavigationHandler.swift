import SwiftUI
@preconcurrency import AppKit

@MainActor
public final class KeyboardNavigationHandler: ObservableObject {
    public static let shared = KeyboardNavigationHandler()

    private var eventMonitor: Any?
    public weak var viewModel: ScannerViewModel?

    private init() {}

    public func startMonitoring(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let vm = self.viewModel else { return event }

            // 1. Intercept Escape (keyCode 53) unconditionally to manage dismissals and prevent exiting fullscreen/maximize mode
            if event.keyCode == 53 {
                return self.handleEscapeKey(vm: vm, event: event)
            }

            // 2. Intercept Command + Period (⌘.) to toggle showing filename extensions anywhere in the app
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) && (event.keyCode == 47 || event.charactersIgnoringModifiers == ".") {
                vm.toggleFileExtensions()
                return nil
            }

            // If a text field or text view is currently editing, do not intercept navigation keys (arrow, return, space)
            if let window = NSApplication.shared.keyWindow,
               let firstResponder = window.firstResponder {
                if firstResponder is NSTextView || firstResponder is NSText || firstResponder is NSTextField {
                    return event
                }
            }

            switch event.keyCode {
            case 49: // Space
                vm.toggleQuickLook()
                return nil

            case 36, 76: // Return / Enter
                vm.openCurrentSelection()
                return nil

            case 123: // Left Arrow
                vm.navigateSelection(direction: .left)
                return nil

            case 124: // Right Arrow
                vm.navigateSelection(direction: .right)
                return nil

            case 126: // Up Arrow
                vm.navigateSelection(direction: .up)
                return nil

            case 125: // Down Arrow
                vm.navigateSelection(direction: .down)
                return nil

            default:
                break
            }

            return event
        }
    }

    /// Handles Escape key hierarchy and prevents exiting macOS maximize/fullscreen mode
    public func handleEscapeKey(vm: ScannerViewModel, event: NSEvent? = nil) -> NSEvent? {
        // If a modal sheet (e.g. Settings sheet) is open, let standard sheet escape dismissal handle it
        if let window = NSApplication.shared.keyWindow, window.attachedSheet != nil {
            return event
        }

        // 1. QuickLook preview active: close QuickLook
        if vm.isQuickLookVisible {
            vm.closeQuickLook()
            return nil
        }

        // 2. Quick Search HUD active: close HUD
        if QuickSearchPanelController.shared.isVisible {
            QuickSearchPanelController.shared.hide()
            return nil
        }

        // 3. Multiple files selected: deselect all files
        if vm.selectedFileSet.count > 1 {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.clearSelection()
            }
            return nil
        }

        // 4. Right Sidebar (Detail Inspector) is open: close sidebar
        if vm.isDetailInspectorVisible || vm.selectedDuplicateGroup != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                vm.closeDetailInspector()
            }
            return nil
        }

        // 5. Search is open (has query text or active filter chips): close search
        let isSearchOpen = !vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.activeChips.isEmpty
        if isSearchOpen {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.searchQuery = ""
                vm.resetFilters()
            }
            if let window = NSApplication.shared.keyWindow {
                window.makeFirstResponder(nil)
            }
            return nil
        }

        // 6. Single file/folder selected: clear selection
        if !vm.selectedFileSet.isEmpty || vm.selectedFile != nil || vm.selectedFolder != nil {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.clearSelection()
            }
            return nil
        }

        // 7. If text field is focused, resign focus
        if isTextFieldActive() {
            if let window = NSApplication.shared.keyWindow {
                window.makeFirstResponder(nil)
            }
            return nil
        }

        // 8. Nothing active: consume Escape unconditionally so macOS NEVER exits maximize/fullscreen mode!
        return nil
    }

    private func isTextFieldActive() -> Bool {
        guard let window = NSApplication.shared.keyWindow, let firstResponder = window.firstResponder else {
            return false
        }
        return firstResponder is NSTextView || firstResponder is NSText || firstResponder is NSTextField
    }

    public func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
