import SwiftUI
import Charts

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

/// Zvolené časové období pro analýzu.
enum Timeframe: String, CaseIterable, Identifiable {
    case day = "Dnes"
    case week = "Týden"
    case month = "Měsíc"
    case year = "Rok"
    case all = "Vše"

    var id: String { rawValue }

    /// Po jakých jednotkách se kreslí graf v tomto období.
    var bucket: Calendar.Component {
        switch self {
        case .day: .hour
        case .week, .month: .day
        case .year, .all: .month
        }
    }

    /// Popisek osy X ve stat baru grafu (pro AxisMarks formát).
    var axisFormat: Date.FormatStyle {
        switch self {
        case .day: .dateTime.hour()
        case .week: .dateTime.weekday(.abbreviated)
        case .month: .dateTime.day()
        case .year, .all: .dateTime.month(.abbreviated)
        }
    }
}

/// Přehled odpracovaného času nad zvoleným obdobím + filtrovaná historie.
struct AnalysisView: View {
    let sessions: [WorkSession]
    let onDelete: (WorkSession) -> Void

    @Environment(\.isSnapshot) private var isSnapshot
    @State private var timeframe: Timeframe = .week

    // MARK: - Odvozená data

    /// Interval zvoleného období (od–do).
    private var interval: DateInterval {
        let cal = Calendar.current
        let now = Date.now
        switch timeframe {
        case .day:   return cal.dateInterval(of: .day, for: now)!
        case .week:  return cal.dateInterval(of: .weekOfYear, for: now)!
        case .month: return cal.dateInterval(of: .month, for: now)!
        case .year:  return cal.dateInterval(of: .year, for: now)!
        case .all:
            let start = sessions.map(\.startDate).min() ?? now
            return DateInterval(start: cal.startOfDay(for: start),
                                end: cal.dateInterval(of: .day, for: now)!.end)
        }
    }

    /// Seance, které v období začaly (řazené nejnovější první díky @Query).
    private var filtered: [WorkSession] {
        sessions.filter { interval.contains($0.startDate) }
    }

    private var totalSeconds: TimeInterval {
        filtered.reduce(0) { $0 + $1.duration }
    }

    private var activeDays: Int {
        let cal = Calendar.current
        return Set(filtered.map { cal.startOfDay(for: $0.startDate) }).count
    }

    private var longest: TimeInterval {
        filtered.map(\.duration).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if isSnapshot {
                    // `ImageRenderer` neumí vykreslit nativní segmented Picker,
                    // pro snapshot ho nahradíme statickou napodobeninou.
                    snapshotPicker
                } else {
                    Picker("Období", selection: $timeframe) {
                        ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            kpiRow

            if totalSeconds > 0 {
                chart
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }

            HStack {
                Text("Historie")
                    .font(.headline)
                Spacer()
                if !filtered.isEmpty {
                    Text(recordsLabel(filtered.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if filtered.isEmpty {
                ContentUnavailableView(
                    "Žádná práce v tomto období",
                    systemImage: "calendar.badge.clock",
                    description: Text("Zkus jiné období nebo spusť stopky.")
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

    // MARK: - KPI

    private var kpiRow: some View {
        HStack(spacing: 10) {
            KPITile(value: hoursText(totalSeconds), label: "Celkem", systemImage: "sum")
            KPITile(value: hoursText(activeDays > 0 ? totalSeconds / Double(activeDays) : 0),
                    label: "Průměr/den", systemImage: "chart.bar.fill")
            KPITile(value: "\(filtered.count)", label: countLabel, systemImage: "number")
            KPITile(value: longest.hoursMinutes, label: "Nejdelší", systemImage: "flame.fill")
        }
        .padding(.horizontal, 20)
    }

    private var countLabel: String {
        switch timeframe {
        case .day: "dnes"
        case .week: "za týden"
        case .month: "za měsíc"
        case .year: "za rok"
        case .all: "celkem"
        }
    }

    // MARK: - Graf

    private var chart: some View {
        Chart(buckets, id: \.date) { item in
            BarMark(
                x: .value("Období", item.date, unit: timeframe.bucket),
                y: .value("Hodiny", item.hours)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel(format: timeframe.axisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let h = value.as(Double.self) {
                        Text("\(Int(h))h")
                    }
                }
            }
        }
        .frame(height: 150)
    }

    /// Rozpočítá práci do bucketů (hodina/den/měsíc), přesah přes hranice se dělí.
    private var buckets: [(date: Date, hours: Double)] {
        let cal = Calendar.current
        let component = timeframe.bucket
        var map: [Date: Double] = [:]

        // Prázdné buckety přes celé období, ať graf nemá díry.
        var cursor = cal.dateInterval(of: component, for: interval.start)?.start ?? interval.start
        while cursor < interval.end {
            map[cursor] = 0
            cursor = cal.date(byAdding: component, value: 1, to: cursor) ?? interval.end
        }

        for session in filtered {
            let start = max(session.startDate, interval.start)
            let end = min(session.endDate, interval.end)
            guard start < end else { continue }
            var c = cal.dateInterval(of: component, for: start)?.start ?? start
            while c < end {
                let next = cal.date(byAdding: component, value: 1, to: c) ?? end
                let lo = max(start, c)
                let hi = min(end, next)
                if hi > lo { map[c, default: 0] += hi.timeIntervalSince(lo) }
                c = next
            }
        }

        return map.sorted { $0.key < $1.key }.map { ($0.key, $0.value / 3600) }
    }

    // MARK: - Seznam

    private var rows: some View {
        // V snapshotu omezíme počet, ať se do fixního rámu vejde bez ořezu.
        let shown = isSnapshot ? Array(filtered.prefix(4)) : filtered
        return VStack(spacing: 4) {
            ForEach(shown) { session in
                SessionRow(session: session, onDelete: onDelete)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    /// Statická napodobenina segmented ovladače pro snapshot.
    private var snapshotPicker: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases) { tf in
                Text(tf.rawValue)
                    .font(.callout)
                    .fontWeight(tf == timeframe ? .semibold : .regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if tf == timeframe {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.selection)
                        }
                    }
            }
        }
        .padding(2)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Formátování

    private func hoursText(_ seconds: TimeInterval) -> String {
        "\(seconds.hours.formatted(.number.precision(.fractionLength(1)))) h"
    }

    private func recordsLabel(_ n: Int) -> String {
        "\(n) \(n == 1 ? "záznam" : n >= 2 && n <= 4 ? "záznamy" : "záznamů")"
    }
}

/// Dlaždice s jedním souhrnným číslem.
private struct KPITile: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
