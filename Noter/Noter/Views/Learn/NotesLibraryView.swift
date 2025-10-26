import SwiftUI
import SwiftData

struct NotesLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var notesByClass: [String: [NoteLoaderService.NoteFile]] = [:]
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var selectedNotes: Set<String> = []
    @State private var expandedClasses: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading notes...")
                } else if notesByClass.isEmpty {
                    ContentUnavailableView(
                        "No Notes Found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("No notes were found in the calhacks25 directory.")
                    )
                } else {
                    notesList
                }
            }
            .navigationTitle("Import Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") {
                        importAllNotes()
                    }
                    .disabled(isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(importMessage ?? "Importing notes...")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .padding(32)
                        .background(.regularMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
        .onAppear {
            loadNotes()
        }
    }
    
    private var notesList: some View {
        List {
            ForEach(Array(notesByClass.keys.sorted()), id: \.self) { className in
                classSection(className: className)
            }
        }
    }
    
    private func classSection(className: String) -> some View {
        Section {
            if expandedClasses.contains(className) {
                ForEach(notesByClass[className] ?? []) { note in
                    NoteRow(note: note, onImport: {
                        importNote(note, className: className)
                    })
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatClassName(className))
                        .font(.headline)
                    
                    Text("\(notesByClass[className]?.count ?? 0) notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if expandedClasses.contains(className) {
                            expandedClasses.remove(className)
                        } else {
                            expandedClasses.insert(className)
                        }
                    }
                }) {
                    Image(systemName: expandedClasses.contains(className) ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if expandedClasses.contains(className) {
                        expandedClasses.remove(className)
                    } else {
                        expandedClasses.insert(className)
                    }
                }
            }
        }
    }
    
    private func loadNotes() {
        Task {
            notesByClass = NoteLoaderService.shared.loadAllNotes()
            isLoading = false
        }
    }
    
    private func importNote(_ note: NoteLoaderService.NoteFile, className: String) {
        Task {
            isImporting = true
            importMessage = "Importing \(note.title)..."
            
            do {
                // Find or create class
                let formattedClassName = formatClassName(className)
                let descriptor = FetchDescriptor<StudyClass>(
                    predicate: #Predicate { $0.title == formattedClassName }
                )
                
                let existingClasses = try modelContext.fetch(descriptor)
                let studyClass: StudyClass
                
                if let existing = existingClasses.first {
                    studyClass = existing
                } else {
                    studyClass = StudyClass(
                        title: formatClassName(className),
                        instructor: "",
                        details: "Imported from notes"
                    )
                    modelContext.insert(studyClass)
                }
                
                // Check if lecture already exists
                let alreadyExists = studyClass.lectures.contains { $0.title == note.title }
                
                if !alreadyExists {
                    let lecture = Lecture(
                        title: note.title,
                        date: Date(),
                        summary: extractSummary(from: note.textContent),
                        notes: [LectureNote(content: note.textContent)]
                    )
                    
                    studyClass.addLecture(lecture, context: modelContext)
                    try modelContext.save()
                }
                
                isImporting = false
                importMessage = nil
            } catch {
                isImporting = false
                importMessage = "Error: \(error.localizedDescription)"
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                importMessage = nil
            }
        }
    }
    
    private func importAllNotes() {
        Task {
            isImporting = true
            
            do {
                try await NoteLoaderService.shared.importNotesToSwiftData(context: modelContext)
                isImporting = false
                dismiss()
            } catch {
                isImporting = false
                importMessage = "Error: \(error.localizedDescription)"
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                importMessage = nil
            }
        }
    }
    
    private func formatClassName(_ className: String) -> String {
        switch className.lowercased() {
        case "cs":
            return "Computer Science"
        case "bio":
            return "Biology"
        case "history":
            return "History"
        case "philo":
            return "Philosophy"
        case "sport":
            return "Sports Science"
        default:
            return className.capitalized
        }
    }
    
    private func extractSummary(from text: String, maxLength: Int = 200) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return "" }
        
        var summary = ""
        for line in lines.prefix(3) {
            if summary.count + line.count > maxLength {
                break
            }
            if !summary.isEmpty {
                summary += " "
            }
            summary += line
        }
        
        if summary.count > maxLength {
            let index = summary.index(summary.startIndex, offsetBy: maxLength)
            summary = String(summary[..<index]) + "..."
        }
        
        return summary
    }
}

struct NoteRow: View {
    let note: NoteLoaderService.NoteFile
    let onImport: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.body)
                
                Text(note.filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onImport) {
                Label("Import", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotesLibraryView()
        .modelContainer(for: [StudyClass.self, Lecture.self])
}
