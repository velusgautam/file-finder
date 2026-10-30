import SwiftUI

/// Distinctive Folder Tab shape replicating Homy's library category folders
public struct FolderTabShape: Shape {
    public var tabWidthRatio: CGFloat = 0.46
    public var tabHeight: CGFloat = 18
    public var cornerRadius: CGFloat = 16
    public var innerCornerRadius: CGFloat = 8

    public init(
        tabWidthRatio: CGFloat = 0.46,
        tabHeight: CGFloat = 18,
        cornerRadius: CGFloat = 16,
        innerCornerRadius: CGFloat = 8
    ) {
        self.tabWidthRatio = tabWidthRatio
        self.tabHeight = tabHeight
        self.cornerRadius = cornerRadius
        self.innerCornerRadius = innerCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let ir = innerCornerRadius
        let th = tabHeight
        let tabW = max(rect.width * tabWidthRatio, 90)

        // Bottom-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge & bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right edge & top-right corner (at base folder level)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + th + r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + th + r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )

        // Lower top edge towards the tab
        path.addLine(to: CGPoint(x: rect.minX + tabW + ir, y: rect.minY + th))

        // Concave curve connecting folder top edge to tab right edge
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tabW, y: rect.minY + th - ir),
            control: CGPoint(x: rect.minX + tabW, y: rect.minY + th)
        )

        // Right edge of tab up to top-right corner of tab
        path.addLine(to: CGPoint(x: rect.minX + tabW, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX + tabW - r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: true
        )

        // Top edge of tab & top-left corner of tab
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Left edge down to bottom-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.closeSubpath()

        return path
    }
}
