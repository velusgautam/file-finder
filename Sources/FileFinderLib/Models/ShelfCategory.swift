import Foundation

public enum ShelfCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case recentDownloads = "recentDownloads"
    case images          = "images"
    case videos          = "videos"
    case documents       = "documents"
    case audio           = "audio"
    case archives        = "archives"
    case code            = "code"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .recentDownloads: return "Recent Downloads"
        case .images:          return "Images & Photos"
        case .videos:          return "Videos & Clips"
        case .documents:       return "Documents"
        case .audio:           return "Audio & Music"
        case .archives:        return "Archives & Packages"
        case .code:            return "Code & Data"
        }
    }

    public var systemImage: String {
        switch self {
        case .recentDownloads: return "arrow.down.circle"
        case .images:          return "photo.on.rectangle.angled"
        case .videos:          return "play.rectangle"
        case .documents:       return "doc.text"
        case .audio:           return "waveform"
        case .archives:        return "archivebox"
        case .code:            return "curlybraces"
        }
    }

    public var matchingExtensions: Set<String> {
        switch self {
        case .recentDownloads:
            return []
        case .images:
            return ["png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff", "svg", "raw", "cr2", "nef", "psd"]
        case .videos:
            return ["mp4", "mov", "m4v", "mkv", "avi", "webm", "flv", "wmv"]
        case .documents:
            return ["pdf", "doc", "docx", "pages", "key", "numbers", "txt", "rtf", "md", "markdown", "csv", "xls", "xlsx", "ppt", "pptx", "epub"]
        case .audio:
            return ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff"]
        case .archives:
            return ["zip", "tar", "gz", "tgz", "bz2", "7z", "rar", "dmg", "iso", "pkg"]
        case .code:
            return ["swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "scss", "json", "xml", "yaml", "yml", "c", "cpp", "h", "hpp", "rs", "go", "java", "kt", "sh", "zsh", "rb", "sql"]
        }
    }

    public static func category(for url: URL, isRecentDownload: Bool = false) -> ShelfCategory {
        if isRecentDownload {
            return .recentDownloads
        }
        let ext = url.pathExtension.lowercased()
        for cat in ShelfCategory.allCases where cat != .recentDownloads {
            if cat.matchingExtensions.contains(ext) {
                return cat
            }
        }
        return .documents
    }
}
