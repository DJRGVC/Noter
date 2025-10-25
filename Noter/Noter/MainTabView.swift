import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""

    var body: some View {
        TabView {
            ClassesTabView()
                .tabItem {
                    Label("Classes", systemImage: "books.vertical")
                }

            LearnTabView()
                .tabItem {
                    Label("Learn", systemImage: "brain.head.profile")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            // Preload data if the container is empty for brand-new accounts.
            if (try? modelContext.fetch(FetchDescriptor<StudyClass>()))?.isEmpty == true {
                StudyClass.mockData(context: modelContext)
                try? modelContext.save()
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.thinMaterial, for: .tabBar)
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [StudyClass.self, Lecture.self, LectureNote.self], inMemory: true)
}
