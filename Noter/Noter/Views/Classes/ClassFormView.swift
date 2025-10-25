import SwiftUI

struct ClassFormView: View {
    enum Mode {
        case create
        case edit(StudyClass)

        var title: String {
            switch self {
            case .create: "New Class"
            case .edit: "Edit Class"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var instructor: String
    @State private var details: String

    let mode: Mode
    let onSave: (StudyClass) -> Void

    init(mode: Mode, onSave: @escaping (StudyClass) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _instructor = State(initialValue: "")
            _details = State(initialValue: "")
        case .edit(let studyClass):
            _title = State(initialValue: studyClass.title)
            _instructor = State(initialValue: studyClass.instructor)
            _details = State(initialValue: studyClass.details)
        }
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $title)
                TextField("Instructor", text: $instructor)
                TextField("Description", text: $details, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Capture Options") {
                Label("Drop lecture audio here to auto-generate notes", systemImage: "waveform")
                    .foregroundStyle(.secondary)
                Label("Attach slide PDFs or supplementary material via the lecture toolbar.", systemImage: "doc.richtext")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .create:
            let newClass = StudyClass(title: trimmedTitle, instructor: instructor, details: details)
            onSave(newClass)
        case .edit(let studyClass):
            studyClass.title = trimmedTitle
            studyClass.instructor = instructor
            studyClass.details = details
            onSave(studyClass)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ClassFormView(mode: .create) { _ in }
    }
}
