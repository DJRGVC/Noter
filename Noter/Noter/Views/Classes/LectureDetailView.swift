import SwiftUI
import SwiftData

struct LectureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isAnalyzing = false
    @State private var showingAddNote = false
    @State private var newNote = ""

    let lecture: Lecture

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Date") { Text(lecture.date, style: .date) }
                if let audio = lecture.audioReference {
                    Link("Audio Reference", destination: audio)
                }
                if let slides = lecture.slideReference {
                    Link("Slides", destination: slides)
                }
                if !lecture.summary.isEmpty {
                    Text(lecture.summary)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.clear.background(.ultraThinMaterial))

            if !lecture.attachments.isEmpty {
                Section("Attachments") {
                    ForEach(lecture.attachments) { attachment in
                        HStack {
                            Image(systemName: symbol(for: attachment.type))
                            Text(attachment.name)
                            Spacer()
                            if let url = attachment.url {
                                Image(systemName: "link")
                                    .foregroundStyle(.secondary)
                                    .help(url.absoluteString)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear.background(.ultraThinMaterial))
            }

            Section("Notes") {
                if lecture.notes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "note.text", description: Text("Captured lecture notes, AI summaries, and action items will collect here."))
                } else {
                    ForEach(lecture.notes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.content)
                                .font(.body)
                            Text(note.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deleteNotes)
                }

                if showingAddNote {
                    TextField("New note", text: $newNote, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") { appendNote() }
                        .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Add note") { showingAddNote = true }
                }
            }
            .listRowBackground(Color.clear.background(.thinMaterial))
        }
        .navigationTitle(lecture.title)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Task { await analyzeWithAI() }
                } label: {
                    if isAnalyzing {
                        ProgressView()
                    } else {
                        Label("Analyze with AI", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        lecture.notes.remove(atOffsets: offsets)
        try? modelContext.save()
    }

    private func appendNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lecture.appendNote(trimmed)
        newNote = ""
        showingAddNote = false
        try? modelContext.save()
    }

    private func analyzeWithAI() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        // Hook up your preferred AI endpoint (e.g., OpenAI, Azure, Anthropic) here.
        // Send lecture.audioReference + lecture.notes to generate structured study aids.
        try? await Task.sleep(for: .seconds(1))
    }

    private func symbol(for type: LectureAttachment.AttachmentType) -> String {
        switch type {
        case .audio: return "waveform"
        case .document: return "doc"
        case .link: return "link"
        case .other: return "paperclip"
        }
    }
}

#Preview {
    NavigationStack {
        LectureDetailView(lecture: StudyClass.mockClasses().first!.lectures.first!)
    }
    .modelContainer(PreviewContainer.container)
}
