import SwiftUI

public struct ShelfView: View {
    public let category: ShelfCategory
    public let items: [FileItem]
    public let onSeeAll: (() -> Void)?
    public let onTrash: ((FileItem) -> Void)?

    public init(category: ShelfCategory, items: [FileItem], onSeeAll: (() -> Void)? = nil, onTrash: ((FileItem) -> Void)? = nil) {
        self.category = category
        self.items = items
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
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items.prefix(20)) { item in
                            FileCardView(item: item, onTrash: onTrash)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
