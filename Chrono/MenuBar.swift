import SwiftUI

/// To, co je vidět přímo v liště nahoře: běžící čas, nebo ikonka stopek.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.stopwatch.isActive {
            Image(systemName: model.stopwatch.state == .paused ? "pause.circle" : "stopwatch.fill")
            Text(model.stopwatch.elapsed.hoursMinutesSeconds)
        } else {
            Image(systemName: "stopwatch")
        }
    }
}

/// Rozbalovací menu s ovládáním stopek.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        switch model.stopwatch.state {
        case .idle:
            Button("Začít měřit") { model.stopwatch.start() }

        case .running:
            Text("Běží: \(model.stopwatch.elapsed.hoursMinutesSeconds)")
            Button("Pauza") { model.stopwatch.pause() }
            Button("Ukončit a uložit…") { finish() }

        case .paused:
            Text("Pauza: \(model.stopwatch.elapsed.hoursMinutesSeconds)")
            Button("Pokračovat") { model.stopwatch.resume() }
            Button("Ukončit a uložit…") { finish() }
        }

        Divider()
        Button("Otevřít Chrono") { openMainWindow() }
        Button("Ukončit aplikaci") { NSApplication.shared.terminate(nil) }
    }

    /// Ukončí měření a otevře hlavní okno, kde se doplní popis práce.
    private func finish() {
        if model.finish() {
            openMainWindow()
        }
    }

    /// Otevře hlavní okno a dostane ho dopředu (u menu-bar aplikace je to potřeba ručně).
    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
