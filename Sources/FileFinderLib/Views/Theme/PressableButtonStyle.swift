import SwiftUI
@preconcurrency import AppKit

/// Spring bounce click animation for macOS buttons
public struct PressableButtonStyle: ButtonStyle {
    public let scaleAmount: CGFloat

    public init(scaleAmount: CGFloat = 0.96) {
        self.scaleAmount = scaleAmount
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Flicker-free pointing hand cursor overlay using AppKit native cursor rects & tracking areas
public struct PointingHandCursorModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .overlay(
                PointingHandRepresentable()
                    .allowsHitTesting(false)
            )
    }
}

public struct PointingHandRepresentable: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> PointingHandNSView {
        PointingHandNSView()
    }

    public func updateNSView(_ nsView: PointingHandNSView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

public final class PointingHandNSView: NSView {
    private var trackingAreaRef: NSTrackingArea?

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

public extension View {
    /// Changes the cursor to pointingHand on hover without stack corruption or flickering
    func pointerOnHover() -> some View {
        self.modifier(PointingHandCursorModifier())
    }
}
