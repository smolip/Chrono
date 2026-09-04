import SwiftUI

/// Zapnuté jen při renderu snapshotu – `ImageRenderer` neumí vykreslit `ScrollView`,
/// tak řádky v tom režimu poskládáme napřímo.
private struct SnapshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshot: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}

/// Seznam odpracovaných záznamů + souhrnné statistiky.
struct SessionListView: View {
    let sessions: [WorkSession]
    let onDelete: (WorkSession) -> Void

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statRow

            HStack {
                Text("Historie")
                    .font(.headline)
                Spacer()
                if !sessions.isEmpty {
                    Text("\(sessions.count) \(sessions.count == 1 ? "záznam" : sessions.count < 5 ? "záznamy" : "záznamů")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if sessions.isEmpty {
                ContentUnavailableView(
                    "Zatím žádné záznamy",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Spusť stopky a po ukončení se sem zapíše záznam.")
                )
                .frame(maxHeight: .infinity)
            } else if isSnapshot {
                rows
            } else {
                ScrollView { rows }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(sessions) { session in
                SessionRow(session: session, onDelete: onDelete)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Statistiky

    private var statRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Dnes", value: total(in: todaySessions))
            StatTile(label: "Tento týden", value: total(in: weekSessions))
            StatTile(label: "Celkem", value: total(in: sessions))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var todaySessions: [WorkSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    private var weekSessions: [WorkSession] {
        sessions.filter {
            Calendar.current.isDate($0.startDate, equalTo: .now, toGranularity: .weekOfYear)
        }
    }

    private func total(in list: [WorkSession]) -> String {
        let hours = list.reduce(0) { $0 + $1.duration.hours }
        return "\(hours.formatted(.number.precision(.fractionLength(1)))) h"
    }
}

/// Dlaždice s jedním souhrnným číslem.
private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Jeden řádek historie jako karta s hoverem a mazáním.
private struct SessionRow: View {
    let session: WorkSession
    let onDelete: (WorkSession) -> Void
    @State private var hovering = false

    private var timeRange: String {
        let start = session.startDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            Text(session.note.isEmpty ? "—" : session.note)
                .font(.subheadline)
                .foregroundStyle(session.note.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(session.duration.hoursMinutesSeconds)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.5), in: Capsule())

            Button {
                onDelete(session)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0)
            .help("Smazat záznam")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(hovering ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
