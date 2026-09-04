#if DEBUG
import SwiftUI
import SwiftData
import AppKit

/// Vyrenderuje hlavní UI do PNG pomocí `ImageRenderer` – bez potřeby
/// oprávnění „Nahrávání obrazovky". Spouští se argumentem `--snapshot <cesta>`.
enum Snapshotter {

    /// Vrátí cestu k PNG, pokud byl předán argument `--snapshot`.
    static var requestedPath: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var wantsRunning: Bool {
        CommandLine.arguments.contains("--running")
    }

    @MainActor
    static func render(to path: String) {
        let container = try! ModelContainer(
            for: WorkSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        seed(into: container.mainContext)

        let model = AppModel()
        if wantsRunning {
            model.stopwatch.debugSeedRunning(elapsed: 47 * 60 + 12) // 0:47:12
        }

        let view = ContentView()
            .environment(model)
            .modelContainer(container)
            .frame(width: 480, height: 620)
            .environment(\.colorScheme, .dark)
            .environment(\.isSnapshot, true)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: render failed\n".utf8))
            return
        }
        // Sandbox povolí zápis jen do vlastního kontejneru – když je cílová
        // cesta mimo, přesměrujeme do temp adresáře appky.
        var target = URL(fileURLWithPath: path)
        do {
            try png.write(to: target)
        } catch {
            target = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(target.lastPathComponent)
            try? png.write(to: target)
        }
        FileHandle.standardError.write(Data("snapshot-path: \(target.path)\n".utf8))
    }

    private static func seed(into ctx: ModelContext) {
        let cal = Calendar.current
        func date(_ daysAgo: Int, _ h: Int, _ m: Int) -> Date {
            let base = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
            return cal.date(bySettingHour: h, minute: m, second: 0, of: base)!
        }
        let samples: [(Date, Date, String)] = [
            (date(0, 9, 5), date(0, 10, 42), "Redesign UI – hero panel a karty"),
            (date(0, 13, 10), date(0, 14, 3), "Code review a oprava buildu"),
            (date(2, 20, 39), date(2, 21, 35), "Bakalářka research"),
            (date(4, 12, 25), date(4, 14, 3), "Wireframe → LiveView a Update"),
            (date(9, 11, 46), date(9, 16, 32), "Blacktorch: Frontend finišování"),
        ]
        for (start, end, note) in samples {
            ctx.insert(WorkSession(startDate: start, endDate: end, note: note))
        }
        try? ctx.save()
    }
}
#endif
