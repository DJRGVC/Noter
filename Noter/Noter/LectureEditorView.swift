import SwiftUI
import SwiftData

struct LectureEditorView: View {
    enum Mode: Identifiable, Equatable {
        case new(StudyClass)
        case edit(Lecture)

        var id: UUID {
            switch self {
            case .new(let studyClass):
                return studyClass.id
            case .edit(let lecture):
                return lecture.id
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    @State private var title: String
    @State private var date: Date
    @State private var summary: String
    @State private var transcript: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new:
            _title = State(initialValue: "")
            _date = State(initialValue: .now)
            _summary = State(initialValue: "")
            _transcript = State(initialValue: "")
        case .edit(let lecture):
            _title = State(initialValue: lecture.title)
            _date = State(initialValue: lecture.date)
            _summary = State(initialValue: lecture.summary)
            _transcript = State(initialValue: lecture.transcript)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Summary") {
                    TextField("Key takeaways", text: $summary, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Transcript / Notes") {
                    TextEditor(text: $transcript)
                        .frame(minHeight: 120)
                    Text("Drop your generated transcript or paste notes here. We'll use this text when calling the AI summarization endpoints.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Integrations") {
                    Text("Audio upload and slide parsing will invoke your configured AI provider once connected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.navTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.actionTitle, action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        switch mode {
        case .new(let studyClass):
            let lecture = Lecture(title: title, date: date, summary: summary, transcript: transcript, parentClass: studyClass)
            studyClass.lectures.append(lecture)
        case .edit(let lecture):
            lecture.title = title
            lecture.date = date
            lecture.summary = summary
            lecture.transcript = transcript
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save lecture: \(error)")
        }
    }
}

private extension LectureEditorView.Mode {
    var navTitle: String {
        switch self {
        case .new: "New Lecture"
        case .edit: "Edit Lecture"
        }
    }

    var actionTitle: String {
        switch self {
        case .new: "Add"
        case .edit: "Save"
        }
    }
}

#Preview {
    let mockClass = StudyClass.mockData().first!
    return LectureEditorView(mode: .new(mockClass))
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
}
