import Testing
import SwiftData
@testable import Noter

@MainActor
struct NoterModelTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            StudyClass.self,
            Lecture.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Create class persists")
    func createClass() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let studyClass = StudyClass(title: "Test", instructor: "Instructor", details: "Details")
        context.insert(studyClass)
        try context.save()

        let descriptor = FetchDescriptor<StudyClass>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.title == "Test")
    }

    @Test("Update lecture adds note")
    func updateLecture() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let lecture = Lecture(title: "Lecture")
        let studyClass = StudyClass(title: "Course", lectures: [lecture])
        lecture.parentClass = studyClass
        context.insert(studyClass)
        try context.save()

        lecture.appendNote("Remember the key concept")
        try context.save()

        let descriptor = FetchDescriptor<Lecture>()
        let lectures = try context.fetch(descriptor)
        #expect(lectures.first?.notes.count == 1)
    }

    @Test("Deleting class cascades lectures")
    func deleteCascade() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let lecture = Lecture(title: "Lecture")
        let studyClass = StudyClass(title: "Course", lectures: [lecture])
        lecture.parentClass = studyClass
        context.insert(studyClass)
        try context.save()

        context.delete(studyClass)
        try context.save()

        let classDescriptor = FetchDescriptor<StudyClass>()
        let lectureDescriptor = FetchDescriptor<Lecture>()
        #expect((try context.fetch(classDescriptor)).isEmpty)
        #expect((try context.fetch(lectureDescriptor)).isEmpty)
    }
}
