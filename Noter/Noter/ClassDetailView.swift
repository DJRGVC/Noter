import SwiftUI
import SwiftData
import Observation

struct ClassDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var quickNote: String = ""
    @State private var isPresentingLectureForm = false
    @State private var lectureToEdit: Lecture?
    @Bindable var studyClass: StudyClass

    var body: some View {
        List {
            if !studyClass.details.isEmpty {
                Section("Overview") {
                    Text(studyClass.details)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Lectures") {
                if studyClass.sortedLectures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No lectures yet")
                            .font(.headline)
                        Text("Add lectures from recordings or import slides to start generating notes automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(studyClass.sortedLectures) { lecture in
                        NavigationLink(destination: LectureDetailView(lecture: lecture)) {
                            LectureTimelineRow(lecture: lecture)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { lectureToEdit = lecture }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(lecture)
                            }
                        }
                    }
                    .onDelete(perform: deleteLectures)
                }
            }

            Section("Quick Note") {
                VStack(spacing: 12) {
                    TextField("Capture a thought…", text: $quickNote, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addQuickNote) {
                        Label("Save to latest lecture", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Audio uploads and AI summarization hooks will live here—feed transcripts to your preferred endpoint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .background(.regularMaterial)
        .navigationTitle(studyClass.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingLectureForm = true
                } label: {
                    Label("New Lecture", systemImage: "plus")
                }

                Menu {
                    Button("Import slides", systemImage: "doc.badge.plus") {
                        // Integrate document importer and AI parsing pipeline here.
                    }
                    Button("Record audio", systemImage: "waveform") {
                        // Hook microphone capture + transcription to produce lecture notes.
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isPresentingLectureForm) {
            LectureEditorView(mode: .new(studyClass))
        }
        .sheet(item: $lectureToEdit) { lecture in
            LectureEditorView(mode: .edit(lecture))
        }
    }

    private func addQuickNote() {
        let trimmed = quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = LectureNote(content: trimmed)

        if let latest = studyClass.sortedLectures.first {
            latest.notes.append(note)
            note.lecture = latest
        } else {
            let catchAllLecture = Lecture(title: "Quick Notes", summary: "Drop-in notes until a lecture exists", notes: [note], parentClass: studyClass)
            studyClass.lectures.append(catchAllLecture)
        }

        do {
            try modelContext.save()
            quickNote = ""
        } catch {
            assertionFailure("Failed to save note: \(error)")
        }
    }

    private func delete(_ lecture: Lecture) {
        withAnimation {
            modelContext.delete(lecture)
            saveContext()
        }
    }

    private func deleteLectures(at offsets: IndexSet) {
        for index in offsets {
            let lecture = studyClass.sortedLectures[index]
            delete(lecture)
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to persist lecture changes: \(error)")
        }
    }
}

private struct LectureTimelineRow: View {
    let lecture: Lecture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lecture.title)
                    .font(.headline)
                Spacer()
                Text(lecture.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(lecture.snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !lecture.notes.isEmpty {
                Label("\(lecture.notes.count) notes", systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! ModelContainer(for: StudyClass.self, Lecture.self, LectureNote.self, configurations: [.init(isStoredInMemoryOnly: true)])
    let sample = StudyClass.mockData(context: container.mainContext).first!
    return NavigationStack {
        ClassDetailView(studyClass: sample)
    }
    .modelContainer(container)
}
