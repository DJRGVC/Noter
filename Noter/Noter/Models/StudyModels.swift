import Foundation
import SwiftData

@Model
final class StudyClass {
    var title: String
    var instructor: String
    var details: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Lecture.parentClass)
    var lectures: [Lecture]

    init(
        title: String,
        instructor: String = "",
        details: String = "",
        createdAt: Date = .now,
        lectures: [Lecture] = []
    ) {
        self.title = title
        self.instructor = instructor
        self.details = details
        self.createdAt = createdAt
        self.lectures = lectures
    }

    var sortedLectures: [Lecture] {
        lectures.sorted { $0.date > $1.date }
    }

    var summary: String {
        let lectureSummary = lectures.isEmpty ? "No lectures yet" : "\(lectures.count) lecture\(lectures.count == 1 ? "" : "s")"
        let instructorLine = instructor.isEmpty ? "" : " with \(instructor)"
        return "\(title)\(instructorLine) – \(lectureSummary)"
    }

    func addLecture(_ lecture: Lecture, context: ModelContext) {
        lectures.append(lecture)
        lecture.parentClass = self
        context.insert(lecture)
    }

    static func mockClasses() -> [StudyClass] {
        let swiftLecture = Lecture(
            title: "Protocol-Oriented Programming",
            date: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            summary: "Explored protocol extensions and default implementations.",
            notes: [
                LectureNote(content: "Remember to emphasize value semantics."),
                LectureNote(content: "Add challenge on protocol composition.")
            ]
        )
        let aiLecture = Lecture(
            title: "Transformers 101",
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            summary: "Covered attention, positional encodings, and decoder-only models.",
            audioReference: URL(string: "https://example.com/transformers.m4a"),
            attachments: [
                LectureAttachment(name: "Slides", type: .document, url: URL(string: "https://example.com/slides.pdf"))
            ],
            notes: [LectureNote(content: "Link to hugging face datasets.")]
        )
        let swiftClass = StudyClass(
            title: "Advanced Swift",
            instructor: "Dr. Calder",
            details: "Deep dive into Swift concurrency, generics, and SwiftData.",
            lectures: [swiftLecture]
        )
        let aiClass = StudyClass(
            title: "Applied Generative AI",
            instructor: "Prof. Morales",
            details: "Weekly explorations of practical generative AI workflows.",
            lectures: [aiLecture]
        )
        swiftLecture.parentClass = swiftClass
        aiLecture.parentClass = aiClass
        return [swiftClass, aiClass]
    }
}

@Model
final class Lecture {
    var title: String
    var date: Date
    var summary: String
    var audioReference: URL?
    var slideReference: URL?
    var attachments: [LectureAttachment]
    var notes: [LectureNote]
    var parentClass: StudyClass?

    init(
        title: String,
        date: Date = .now,
        summary: String = "",
        audioReference: URL? = nil,
        slideReference: URL? = nil,
        attachments: [LectureAttachment] = [],
        notes: [LectureNote] = []
    ) {
        self.title = title
        self.date = date
        self.summary = summary
        self.audioReference = audioReference
        self.slideReference = slideReference
        self.attachments = attachments
        self.notes = notes
    }

    var noteCountDescription: String {
        notes.isEmpty ? "No notes yet" : "\(notes.count) note\(notes.count == 1 ? "" : "s")"
    }

    func appendNote(_ content: String) {
        notes.append(LectureNote(content: content))
    }
}

struct LectureAttachment: Identifiable, Codable, Hashable {
    enum AttachmentType: String, Codable, Hashable, CaseIterable {
        case audio
        case document
        case link
        case other

        var label: String {
            switch self {
            case .audio: "Audio"
            case .document: "Document"
            case .link: "Link"
            case .other: "Other"
            }
        }
    }

    var id: UUID = .init()
    var name: String
    var type: AttachmentType
    var url: URL?

    init(id: UUID = .init(), name: String, type: AttachmentType, url: URL? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
    }
}

struct LectureNote: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var content: String
    var createdAt: Date

    init(id: UUID = .init(), content: String, createdAt: Date = .now) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

@Model
final class UserProfile {
    var name: String
    var email: String
    var createdAt: Date

    init(name: String, email: String = "", createdAt: Date = .now) {
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }

    static func mockProfile() -> UserProfile {
        UserProfile(name: "Taylor Swift", email: "taylor@example.com")
    }
}

extension StudyClass: Identifiable {}
extension Lecture: Identifiable {}
