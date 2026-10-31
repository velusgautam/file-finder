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

            // If a text field or text view is currently editing, do not intercept
            if let window = NSApp.keyWindow,
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

            case 53: // Escape
                if vm.isQuickLookVisible {
                    vm.closeQuickLook()
                    return nil
                }

            default:
                break
            }

            return event
        }
    }

    public func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
