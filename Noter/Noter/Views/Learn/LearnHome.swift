import SwiftUI
import SwiftData

struct LearnHome: View {
    enum Mode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case mcq = "MCQ Practice"
        case summary = "Summaries"

        var id: String { rawValue }
    }

    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]

    let activeProfile: UserProfile

    @State private var mode: Mode = .flashcards
    @State private var selectedClassID: PersistentIdentifier?
    @State private var selectedLectureID: PersistentIdentifier?
    @State private var isRegenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Hello, \(activeProfile.name.isEmpty ? "Student" : activeProfile.name) 👋")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Study Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    classPicker
                    lecturePicker

                    Group {
                        switch mode {
                        case .flashcards:
                            flashcardStack
                        case .mcq:
                            mcqList
                        case .summary:
                            summaryView
                        }
                    }
                    .transition(.opacity)
                }
                .padding()
            }
            .navigationTitle("Learn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Regenerate", action: regenerate)
                        .disabled(isRegenerating)
                }
            }
            .background(LinearGradient(colors: [.clear, .blue.opacity(0.12)], startPoint: .top, endPoint: .bottom))
        }
        .onAppear(perform: bootstrapSelection)
        .onChange(of: classes) {
            bootstrapSelection()
        }
    }

    private var selectedClass: StudyClass? {
        classes.first { $0.persistentModelID == selectedClassID }
    }

    private var selectedLecture: Lecture? {
        selectedClass?.lectures.first { $0.persistentModelID == selectedLectureID }
    }

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Class")
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(classes) { studyClass in
                    Button(studyClass.title) {
                        selectedClassID = studyClass.persistentModelID
                        selectedLectureID = studyClass.sortedLectures.first?.persistentModelID
                    }
                }
            } label: {
                LabeledContent("Selected", value: selectedClass?.title ?? "None")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var lecturePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lecture")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let studyClass = selectedClass, !studyClass.sortedLectures.isEmpty {
                Menu {
                    ForEach(studyClass.sortedLectures) { lecture in
                        Button(lecture.title) {
                            selectedLectureID = lecture.persistentModelID
                        }
                    }
                } label: {
                    LabeledContent("Selected", value: selectedLecture?.title ?? "All Lectures")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Text("Add a lecture to unlock AI generated study material.")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("AI powered content tailors itself to the chosen lecture. Connect your API key in Settings to enable live generation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var flashcardStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flashcards")
                .font(.title2.bold())
            ForEach(Array(sampleFlashcards().enumerated()), id: \.offset) { _, card in
                VStack(alignment: .leading, spacing: 10) {
                    Text(card.prompt)
                        .font(.headline)
                    Text(card.answer)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var mcqList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiple Choice Practice")
                .font(.title2.bold())
            ForEach(sampleMCQs()) { question in
                VStack(alignment: .leading, spacing: 12) {
                    Text(question.prompt)
                        .font(.headline)
                    ForEach(question.options, id: \.self) { option in
                        HStack {
                            Image(systemName: option == question.answer ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(option == question.answer ? .green : .secondary)
                            Text(option)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.title2.bold())
            Text(sampleSummary())
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func regenerate() {
        guard !isRegenerating else { return }
        isRegenerating = true
        Task {
            // Connect to the same AI provider configured in Settings. Stream regenerated study aids here.
            try? await Task.sleep(for: .seconds(1.2))
            isRegenerating = false
        }
    }

    private func bootstrapSelection() {
        guard let firstClass = classes.first else { return }
        if selectedClassID == nil { selectedClassID = firstClass.persistentModelID }
        if selectedLectureID == nil { selectedLectureID = firstClass.sortedLectures.first?.persistentModelID }
    }

    private func sampleFlashcards() -> [Flashcard] {
        guard let lecture = selectedLecture else {
            return [Flashcard(prompt: "No lecture selected", answer: "Choose a lecture to generate flashcards.")]
        }
        let generated = lecture.notes.map { note in
            Flashcard(prompt: note.content, answer: "Response synthesized from \(lecture.title) context.")
        }
        return generated.isEmpty ? [Flashcard(prompt: lecture.title, answer: "Highlights will appear after AI runs.")] : generated
    }

    private func sampleMCQs() -> [MCQQuestion] {
        guard let lecture = selectedLecture else {
            return [MCQQuestion(prompt: "Select a lecture to see sample questions", options: ["--"], answer: "--")]
        }
        let topic = lecture.summary.isEmpty ? "the primary concept" : lecture.summary
        return [
            MCQQuestion(prompt: "Which idea best describes \(topic)?", options: ["Concurrency", "Protocol Extensions", "Memory Management", "UI Design"], answer: "Protocol Extensions")
        ]
    }

    private func sampleSummary() -> String {
        guard let lecture = selectedLecture else {
            return "Choose a class and lecture to surface AI powered summaries."
        }
        if !lecture.summary.isEmpty { return lecture.summary }
        return "Summary pending. When AI generation is connected, this area will display concise takeaways and action steps for \(lecture.title)."
    }
}

private struct Flashcard: Hashable {
    var prompt: String
    var answer: String
}

private struct MCQQuestion: Identifiable, Hashable {
    var id: UUID = .init()
    var prompt: String
    var options: [String]
    var answer: String
}

#Preview {
    LearnHome(activeProfile: .mockProfile())
        .modelContainer(PreviewContainer.container)
}
