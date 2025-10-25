import Testing
import SwiftData
@testable import Noter

@MainActor
struct ModelCRUDTests {
    private let container: ModelContainer = {
        let schema = Schema([
            StudyClass.self,
            Lecture.self,
            LectureNote.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var context: ModelContext { container.mainContext }

    @Test("Create, update, and delete StudyClass")
    func classLifecycle() throws {
        let studyClass = StudyClass(title: "Algorithms", courseCode: "CS301", instructor: "Ada Lovelace")
        context.insert(studyClass)
        try context.save()

        #expect(studyClass.persistentModelID != nil)

        studyClass.instructor = "Prof. Lovelace"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StudyClass>())
        #expect(fetched.first?.instructor == "Prof. Lovelace")

        context.delete(studyClass)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<StudyClass>())
        #expect(remaining.isEmpty)
    }

    @Test("Lecture CRUD propagates to notes")
    func lectureLifecycle() throws {
        let hostClass = StudyClass(title: "SwiftUI", courseCode: "CS402", instructor: "Prof. Lin")
        context.insert(hostClass)
        try context.save()

        let lecture = Lecture(title: "Layouts", summary: "Stacks and grids", transcript: "Transcript")
        hostClass.lectures.append(lecture)
        try context.save()

        #expect(hostClass.sortedLectures.count == 1)

        let note = LectureNote(content: "Remember stacks.")
        lecture.notes.append(note)
        try context.save()
        #expect(lecture.notes.count == 1)

        context.delete(lecture)
        try context.save()
        let classes = try context.fetch(FetchDescriptor<StudyClass>())
        #expect(classes.first?.lectures.isEmpty ?? false)
    }
}
