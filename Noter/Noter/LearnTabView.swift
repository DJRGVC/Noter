import SwiftUI
import SwiftData

struct LearnTabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case flashcards = "Flashcards"
        case mcq = "MCQ Practice"
        case summaries = "Summaries"

        var id: String { rawValue }
    }

    @Query(sort: \StudyClass.title) private var classes: [StudyClass]
    @State private var mode: Mode = .flashcards
    @State private var selectedClass: StudyClass?
    @State private var selectedLecture: Lecture?
    @State private var isRegenerating = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Learning Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top)

                filterControls

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(modeHeadline)
                            .font(.title2.bold())
                        Text(currentContent)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))

                        Button(action: regenerate) {
                            Label(isRegenerating ? "Generating…" : "Regenerate", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRegenerating)
                        .task(id: isRegenerating) {
                            guard isRegenerating else { return }
                            // Replace with your async AI regeneration pipeline.
                            // Example: await StudyAI.shared.generate(contentFor: selectedLecture)
                            try? await Task.sleep(nanoseconds: 700_000_000)
                            isRegenerating = false
                        }
                        Text("Connect your AI provider in Settings. We'll send the lecture transcript + notes to generate these study aids.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                }
            }
            .padding(.horizontal)
            .background(LinearGradient(colors: [.purple.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("Learn")
        }
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if classes.isEmpty {
                Text("Add a class to begin generating personalized study material.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(classes) { studyClass in
                        Button(studyClass.title) {
                            selectedClass = studyClass
                            selectedLecture = studyClass.sortedLectures.first
                        }
                    }
                } label: {
                    Label(selectedClass?.title ?? "Choose Class", systemImage: "books.vertical")
                }

                if let selectedClass, !selectedClass.lectures.isEmpty {
                    Menu {
                        ForEach(selectedClass.sortedLectures) { lecture in
                            Button(lecture.title) {
                                selectedLecture = lecture
                            }
                        }
                    } label: {
                        Label(selectedLecture?.title ?? "Latest Lecture", systemImage: "list.bullet")
                    }
                }
            }
        }
    }

    private var selectedLectureOrFallback: Lecture? {
        if let selectedLecture {
            return selectedLecture
        }
        if let selectedClass = selectedClass ?? classes.first {
            return selectedClass.sortedLectures.first
        }
        return nil
    }

    private var modeHeadline: String {
        switch mode {
        case .flashcards: return "Flashcards"
        case .mcq: return "Practice Questions"
        case .summaries: return "Smart Summary"
        }
    }

    private var currentContent: String {
        guard let lecture = selectedLectureOrFallback else {
            return "Add a lecture to generate study prompts."
        }
        switch mode {
        case .flashcards:
            return "1. What concept anchors \(lecture.title)?\n2. How does it connect to prior material?\n3. List two examples from the lecture."
        case .mcq:
            return "Sample MCQs for \(lecture.title) will appear here. Provide your AI endpoint with lecture.transcript + notes."
        case .summaries:
            return "Summary for \(lecture.title): \(lecture.summary.isEmpty ? "Awaiting AI generation." : lecture.summary)"
        }
    }

    private func regenerate() {
        guard !isRegenerating else { return }
        isRegenerating = true
    }
}

#Preview {
    LearnTabView()
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
        .taskPreview {
            let context = $0.modelContext
            if (try? context.fetch(FetchDescriptor<StudyClass>()))?.isEmpty ?? true {
                StudyClass.mockData(context: context)
            }
        }
}
