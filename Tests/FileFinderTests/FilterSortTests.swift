import Testing
import Foundation
@testable import FileFinderLib

@Suite("Filter & Sorting Tests")
struct FilterSortTests {

    @Test("Size Filter thresholds")
    func testSizeFilter() {
        let smallBytes: Int64 = 500 * 1024 // 500 KB
        let mediumBytes: Int64 = 10 * 1024 * 1024 // 10 MB
        let largeBytes: Int64 = 100 * 1024 * 1024 // 100 MB

        // All Sizes
        #expect(SizeFilter.all.matches(fileSize: smallBytes))
        #expect(SizeFilter.all.matches(fileSize: mediumBytes))
        #expect(SizeFilter.all.matches(fileSize: largeBytes))

        // Small (< 1 MB)
        #expect(SizeFilter.small.matches(fileSize: smallBytes))
        #expect(!SizeFilter.small.matches(fileSize: mediumBytes))
        #expect(!SizeFilter.small.matches(fileSize: largeBytes))

        // Medium (1 MB - 50 MB)
        #expect(!SizeFilter.medium.matches(fileSize: smallBytes))
        #expect(SizeFilter.medium.matches(fileSize: mediumBytes))
        #expect(!SizeFilter.medium.matches(fileSize: largeBytes))

        // Large (> 50 MB)
        #expect(!SizeFilter.large.matches(fileSize: smallBytes))
        #expect(!SizeFilter.large.matches(fileSize: mediumBytes))
        #expect(SizeFilter.large.matches(fileSize: largeBytes))
    }

    @Test("Date Filter ranges")
    func testDateFilter() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let fiveDaysAgo = now.addingTimeInterval(-5 * 86400)
        let twentyDaysAgo = now.addingTimeInterval(-20 * 86400)
        let twoMonthsAgo = now.addingTimeInterval(-60 * 86400)
        let twoYearsAgo = now.addingTimeInterval(-730 * 86400)

        // All
        #expect(DateFilter.all.matches(date: now))
        #expect(DateFilter.all.matches(date: twoYearsAgo))

        // Today
        #expect(DateFilter.today.matches(date: now))

        // Past 7 Days
        #expect(DateFilter.pastWeek.matches(date: yesterday))
        #expect(DateFilter.pastWeek.matches(date: fiveDaysAgo))
        #expect(!DateFilter.pastWeek.matches(date: twentyDaysAgo))

        // Past 30 Days
        #expect(DateFilter.pastMonth.matches(date: fiveDaysAgo))
        #expect(DateFilter.pastMonth.matches(date: twentyDaysAgo))
        #expect(!DateFilter.pastMonth.matches(date: twoMonthsAgo))

        // Past Year
        #expect(DateFilter.pastYear.matches(date: twoMonthsAgo))
        #expect(!DateFilter.pastYear.matches(date: twoYearsAgo))
    }

    @Test("Sort Order toggle")
    func testSortOptionToggle() {
        var order = SortOrder.descending
        #expect(order.iconName == "arrow.down")

        order.toggle()
        #expect(order == .ascending)
        #expect(order.iconName == "arrow.up")

        order.toggle()
        #expect(order == .descending)
    }

    @Test("Sorting items by various criteria")
    func testSortingItems() {
        let now = Date()
        let item1 = FileItem(
            url: URL(fileURLWithPath: "/tmp/a_doc.pdf"),
            name: "A_doc",
            fileSize: 1000,
            modificationDate: now.addingTimeInterval(-100),
            creationDate: now.addingTimeInterval(-200),
            category: .documents,
            origin: .chrome,
            originURL: nil
        )

        let item2 = FileItem(
            url: URL(fileURLWithPath: "/tmp/z_doc.pdf"),
            name: "Z_doc",
            fileSize: 5000,
            modificationDate: now,
            creationDate: now,
            category: .documents,
            origin: .slack,
            originURL: nil
        )

        let files = [item1, item2]

        // Sort by name ascending
        let sortedByNameAsc = files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        #expect(sortedByNameAsc.first?.name == "A_doc")

        // Sort by name descending
        let sortedByNameDesc = files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        #expect(sortedByNameDesc.first?.name == "Z_doc")

        // Sort by size ascending
        let sortedBySizeAsc = files.sorted { $0.fileSize < $1.fileSize }
        #expect(sortedBySizeAsc.first?.fileSize == 1000)

        // Sort by date modified descending
        let sortedByModDesc = files.sorted { $0.modificationDate > $1.modificationDate }
        #expect(sortedByModDesc.first?.name == "Z_doc")
    }

    @Test("ScannerViewModel filter reset")
    @MainActor
    func testScannerViewModelResetFilters() {
        let vm = ScannerViewModel()
        vm.selectedCategoryFilter = .documents
        vm.selectedOriginFilter = .slack
        vm.selectedSizeFilter = .large
        vm.selectedDateFilter = .pastWeek
        vm.searchQuery = "test"

        #expect(vm.hasActiveFilters)
        #expect(vm.activeFilterCount == 4)

        vm.resetFilters()

        #expect(vm.selectedCategoryFilter == nil)
        #expect(vm.selectedOriginFilter == nil)
        #expect(vm.selectedSizeFilter == .all)
        #expect(vm.selectedDateFilter == .all)
        #expect(vm.searchQuery == "")
        #expect(!vm.hasActiveFilters)
        #expect(vm.activeFilterCount == 0)
    }
}
