import SwiftUI

public struct HomySidebarView: View {
    @ObservedObject public var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // App Brand Header with Working Collapse Button
                brandHeaderView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Dynamic Reorderable Sections
                ForEach(viewModel.sidebarSections) { sectionKind in
                    VStack(alignment: .leading, spacing: 6) {
                        sectionView(for: sectionKind)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.draggedSection == sectionKind ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                viewModel.draggedSection == sectionKind ? Color.accentColor.opacity(0.4) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .onDrag {
                        viewModel.draggedSection = sectionKind
                        return NSItemProvider(object: sectionKind.rawValue as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: SidebarSectionDropDelegate(
                            section: sectionKind,
                            sections: $viewModel.sidebarSections,
                            draggedSection: $viewModel.draggedSection,
                            onCommit: {
                                viewModel.saveSidebarSections()
                            }
                        )
                    )

                    if sectionKind != viewModel.sidebarSections.last {
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(0.5)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 224)
        .background(ScandinavianTheme.sidebarBackground)
    }

    // Brand Logo Helper
    private var brandLogoImage: NSImage? {
        if let bundleURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: bundleURL) {
            return img
        }
        if let bundleURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: bundleURL) {
            return img
        }
        let fallbackPath = "Resources/AppIcon_1024.png"
        if FileManager.default.fileExists(atPath: fallbackPath),
           let img = NSImage(contentsOfFile: fallbackPath) {
            return img
        }
        return nil
    }

    // App Header Bar
    private var brandHeaderView: some View {
        HStack(spacing: 8) {
            if let icon = brandLogoImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.20, green: 0.60, blue: 0.98), Color(red: 0.10, green: 0.45, blue: 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 26, height: 26)

                    Image(systemName: "house.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text("File Finder")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(scaleAmount: 0.88))
            .pointerOnHover()
            .help("Hide Sidebar (⌘\\)")
        }
    }

    // Section Dispatcher
    @ViewBuilder
    private func sectionView(for section: SidebarSectionKind) -> some View {
        switch section {
        case .library:
            librarySectionView
        case .cleanUp:
            cleanUpSectionView
        case .locations:
            locationsSectionView
        }
    }

    // Section Header with Drag Handle
    private func sectionHeader(title: String, icon: String, section: SidebarSectionKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.35))
                .help("Drag section to reorder")

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    // 1. Library Section
    private var librarySectionView: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title: "Library", icon: "books.vertical", section: .library)

            SidebarItemRow(
                title: "Home",
                icon: "house",
                isSelected: viewModel.currentSection == .home && viewModel.searchQuery.isEmpty,
                badge: nil
            ) {
                viewModel.currentSection = .home
                viewModel.clearAllFilters()
            }

            SidebarItemRow(
                title: "Recents",
                icon: "clock",
                isSelected: viewModel.currentSection == .recents,
                badge: nil
            ) {
                viewModel.currentSection = .recents
            }

            SidebarItemRow(
                title: "Images",
                icon: "photo.on.rectangle.angled",
                isSelected: isCategorySelected(.images),
                badge: "\(viewModel.shelves[.images]?.count ?? 0)"
            ) {
                selectCategory(.images)
            }

            SidebarItemRow(
                title: "Videos",
                icon: "play.rectangle",
                isSelected: isCategorySelected(.videos),
                badge: "\(viewModel.shelves[.videos]?.count ?? 0)"
            ) {
                selectCategory(.videos)
            }

            SidebarItemRow(
                title: "Music",
                icon: "music.note",
                isSelected: isCategorySelected(.audio),
                badge: "\(viewModel.shelves[.audio]?.count ?? 0)"
            ) {
                selectCategory(.audio)
            }

            SidebarItemRow(
                title: "Documents",
                icon: "doc.text",
                isSelected: isCategorySelected(.documents),
                badge: "\(viewModel.shelves[.documents]?.count ?? 0)"
            ) {
                selectCategory(.documents)
            }

            SidebarItemRow(
                title: "Archives",
                icon: "archivebox",
                isSelected: isCategorySelected(.archives),
                badge: "\(viewModel.shelves[.archives]?.count ?? 0)"
            ) {
                selectCategory(.archives)
            }

            SidebarItemRow(
                title: "Apps",
                icon: "square.grid.2x2",
                isSelected: viewModel.currentSection == .applications,
                badge: "\(viewModel.installedAppsCount)"
            ) {
                viewModel.currentSection = .applications
            }
        }
    }

    // 2. Smart Shelves / Clean Up Section
    private var cleanUpSectionView: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title: "Smart Shelves", icon: "sparkles", section: .cleanUp)

            SidebarItemRow(
                title: "Large Files",
                icon: "square.dashed",
                isSelected: viewModel.currentSection == .largeFiles,
                badge: "\(viewModel.largeFiles.count)",
                badgeColor: viewModel.largeFiles.count > 0 ? ScandinavianTheme.redBadge : nil,
                badgeTextColor: viewModel.largeFiles.count > 0 ? .white : nil
            ) {
                viewModel.currentSection = .largeFiles
            }

            SidebarItemRow(
                title: "Screenshots",
                icon: "camera.viewfinder",
                isSelected: viewModel.currentSection == .screenshots,
                badge: "\(viewModel.screenshots.count)"
            ) {
                viewModel.currentSection = .screenshots
            }

            SidebarItemRow(
                title: "Duplicates",
                icon: "doc.on.doc",
                isSelected: viewModel.currentSection == .duplicates,
                badge: viewModel.duplicateTotalWastedBytes > 0 ? viewModel.formattedDuplicateSize : "0 KB",
                badgeColor: viewModel.duplicateTotalWastedBytes > 0 ? ScandinavianTheme.greenHighlight.opacity(0.15) : nil,
                badgeTextColor: viewModel.duplicateTotalWastedBytes > 0 ? ScandinavianTheme.greenHighlight : nil
            ) {
                viewModel.currentSection = .duplicates
            }

            SidebarItemRow(
                title: "Clean Up",
                icon: "sparkles",
                isSelected: viewModel.currentSection == .cleanUp,
                badge: viewModel.formattedCleanupTotal,
                badgeColor: viewModel.totalCleanupBytes > 0 ? ScandinavianTheme.greenHighlight.opacity(0.15) : nil,
                badgeTextColor: viewModel.totalCleanupBytes > 0 ? ScandinavianTheme.greenHighlight : nil
            ) {
                viewModel.currentSection = .cleanUp
            }

            SidebarItemRow(
                title: "Downloaded From",
                icon: "arrow.down.circle",
                isSelected: isDownloadedFromSelected,
                badge: "\(viewModel.downloadedFromSummaries.count)"
            ) {
                viewModel.currentSection = .downloadedFromOverview
            }
        }
    }

    // 3. Locations Section (Drag & Drop Reorderable + Removable)
    private var locationsSectionView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header with Drag Handle & Add Menu
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.35))
                    .help("Drag section to reorder")

                Text("Locations")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Menu {
                    Button {
                        viewModel.addCustomLocation()
                    } label: {
                        Label("Add Location...", systemImage: "plus")
                    }

                    Divider()

                    Button {
                        viewModel.resetSidebarLocationsToDefaults()
                    } label: {
                        Label("Reset to Default Locations", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .pointerOnHover()
                .help("Location options")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)

            // Reorderable & Removable Location Items
            if viewModel.sidebarLocations.isEmpty {
                Text("No locations pinned")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            } else {
                ForEach(viewModel.sidebarLocations) { loc in
                    LocationSidebarRow(
                        location: loc,
                        isSelected: isLocationSelected(loc),
                        viewModel: viewModel
                    )
                    .onDrag {
                        viewModel.draggedLocation = loc
                        return NSItemProvider(object: loc.id as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: LocationRowDropDelegate(
                            item: loc,
                            locations: $viewModel.sidebarLocations,
                            draggedLocation: $viewModel.draggedLocation,
                            onCommit: {
                                viewModel.saveSidebarLocations()
                            }
                        )
                    )
                }
            }
        }
    }

    private func isCategorySelected(_ cat: ShelfCategory) -> Bool {
        if case .category(let selected) = viewModel.currentSection {
            return selected == cat
        }
        return false
    }

    private var isDownloadedFromSelected: Bool {
        switch viewModel.currentSection {
        case .downloadedFromOverview, .downloadedFrom:
            return true
        default:
            return false
        }
    }

    private func selectCategory(_ cat: ShelfCategory) {
        viewModel.currentSection = .category(cat)
    }

    private func isLocationSelected(_ loc: SidebarLocationItem) -> Bool {
        if case .location(_, let url) = viewModel.currentSection {
            return url.path == loc.url.path
        }
        return false
    }
}

/// Dedicated reorderable and removable sidebar location row
struct LocationSidebarRow: View {
    let location: SidebarLocationItem
    let isSelected: Bool
    @ObservedObject var viewModel: ScannerViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Drag grip indicator on hover
            Image(systemName: "line.2.horizontal")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(isHovered ? 0.45 : 0))
                .frame(width: 8)

            Image(systemName: location.iconSystemName)
                .font(.system(size: 12.5))
                .foregroundColor(Color(red: 0.25, green: 0.60, blue: 0.95))
                .frame(width: 16)

            Text(location.name)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : Color(nsColor: .labelColor))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Remove button on hover
            if isHovered {
                Button {
                    viewModel.removeSidebarLocation(location)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .help("Remove \(location.name) from Sidebar")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isSelected
                ? Color.primary.opacity(0.08)
                : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            viewModel.selectLocation(name: location.name, url: location.url)
        }
        .contextMenu {
            Button("Open") {
                viewModel.selectLocation(name: location.name, url: location.url)
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([location.url])
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(location.url.path, forType: .string)
            }

            Divider()

            Button(role: .destructive) {
                viewModel.removeSidebarLocation(location)
            } label: {
                Label("Remove from Sidebar", systemImage: "minus.circle")
            }

            Button(role: .destructive) {
                viewModel.trashLocationFolder(location)
            } label: {
                Label("Move Folder to Trash", systemImage: "trash")
            }
        }
    }
}

/// Drag-and-drop delegate for live reordering of sidebar sections
struct SidebarSectionDropDelegate: DropDelegate {
    let section: SidebarSectionKind
    @Binding var sections: [SidebarSectionKind]
    @Binding var draggedSection: SidebarSectionKind?
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedSection,
              dragged != section,
              let from = sections.firstIndex(of: dragged),
              let to = sections.firstIndex(of: section) else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            sections.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        onCommit()
        return true
    }
}

/// Drag-and-drop delegate for live reordering of individual sidebar locations
struct LocationRowDropDelegate: DropDelegate {
    let item: SidebarLocationItem
    @Binding var locations: [SidebarLocationItem]
    @Binding var draggedLocation: SidebarLocationItem?
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedLocation,
              dragged.id != item.id,
              let from = locations.firstIndex(where: { $0.id == dragged.id }),
              let to = locations.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            locations.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedLocation = nil
        onCommit()
        return true
    }
}

/// Standard sidebar button row
struct SidebarItemRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let badge: String?
    var badgeColor: Color? = nil
    var badgeTextColor: Color? = nil
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : Color(nsColor: .labelColor))

                Spacer()

                if let badge = badge {
                    if let bg = badgeColor {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bg)
                            .foregroundColor(badgeTextColor ?? .primary)
                            .clipShape(Capsule())
                    } else {
                        Text(badge)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.primary.opacity(0.08)
                    : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle(scaleAmount: 0.97))
        .pointerOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
