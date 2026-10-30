import Testing
import Foundation
@testable import FileFinderLib

@Suite("View Layout Mode & Grid Sizing Tests")
struct ViewLayoutModeTests {

    @Test("Layout mode identifiers and icons")
    func testLayoutModes() {
        #expect(ViewLayoutMode.grid.iconName == "square.grid.2x2")
        #expect(ViewLayoutMode.list.iconName == "list.bullet")
        #expect(ViewLayoutMode.allCases.count == 2)
    }

    @Test("Grid size presets card width scaling")
    func testGridSizePresets() {
        #expect(GridSizePreset.small.cardWidth == 145)
        #expect(GridSizePreset.medium.cardWidth == 185)
        #expect(GridSizePreset.large.cardWidth == 235)
        #expect(GridSizePreset.small.cardWidth < GridSizePreset.medium.cardWidth)
        #expect(GridSizePreset.medium.cardWidth < GridSizePreset.large.cardWidth)
    }

    @Test("FolderItem properties formatting and date calculation")
    func testFolderItemProperties() {
        let now = Date()
        let singleItemFolder = FolderItem(
            url: URL(fileURLWithPath: "/tmp/test1"),
            name: "TestFolder1",
            itemCount: 1,
            modificationDate: now
        )
        #expect(singleItemFolder.formattedItemCount == "1 item")
        #expect(!singleItemFolder.relativeDateString.isEmpty)

        let multipleItemsFolder = FolderItem(
            url: URL(fileURLWithPath: "/tmp/test2"),
            name: "TestFolder2",
            itemCount: 5,
            modificationDate: now.addingTimeInterval(-3600)
        )
        #expect(multipleItemsFolder.formattedItemCount == "5 items")
        #expect(!multipleItemsFolder.relativeDateString.isEmpty)
    }
}
