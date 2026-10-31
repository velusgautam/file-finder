import Testing
import Foundation
@testable import FileFinderLib

@Suite("Sidebar Reordering & Location Tests", .serialized)
struct SidebarReorderTests {

    @Test("Sidebar section kind defaults and titles")
    func testSidebarSectionKindDefaults() {
        let defaults = SidebarSectionStore.shared.resetToDefaults()
        #expect(defaults == [.library, .cleanUp, .locations])

        #expect(SidebarSectionKind.library.title == "Library")
        #expect(SidebarSectionKind.cleanUp.title == "Smart Shelves")
        #expect(SidebarSectionKind.locations.title == "Locations")
    }

    @Test("Sidebar section reordering and persistence")
    func testSidebarSectionReordering() {
        let store = SidebarSectionStore.shared
        var sections: [SidebarSectionKind] = [.library, .cleanUp, .locations]

        // Reorder: Move locations to index 1 (between library and cleanup)
        sections.move(fromOffsets: IndexSet(integer: 2), toOffset: 1)
        #expect(sections == [.library, .locations, .cleanUp])

        store.saveSections(sections)
        let loaded = store.loadSections()
        #expect(loaded == [.library, .locations, .cleanUp])

        // Reset
        _ = store.resetToDefaults()
        #expect(store.loadSections() == [.library, .cleanUp, .locations])
    }

    @Test("Sidebar default locations and custom removal")
    func testSidebarLocationDefaultsAndRemoval() {
        let store = SidebarLocationStore.shared
        var locations = store.resetToDefaults()

        #expect(!locations.isEmpty)
        #expect(locations.contains { $0.name == "Desktop" })
        #expect(locations.contains { $0.name == "Documents" })
        #expect(locations.contains { $0.name == "Downloads" })

        // Remove Desktop
        locations.removeAll { $0.name == "Desktop" }
        #expect(!locations.contains { $0.name == "Desktop" })

        store.saveLocations(locations)
        let loaded = store.loadLocations()
        #expect(!loaded.contains { $0.name == "Desktop" })

        // Reorder locations
        var reordered = loaded
        if reordered.count >= 2 {
            reordered.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
            store.saveLocations(reordered)
            let loadedReordered = store.loadLocations()
            #expect(loadedReordered.first?.id == reordered.first?.id)
        }

        // Reset
        _ = store.resetToDefaults()
        #expect(store.loadLocations().contains { $0.name == "Desktop" })
    }

    @Test("FolderItem deletion / trashing in ScannerViewModel")
    @MainActor
    func testFolderTrashing() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let subfolder = base.appendingPathComponent("FolderToDelete")
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        try "Hello World".write(to: subfolder.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let vm = ScannerViewModel()
        vm.selectLocation(name: "TestBase", url: base)

        #expect(vm.currentFolderSubfolders.contains { $0.name == "FolderToDelete" })

        if let folderItem = vm.currentFolderSubfolders.first(where: { $0.name == "FolderToDelete" }) {
            vm.trashFolder(folderItem)
            #expect(!vm.currentFolderSubfolders.contains { $0.name == "FolderToDelete" })
        }
    }
}
