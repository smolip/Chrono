import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var model
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    private var stopwatch: Stopwatch { model.stopwatch }

    var body: some View {
        VStack(spacing: 0) {
            timerPanel
            SessionListView(sessions: sessions, onDelete: delete)
        }
        .frame(minWidth: 460, minHeight: 580)
        .background(.background)
        .sheet(item: pendingBinding) { pending in
            noteSheet(for: pending)
        }
    }

    // MARK: - Horní panel se stopkami

    private var timerPanel: some View {
        VStack(spacing: 22) {
            StatusBadge(state: stopwatch.state)

            Text(stopwatch.elapsed.hoursMinutesSeconds)
                .font(.system(size: 66, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerColor)
                .contentTransition(.numericText())

            controls
                .controlSize(.large)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(heroBackground)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    private var heroBackground: some View {
        LinearGradient(
            colors: [accentColor.opacity(0.16), accentColor.opacity(0.015)],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.4), value: stopwatch.state)
    }

    private var accentColor: Color {
        switch stopwatch.state {
        case .running: .green
        case .paused: .orange
        case .idle: .gray
        }
    }

    private var timerColor: Color {
        switch stopwatch.state {
        case .running: .primary
        case .paused: .orange
        case .idle: .secondary
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            switch stopwatch.state {
            case .idle:
                Button {
                    stopwatch.start()
                } label: {
                    Label("Začít", systemImage: "play.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

            case .running:
                Button {
                    stopwatch.pause()
                } label: {
                    Label("Pauza", systemImage: "pause.fill")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                finishButton

            case .paused:
                Button {
                    stopwatch.resume()
                } label: {
                    Label("Pokračovat", systemImage: "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                finishButton
            }
        }
    }

    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Label("Ukončit", systemImage: "stop.fill")
                .frame(minWidth: 100)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    // MARK: - Prompt na popis práce

    private func noteSheet(for pending: PendingSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Co jsi dělal?")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                Label(pending.value.start.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                Spacer()
                Label(pending.value.end.timeIntervalSince(pending.value.start).hoursMinutesSeconds,
                      systemImage: "clock")
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            TextEditor(text: noteBinding)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 130)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            HStack {
                Spacer()
                Button("Zahodit", role: .cancel) {
                    model.pendingSession = nil
                    model.noteText = ""
                }
                Button("Uložit") {
                    save(pending.value)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Akce

    private func finish() {
        model.finish()
    }

    private func save(_ result: (start: Date, end: Date)) {
        let session = WorkSession(startDate: result.start, endDate: result.end, note: model.noteText)
        context.insert(session)
        model.pendingSession = nil
        model.noteText = ""
    }

    private func delete(_ session: WorkSession) {
        context.delete(session)
    }

    // MARK: - Bindingy

    private var noteBinding: Binding<String> {
        Binding(get: { model.noteText }, set: { model.noteText = $0 })
    }

    private var pendingBinding: Binding<PendingSession?> {
        Binding(
            get: { model.pendingSession.map(PendingSession.init) },
            set: { if $0 == nil { model.pendingSession = nil } }
        )
    }
}

/// Stavová tečka s popiskem – při běhu „pulzuje".
private struct StatusBadge: View {
    let state: Stopwatch.State
    @State private var pulse = false

    private var color: Color {
        switch state {
        case .running: .green
        case .paused: .orange
        case .idle: .gray
        }
    }

    private var text: String {
        switch state {
        case .running: "Běží"
        case .paused: "Pozastaveno"
        case .idle: "Připraveno"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulse ? 1.5 : 0.7)
                    .opacity(pulse ? 0 : 0.7)
                    .animation(
                        state == .running
                            ? .easeOut(duration: 1.3).repeatForever(autoreverses: false)
                            : .default,
                        value: pulse
                    )
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(color)
        }
        .onAppear { pulse = (state == .running) }
        .onChange(of: state) { _, newState in
            pulse = (newState == .running)
        }
    }
}

/// Obal, aby šla dvojice (start, end) použít v `.sheet(item:)`.
struct PendingSession: Identifiable {
    let id = UUID()
    let value: (start: Date, end: Date)
}

#Preview {
    ContentView()
        .environment(AppModel())
        .modelContainer(for: WorkSession.self, inMemory: true)
}
