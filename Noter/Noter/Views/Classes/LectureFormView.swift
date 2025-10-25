import SwiftUI
import SwiftData

struct LectureFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var summary: String = ""
    @State private var audioURLString: String = ""
    @State private var slideURLString: String = ""

    let studyClass: StudyClass

    var body: some View {
        Form {
            Section("Lecture Info") {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Summary", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Media & Attachments") {
                TextField("Audio URL", text: $audioURLString)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                TextField("Slides URL", text: $slideURLString)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                Text("Drop recordings or PDFs here to kick off the AI transcription and annotation pipeline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New Lecture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let audioURL = URL(string: audioURLString)
        let slideURL = URL(string: slideURLString)
        let lecture = Lecture(title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: date, summary: summary, audioReference: audioURL, slideReference: slideURL)
        studyClass.addLecture(lecture, context: modelContext)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LectureFormView(studyClass: StudyClass.mockClasses().first!)
    }
    .modelContainer(PreviewContainer.container)
}
