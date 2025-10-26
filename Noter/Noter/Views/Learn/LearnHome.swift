import SwiftUI
import SwiftData
import WebKit

struct LearnHome: View {
    enum Mode: String, CaseIterable, Identifiable {
        case notes = "Notes"
        case flashcards = "Flashcards"
        case mcq = "MCQ Practice"
        case animations = "Animations"

        var id: String { rawValue }
    }

    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]

    let activeProfile: UserProfile

    @State private var mode: Mode = .notes
    @State private var selectedClassID: PersistentIdentifier?
    @State private var selectedLectureID: PersistentIdentifier?
    @State private var isRegenerating = false

    // AI-generated content
    @State private var generatedFlashcards: [Flashcard] = []
    @State private var generatedQuizzes: [QuizQuestion] = []
    @State private var animationCode: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    // Animation-specific state
    @State private var animationTopic: String = ""
    @State private var renderedVideoURL: URL?
    @State private var aspectRatio: VideoAspectRatio = .standard
    @State private var renderingProgress: (animation: Int, percentage: Int)?
    @State private var isGeneratingCode = false
    @State private var isRenderingVideo = false
    @State private var showingImportNotes = false
    
    // Assistant state
    @State private var showingAssistant = false
    @State private var assistantMessages: [ChatMessage] = []
    @State private var currentQuestion = ""
    @State private var isAskingQuestion = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section with controls (fixed at top)
                VStack(alignment: .leading, spacing: 16) {
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
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Content section (fills remaining space)
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    Group {
                        switch mode {
                        case .notes:
                            notesView
                        case .flashcards:
                            flashcardStackScrollable
                        case .mcq:
                            mcqListScrollable
                        case .animations:
                            animationViewScrollable
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Learn")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingImportNotes = true
                    } label: {
                        Label("Import Notes", systemImage: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            showingAssistant = true
                        } label: {
                            Label("Assistant", systemImage: "message.circle.fill")
                        }
                        
                        Button("Regenerate", action: regenerate)
                            .disabled(isRegenerating)
                    }
                }
            }
            .sheet(isPresented: $showingImportNotes) {
                NotesLibraryView()
            }
            .sheet(isPresented: $showingAssistant) {
                AssistantView(
                    lecture: selectedLecture,
                    messages: $assistantMessages,
                    isGeneral: selectedLecture == nil
                )
            }
            .background(LinearGradient(colors: [.clear, .blue.opacity(0.12)], startPoint: .top, endPoint: .bottom))
        }
        .onAppear(perform: bootstrapSelection)
        .onChange(of: classes) { _ in 
            bootstrapSelection()
        }
        .onChange(of: selectedClassID) { _ in
            // When class changes, update lecture selection
            if let studyClass = selectedClass {
                selectedLectureID = studyClass.sortedLectures.first?.persistentModelID
            }
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
            
            if classes.isEmpty {
                Button {
                    showingImportNotes = true
                } label: {
                    Label("Import Notes to Get Started", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Menu {
                    ForEach(classes) { studyClass in
                        Button(studyClass.title) {
                            selectedClassID = studyClass.persistentModelID
                            selectedLectureID = studyClass.sortedLectures.first?.persistentModelID
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedClass?.title ?? "Select a class")
                            .foregroundStyle(selectedClass == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
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
                    HStack {
                        Text(selectedLecture?.title ?? "Select a lecture")
                            .foregroundStyle(selectedLecture == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Text(selectedClass == nil ? "Select a class first" : "No lectures in this class")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
    
    private var notesView: some View {
        Group {
            if let studyClass = selectedClass {
                if studyClass.lectures.isEmpty {
                    emptyStateView(
                        message: "No lectures yet",
                        instruction: "Import notes or add lectures to this class"
                    )
                } else if let lecture = selectedLecture {
                    // Full-screen note view for selected lecture
                    FullScreenNoteView(lecture: lecture)
                } else {
                    emptyStateView(
                        message: "Select a lecture",
                        instruction: "Choose a lecture to view its notes"
                    )
                }
            } else {
                emptyStateView(
                    message: "Select a class",
                    instruction: "Choose a class to view its notes"
                )
            }
        }
    }
    
    private var flashcardStackScrollable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                flashcardStack
            }
            .padding()
        }
    }

    private var flashcardStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flashcards")
                .font(.title2.bold())

            if generatedFlashcards.isEmpty {
                emptyStateView(
                    message: "No flashcards yet",
                    instruction: "Tap 'Regenerate' to generate AI-powered flashcards from your lecture notes"
                )
            } else {
                ForEach(generatedFlashcards) { card in
                    FlashcardView(flashcard: card)
                }
            }
        }
    }
    
    private var mcqListScrollable: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mcqList
            }
            .padding()
        }
    }

    private var mcqList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quiz Practice")
                .font(.title2.bold())

            if generatedQuizzes.isEmpty {
                emptyStateView(
                    message: "No quiz questions yet",
                    instruction: "Tap 'Regenerate' to generate AI-powered quiz questions from your lecture notes"
                )
            } else {
                ForEach(generatedQuizzes) { question in
                    QuizQuestionView(question: question)
                }
            }
        }
    }

    private func regenerate() {
        guard !isRegenerating, let lecture = selectedLecture else { return }
        isRegenerating = true
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .notes:
                    // Notes are managed directly, no regeneration needed
                    break
                case .flashcards:
                    generatedFlashcards = try await BackendService.shared.generateFlashcards(from: lecture)
                case .mcq:
                    generatedQuizzes = try await BackendService.shared.generateQuiz(from: lecture)
                case .animations:
                    animationCode = try await BackendService.shared.generateAnimation(
                        topic: lecture.title,
                        quizQuestions: generatedQuizzes.isEmpty ? [] : generatedQuizzes
                    )
                }
                isLoading = false
            } catch {
                errorMessage = "Failed to generate content: \(error.localizedDescription)"
                isLoading = false
            }
            isRegenerating = false
        }
    }

    private func bootstrapSelection() {
        guard let firstClass = classes.first else { 
            selectedClassID = nil
            selectedLectureID = nil
            return 
        }
        
        // Set class if not selected or if selected class no longer exists
        if selectedClassID == nil || !classes.contains(where: { $0.persistentModelID == selectedClassID }) {
            selectedClassID = firstClass.persistentModelID
        }
        
        // Set lecture if not selected or if selected lecture no longer exists in the current class
        if let studyClass = selectedClass {
            if selectedLectureID == nil || !studyClass.lectures.contains(where: { $0.persistentModelID == selectedLectureID }) {
                selectedLectureID = studyClass.sortedLectures.first?.persistentModelID
            }
        }
    }

    private func sampleFlashcards() -> [Flashcard] {
        guard let lecture = selectedLecture else {
            return []
        }
        let generated = lecture.notes.map { note in
            Flashcard(question: note.content, answer: "Response synthesized from \(lecture.title) context.", lecture: lecture)
        }
        return generated.isEmpty ? [Flashcard(question: lecture.title, answer: "Highlights will appear after AI runs.", lecture: lecture)] : generated
    }

    private func sampleMCQs() -> [QuizQuestion] {
        guard let lecture = selectedLecture else {
            return []
        }
        let topic = lecture.summary.isEmpty ? "the primary concept" : lecture.summary
        return [
            QuizQuestion(
                question: "Which idea best describes \(topic)?",
                type: .multipleChoice,
                options: ["Concurrency", "Protocol Extensions", "Memory Management", "UI Design"],
                correctAnswer: 1,
                explanation: "Protocol extensions are used to provide default implementations and compose behavior.",
                sampleAnswer: nil,
                lecture: lecture
            )
        ]
    }

    // MARK: - Helper Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating AI-powered content...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.headline)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                regenerate()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func emptyStateView(message: String, instruction: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
            Text(instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var animationViewScrollable: some View {
        ScrollView {
            VStack {
                animationView
            }
            .padding()
        }
    }

    private var animationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Animations")
                .font(.title2.bold())

            // Topic Input
            if animationCode.isEmpty && renderedVideoURL == nil {
                TopicInputView(
                    topic: $animationTopic,
                    onGenerate: generateAnimationCode,
                    isLoading: isGeneratingCode
                )
            }

            // Code Editor (if code exists)
            if !animationCode.isEmpty {
                CodeEditorView(code: $animationCode)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Aspect Ratio Picker & Render Button (if code exists but not rendering/rendered)
            if !animationCode.isEmpty && renderedVideoURL == nil && !isRenderingVideo {
                VStack(spacing: 12) {
                    AspectRatioPicker(selectedRatio: $aspectRatio)

                    Button(action: renderVideo) {
                        Label("Render Video", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Rendering Progress
            if isRenderingVideo, let progress = renderingProgress {
                RenderingProgressView(
                    currentAnimation: progress.animation,
                    percentage: progress.percentage
                )
            }

            // Video Player (when rendered)
            if let videoURL = renderedVideoURL {
                VStack(spacing: 12) {
                    VideoPlayerView(videoURL: videoURL)

                    HStack(spacing: 12) {
                        Button(action: resetAnimation) {
                            Label("New Animation", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: renderVideo) {
                            Label("Re-render", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func generateAnimationCode() {
        guard !animationTopic.isEmpty else { return }
        isGeneratingCode = true
        errorMessage = nil

        Task {
            do {
                animationCode = try await VideoRenderingService.shared.generateManimCode(prompt: animationTopic)
                isGeneratingCode = false
            } catch {
                errorMessage = "Failed to generate code: \(error.localizedDescription)"
                isGeneratingCode = false
            }
        }
    }

    private func renderVideo() {
        guard !animationCode.isEmpty else { return }
        isRenderingVideo = true
        renderedVideoURL = nil
        renderingProgress = nil
        errorMessage = nil

        Task {
            do {
                for try await progress in VideoRenderingService.shared.streamRenderingProgress(
                    code: animationCode,
                    className: "GenScene",
                    aspectRatio: aspectRatio
                ) {
                    switch progress {
                    case .progress(let animation, let percentage):
                        renderingProgress = (animation, percentage)
                    case .completed(let videoURL):
                        renderedVideoURL = videoURL
                        renderingProgress = nil
                        isRenderingVideo = false
                    }
                }
            } catch {
                errorMessage = "Failed to render video: \(error.localizedDescription)"
                renderingProgress = nil
                isRenderingVideo = false
            }
        }
    }

    private func resetAnimation() {
        animationCode = ""
        renderedVideoURL = nil
        animationTopic = ""
        renderingProgress = nil
        isRenderingVideo = false
        isGeneratingCode = false
    }

    private func copyAnimationCode() {
        #if os(iOS)
        UIPasteboard.general.string = animationCode
        #endif
    }
}

// MARK: - Component Views

private struct FlashcardView: View {
    let flashcard: Flashcard
    @State private var isFlipped: Bool = false
    
    private var frontColor: Color {
        Color.blue.opacity(0.15)
    }
    
    private var backColor: Color {
        Color.purple.opacity(0.15)
    }

    var body: some View {
        ZStack {
            // Front side (Question)
            if !isFlipped {
                CardFace(
                    title: "Question",
                    content: flashcard.question,
                    backgroundColor: frontColor,
                    accentColor: .blue
                )
                .transition(.flipTransition)
            }
            
            // Back side (Answer)
            if isFlipped {
                CardFace(
                    title: "Answer",
                    content: flashcard.answer,
                    backgroundColor: backColor,
                    accentColor: .purple
                )
                .transition(.flipTransition)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .onTapGesture {
            flipCard()
        }
        .overlay(alignment: .bottom) {
            // Flip hint
            HStack(spacing: 4) {
                Image(systemName: "hand.tap.fill")
                    .font(.caption2)
                Text("Tap to flip")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 8)
            .opacity(0.6)
        }
    }
    
    private func flipCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isFlipped.toggle()
        }
    }
}

// Custom flip transition
extension AnyTransition {
    static var flipTransition: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .modifier(
                active: FlipModifier(angle: -180, opacity: 0),
                identity: FlipModifier(angle: 0, opacity: 1)
            ),
            removal: .modifier(
                active: FlipModifier(angle: 180, opacity: 0),
                identity: FlipModifier(angle: 0, opacity: 1)
            )
        )
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .opacity(opacity)
    }
}

private struct CardFace: View {
    let title: String
    let content: String
    let backgroundColor: Color
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with colored accent
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(accentColor)
                    .textCase(.uppercase)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
            }
            
            Divider()
                .background(accentColor.opacity(0.3))
            
            // Content
            ScrollView {
                Text(content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxHeight: 140)
            
            Spacer()
            
            // Bottom indicator
            HStack {
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(accentColor.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: accentColor.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

private struct QuizQuestionView: View {
    let question: QuizQuestion
    @State private var isSubmitted: Bool = false
    @State private var selectedAnswer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question)
                .font(.headline)

            if question.type == .multipleChoice {
                multipleChoiceOptions
            } else {
                freeResponseInput
            }

            if isSubmitted {
                resultView
            } else {
                Button("Submit") {
                    isSubmitted = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAnswer == nil || selectedAnswer?.isEmpty == true)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var multipleChoiceOptions: some View {
        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
            Button(action: {
                if !isSubmitted {
                    selectedAnswer = String(index)
                }
            }) {
                HStack {
                    Image(systemName: getOptionIcon(for: index))
                        .foregroundStyle(getOptionColor(for: index))
                    Text(option)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding()
                .background(
                    selectedAnswer == String(index) ? Color.blue.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            .disabled(isSubmitted)
        }
    }

    @ViewBuilder
    private var freeResponseInput: some View {
        TextField("Type your answer here...", text: Binding(
            get: { selectedAnswer ?? "" },
            set: { selectedAnswer = $0 }
        ), axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
        .disabled(isSubmitted)
    }

    @ViewBuilder
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if question.type == .multipleChoice {
                if let correctAnswer = question.correctAnswer,
                   selectedAnswer == String(correctAnswer) {
                    Label("Correct!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                } else {
                    Label("Incorrect", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.headline)
                }
                if let explanation = question.explanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let sampleAnswer = question.sampleAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Answer:")
                        .font(.caption.bold())
                    Text(sampleAnswer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }

    private func getOptionIcon(for index: Int) -> String {
        if !isSubmitted {
            return selectedAnswer == String(index) ? "circle.fill" : "circle"
        }

        if let correctAnswer = question.correctAnswer {
            if index == correctAnswer {
                return "checkmark.circle.fill"
            } else if selectedAnswer == String(index) {
                return "xmark.circle.fill"
            }
        }

        return "circle"
    }

    private func getOptionColor(for index: Int) -> Color {
        if !isSubmitted {
            return selectedAnswer == String(index) ? .blue : .secondary
        }

        if let correctAnswer = question.correctAnswer {
            if index == correctAnswer {
                return .green
            } else if selectedAnswer == String(index) {
                return .red
            }
        }

        return .secondary
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Full Screen Note View

private struct FullScreenNoteView: View {
    let lecture: Lecture
    @State private var htmlContent: String?
    @State private var isLoadingHTML = false
    @State private var showingAssistant = false
    @State private var assistantMessages: [ChatMessage] = []
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main content - full screen HTML
            VStack(spacing: 0) {
                if isLoadingHTML {
                    VStack {
                        Spacer()
                        ProgressView("Loading notes...")
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else if let html = htmlContent {
                    EmbeddedWebView(htmlString: html)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    // Fallback to plain text
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !lecture.summary.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Summary")
                                        .font(.headline)
                                    
                                    Text(lecture.summary)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(12)
                            }
                            
                            ForEach(lecture.notes) { note in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(note.content)
                                        .font(.body)
                                    
                                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
            }
            
            // Floating chat button
            FloatingChatButton(
                isShowing: $showingAssistant,
                lecture: lecture,
                messages: $assistantMessages
            )
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            loadHTMLContent()
        }
    }
    
    private func loadHTMLContent() {
        guard htmlContent == nil else { return }
        isLoadingHTML = true
        
        Task {
            let content = NoteLoaderService.shared.getHTMLContent(for: lecture)
            await MainActor.run {
                htmlContent = content
                isLoadingHTML = false
            }
        }
    }
}

// MARK: - Floating Chat Button

private struct FloatingChatButton: View {
    @Binding var isShowing: Bool
    let lecture: Lecture
    @Binding var messages: [ChatMessage]
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact chat window
            if isShowing {
                CompactAssistantView(
                    lecture: lecture,
                    messages: $messages,
                    isShowing: $isShowing
                )
                .frame(width: 350, height: 500)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
                .padding(.bottom, 8)
            }
            
            // Chat toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowing.toggle()
                }
            } label: {
                Image(systemName: isShowing ? "xmark.circle.fill" : "message.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
            }
            .rotationEffect(.degrees(isShowing ? 0 : 0))
        }
    }
}

// MARK: - Compact Assistant View

private struct CompactAssistantView: View {
    let lecture: Lecture
    @Binding var messages: [ChatMessage]
    @Binding var isShowing: Bool
    @State private var currentQuestion = ""
    @State private var isAsking = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Study Assistant")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(lecture.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    withAnimation {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            // Welcome message
                            MessageBubble(
                                message: ChatMessage(
                                    text: "Hi! Ask me anything about \"\(lecture.title)\"!",
                                    isUser: false
                                )
                            )
                        }
                        
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isAsking {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask a question...", text: $currentQuestion, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .disabled(isAsking)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentQuestion.isEmpty ? Color.secondary : Color.blue)
                }
                .disabled(currentQuestion.isEmpty || isAsking)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private func sendMessage() {
        guard !currentQuestion.isEmpty else { return }
        
        let question = currentQuestion
        currentQuestion = ""
        
        // Add user message
        let userMessage = ChatMessage(text: question, isUser: true)
        messages.append(userMessage)
        
        isAsking = true
        
        Task {
            do {
                let context = buildContext()
                let answer = try await ClaudeService.shared.askQuestion(
                    question: question,
                    context: context
                )
                
                let assistantMessage = ChatMessage(text: answer, isUser: false)
                await MainActor.run {
                    messages.append(assistantMessage)
                    isAsking = false
                }
            } catch {
                let errorMessage = ChatMessage(
                    text: "Sorry, I encountered an error: \(error.localizedDescription)",
                    isUser: false
                )
                await MainActor.run {
                    messages.append(errorMessage)
                    isAsking = false
                }
            }
        }
    }
    
    private func buildContext() -> String {
        var context = """
        Lecture: \(lecture.title)
        Date: \(lecture.date.formatted(date: .long, time: .omitted))
        Summary: \(lecture.summary)
        
        Notes:
        """
        
        for note in lecture.notes {
            context += "\n- \(note.content)"
        }
        
        return context
    }
}

// MARK: - Lecture Notes Section

private struct LectureNotesSection: View {
    let lecture: Lecture
    @State private var isExpanded = true
    @State private var showingAssistant = false
    @State private var showingFullHTML = false
    @State private var assistantMessages: [ChatMessage] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Lecture header with expand/collapse
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lecture.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(lecture.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Ask AI button
                        Button {
                            showingAssistant = true
                        } label: {
                            Image(systemName: "message.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        // View full HTML button
                        Button {
                            showingFullHTML = true
                        } label: {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                        
                        // Note count
                        Text("\(lecture.notes.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                        
                        // Expand/collapse indicator
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Show notes when expanded
            if isExpanded && !lecture.notes.isEmpty {
                ForEach(lecture.notes) { note in
                    NoteCardView(note: note, lecture: lecture)
                        .padding(.leading, 16)
                }
            }
        }
        .sheet(isPresented: $showingAssistant) {
            AssistantView(
                lecture: lecture,
                messages: $assistantMessages,
                isGeneral: false
            )
        }
        .sheet(isPresented: $showingFullHTML) {
            NavigationStack {
                NoteHTMLView(lecture: lecture)
                    .navigationTitle(lecture.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingFullHTML = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Note Card View

private struct NoteCardView: View {
    let note: LectureNote
    let lecture: Lecture
    @State private var showingHTMLPreview = false
    @State private var htmlContent: String?
    @State private var isLoadingHTML = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show HTML preview if available
            if let html = htmlContent {
                EmbeddedWebView(htmlString: html)
                    .frame(minHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            } else {
                // Fallback to plain text
                Text(note.content)
                    .font(.body)
            }
            
            HStack {
                Text(note.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isLoadingHTML {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            loadHTMLContent()
        }
    }
    
    private func loadHTMLContent() {
        guard htmlContent == nil else { return }
        isLoadingHTML = true
        
        Task {
            let content = NoteLoaderService.shared.getHTMLContent(for: lecture)
            await MainActor.run {
                htmlContent = content
                isLoadingHTML = false
            }
        }
    }
}

// MARK: - Assistant View

struct AssistantView: View {
    let lecture: Lecture?
    @Binding var messages: [ChatMessage]
    let isGeneral: Bool
    var specificNote: String?
    
    @State private var currentQuestion = ""
    @State private var isAsking = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            MessageBubble(
                                message: ChatMessage(
                                    text: welcomeMessage,
                                    isUser: false
                                )
                            )
                            
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isAsking {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Ask a question...", text: $currentQuestion, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .disabled(isAsking)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(currentQuestion.isEmpty ? Color.secondary : Color.blue)
                    }
                    .disabled(currentQuestion.isEmpty || isAsking)
                }
                .padding()
                .background(.background)
            }
            .navigationTitle(isGeneral ? "Study Assistant" : "Note Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var welcomeMessage: String {
        if let specificNote = specificNote {
            return "Hi! I can help you understand this note better. What would you like to know?"
        } else if let lecture = lecture {
            return "Hi! I'm here to help with \"\(lecture.title)\". Ask me anything about this lecture!"
        } else {
            return "Hi! I'm your study assistant. Ask me about your classes, lectures, or general study questions!"
        }
    }
    
    private func sendMessage() {
        guard !currentQuestion.isEmpty else { return }
        
        let question = currentQuestion
        currentQuestion = ""
        
        // Add user message
        let userMessage = ChatMessage(text: question, isUser: true)
        messages.append(userMessage)
        
        isAsking = true
        
        Task {
            do {
                let context = buildContext()
                let answer = try await ClaudeService.shared.askQuestion(
                    question: question,
                    context: context
                )
                
                let assistantMessage = ChatMessage(text: answer, isUser: false)
                await MainActor.run {
                    messages.append(assistantMessage)
                    isAsking = false
                }
            } catch {
                let errorMessage = ChatMessage(
                    text: "Sorry, I encountered an error: \(error.localizedDescription)",
                    isUser: false
                )
                await MainActor.run {
                    messages.append(errorMessage)
                    isAsking = false
                }
            }
        }
    }
    
    private func buildContext() -> String {
        if let specificNote = specificNote {
            return """
            Note Content:
            \(specificNote)
            
            Please answer questions specifically about this note.
            """
        } else if let lecture = lecture {
            var context = """
            Lecture: \(lecture.title)
            Date: \(lecture.date.formatted(date: .long, time: .omitted))
            Summary: \(lecture.summary)
            
            Notes:
            """
            
            for note in lecture.notes {
                context += "\n- \(note.content)"
            }
            
            return context
        } else {
            return "General study questions - provide helpful academic guidance."
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background {
                        if message.isUser {
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color(uiColor: .secondarySystemGroupedBackground)
                        }
                    }
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !message.isUser { Spacer() }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .opacity(animating ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Spacer()
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Embedded WebView for HTML Rendering

private struct EmbeddedWebView: UIViewRepresentable {
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Add custom CSS for better mobile viewing
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px;
                    margin: 0;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #333;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                pre {
                    overflow-x: auto;
                    background: #f5f5f5;
                    padding: 12px;
                    border-radius: 8px;
                }
                code {
                    background: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-size: 14px;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 16px 0;
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f0f0f0;
                        background-color: transparent;
                    }
                    pre, code {
                        background: #2a2a2a;
                        color: #f0f0f0;
                    }
                }
            </style>
        </head>
        <body>
            \(htmlString)
        </body>
        </html>
        """
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
}

#Preview {
    LearnHome(activeProfile: .mockProfile())
        .modelContainer(PreviewContainer.container)
}

