import SwiftUI

public struct HomeDashboardView: View {
    @ObservedObject public var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    private let libraryColumns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    private let cleanupColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Greeting & Global Real Stats Row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.greeting)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(nsColor: .labelColor))

                        Text("\(viewModel.totalFileCount) files · \(viewModel.formattedTotalSize) across your Mac")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Refresh Button
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                .animation(
                                    viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                    value: viewModel.isLoading
                                )

                            Text("Refresh")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ScandinavianTheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // 1. Library Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text("Library")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(nsColor: .labelColor))

                        Text("\(libraryCategories.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)

                    LazyVGrid(columns: libraryColumns, spacing: 20) {
                        ForEach(libraryCategories, id: \.self) { cat in
                            let items = viewModel.shelves[cat] ?? []
                            LibraryFolderCardView(
                                category: cat,
                                items: items,
                                totalByteSize: nil
                            ) {
                                viewModel.currentSection = .category(cat)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // 2. Clean Up Section with Real Data
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Clean Up")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(nsColor: .labelColor))

                        // Green Pill Badge
                        Text("Free up to \(viewModel.formattedCleanupTotal)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ScandinavianTheme.greenHighlight)
                            .foregroundColor(.white)
                            .clipShape(Capsule())

                        Spacer()

                        Button {
                            viewModel.currentSection = .cleanUp
                        } label: {
                            HStack(spacing: 4) {
                                Text("See all")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 32)

                    LazyVGrid(columns: cleanupColumns, spacing: 16) {
                        CleanUpCardView(
                            type: .duplicates,
                            formattedSize: viewModel.duplicateTotalWastedBytes > 0 ? viewModel.formattedDuplicateSize : "0 KB",
                            itemCount: viewModel.duplicateFiles.count,
                            sampleItems: viewModel.duplicateFiles
                        ) {
                            viewModel.currentSection = .duplicates
                        }

                        CleanUpCardView(
                            type: .forgottenDownloads,
                            formattedSize: viewModel.forgottenDownloadsBytes > 0 ? viewModel.formattedForgottenDownloadsSize : "0 KB",
                            itemCount: viewModel.forgottenDownloads.count,
                            sampleItems: viewModel.forgottenDownloads
                        ) {
                            viewModel.currentSection = .cleanUp
                        }

                        CleanUpCardView(
                            type: .oldScreenshots,
                            formattedSize: viewModel.oldScreenshotsBytes > 0 ? viewModel.formattedOldScreenshotsSize : "0 KB",
                            itemCount: viewModel.oldScreenshots.count,
                            sampleItems: viewModel.oldScreenshots
                        ) {
                            viewModel.currentSection = .screenshots
                        }

                        CleanUpCardView(
                            type: .largeFiles,
                            formattedSize: viewModel.largeFilesBytes > 0 ? viewModel.formattedLargeFilesSize : "0 KB",
                            itemCount: viewModel.largeFiles.count,
                            sampleItems: viewModel.largeFiles
                        ) {
                            viewModel.currentSection = .largeFiles
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // 3. Downloaded From Section with 100% Real Detected Data
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Downloaded From")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(nsColor: .labelColor))

                        Text("\(viewModel.downloadedFromSummaries.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundColor(.secondary)

                        Spacer()

                        if !viewModel.downloadedFromSummaries.isEmpty {
                            Button {
                                viewModel.currentSection = .downloadedFromOverview
                            } label: {
                                HStack(spacing: 4) {
                                    Text("See all")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 32)

                    if viewModel.downloadedFromSummaries.isEmpty {
                        HStack {
                            Text("No downloads with origin tags found in scanned folders.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 14)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(viewModel.downloadedFromSummaries) { summary in
                                    DownloadedFromCardView(
                                        origin: summary.origin,
                                        count: summary.count,
                                        totalByteSize: summary.totalSize,
                                        sampleItems: summary.sampleItems
                                    ) {
                                        viewModel.currentSection = .downloadedFrom(summary.origin)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(.bottom, 48)
        }
        .background(ScandinavianTheme.canvasBackground)
    }

    private var libraryCategories: [ShelfCategory] {
        [.images, .videos, .audio, .documents, .archives, .code]
    }
}
