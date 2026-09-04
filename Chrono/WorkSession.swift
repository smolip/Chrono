import Foundation
import SwiftData

/// Jeden odpracovaný záznam – kdy začal, kdy skončil a co se dělalo.
@Model
final class WorkSession {
    var startDate: Date
    var endDate: Date
    var note: String

    init(startDate: Date, endDate: Date, note: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
    }

    /// Délka práce v sekundách.
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

extension TimeInterval {
    /// Formát "1:23:45" (h:mm:ss).
    var hoursMinutesSeconds: String {
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// Délka v hodinách jako desetinné číslo, např. 1.5.
    var hours: Double {
        self / 3600
    }
}
