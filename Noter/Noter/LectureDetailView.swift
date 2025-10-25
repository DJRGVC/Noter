import SwiftUI
import SwiftData
import Observation

struct LectureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var newNote: String = ""
    @Bindable var lecture: Lecture

    var body: some View {
        List {
            Section("Summary") {
                Text(lecture.summary.isEmpty ? "No summary yet. Paste or generate one using the AI button below." : lecture.summary)
                    .foregroundStyle(.secondary)
            }

            Section("Transcript") {
                Text(lecture.transcript.isEmpty ? "Transcript placeholder. Attach audio to auto-transcribe." : lecture.transcript)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                ForEach(lecture.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.content)
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(note)
                        }
                    }
                }
                .onDelete(perform: deleteNotes)

                VStack(spacing: 8) {
                    TextField("Add a note", text: $newNote)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Note", action: addNote)
                        .buttonStyle(.borderedProminent)
                        .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lecture.title)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    Task { await analyzeWithAI() }
                } label: {
                    Label("Analyze with AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = LectureNote(content: trimmed, lecture: lecture)
        lecture.notes.append(note)
        saveContext()
        newNote = ""
    }

    private func delete(_ note: LectureNote) {
        modelContext.delete(note)
        saveContext()
    }

    private func deleteNotes(at offsets: IndexSet) {
        let sorted = lecture.notes.sorted(by: { $0.createdAt > $1.createdAt })
        for index in offsets {
            let note = sorted[index]
            delete(note)
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to persist lecture notes: \(error)")
        }
    }

    private func analyzeWithAI() async {
        // Replace this placeholder with your AI pipeline.
        // Example: await AIService.shared.analyze(lecture: lecture) to generate insights.
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

#Preview {
    let container = try! ModelContainer(for: StudyClass.self, Lecture.self, LectureNote.self, configurations: [.init(isStoredInMemoryOnly: true)])
    let context = container.mainContext
    let sampleClass = StudyClass.mockData(context: context).first!
    let lecture = sampleClass.lectures.first!
    return NavigationStack {
        LectureDetailView(lecture: lecture)
    }
    .modelContainer(container)
}
