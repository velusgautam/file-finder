import SwiftUI
import FileFinderLib

@main
struct FileFinderApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .preferredColorScheme(nil) // Automatically follows system Light/Dark appearance
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
