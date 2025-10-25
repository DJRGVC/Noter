import SwiftUI
import SwiftData
import UIKit

struct ClassEditorView: View {
    enum Mode: Equatable {
        case new
        case edit(StudyClass)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let mode: Mode
    @State private var title: String
    @State private var courseCode: String
    @State private var instructor: String
    @State private var details: String
    @State private var colorHex: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new:
            _title = State(initialValue: "")
            _courseCode = State(initialValue: "")
            _instructor = State(initialValue: "")
            _details = State(initialValue: "")
            _colorHex = State(initialValue: StudyClass.defaultColorHex)
        case .edit(let studyClass):
            _title = State(initialValue: studyClass.title)
            _courseCode = State(initialValue: studyClass.courseCode)
            _instructor = State(initialValue: studyClass.instructor)
            _details = State(initialValue: studyClass.details)
            _colorHex = State(initialValue: studyClass.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class Details") {
                    TextField("Title", text: $title)
                        .textContentType(.organizationName)
                    TextField("Course Code", text: $courseCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Instructor", text: $instructor)
                        .textContentType(.name)
                }

                Section("Description") {
                    TextField("Overview", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Styling") {
                    ColorPicker("Accent Color", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { newValue in
                            colorHex = newValue.toHex() ?? StudyClass.defaultColorHex
                        }
                    ))
                }

                Section("Upcoming features") {
                    Text("Upload slide PDFs or lecture audio from here once integrations land.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.title)
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
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !courseCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        switch mode {
        case .new:
            let newClass = StudyClass(title: title, courseCode: courseCode, instructor: instructor, details: details, colorHex: colorHex)
            modelContext.insert(newClass)
        case .edit(let studyClass):
            studyClass.title = title
            studyClass.courseCode = courseCode
            studyClass.instructor = instructor
            studyClass.details = details
            studyClass.colorHex = colorHex
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save class: \(error)")
        }
    }
}

private extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = components[0]
        let g = components.count >= 3 ? components[1] : r
        let b = components.count >= 3 ? components[2] : r
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

private extension ClassEditorView.Mode {
    var title: String {
        switch self {
        case .new: "New Class"
        case .edit: "Edit Class"
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
    ClassEditorView(mode: .new)
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
}
