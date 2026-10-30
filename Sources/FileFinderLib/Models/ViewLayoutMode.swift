import Foundation

public enum ViewLayoutMode: String, CaseIterable, Identifiable, Sendable {
    case grid = "Grid"
    case list = "List"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

public enum GridSizePreset: String, CaseIterable, Identifiable, Sendable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"

    public var id: String { rawValue }

    public var cardWidth: CGFloat {
        switch self {
        case .small:  return 145
        case .medium: return 185
        case .large:  return 235
        }
    }
}
