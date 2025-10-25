import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(activeProfile: profile)
                    .transition(.opacity.combined(with: .scale))
            } else {
                OnboardingView()
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.smooth(duration: 0.25), value: profiles.first?.id)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.container)
}
