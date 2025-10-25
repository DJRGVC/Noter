import Foundation
import SwiftData

@Model
final class StudyClass {
    @Attribute(.unique) var id: UUID
    var title: String
    var courseCode: String
    var instructor: String
    var details: String
    var colorHex: String
    @Relationship(deleteRule: .cascade, inverse: \Lecture.parentClass) var lectures: [Lecture]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        courseCode: String,
        instructor: String,
        details: String = "",
        colorHex: String = StudyClass.defaultColorHex,
        lectures: [Lecture] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.courseCode = courseCode
        self.instructor = instructor
        self.details = details
        self.colorHex = colorHex
        self.lectures = lectures
        self.createdAt = createdAt
        self.lectures.forEach { $0.parentClass = self }
    }
}

extension StudyClass {
    static let defaultColorHex = "3B82F6"

    var color: String { colorHex }

    var sortedLectures: [Lecture] {
        lectures.sorted { $0.date > $1.date }
    }

    var summary: String {
        let lectureCount = lectures.count
        if lectureCount == 0 {
            return "No lectures yet"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let latest = sortedLectures.first {
            return "Last lecture on \(formatter.string(from: latest.date))"
        }
        return "\(lectureCount) lectures"
    }

    static func mockData(context: ModelContext? = nil) -> [StudyClass] {
        let mockLectures = [
            Lecture(title: "Introduction", date: .now.addingTimeInterval(-86400 * 3), summary: "Overview of core concepts", transcript: "A concise intro transcript", notes: [LectureNote(content: "Remember to review the syllabus."), LectureNote(content: "Set up project skeleton.")]),
            Lecture(title: "Deep Dive", date: .now.addingTimeInterval(-86400), summary: "Detailed coverage of important topic", transcript: "Transcript of deep dive session", notes: [LectureNote(content: "Highlight the major theorem."), LectureNote(content: "Practice derived problems." )])
        ]
        let classes = [
            StudyClass(title: "Modern SwiftUI", courseCode: "CS 402", instructor: "Prof. Lin", details: "Building adaptive, data-driven UIs", colorHex: "10B981", lectures: mockLectures),
            StudyClass(title: "Machine Learning", courseCode: "AI 201", instructor: "Dr. Singh", details: "Supervised models and evaluation", colorHex: "F97316", lectures: [
                Lecture(title: "Regression", date: .now.addingTimeInterval(-86400 * 5), summary: "Linear regression recap", transcript: "Audio summary placeholder", notes: [LectureNote(content: "Check gradient descent variations.")])
            ])
        ]
        if let context {
            classes.forEach { context.insert($0) }
        }
        return classes
    }
}

@Model
final class Lecture {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var summary: String
    var transcript: String
    var audioURL: URL?
    var attachmentURL: URL?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \LectureNote.lecture) var notes: [LectureNote]
    var parentClass: StudyClass?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = .now,
        summary: String = "",
        transcript: String = "",
        audioURL: URL? = nil,
        attachmentURL: URL? = nil,
        notes: [LectureNote] = [],
        parentClass: StudyClass? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.summary = summary
        self.transcript = transcript
        self.audioURL = audioURL
        self.attachmentURL = attachmentURL
        self.notes = notes
        self.parentClass = parentClass
        self.createdAt = createdAt
        self.notes.forEach { $0.lecture = self }
    }
}

extension Lecture {
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    var snippet: String {
        if !summary.isEmpty { return summary }
        if !transcript.isEmpty { return String(transcript.prefix(120)) + "…" }
        return "No summary yet"
    }

    static func mock(for studyClass: StudyClass? = nil) -> Lecture {
        Lecture(title: "Sample Lecture", summary: "Overview of the assigned reading", transcript: "Audio transcript placeholder", notes: [LectureNote(content: "Focus on definitions." )], parentClass: studyClass)
    }
}

@Model
final class LectureNote {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var lecture: Lecture?

    init(id: UUID = UUID(), content: String, createdAt: Date = .now, lecture: Lecture? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.lecture = lecture
    }
}

extension StudyClass: Hashable {
    static func == (lhs: StudyClass, rhs: StudyClass) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Lecture: Hashable {
    static func == (lhs: Lecture, rhs: Lecture) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension LectureNote: Hashable {
    static func == (lhs: LectureNote, rhs: LectureNote) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
