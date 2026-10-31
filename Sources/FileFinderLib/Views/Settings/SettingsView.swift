import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var viewModel: ScannerViewModel
    @Environment(\.dismiss) private var dismiss

    // Clean Up Rules state
    @State private var isOldInstallersEnabled: Bool = CleanUpRulesEngine.shared.isOldInstallersEnabled
    @State private var isOldInstallersAutoRun: Bool = CleanUpRulesEngine.shared.isOldInstallersAutoRun
    @State private var oldInstallersDays: Int = CleanUpRulesEngine.shared.oldInstallersDaysThreshold

    @State private var isScreenshotsEnabled: Bool = CleanUpRulesEngine.shared.isScreenshotsByMonthEnabled
    @State private var isScreenshotsAutoRun: Bool = CleanUpRulesEngine.shared.isScreenshotsAutoRun

    @State private var cleanUpStatusMessage: String? = nil

    // Saved Searches state
    @State private var savedSearches: [SavedSearch] = SavedSearchStore.shared.loadSavedSearches()
    @State private var newSearchName: String = ""
    @State private var newSearchQuery: String = ""
    @State private var isAddingSearch: Bool = false

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Clean up automation and saved natural language searches")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().opacity(0.4)

            // Content Scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Feedback alert banner if an action was run
                    if let message = cleanUpStatusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(message)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            Spacer()
                            Button("Dismiss") {
                                withAnimation { cleanUpStatusMessage = nil }
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Section 1: Clean Up Rules
                    cleanUpRulesSection

                    Divider().opacity(0.3)

                    // Section 2: Saved Searches
                    savedSearchesSection
                }
                .padding(24)
            }
        }
        .frame(width: 580, height: 560)
        .background(ScandinavianTheme.canvasBackground)
    }

    // MARK: - Clean Up Rules Section

    private var cleanUpRulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Clean Up Rules")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            // Rule 1: Move Old Installers
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Move old installers to Trash")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Identifies disk images (.dmg, .pkg, .iso) in Downloads older than \(oldInstallersDays) days.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isOldInstallersEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: isOldInstallersEnabled) { _, newValue in
                            CleanUpRulesEngine.shared.isOldInstallersEnabled = newValue
                        }
                }

                if isOldInstallersEnabled {
                    HStack(spacing: 16) {
                        Toggle("Run automatically during background scan", isOn: $isOldInstallersAutoRun)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .onChange(of: isOldInstallersAutoRun) { _, newValue in
                                CleanUpRulesEngine.shared.isOldInstallersAutoRun = newValue
                            }

                        Spacer()

                        Button {
                            runOldInstallersNow()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Run Now")
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.leading, 6)
                }
            }
            .padding(14)
            .background(ScandinavianTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))

            // Rule 2: Organize Screenshots by Month
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organize screenshots by month")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Groups screenshots on Desktop and Downloads into Screenshots/YYYY-MM/ folders.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isScreenshotsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: isScreenshotsEnabled) { _, newValue in
                            CleanUpRulesEngine.shared.isScreenshotsByMonthEnabled = newValue
                        }
                }

                if isScreenshotsEnabled {
                    HStack(spacing: 16) {
                        Toggle("Run automatically when new screenshots are detected", isOn: $isScreenshotsAutoRun)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .onChange(of: isScreenshotsAutoRun) { _, newValue in
                                CleanUpRulesEngine.shared.isScreenshotsAutoRun = newValue
                            }

                        Spacer()

                        Button {
                            runScreenshotsOrganizationNow()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.gearshape")
                                Text("Run Now")
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.leading, 6)
                }
            }
            .padding(14)
            .background(ScandinavianTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 1))
        }
    }

    // MARK: - Saved Searches Section

    private var savedSearchesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass.circle")
                        .foregroundColor(.accentColor)
                    Text("Saved Searches")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isAddingSearch.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAddingSearch ? "chevron.up" : "plus")
                        Text(isAddingSearch ? "Cancel" : "Add Search")
                    }
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Inline New Search Form
            if isAddingSearch {
                VStack(spacing: 8) {
                    TextField("Search Title (e.g. Recent Invoices)", text: $newSearchName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    TextField("Query or Filter (e.g. type:pdf from:last-week)", text: $newSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    HStack {
                        Spacer()
                        Button("Save") {
                            addNewSearch()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newSearchName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(12)
                .background(ScandinavianTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }

            // List of Saved Searches
            VStack(spacing: 8) {
                ForEach(savedSearches) { search in
                    HStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(search.name)
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            Text(search.query)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Execute Search
                        Button {
                            executeSearch(search)
                        } label: {
                            HStack(spacing: 3) {
                                Text("Execute")
                                Image(systemName: "arrow.right.circle")
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        // Delete Search
                        Button {
                            deleteSearch(search)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .pointerOnHover()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ScandinavianTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ScandinavianTheme.hairlineBorder, lineWidth: 0.8))
                }
            }
        }
    }

    // MARK: - Actions

    private func runOldInstallersNow() {
        let trashed = CleanUpRulesEngine.shared.runOldInstallersCleanup(
            in: viewModel.allFiles,
            olderThanDays: oldInstallersDays
        )

        Task {
            await viewModel.refresh()
        }

        withAnimation {
            if trashed.isEmpty {
                cleanUpStatusMessage = "No installers older than \(oldInstallersDays) days found in Downloads."
            } else {
                cleanUpStatusMessage = "Moved \(trashed.count) old installer(s) to Trash."
            }
        }
    }

    private func runScreenshotsOrganizationNow() {
        let organized = CleanUpRulesEngine.shared.runScreenshotsOrganization(in: viewModel.allFiles)

        Task {
            await viewModel.refresh()
        }

        withAnimation {
            if organized.isEmpty {
                cleanUpStatusMessage = "No screenshots needing organization found on Desktop or Downloads."
            } else {
                cleanUpStatusMessage = "Organized \(organized.count) screenshot(s) into month folders."
            }
        }
    }

    private func addNewSearch() {
        let trimmedName = newSearchName.trimmingCharacters(in: .whitespaces)
        let trimmedQuery = newSearchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty && !trimmedQuery.isEmpty else { return }

        let search = SavedSearch(name: trimmedName, query: trimmedQuery)
        SavedSearchStore.shared.addSavedSearch(search)
        savedSearches = SavedSearchStore.shared.loadSavedSearches()

        newSearchName = ""
        newSearchQuery = ""
        withAnimation {
            isAddingSearch = false
        }
    }

    private func deleteSearch(_ search: SavedSearch) {
        SavedSearchStore.shared.removeSavedSearch(id: search.id)
        withAnimation {
            savedSearches.removeAll { $0.id == search.id }
        }
    }

    private func executeSearch(_ search: SavedSearch) {
        viewModel.searchQuery = search.query
        dismiss()
    }
}
