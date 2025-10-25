import SwiftUI
import SwiftData

struct ClassDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingLectureCreator = false
    @State private var quickNote = ""
    @FocusState private var isComposerFocused: Bool

    let studyClass: StudyClass

    var body: some View {
        List {
            Section {
                Text(studyClass.details.isEmpty ? "Describe this class to help AI generate relevant study aids." : studyClass.details)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if !studyClass.instructor.isEmpty {
                    Label(studyClass.instructor, systemImage: "person.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(.ultraThinMaterial)

            Section("Lecture Timeline") {
                if studyClass.sortedLectures.isEmpty {
                    ContentUnavailableView("No lectures yet", systemImage: "rectangle.stack", description: Text("Use the toolbar to record or import a lecture. Audio dropped here will be transcribed and summarized automatically."))
                } else {
                    ForEach(studyClass.sortedLectures) { lecture in
                        NavigationLink(destination: LectureDetailView(lecture: lecture)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(lecture.title)
                                    .font(.headline)
                                Text(lecture.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(lecture.summary.isEmpty ? "Summary will appear after AI processing." : lecture.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteLecture)
                }
            }
            .listRowBackground(.thinMaterial)

            Section("Quick note") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Capture a quick thought…", text: $quickNote, axis: .vertical)
                        .focused($isComposerFocused)
                        .lineLimit(2...4)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        saveQuickNote()
                    } label: {
                        Label("Save to latest lecture", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .tint(.accentColor)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(.thinMaterial)
        }
        .navigationTitle(studyClass.title)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingLectureCreator = true
                } label: {
                    Label("New Lecture", systemImage: "plus")
                }

                Button {
                    // Future: trigger document picker / audio importer feeding AI transcription pipeline.
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $isPresentingLectureCreator) {
            NavigationStack {
                LectureFormView(studyClass: studyClass)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func deleteLecture(at offsets: IndexSet) {
        for offset in offsets {
            let lecture = studyClass.sortedLectures[offset]
            if let index = studyClass.lectures.firstIndex(where: { $0.persistentModelID == lecture.persistentModelID }) {
                studyClass.lectures.remove(at: index)
            }
            modelContext.delete(lecture)
        }
        try? modelContext.save()
    }

    private func saveQuickNote() {
        let trimmed = quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let recentLecture = studyClass.sortedLectures.first {
            recentLecture.appendNote(trimmed)
        } else {
            let quickLecture = Lecture(title: "Quick Note", summary: trimmed)
            studyClass.addLecture(quickLecture, context: modelContext)
        }

        try? modelContext.save()
        quickNote = ""
        isComposerFocused = false
    }
}

#Preview {
    NavigationStack {
        ClassDetailView(studyClass: StudyClass.mockClasses().first!)
    }
    .modelContainer(PreviewContainer.container)
}
