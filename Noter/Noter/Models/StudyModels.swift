import Foundation
import SwiftData

@Model
final class StudyClass {
    var id: UUID
    var title: String
    var instructor: String
    var details: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Lecture.parentClass)
    var lectures: [Lecture] = [Lecture]()

    init(
        id: UUID = .init(),
        title: String,
        instructor: String = "",
        details: String = "",
        createdAt: Date = .now,
        lectures: [Lecture] = [Lecture]()
    ) {
        self.id = id
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
            attachments: [
                LectureAttachment(name: "Slides", type: .document, url: URL(string: "https://example.com/slides.pdf"))
            ],
            recordings: [
                LectureRecording(
                    originalFileName: "transformers-101.m4a",
                    contentType: "audio/mp4",
                    duration: 3_245,
                    remoteURLString: "https://example.com/transformers.m4a"
                )

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
    var id: UUID
    var title: String
    var date: Date
    var summary: String
    var slideReference: URL?
    @Relationship(deleteRule: .cascade, inverse: \LectureAttachment.parentLecture)
    var attachments: [LectureAttachment] = [LectureAttachment]() {
        didSet { attachments.forEach { $0.parentLecture = self } }
    }
    @Relationship(deleteRule: .cascade, inverse: \LectureRecording.parentLecture)
    var recordings: [LectureRecording] = [LectureRecording]() {
        didSet { recordings.forEach { $0.parentLecture = self } }
    }
    @Relationship(deleteRule: .cascade, inverse: \LectureNote.parentLecture)
    var notes: [LectureNote] = [LectureNote]() {
        didSet { notes.forEach { $0.parentLecture = self } }
    }
    var parentClass: StudyClass?

    init(
        id: UUID = .init(),
        title: String,
        date: Date = .now,
        summary: String = "",
        slideReference: URL? = nil,
        attachments: [LectureAttachment] = [LectureAttachment](),
        recordings: [LectureRecording] = [LectureRecording](),
        notes: [LectureNote] = [LectureNote]()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.summary = summary
        self.slideReference = slideReference
        self.attachments = attachments
        self.recordings = recordings
        self.notes = notes
    }

    var noteCountDescription: String {
        notes.isEmpty ? "No notes yet" : "\(notes.count) note\(notes.count == 1 ? "" : "s")"
    }

    func appendNote(_ content: String) {
        let note = LectureNote(content: content, parentLecture: self)
        notes.append(note)
    }
}

@Model
final class LectureAttachment {
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

    var id: UUID
    var name: String
    var type: AttachmentType
    var url: URL?
    var storedFileName: String?
    var originalFileName: String?
    var fileSize: Int64?
    var contentType: String?
    var parentLecture: Lecture?

    init(
        id: UUID = .init(),
        name: String,
        type: AttachmentType,
        url: URL? = nil,
        storedFileName: String? = nil,
        originalFileName: String? = nil,
        fileSize: Int64? = nil,
        contentType: String? = nil,
        parentLecture: Lecture? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.storedFileName = storedFileName
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentType = contentType
        self.parentLecture = parentLecture
    }
}

@Model
final class LectureRecording {
    var id: UUID
    var createdAt: Date
    var storedFileName: String?
    var originalFileName: String
    var fileSize: Int64?
    var contentType: String?
    var duration: TimeInterval?
    var remoteURLString: String?
    var storagePath: String?
    var parentLecture: Lecture?

    init(
        id: UUID = .init(),
        createdAt: Date = .now,
        storedFileName: String? = nil,
        originalFileName: String,
        fileSize: Int64? = nil,
        contentType: String? = nil,
        duration: TimeInterval? = nil,
        remoteURLString: String? = nil,
        storagePath: String? = nil,
        parentLecture: Lecture? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.storedFileName = storedFileName
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentType = contentType
        self.duration = duration
        self.remoteURLString = remoteURLString
        self.storagePath = storagePath
        self.parentLecture = parentLecture
    }
}

@Model
final class LectureNote {
    var id: UUID
    var content: String
    var createdAt: Date
    var parentLecture: Lecture?

    init(id: UUID = .init(), content: String, createdAt: Date = .now, parentLecture: Lecture? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.parentLecture = parentLecture
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
extension LectureAttachment: Identifiable {}
extension LectureRecording: Identifiable {}
extension LectureNote: Identifiable {}

extension LectureRecording {
    var displayName: String { originalFileName }

    var remoteURL: URL? {
        guard let remoteURLString else { return nil }
        return URL(string: remoteURLString)
    }

    var localURL: URL? {
        guard let storedFileName else { return nil }
        return LectureMediaStore.shared.url(forStoredFileName: storedFileName)
    }

    var shareableURL: URL? {
        remoteURL ?? localURL
    }

    var formattedFileSize: String? {
        guard let fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration)
    }
}
