import Testing
import Foundation
@testable import FileFinderLib

@Suite("Location Folder Browsing & Breadcrumbs Tests")
struct FolderBrowsingTests {

    @Test("Shallow folder browsing, breadcrumbs, and parent navigation")
    @MainActor
    func testFolderBrowsingAndBreadcrumbs() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let rootURL = base.appendingPathComponent("Workspace")
        let subfolderA = rootURL.appendingPathComponent("ProjectAlpha")
        let subfolderB = rootURL.appendingPathComponent("ProjectBeta")
        let nestedFolder = subfolderA.appendingPathComponent("DeepNested")

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subfolderA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subfolderB, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        // Populate root files
        try "Root File 1".write(to: rootURL.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        try "Root File 2".write(to: rootURL.appendingPathComponent("todo.md"), atomically: true, encoding: .utf8)

        // Populate subfolder files
        try "Alpha File 1".write(to: subfolderA.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let vm = ScannerViewModel()
        vm.selectLocation(name: "Workspace", url: rootURL)

        // 1. Verify root contents
        #expect(vm.currentFolderSubfolders.count == 2)
        #expect(vm.currentFolderSubfolders.contains { $0.name == "ProjectAlpha" })
        #expect(vm.currentFolderSubfolders.contains { $0.name == "ProjectBeta" })
        #expect(vm.currentFolderFiles.count == 2)
        #expect(vm.locationBreadcrumbs.count == 1)
        #expect(vm.locationBreadcrumbs.first?.name == "Workspace")
        #expect(!vm.canNavigateUp)

        // 2. Navigate inside subfolderA
        vm.navigateToFolder(subfolderA)
        #expect(vm.currentFolderURL?.standardizedFileURL.path == subfolderA.standardizedFileURL.path)
        #expect(vm.canNavigateUp)
        #expect(vm.locationBreadcrumbs.count == 2)
        #expect(vm.locationBreadcrumbs[0].name == "Workspace")
        #expect(vm.locationBreadcrumbs[1].name == "ProjectAlpha")
        #expect(vm.currentFolderSubfolders.count == 1) // DeepNested
        #expect(vm.currentFolderSubfolders.first?.name == "DeepNested")
        #expect(vm.currentFolderFiles.count == 1) // main.swift

        // 3. Navigate into DeepNested
        vm.navigateToFolder(nestedFolder)
        #expect(vm.currentFolderURL?.standardizedFileURL.path == nestedFolder.standardizedFileURL.path)
        #expect(vm.locationBreadcrumbs.count == 3)
        #expect(vm.locationBreadcrumbs[2].name == "DeepNested")
        #expect(vm.currentFolderSubfolders.isEmpty)
        #expect(vm.currentFolderFiles.isEmpty)

        // 4. Navigate up
        vm.navigateUp()
        #expect(vm.currentFolderURL?.standardizedFileURL.path == subfolderA.standardizedFileURL.path)
        #expect(vm.locationBreadcrumbs.count == 2)

        // 5. Navigate via breadcrumb directly to Workspace root
        vm.navigateToBreadcrumb(rootURL)
        #expect(vm.currentFolderURL?.standardizedFileURL.path == rootURL.standardizedFileURL.path)
        #expect(vm.locationBreadcrumbs.count == 1)
        #expect(!vm.canNavigateUp)
    }
}
