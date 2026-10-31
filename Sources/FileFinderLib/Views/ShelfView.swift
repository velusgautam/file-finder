import SwiftUI

public struct ShelfView: View {
    public let category: ShelfCategory
    public let items: [FileItem]
    public let viewModel: ScannerViewModel?
    public let onSeeAll: (() -> Void)?
    public let onTrash: ((FileItem) -> Void)?

    public init(
        category: ShelfCategory,
        items: [FileItem],
        viewModel: ScannerViewModel? = nil,
        onSeeAll: (() -> Void)? = nil,
        onTrash: ((FileItem) -> Void)? = nil
    ) {
        self.category = category
        self.items = items
        self.viewModel = viewModel
        self.onSeeAll = onSeeAll
        self.onTrash = onTrash
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(category.displayTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("\(items.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundColor(.secondary)

                Spacer()

                if let onSeeAll = onSeeAll, !items.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 3) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            // Horizontal Carousel
            if items.isEmpty {
                HStack {
                    Text("No files in this shelf")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 32)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(items.prefix(20)) { item in
                                let isSelected = (viewModel?.selectedFileSet.contains(item.url) ?? false) || (viewModel?.selectedFile?.url == item.url)

                                FileCardView(
                                    item: item,
                                    isSelected: isSelected,
                                    selectedURLs: viewModel.map { Array($0.selectedFileSet) },
                                    onSelect: {
                                        if let vm = viewModel {
                                            let flags = NSEvent.modifierFlags
                                            if flags.contains(.command) {
                                                vm.toggleFileSelection(item)
                                            } else if flags.contains(.shift) {
                                                vm.selectFileRange(to: item)
                                            } else {
                                                vm.selectSingleFile(item)
                                            }
                                            vm.selectedDuplicateGroup = nil
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                vm.isDetailInspectorVisible = true
                                            }
                                        }
                                    },
                                    onTrash: onTrash
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: viewModel?.selectedFile) { _, newFile in
                        if let file = newFile, items.prefix(20).contains(where: { $0.url == file.url }) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(file.id, anchor: nil)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
