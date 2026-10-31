import Testing
import Foundation
import UniformTypeIdentifiers
@testable import FileFinderLib

@Suite("Native QuickLook & Finder-Style Interaction Tests")
struct QuickLookAndInteractionTests {

    // Helper to generate mock FileItems
    private func makeMockFile(name: String, ext: String = "txt", size: Int64 = 1024) -> FileItem {
        let url = URL(fileURLWithPath: "/tmp/\(name).\(ext)")
        return FileItem(
            url: url,
            name: name,
            fileSize: size,
            modificationDate: Date(),
            creationDate: Date(),
            category: .documents,
            origin: .unknown,
            originURL: nil
        )
    }

    // MARK: - 1. Selection Navigator Index Calculations

    @Test("SelectionNavigator: Previous index calculation and bounds clamping")
    func testPreviousIndexCalculations() {
        // Normal decrement
        #expect(SelectionNavigator.previousIndex(from: 3, totalCount: 5) == 2)
        #expect(SelectionNavigator.previousIndex(from: 1, totalCount: 5) == 0)

        // Clamping at zero
        #expect(SelectionNavigator.previousIndex(from: 0, totalCount: 5) == 0)

        // Unselected starts at 0
        #expect(SelectionNavigator.previousIndex(from: nil, totalCount: 5) == 0)

        // Empty list returns nil
        #expect(SelectionNavigator.previousIndex(from: 0, totalCount: 0) == nil)
        #expect(SelectionNavigator.previousIndex(from: nil, totalCount: 0) == nil)
    }

    @Test("SelectionNavigator: Next index calculation and bounds clamping")
    func testNextIndexCalculations() {
        // Normal increment
        #expect(SelectionNavigator.nextIndex(from: 0, totalCount: 5) == 1)
        #expect(SelectionNavigator.nextIndex(from: 3, totalCount: 5) == 4)

        // Clamping at upper bound
        #expect(SelectionNavigator.nextIndex(from: 4, totalCount: 5) == 4)

        // Unselected starts at 0
        #expect(SelectionNavigator.nextIndex(from: nil, totalCount: 5) == 0)

        // Empty list returns nil
        #expect(SelectionNavigator.nextIndex(from: 0, totalCount: 0) == nil)
        #expect(SelectionNavigator.nextIndex(from: nil, totalCount: 0) == nil)
    }

    @Test("SelectionNavigator: Grid row jump (Up / Down) with column step")
    func testRowJumpCalculations() {
        let columns = 4
        let totalCount = 10

        // Jump Up
        #expect(SelectionNavigator.indexAbove(from: 6, totalCount: totalCount, columns: columns) == 2)
        #expect(SelectionNavigator.indexAbove(from: 4, totalCount: totalCount, columns: columns) == 0)
        #expect(SelectionNavigator.indexAbove(from: 2, totalCount: totalCount, columns: columns) == 0) // Clamps at 0

        // Jump Down
        #expect(SelectionNavigator.indexBelow(from: 1, totalCount: totalCount, columns: columns) == 5)
        #expect(SelectionNavigator.indexBelow(from: 5, totalCount: totalCount, columns: columns) == 9)
        #expect(SelectionNavigator.indexBelow(from: 8, totalCount: totalCount, columns: columns) == 9) // Clamps at 9

        // Single column (List Mode)
        #expect(SelectionNavigator.indexAbove(from: 3, totalCount: totalCount, columns: 1) == 2)
        #expect(SelectionNavigator.indexBelow(from: 3, totalCount: totalCount, columns: 1) == 4)
    }

    @Test("SelectionNavigator: Unified navigate function across all directions")
    func testUnifiedNavigateFunction() {
        let total = 8
        let cols = 3

        #expect(SelectionNavigator.navigate(from: 4, direction: .left, totalCount: total, columns: cols) == 3)
        #expect(SelectionNavigator.navigate(from: 4, direction: .right, totalCount: total, columns: cols) == 5)
        #expect(SelectionNavigator.navigate(from: 4, direction: .up, totalCount: total, columns: cols) == 1)
        #expect(SelectionNavigator.navigate(from: 4, direction: .down, totalCount: total, columns: cols) == 7)
    }

    // MARK: - 2. Multi-Selection Set Operations

    @Test("MultiSelectionHelper: Toggle individual item in Set")
    func testMultiSelectionToggle() {
        var set: Set<String> = ["A", "B"]

        // Toggle out existing item
        MultiSelectionHelper.toggle(item: "B", in: &set)
        #expect(!set.contains("B"))
        #expect(set == ["A"])

        // Toggle in new item
        MultiSelectionHelper.toggle(item: "C", in: &set)
        #expect(set.contains("C"))
        #expect(set == ["A", "C"])
    }

    @Test("MultiSelectionHelper: Range selection forward and backward")
    func testMultiSelectionRange() {
        let items = ["file0", "file1", "file2", "file3", "file4", "file5"]

        // Forward range: file1 to file4
        let forwardRange = MultiSelectionHelper.rangeSelection(from: "file1", to: "file4", in: items)
        #expect(forwardRange == Set(["file1", "file2", "file3", "file4"]))

        // Backward range: file4 to file2
        let backwardRange = MultiSelectionHelper.rangeSelection(from: "file4", to: "file2", in: items)
        #expect(backwardRange == Set(["file2", "file3", "file4"]))

        // Single item range (anchor == target)
        let singleRange = MultiSelectionHelper.rangeSelection(from: "file3", to: "file3", in: items)
        #expect(singleRange == Set(["file3"]))

        // Missing anchor defaults to target
        let missingAnchorRange = MultiSelectionHelper.rangeSelection(from: "unknown", to: "file2", in: items)
        #expect(missingAnchorRange == Set(["file2"]))
    }

    // MARK: - 3. Multi-File Drag Item Provider Generation

    @Test("MultiSelectionHelper: Item providers generation for multi-file drag")
    func testMultiFileItemProviders() {
        let urls = [
            URL(fileURLWithPath: "/tmp/doc1.pdf"),
            URL(fileURLWithPath: "/tmp/doc2.pdf"),
            URL(fileURLWithPath: "/tmp/doc3.pdf")
        ]

        let providers = MultiSelectionHelper.createItemProviders(for: urls)
        #expect(providers.count == 3)

        // Combined drag provider
        let combinedProvider = MultiSelectionHelper.createMultiFileItemProvider(for: urls[0], selectedURLs: urls)
        #expect(combinedProvider.registeredTypeIdentifiers.contains(UTType.fileURL.identifier))
        #expect(combinedProvider.registeredTypeIdentifiers.contains("NSFilenamesPboardType"))
    }

    // MARK: - 4. ScannerViewModel Selection & Quick Look State

    @Test("ScannerViewModel: Single file selection updates selectedFileSet")
    @MainActor
    func testViewModelSingleSelection() {
        let vm = ScannerViewModel()
        let fileA = makeMockFile(name: "alpha")
        let fileB = makeMockFile(name: "beta")

        vm.selectSingleFile(fileA)
        #expect(vm.selectedFile?.url == fileA.url)
        #expect(vm.selectedFileSet == [fileA.url])
        #expect(vm.selectedFolder == nil)

        vm.selectSingleFile(fileB)
        #expect(vm.selectedFile?.url == fileB.url)
        #expect(vm.selectedFileSet == [fileB.url])
    }

    @Test("ScannerViewModel: Command-click toggle and Shift-click range in ViewModel")
    @MainActor
    func testViewModelToggleAndRange() {
        let vm = ScannerViewModel()
        let file1 = makeMockFile(name: "item1")
        let file2 = makeMockFile(name: "item2")

        vm.selectSingleFile(file1)
        #expect(vm.selectedFileSet == [file1.url])

        // Command-click adds file2
        vm.toggleFileSelection(file2)
        #expect(vm.selectedFileSet.contains(file1.url))
        #expect(vm.selectedFileSet.contains(file2.url))
        #expect(vm.selectedFileSet.count == 2)

        // Command-click removes file1
        vm.toggleFileSelection(file1)
        #expect(!vm.selectedFileSet.contains(file1.url))
        #expect(vm.selectedFileSet == [file2.url])
    }

    @Test("ScannerViewModel: Quick Look toggle and live selection update")
    @MainActor
    func testQuickLookToggleAndLiveUpdate() {
        let vm = ScannerViewModel()
        let fileA = makeMockFile(name: "imageA", ext: "png")
        let fileB = makeMockFile(name: "imageB", ext: "png")

        vm.selectSingleFile(fileA)

        // Space toggles Quick Look open
        vm.toggleQuickLook()
        #expect(vm.isQuickLookVisible == true)
        #expect(vm.quickLookURL == fileA.url)

        // Changing selection updates Quick Look in real time without closing
        vm.selectSingleFile(fileB)
        #expect(vm.isQuickLookVisible == true)
        #expect(vm.quickLookURL == fileB.url)

        // Space again closes Quick Look
        vm.toggleQuickLook()
        #expect(vm.isQuickLookVisible == false)
        #expect(vm.quickLookURL == nil)
    }

    // MARK: - 5. Escape Key Hierarchical Actions & Fullscreen Protection

    @Test("Escape key closes search when search query is active and returns nil")
    @MainActor
    func testEscapeClosesSearchWhenActive() {
        let vm = ScannerViewModel()
        vm.searchQuery = "financial report"
        #expect(!vm.searchQuery.isEmpty)

        let result = KeyboardNavigationHandler.shared.handleEscapeKey(vm: vm)
        #expect(result == nil) // Consumed
        #expect(vm.searchQuery.isEmpty)
    }

    @Test("Escape key deselects multiple files when multi-selection is active")
    @MainActor
    func testEscapeDeselectsMultipleFiles() {
        let vm = ScannerViewModel()
        let fileA = makeMockFile(name: "fileA")
        let fileB = makeMockFile(name: "fileB")

        vm.toggleFileSelection(fileA)
        vm.toggleFileSelection(fileB)
        #expect(vm.selectedFileSet.count == 2)

        let result = KeyboardNavigationHandler.shared.handleEscapeKey(vm: vm)
        #expect(result == nil) // Consumed
        #expect(vm.selectedFileSet.isEmpty)
        #expect(vm.selectedFile == nil)
    }

    @Test("Escape key closes right detail sidebar when open and file was clicked")
    @MainActor
    func testEscapeClosesRightDetailSidebar() {
        let vm = ScannerViewModel()
        let file = makeMockFile(name: "document")

        vm.selectSingleFile(file)
        vm.isDetailInspectorVisible = true
        #expect(vm.isDetailInspectorVisible == true)

        let result = KeyboardNavigationHandler.shared.handleEscapeKey(vm: vm)
        #expect(result == nil) // Consumed
        #expect(vm.isDetailInspectorVisible == false)
        #expect(vm.selectedFile == nil)
    }

    @Test("Escape key returns nil unconditionally when idle to prevent exiting macOS fullscreen/maximize mode")
    @MainActor
    func testEscapeConsumedUnconditionallyToPreventExitingFullscreen() {
        let vm = ScannerViewModel()
        // Ensure everything is idle
        vm.searchQuery = ""
        vm.clearSelection()
        vm.isDetailInspectorVisible = false

        let result = KeyboardNavigationHandler.shared.handleEscapeKey(vm: vm)
        // Must return nil so macOS AppKit window never receives Escape and never exits fullscreen
        #expect(result == nil)
    }
}
