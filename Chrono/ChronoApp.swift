import SwiftUI
import SwiftData

@main
struct ChronoApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        if let path = Snapshotter.requestedPath {
            Snapshotter.render(to: path)
            exit(0)
        }
        #endif
    }

    var body: some Scene {
        Window("Chrono", id: "main") {
            ContentView()
                .environment(model)
        }
        .modelContainer(for: WorkSession.self)
        .defaultSize(width: 480, height: 620)

        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel()
                .environment(model)
        }
    }
}
