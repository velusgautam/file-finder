import SwiftUI
import AppKit

public enum ScandinavianTheme {
    // Dynamic canvas background (Light: warm porcelain #FAF9F6, Dark: deep charcoal #121214)
    public static let canvasBackground = Color(nsColor: NSColor(name: "canvasBackground", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)
            : NSColor(red: 0.98, green: 0.976, blue: 0.965, alpha: 1.0)
    }))

    // Dynamic sidebar background (Light: #F5F4F0, Dark: #18181B)
    public static let sidebarBackground = Color(nsColor: NSColor(name: "sidebarBackground", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            : NSColor(red: 0.96, green: 0.955, blue: 0.945, alpha: 1.0)
    }))

    // Dynamic file card fill
    public static let cardBackground = Color(nsColor: NSColor(name: "cardBackground", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 0.85)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
    }))

    // Dynamic search bar pill fill
    public static let searchBarBackground = Color(nsColor: NSColor(name: "searchBarBackground", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 0.95)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    }))

    // Dynamic circular bubble fill
    public static let bubbleBackground = Color(nsColor: NSColor(name: "bubbleBackground", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    }))

    public static let hairlineBorder = Color(nsColor: NSColor(name: "hairlineBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.08)
            : NSColor.black.withAlphaComponent(0.06)
    }))

    public static let cardCornerRadius: CGFloat = 16.0
    public static let pillCornerRadius: CGFloat = 8.0
    public static let softShadow = Color.black.opacity(0.04)

    // Library Folder Pastel Palettes with Full Dark Mode Adaptation
    public static func folderColor(for category: ShelfCategory) -> Color {
        return Color(nsColor: NSColor(name: "folder_\(category.rawValue)", dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            switch category {
            case .images:
                return isDark
                    ? NSColor(red: 0.14, green: 0.16, blue: 0.25, alpha: 1.0)
                    : NSColor(red: 0.93, green: 0.95, blue: 1.00, alpha: 1.0) // #EDF2FE
            case .videos:
                return isDark
                    ? NSColor(red: 0.12, green: 0.18, blue: 0.26, alpha: 1.0)
                    : NSColor(red: 0.91, green: 0.96, blue: 1.00, alpha: 1.0) // #E8F4FD
            case .audio:
                return isDark
                    ? NSColor(red: 0.24, green: 0.15, blue: 0.14, alpha: 1.0)
                    : NSColor(red: 1.00, green: 0.94, blue: 0.92, alpha: 1.0) // #FEEFEA
            case .documents:
                return isDark
                    ? NSColor(red: 0.13, green: 0.20, blue: 0.15, alpha: 1.0)
                    : NSColor(red: 0.92, green: 0.97, blue: 0.93, alpha: 1.0) // #EBF7EE
            case .archives:
                return isDark
                    ? NSColor(red: 0.24, green: 0.20, blue: 0.12, alpha: 1.0)
                    : NSColor(red: 1.00, green: 0.98, blue: 0.90, alpha: 1.0) // #FEF9E7
            case .code:
                return isDark
                    ? NSColor(red: 0.20, green: 0.14, blue: 0.22, alpha: 1.0)
                    : NSColor(red: 0.99, green: 0.94, blue: 0.96, alpha: 1.0) // #FDF1F5
            case .recentDownloads:
                return isDark
                    ? NSColor(red: 0.13, green: 0.19, blue: 0.22, alpha: 1.0)
                    : NSColor(red: 0.93, green: 0.96, blue: 0.98, alpha: 1.0)
            }
        }))
    }

    public static func folderAccentColor(for category: ShelfCategory) -> Color {
        switch category {
        case .images:          return Color(red: 0.45, green: 0.55, blue: 0.95)
        case .videos:          return Color(red: 0.30, green: 0.65, blue: 0.95)
        case .audio:           return Color(red: 0.95, green: 0.50, blue: 0.35)
        case .documents:       return Color(red: 0.35, green: 0.70, blue: 0.50)
        case .archives:        return Color(red: 0.90, green: 0.70, blue: 0.25)
        case .code:            return Color(red: 0.85, green: 0.45, blue: 0.75)
        case .recentDownloads: return Color(red: 0.30, green: 0.70, blue: 0.80)
        }
    }

    // Clean Up Card Palettes with Dynamic Dark Mode Variants
    public static let duplicatesTint = Color(nsColor: NSColor(name: "duplicatesTint", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.22, green: 0.12, blue: 0.14, alpha: 1.0)
            : NSColor(red: 0.99, green: 0.95, blue: 0.95, alpha: 1.0)
    }))

    public static let duplicatesBorder = Color(nsColor: NSColor(name: "duplicatesBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.38, green: 0.18, blue: 0.20, alpha: 1.0)
            : NSColor(red: 0.99, green: 0.80, blue: 0.82, alpha: 1.0)
    }))

    public static let duplicatesIcon = Color(red: 0.94, green: 0.27, blue: 0.32)

    public static let forgottenDownloadsTint = Color(nsColor: NSColor(name: "forgottenDownloadsTint", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.12, green: 0.16, blue: 0.26, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.96, blue: 1.00, alpha: 1.0)
    }))

    public static let forgottenDownloadsBorder = Color(nsColor: NSColor(name: "forgottenDownloadsBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.18, green: 0.28, blue: 0.44, alpha: 1.0)
            : NSColor(red: 0.75, green: 0.86, blue: 1.00, alpha: 1.0)
    }))

    public static let forgottenDownloadsIcon = Color(red: 0.30, green: 0.60, blue: 0.98)

    public static let oldScreenshotsTint = Color(nsColor: NSColor(name: "oldScreenshotsTint", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.22, green: 0.12, blue: 0.18, alpha: 1.0)
            : NSColor(red: 0.99, green: 0.95, blue: 0.97, alpha: 1.0)
    }))

    public static let oldScreenshotsBorder = Color(nsColor: NSColor(name: "oldScreenshotsBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.38, green: 0.18, blue: 0.30, alpha: 1.0)
            : NSColor(red: 0.98, green: 0.81, blue: 0.91, alpha: 1.0)
    }))

    public static let oldScreenshotsIcon = Color(red: 0.90, green: 0.30, blue: 0.65)

    public static let unusedAppsTint = Color(nsColor: NSColor(name: "unusedAppsTint", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.12, green: 0.20, blue: 0.15, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.99, blue: 0.96, alpha: 1.0)
    }))

    public static let unusedAppsBorder = Color(nsColor: NSColor(name: "unusedAppsBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.18, green: 0.35, blue: 0.24, alpha: 1.0)
            : NSColor(red: 0.73, green: 0.97, blue: 0.82, alpha: 1.0)
    }))

    public static let unusedAppsIcon = Color(red: 0.20, green: 0.75, blue: 0.45)

    // Green Highlight Badge
    public static let greenHighlight = Color(red: 0.13, green: 0.77, blue: 0.37)
    // Red Counter Badge
    public static let redBadge = Color(red: 0.94, green: 0.27, blue: 0.27)
}
