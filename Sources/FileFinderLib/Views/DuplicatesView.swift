import SwiftUI

public struct DuplicatesView: View {
    @ObservedObject public var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    private let columns = [
        GridItem(.adaptive(minimum: 195, maximum: 230), spacing: 24)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Unified Filter & Sorting Toolbar
            FilterSortToolbarView(viewModel: viewModel) {
                if viewModel.duplicateTotalWastedBytes > 0 {
                    Button {
                        viewModel.cleanAllDuplicateCopies()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clean Copies (\(viewModel.formattedDuplicateSize))")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(ScandinavianTheme.duplicatesIcon)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .pointerOnHover()
                    .help("Move all duplicate copies to Trash")
                }
            }

            Divider().opacity(0.3)

            // Content
            ScrollView {
                if viewModel.displayedDuplicateGroups.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(ScandinavianTheme.greenHighlight)
                        Text(viewModel.duplicateGroups.isEmpty ? "No Duplicate Files Found" : "No Matching Duplicates")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(viewModel.duplicateGroups.isEmpty ? "All indexed files across your Mac are unique." : "Try adjusting or clearing your filter criteria.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if !viewModel.duplicateGroups.isEmpty {
                            Button("Reset Filters") {
                                viewModel.resetFilters()
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 350)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Click any stacked card to inspect duplicate paths and choose which copy to keep.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(viewModel.displayedDuplicateGroups) { group in
                                DuplicateStackCardView(
                                    group: group,
                                    isSelected: viewModel.selectedDuplicateGroup?.id == group.id
                                ) {
                                    viewModel.selectedDuplicateGroup = group
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.isDetailInspectorVisible = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.selectedDuplicateGroup == nil, let first = viewModel.displayedDuplicateGroups.first {
                viewModel.selectedDuplicateGroup = first
                viewModel.isDetailInspectorVisible = true
            }
        }
    }
}
