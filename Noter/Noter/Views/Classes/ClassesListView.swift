import SwiftUI
import SwiftData

struct ClassesListView: View {
    @Query(sort: \StudyClass.createdAt, order: .reverse) private var classes: [StudyClass]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingImportNotes = false
    @State private var showingAddClass = false
    
    var body: some View {
        NavigationStack {
            Group {
                if classes.isEmpty {
                    emptyState
                } else {
                    classList
                }
            }
            .navigationTitle("Classes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingImportNotes = true
                    } label: {
                        Label("Import Notes", systemImage: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddClass = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImportNotes) {
                NotesLibraryView()
            }
            .sheet(isPresented: $showingAddClass) {
                AddClassView()
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Classes", systemImage: "book.closed")
        } description: {
            Text("Import notes or add a class to get started")
        } actions: {
            Button("Import Notes") {
                showingImportNotes = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var classList: some View {
        List {
            ForEach(classes) { studyClass in
                NavigationLink(destination: ClassDetailView(studyClass: studyClass)) {
                    ClassRow(studyClass: studyClass)
                }
            }
            .onDelete(perform: deleteClasses)
        }
        .refreshable {
            // This allows pull to refresh if needed
        }
    }
    
    private func deleteClasses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(classes[index])
        }
    }
}

struct ClassRow: View {
    let studyClass: StudyClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(studyClass.title)
                .font(.headline)
            
            if !studyClass.instructor.isEmpty {
                Text(studyClass.instructor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("\(studyClass.lectures.count)", systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !studyClass.details.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(studyClass.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddClassView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var instructor = ""
    @State private var details = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Class Information") {
                    TextField("Title", text: $title)
                    TextField("Instructor", text: $instructor)
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addClass()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addClass() {
        let newClass = StudyClass(
            title: title,
            instructor: instructor,
            details: details
        )
        modelContext.insert(newClass)
        dismiss()
    }
}

struct AddLectureView: View {
    let studyClass: StudyClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var summary = ""
    @State private var noteContent = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Lecture Information") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Notes") {
                    TextField("Note Content", text: $noteContent, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Add Lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLecture()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addLecture() {
        let notes = noteContent.isEmpty ? [] : [LectureNote(content: noteContent)]
        
        let lecture = Lecture(
            title: title,
            date: date,
            summary: summary,
            notes: notes
        )
        
        studyClass.addLecture(lecture, context: modelContext)
        dismiss()
    }
}

#Preview {
    ClassesListView()
        .modelContainer(for: [StudyClass.self, Lecture.self])
}
