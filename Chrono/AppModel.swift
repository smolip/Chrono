import Foundation
import Observation

/// Sdílený stav aplikace – žije po celou dobu běhu, takže okno i menu bar
/// pracují se stejnými stopkami a stejným promptem na popis práce.
@Observable
final class AppModel {
    let stopwatch = Stopwatch()

    /// Nevyřízený záznam čekající na popis (po stisku „Ukončit a uložit“).
    var pendingSession: (start: Date, end: Date)?
    var noteText: String = ""

    /// Ukončí měření a připraví prompt na popis. Vrací true, když je co uložit.
    @discardableResult
    func finish() -> Bool {
        guard let result = stopwatch.finish() else { return false }
        noteText = ""
        pendingSession = result
        return true
    }
}
