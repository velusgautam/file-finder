import SwiftUI
@preconcurrency import AppKit

/// In-memory cache for app bundle icons
private final class AppIconCache: @unchecked Sendable {
    static let shared = AppIconCache()
    private let cache = NSCache<NSURL, NSImage>()

    func icon(for url: URL, targetSize: CGFloat) -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: targetSize * 2, height: targetSize * 2)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

public struct ApplicationsView: View {
    @ObservedObject public var viewModel: ScannerViewModel
    @State private var selectedAppURL: URL? = nil

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    private var gridColumns: [GridItem] {
        let minWidth = max(160, viewModel.gridIconSize)
        let maxWidth = max(210, viewModel.gridIconSize + 40)
        return [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: 18)]
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Unified Filter & Sort Toolbar
            FilterSortToolbarView(viewModel: viewModel)

            Divider().opacity(0.3)

            // Content Area
            if viewModel.displayedApplications.isEmpty {
                emptyStateView
            } else {
                if viewModel.layoutMode == .list {
                    listView
                } else {
                    gridView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid View Mode
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 18) {
                ForEach(viewModel.displayedApplications) { app in
                    InstalledAppCardView(
                        app: app,
                        cardWidth: viewModel.gridIconSize,
                        isSelected: selectedAppURL == app.url,
                        onSelect: {
                            selectedAppURL = app.url
                        },
                        onLaunch: {
                            NSWorkspace.shared.open(app.url)
                        }
                    )
                }
            }
            .padding(24)
        }
    }

    // MARK: - List View Mode
    private var listView: some View {
        VStack(spacing: 0) {
            // Table Header Row
            HStack(spacing: 12) {
                // Name Column
                tableHeaderCell(title: "Application Name", option: .name, alignment: .leading)
                    .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

                // Version Column
                Text("Version")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                // Size Column
                tableHeaderCell(title: "Size", option: .size, alignment: .trailing)
                    .frame(width: 90, alignment: .trailing)

                // Date Modified Column
                tableHeaderCell(title: "Date Modified", option: .dateModified, alignment: .leading)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
            .overlay(Divider().opacity(0.3), alignment: .bottom)

            // Table Rows
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(viewModel.displayedApplications) { app in
                        InstalledAppListRowView(
                            app: app,
                            isSelected: selectedAppURL == app.url,
                            onSelect: {
                                selectedAppURL = app.url
                            },
                            onLaunch: {
                                NSWorkspace.shared.open(app.url)
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
        }
    }

    // Header Sort Cell
    private func tableHeaderCell(title: String, option: SortOption, alignment: Alignment) -> some View {
        Button {
            if viewModel.selectedSortOption == option {
                viewModel.selectedSortOrder.toggle()
            } else {
                viewModel.selectedSortOption = option
                viewModel.selectedSortOrder = (option == .name) ? .ascending : .descending
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(viewModel.selectedSortOption == option ? Color.accentColor : .secondary)

                if viewModel.selectedSortOption == option {
                    Image(systemName: viewModel.selectedSortOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .pointerOnHover()
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42))
                .foregroundColor(.secondary.opacity(0.4))

            Text(viewModel.installedApps.isEmpty ? "No Applications Found" : "No Matching Applications")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))

            Text(viewModel.installedApps.isEmpty
                 ? "No .app bundles were found in standard application directories."
                 : "Try adjusting or clearing your filter criteria.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !viewModel.installedApps.isEmpty {
                Button("Reset Filters") {
                    viewModel.resetFilters()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
                .pointerOnHover()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Installed App Card View (Grid Mode)
public struct InstalledAppCardView: View {
    public let app: InstalledAppItem
    public let cardWidth: CGFloat
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onLaunch: () -> Void

    @State private var isHovered: Bool = false

    public init(
        app: InstalledAppItem,
        cardWidth: CGFloat,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onLaunch: @escaping () -> Void
    ) {
        self.app = app
        self.cardWidth = cardWidth
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onLaunch = onLaunch
    }

    private var iconDisplaySize: CGFloat {
        max(64, min(96, cardWidth * 0.45))
    }

    public var body: some View {
        VStack(spacing: 10) {
            // High-Resolution App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(isHovered ? 0.05 : 0.02))
                    .frame(height: max(90, cardWidth * 0.65))

                Image(nsImage: AppIconCache.shared.icon(for: app.url, targetSize: iconDisplaySize))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconDisplaySize, height: iconDisplaySize)
                    .shadow(color: Color.black.opacity(isHovered ? 0.18 : 0.08), radius: isHovered ? 6 : 3, x: 0, y: isHovered ? 3 : 1)
            }

            // App Name & Details
            VStack(spacing: 4) {
                Text(app.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }

                    if app.fileSize > 0 {
                        Text(app.formattedSize)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : ScandinavianTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ScandinavianTheme.cardCornerRadius)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.18) : ScandinavianTheme.hairlineBorder),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: ScandinavianTheme.softShadow, radius: isHovered ? 5 : 2, x: 0, y: isHovered ? 3 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onLaunch()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                onSelect()
            }
        )
        .contextMenu {
            appContextMenu
        }
        .pointerOnHover()
        .help("\(app.name)\n\(app.url.path)")
    }

    @ViewBuilder
    private var appContextMenu: some View {
        Button {
            onLaunch()
        } label: {
            Label("Launch Application", systemImage: "arrow.up.forward.app")
        }

        Divider()

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([app.url])
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(app.url.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }

        if !app.bundleIdentifier.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.bundleIdentifier, forType: .string)
            } label: {
                Label("Copy Bundle ID", systemImage: "tag")
            }
        }
    }
}

// MARK: - Installed App List Row View (List Mode)
public struct InstalledAppListRowView: View {
    public let app: InstalledAppItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onLaunch: () -> Void

    @State private var isHovered: Bool = false

    public init(
        app: InstalledAppItem,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onLaunch: @escaping () -> Void
    ) {
        self.app = app
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onLaunch = onLaunch
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon & Name Column
            HStack(spacing: 10) {
                Image(nsImage: AppIconCache.shared.icon(for: app.url, targetSize: 28))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)

                    if !app.bundleIdentifier.isEmpty {
                        Text(app.bundleIdentifier)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            // Version Column
            Group {
                if !app.version.isEmpty {
                    Text(app.version)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                } else {
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(width: 110, alignment: .leading)

            // Size Column
            Text(app.fileSize > 0 ? app.formattedSize : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)

            // Date Modified Column
            Text(app.relativeDateString)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onLaunch()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                onSelect()
            }
        )
        .contextMenu {
            Button {
                onLaunch()
            } label: {
                Label("Launch Application", systemImage: "arrow.up.forward.app")
            }

            Divider()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            if !app.bundleIdentifier.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(app.bundleIdentifier, forType: .string)
                } label: {
                    Label("Copy Bundle ID", systemImage: "tag")
                }
            }
        }
        .pointerOnHover()
        .help("\(app.name)\n\(app.url.path)")
    }
}
