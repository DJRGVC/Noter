import Foundation
import SwiftData

/// Service for loading notes from the calhacks25 directory structure
class NoteLoaderService {
    static let shared = NoteLoaderService()
    
    private init() {}
    
    // Base path to notes directory
    private let notesBasePath = "/Users/haoming/Desktop/Noter/Noter/calhacks25"
    
    struct NoteFile: Identifiable {
        let id = UUID()
        let filename: String
        let path: String
        let title: String
        let className: String
        let htmlContent: String
        let textContent: String
    }
    
    /// Load all available classes and their notes
    func loadAllNotes() -> [String: [NoteFile]] {
        var notesByClass: [String: [NoteFile]] = [:]
        
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: notesBasePath)
        
        guard let classDirs = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("Failed to read notes directory")
            return [:]
        }
        
        for classDir in classDirs {
            guard classDir.hasDirectoryPath else { continue }
            
            let className = classDir.lastPathComponent
            
            // Skip non-class directories
            if className == ".DS_Store" || className.hasPrefix(".") {
                continue
            }
            
            var classNotes: [NoteFile] = []
            
            guard let htmlFiles = try? fileManager.contentsOfDirectory(
                at: classDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter({ $0.pathExtension == "html" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
                continue
            }
            
            for htmlFile in htmlFiles {
                if let noteFile = loadNoteFile(at: htmlFile, className: className) {
                    classNotes.append(noteFile)
                }
            }
            
            if !classNotes.isEmpty {
                notesByClass[className] = classNotes
            }
        }
        
        return notesByClass
    }
    
    /// Load a single note file
    private func loadNoteFile(at url: URL, className: String) -> NoteFile? {
        guard let htmlContent = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        // Try to load corresponding .txt file
        let txtURL = url.deletingPathExtension().appendingPathExtension("txt")
        let textContent = (try? String(contentsOf: txtURL, encoding: .utf8)) ?? ""
        
        let title = extractTitle(from: htmlContent) ?? url.deletingPathExtension().lastPathComponent
        
        return NoteFile(
            filename: url.lastPathComponent,
            path: url.path,
            title: title,
            className: className,
            htmlContent: htmlContent,
            textContent: textContent
        )
    }
    
    /// Extract title from HTML content
    private func extractTitle(from html: String) -> String? {
        // Try to find <h1> tag
        if let h1Range = html.range(of: "<h1[^>]*>(.*?)</h1>", options: .regularExpression) {
            let h1Content = String(html[h1Range])
            if let contentRange = h1Content.range(of: "(?<=>)[^<]+(?=<)", options: .regularExpression) {
                return String(h1Content[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try to find <title> tag
        if let titleRange = html.range(of: "<title>(.*?)</title>", options: .regularExpression) {
            let titleContent = String(html[titleRange])
            if let contentRange = titleContent.range(of: "(?<=>)[^<]+(?=<)", options: .regularExpression) {
                return String(titleContent[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try to find first # heading (markdown style)
        if let mdHeadingRange = html.range(of: "^#\\s+(.+)$", options: .regularExpression) {
            let heading = String(html[mdHeadingRange])
            return heading.replacingOccurrences(of: "^#\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    /// Import notes into SwiftData
    func importNotesToSwiftData(context: ModelContext) async throws {
        let notesByClass = loadAllNotes()
        
        for (className, notes) in notesByClass {
            // Find or create class
            let formattedClassName = formatClassName(className)
            let descriptor = FetchDescriptor<StudyClass>(
                predicate: #Predicate { $0.title == formattedClassName }
            )
            
            let existingClasses = try context.fetch(descriptor)
            let studyClass: StudyClass
            
            if let existing = existingClasses.first {
                studyClass = existing
            } else {
                studyClass = StudyClass(
                    title: formattedClassName,
                    instructor: "",
                    details: "Imported from notes"
                )
                context.insert(studyClass)
            }
            
            // Import each note as a lecture
            for (index, note) in notes.enumerated() {
                // Check if lecture already exists
                let lectureTitle = note.title
                let alreadyExists = studyClass.lectures.contains { $0.title == lectureTitle }
                
                if !alreadyExists {
                    let lecture = Lecture(
                        title: lectureTitle,
                        date: Date().addingTimeInterval(TimeInterval(-86400 * index)), // Spread out by days
                        summary: extractSummary(from: note.textContent),
                        notes: [LectureNote(content: note.textContent)]
                    )
                    
                    studyClass.addLecture(lecture, context: context)
                }
            }
        }
        
        try context.save()
    }
    
    /// Format class name for display
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
    
    /// Extract summary from text content (first few sentences)
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
    
    /// Get HTML content for a specific lecture (if it was imported from files)
    func getHTMLContent(for lecture: Lecture) -> String? {
        let notesByClass = loadAllNotes()
        
        for (_, notes) in notesByClass {
            if let note = notes.first(where: { $0.title == lecture.title }) {
                return note.htmlContent
            }
        }
        
        return nil
    }
}
