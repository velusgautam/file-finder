import SwiftUI

public struct DownloadedFromOverviewView: View {
    @ObservedObject public var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 280), spacing: 20)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
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

                Text("Downloaded From")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))

                Text("\(viewModel.downloadedFromSummaries.count) sources")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.45))

            Divider().opacity(0.3)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select any source to view all downloaded files. You can clear the filter at any time to return to Home.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    if viewModel.downloadedFromSummaries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No Download Sources Found")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("Downloaded files in your Downloads folder will appear here grouped by their source app or website.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.downloadedFromSummaries) { summary in
                                DownloadedFromCardView(
                                    origin: summary.origin,
                                    count: summary.count,
                                    totalByteSize: summary.totalSize,
                                    sampleItems: summary.sampleItems
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        viewModel.currentSection = .downloadedFrom(summary.origin)
                                    }
                                }
                                .buttonStyle(PressableButtonStyle(scaleAmount: 0.98))
                                .pointerOnHover()
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}
