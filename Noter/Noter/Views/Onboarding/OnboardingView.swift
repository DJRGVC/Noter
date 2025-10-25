import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 12) {
                    Text("Welcome to Noter")
                        .font(.largeTitle.bold())
                    Text("Create an account to keep your lectures, AI summaries, and study sessions synced.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    Task { await createProfile() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Create account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("I already have an account") {
                    // Future: present sign-in with Apple / passkey / email login flow.
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func createProfile() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email)
        modelContext.insert(profile)
        try? modelContext.save()
        // Add seeding of demo content for new accounts here if desired.
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PreviewContainer.container)
}
