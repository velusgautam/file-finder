import SwiftUI

public struct FilterSortToolbarView<TrailingContent: View>: View {
    @ObservedObject public var viewModel: ScannerViewModel
    private let trailingCustomAction: TrailingContent

    public init(
        viewModel: ScannerViewModel,
        @ViewBuilder trailingCustomAction: () -> TrailingContent = { EmptyView() }
    ) {
        self.viewModel = viewModel
        self.trailingCustomAction = trailingCustomAction()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Unified Toolbar Row
            HStack(spacing: 14) {
                // Leading: Navigation & Breadcrumbs / Title
                leadingNavigationArea

                Spacer(minLength: 12)

                // Trailing: Controls (Custom Actions, View Mode, Size, Sort, Filter)
                trailingControlsArea
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.45))

            // Active Filter Pills Strip (Animates in only when filters are active)
            if viewModel.hasActiveFilters {
                Divider().opacity(0.3)
                activeFilterPillsBar
            }
        }
    }

    // MARK: - Leading Navigation & Title Area
    @ViewBuilder
    private var leadingNavigationArea: some View {
        if !viewModel.searchQuery.isEmpty {
            searchHeaderView
        } else {
            switch viewModel.currentSection {
            case .location:
                locationBreadcrumbsView
            default:
                sectionHeaderView
            }
        }
    }

    // Search header displayed when querying
    private var searchHeaderView: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    viewModel.searchQuery = ""
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .pointerOnHover()

            HStack(spacing: 4) {
                Text("Search:")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text("\"\(viewModel.searchQuery)\"")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
            }

            Text("\(viewModel.displayedFiles.count) results")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
        }
    }

    // Breadcrumbs for folder browsing in Locations
    private var locationBreadcrumbsView: some View {
        HStack(spacing: 8) {
            // Parent back button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    viewModel.navigateUp()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(viewModel.canNavigateUp ? .primary : .secondary.opacity(0.35))
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canNavigateUp)
            .pointerOnHover()
            .help(viewModel.canNavigateUp ? "Go to parent folder" : "At root folder")

            // Interactive Breadcrumb Path
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(viewModel.locationBreadcrumbs.enumerated()), id: \.offset) { index, crumb in
                        let isLast = index == viewModel.locationBreadcrumbs.count - 1

                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.4))
                        }

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                viewModel.navigateToBreadcrumb(crumb.url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if index == 0 {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(red: 0.25, green: 0.60, blue: 0.95))
                                }
                                Text(crumb.name)
                                    .font(.system(size: 13, weight: isLast ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isLast ? Color(nsColor: .labelColor) : .secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(isLast ? Color.primary.opacity(0.06) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .pointerOnHover()
                    }
                }
            }

            // Folder & File Count Badge
            HStack(spacing: 4) {
                if !viewModel.currentFolderSubfolders.isEmpty {
                    Text("\(viewModel.currentFolderSubfolders.count) folders")
                    Text("·")
                }
                Text("\(viewModel.displayedFiles.count) files")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.04))
            .clipShape(Capsule())
        }
    }

    // Section Header for Categories, Duplicates, Large Files, etc.
    private var sectionHeaderView: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    viewModel.currentSection = .home
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .pointerOnHover()

            Text(viewModel.currentSection.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))

            let itemCount = (viewModel.currentSection == .applications) ? viewModel.displayedApplications.count : viewModel.displayedFiles.count
            Text("\(itemCount) items")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
        }
    }

    // MARK: - Trailing Controls Area
    private var trailingControlsArea: some View {
        HStack(spacing: 10) {
            // Optional custom action (e.g. Clean All Copies in Duplicates)
            trailingCustomAction

            // 1. View Mode Switcher [ ⊞ Grid | ☰ List ]
            viewModeSwitcher

            // 2. Grid Size Presets [ S | M | L ] (visible only in Grid Mode)
            if viewModel.layoutMode == .grid {
                gridSizeSelector
            }

            Divider()
                .frame(height: 16)
                .opacity(0.4)

            // 3. Sort Menu & Direction
            sortMenuControl

            // 4. Filter Dropdown Menu
            filterMenuControl
        }
    }

    // Segmented View Mode Switcher
    private var viewModeSwitcher: some View {
        HStack(spacing: 1) {
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    viewModel.layoutMode = .grid
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(viewModel.layoutMode == .grid ? .accentColor : .secondary)
                    .frame(width: 26, height: 24)
                    .background(viewModel.layoutMode == .grid ? Color.accentColor.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .help("Grid View")

            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    viewModel.layoutMode = .list
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(viewModel.layoutMode == .list ? .accentColor : .secondary)
                    .frame(width: 26, height: 24)
                    .background(viewModel.layoutMode == .list ? Color.accentColor.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .help("List View")
        }
        .padding(2)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
    }

    // Intuitive Segmented Size Selector [ S | M | L ]
    private var gridSizeSelector: some View {
        HStack(spacing: 1) {
            ForEach(GridSizePreset.allCases) { preset in
                let isSelected = abs(viewModel.gridIconSize - preset.cardWidth) < 10
                let labelText: String = {
                    switch preset {
                    case .small: return "S"
                    case .medium: return "M"
                    case .large: return "L"
                    }
                }()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.gridIconSize = preset.cardWidth
                    }
                } label: {
                    Text(labelText)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .frame(width: 22, height: 24)
                        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .help("\(preset.rawValue) Icons (\(Int(preset.cardWidth))px)")
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
    }

    // Sort Menu & Direction Toggle
    private var sortMenuControl: some View {
        HStack(spacing: 4) {
            Menu {
                // Sort Field Options
                ForEach(SortOption.allCases) { option in
                    Button {
                        viewModel.selectedSortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.selectedSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                // Sort Order Options
                Button {
                    viewModel.selectedSortOrder = .ascending
                } label: {
                    HStack {
                        Text("Ascending")
                        if viewModel.selectedSortOrder == .ascending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    viewModel.selectedSortOrder = .descending
                } label: {
                    HStack {
                        Text("Descending")
                        if viewModel.selectedSortOrder == .descending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text(viewModel.selectedSortOption.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .pointerOnHover()

            // Quick Sort Order Toggle
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    viewModel.selectedSortOrder.toggle()
                }
            } label: {
                Image(systemName: viewModel.selectedSortOrder.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .help("Toggle Sort Direction (Ascending / Descending)")
        }
    }

    // Filter Dropdown Menu
    private var filterMenuControl: some View {
        Menu {
            // Category / File Type Submenu
            Menu("File Type") {
                Button {
                    viewModel.selectedCategoryFilter = nil
                } label: {
                    HStack {
                        Text("All Types")
                        if viewModel.selectedCategoryFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(ShelfCategory.allCases) { cat in
                    Button {
                        viewModel.selectedCategoryFilter = cat
                    } label: {
                        HStack {
                            Label(cat.displayTitle, systemImage: cat.systemImage)
                            if viewModel.selectedCategoryFilter == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // Download Origin Submenu
            if !viewModel.downloadedFromSummaries.isEmpty {
                Menu("Downloaded From") {
                    Button {
                        viewModel.selectedOriginFilter = nil
                    } label: {
                        HStack {
                            Text("All Sources")
                            if viewModel.selectedOriginFilter == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(viewModel.downloadedFromSummaries) { summary in
                        Button {
                            viewModel.selectedOriginFilter = summary.origin
                        } label: {
                            HStack {
                                Label("\(summary.origin.displayName) (\(summary.count))", systemImage: summary.origin.iconSystemName)
                                if viewModel.selectedOriginFilter == summary.origin {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // Size Submenu
            Menu("File Size") {
                ForEach(SizeFilter.allCases) { filter in
                    Button {
                        viewModel.selectedSizeFilter = filter
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                            if viewModel.selectedSizeFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // Date Submenu
            Menu("Date Range") {
                ForEach(DateFilter.allCases) { filter in
                    Button {
                        viewModel.selectedDateFilter = filter
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                            if viewModel.selectedDateFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if viewModel.hasActiveFilters {
                Divider()
                Button("Reset All Filters") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.resetFilters()
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11.5))

                Text("Filter")
                    .font(.system(size: 12, weight: .medium, design: .rounded))

                if viewModel.activeFilterCount > 0 {
                    Text("\(viewModel.activeFilterCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(viewModel.hasActiveFilters ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            .foregroundColor(viewModel.hasActiveFilters ? .accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .pointerOnHover()
    }

    // MARK: - Active Filter Pills Strip
    private var activeFilterPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Filters:")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 2)

                // 1. Origin Section Pill
                if case .downloadedFrom(let origin) = viewModel.currentSection {
                    activeFilterPill(
                        title: origin.displayName,
                        icon: origin.iconSystemName,
                        tint: origin.tintColor
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.currentSection = .home
                        }
                    }
                }

                // 2. Category Filter Pill
                if let cat = viewModel.selectedCategoryFilter {
                    activeFilterPill(
                        title: cat.displayTitle,
                        icon: cat.systemImage,
                        tint: .blue
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.selectedCategoryFilter = nil
                        }
                    }
                }

                // 3. Origin Filter Pill
                if let origin = viewModel.selectedOriginFilter {
                    activeFilterPill(
                        title: origin.displayName,
                        icon: origin.iconSystemName,
                        tint: origin.tintColor
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.selectedOriginFilter = nil
                        }
                    }
                }

                // 4. Size Filter Pill
                if viewModel.selectedSizeFilter != .all {
                    activeFilterPill(
                        title: viewModel.selectedSizeFilter.rawValue,
                        icon: "internaldrive",
                        tint: .secondary
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.selectedSizeFilter = .all
                        }
                    }
                }

                // 5. Date Filter Pill
                if viewModel.selectedDateFilter != .all {
                    activeFilterPill(
                        title: viewModel.selectedDateFilter.rawValue,
                        icon: "calendar",
                        tint: .secondary
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.selectedDateFilter = .all
                        }
                    }
                }

                // "Clear all" action
                Button("Clear all") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        viewModel.resetFilters()
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.leading, 6)
                .pointerOnHover()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
        }
        .background(Color.primary.opacity(0.02))
    }

    private func activeFilterPill(
        title: String,
        icon: String,
        tint: Color,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(tint.opacity(0.8))
            }
            .buttonStyle(.plain)
            .pointerOnHover()
            .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(tint.opacity(0.12))
        .foregroundColor(tint)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.3), lineWidth: 0.8))
    }
}
