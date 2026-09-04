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
            Divider()
            SessionListView(sessions: sessions, onDelete: delete)
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(item: pendingBinding) { pending in
            noteSheet(for: pending)
        }
    }

    // MARK: - Horní panel se stopkami

    private var timerPanel: some View {
        VStack(spacing: 16) {
            Text(stopwatch.elapsed.hoursMinutesSeconds)
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .foregroundStyle(stopwatch.state == .running ? .primary : .secondary)
                .contentTransition(.numericText())

            HStack(spacing: 12) {
                switch stopwatch.state {
                case .idle:
                    Button {
                        stopwatch.start()
                    } label: {
                        Label("Začít", systemImage: "play.fill")
                    }
                    .keyboardShortcut(.defaultAction)

                case .running:
                    Button {
                        stopwatch.pause()
                    } label: {
                        Label("Pauza", systemImage: "pause.fill")
                    }
                    finishButton

                case .paused:
                    Button {
                        stopwatch.resume()
                    } label: {
                        Label("Pokračovat", systemImage: "play.fill")
                    }
                    finishButton
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var finishButton: some View {
        Button(role: .destructive) {
            finish()
        } label: {
            Label("Ukončit a uložit", systemImage: "stop.fill")
        }
        .tint(.red)
    }

    // MARK: - Prompt na popis práce

    private func noteSheet(for pending: PendingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Co jsi dělal?")
                .font(.headline)

            HStack {
                Label(pending.value.start.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                Spacer()
                Label(pending.value.end.timeIntervalSince(pending.value.start).hoursMinutesSeconds,
                      systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            TextEditor(text: noteBinding)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

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
        .padding(20)
        .frame(width: 420)
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
