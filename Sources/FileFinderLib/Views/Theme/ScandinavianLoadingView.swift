import SwiftUI

public struct ScandinavianLoadingView: View {
    @ObservedObject public var viewModel: ScannerViewModel
    @State private var shimmerOffset: CGFloat = -1.0

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Icon with subtle breathing effect
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 68, height: 68)

                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.60, blue: 0.98), Color(red: 0.10, green: 0.45, blue: 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Indexing your Mac")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))

                HStack(spacing: 6) {
                    Text("Scanning")
                        .foregroundColor(.secondary)
                    Text(viewModel.scanCurrentFolder)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(nsColor: .labelColor))
                    Text("across worker threads...")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 13, design: .rounded))
            }

            // Sleek Custom Progress Bar
            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)

                        // Shimmering animated gradient fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.65, blue: 1.0),
                                        Color(red: 0.15, green: 0.45, blue: 0.95),
                                        Color(red: 0.35, green: 0.75, blue: 1.0)
                                    ],
                                    startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                                    endPoint: UnitPoint(x: shimmerOffset + 1.0, y: 0.5)
                                )
                            )
                            .frame(width: geometry.size.width * 0.7, height: 6)
                            .offset(x: max(0, geometry.size.width * (shimmerOffset * 0.5)))
                    }
                    .clipShape(Capsule())
                }
                .frame(width: 320, height: 6)

                // Live Stats Ticker
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 10))
                        Text("\(viewModel.scanFilesCount) files found")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary.opacity(0.4))

                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 10))
                        Text(viewModel.formattedScanBytes)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ScandinavianTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 16, y: 6)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.0
            }
        }
    }
}

/// Subtle top strip progress bar displayed during non-blocking background refreshes
public struct BackgroundScanProgressStrip: View {
    @State private var offset: CGFloat = -1.0

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(height: 2.5)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.60, blue: 0.98),
                                Color(red: 0.40, green: 0.80, blue: 1.0),
                                Color(red: 0.20, green: 0.60, blue: 0.98)
                            ],
                            startPoint: UnitPoint(x: offset, y: 0.5),
                            endPoint: UnitPoint(x: offset + 0.6, y: 0.5)
                        )
                    )
                    .frame(width: proxy.size.width * 0.4, height: 2.5)
                    .offset(x: max(0, proxy.size.width * offset))
            }
        }
        .frame(height: 2.5)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                offset = 1.0
            }
        }
    }
}
