import SwiftUI

/// Tabulka odpracovaných záznamů + souhrn.
struct SessionListView: View {
    let sessions: [WorkSession]
    let onDelete: (WorkSession) -> Void

    private var totalHours: Double {
        sessions.reduce(0) { $0 + $1.duration.hours }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if sessions.isEmpty {
                ContentUnavailableView(
                    "Zatím žádné záznamy",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Spusť stopky a po ukončení se sem zapíše záznam.")
                )
                .frame(maxHeight: .infinity)
            } else {
                Table(sessions) {
                    TableColumn("Datum") { session in
                        Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Čas") { session in
                        Text("\(session.startDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 130)

                    TableColumn("Délka") { session in
                        Text(session.duration.hoursMinutesSeconds)
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 90)

                    TableColumn("Co jsem dělal") { session in
                        Text(session.note.isEmpty ? "—" : session.note)
                            .foregroundStyle(session.note.isEmpty ? .secondary : .primary)
                    }

                    TableColumn("") { session in
                        Button(role: .destructive) {
                            onDelete(session)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(30)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Historie")
                .font(.headline)
            Spacer()
            Text("Celkem: \(totalHours, format: .number.precision(.fractionLength(1))) h")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
