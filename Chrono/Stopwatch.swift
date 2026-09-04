import Foundation
import Observation

/// Řídí měření času. Umí start, pauzu/pokračování a stop.
/// Uběhlý čas se počítá z reálných časů, takže je přesný i po delší době běhu.
@Observable
final class Stopwatch {
    enum State {
        case idle       // neběží, nic se neměří
        case running    // právě běží
        case paused     // pozastaveno
    }

    private(set) var state: State = .idle

    /// Kdy měření reálně začalo (první stisk Start). Slouží jako začátek záznamu.
    private(set) var startDate: Date?

    /// Součet už "zafixovaného" času z předchozích běhů před aktuální pauzou.
    private var accumulated: TimeInterval = 0

    /// Kdy naposledy začal běžet aktuální úsek (po startu nebo po resume).
    private var runningSince: Date?

    /// Aktualizuje se každou sekundu, aby se překresloval displej.
    private var tick: Date = .now

    private var timer: Timer?

    /// Celkový uběhlý čas.
    var elapsed: TimeInterval {
        var total = accumulated
        if let runningSince {
            total += tick.timeIntervalSince(runningSince)
        }
        return total
    }

    var isActive: Bool {
        state != .idle
    }

    func start() {
        guard state == .idle else { return }
        startDate = .now
        accumulated = 0
        runningSince = .now
        state = .running
        startTimer()
    }

    func pause() {
        guard state == .running, let runningSince else { return }
        accumulated += Date.now.timeIntervalSince(runningSince)
        self.runningSince = nil
        state = .paused
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        runningSince = .now
        state = .running
        startTimer()
    }

    /// Ukončí měření a vrátí (začátek, konec) záznamu. Vynuluje stopky.
    func finish() -> (start: Date, end: Date)? {
        guard let startDate else { return nil }
        let end = Date.now
        stopTimer()
        state = .idle
        self.startDate = nil
        accumulated = 0
        runningSince = nil
        return (startDate, end)
    }

    #if DEBUG
    /// Jen pro snapshoty: zafixuje běžící stav s daným uběhlým časem (bez tikání).
    func debugSeedRunning(elapsed: TimeInterval) {
        startDate = Date().addingTimeInterval(-elapsed)
        accumulated = elapsed
        runningSince = nil
        state = .running
    }
    #endif

    private func startTimer() {
        stopTimer()
        tick = .now
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick = .now
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
