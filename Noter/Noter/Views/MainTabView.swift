import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selection: Tab = .classes
    var activeProfile: UserProfile

    enum Tab: Hashable {
        case classes
        case learn
        case settings

        var title: String {
            switch self {
            case .classes: "Classes"
            case .learn: "Learn"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .classes: "rectangle.stack"
            case .learn: "brain"
            case .settings: "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            ClassesHome()
                .tabItem { Label(Tab.classes.title, systemImage: Tab.classes.systemImage) }
                .tag(Tab.classes)

            LearnHome(activeProfile: activeProfile)
                .tabItem { Label(Tab.learn.title, systemImage: Tab.learn.systemImage) }
                .tag(Tab.learn)

            SettingsHome(activeProfile: activeProfile)
                .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.systemImage) }
                .tag(Tab.settings)
        }
        .background(.regularMaterial)
    }
}

#Preview {
    MainTabView(activeProfile: .mockProfile())
        .modelContainer(PreviewContainer.container)
}
