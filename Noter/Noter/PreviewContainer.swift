import Foundation
import SwiftData

enum PreviewContainer {
    static let container: ModelContainer = {
        let schema = Schema([
            StudyClass.self,
            Lecture.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        if (try? context.fetch(FetchDescriptor<StudyClass>()))?.isEmpty ?? true {
            StudyClass.mockClasses().forEach { context.insert($0) }
        }
        if (try? context.fetch(FetchDescriptor<UserProfile>()))?.isEmpty ?? true {
            context.insert(UserProfile.mockProfile())
        }

        try? context.save()
        return container
    }()
}
