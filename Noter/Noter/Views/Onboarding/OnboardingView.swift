import SwiftUI
import SwiftData
import FirebaseAuth

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSaving = false
    @State private var authMode: AuthMode = .signUp
    @State private var errorMessage: String?
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 12) {
                    Text(authMode == .signUp ? "Welcome to Noter" : "Welcome back")
                        .font(.largeTitle.bold())
                    Text(authMode == .signUp
                         ? "Create an account to keep your lectures, AI summaries, and study sessions synced."
                         : "Sign in with your email to access your saved lectures and summaries.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    if authMode == .signUp {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .focused($focusedField, equals: .name)
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .focused($focusedField, equals: .email)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .focused($focusedField, equals: .password)
                }

                Button {
                    Task { await handlePrimaryAction() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(authMode.primaryButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isSaving || !isFormValid)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Button(authMode.secondaryButtonTitle) {
                    withAnimation(.smooth) {
                        toggleAuthMode()
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else { return false }
        guard trimmedPassword.count >= 6 else { return false }
        guard trimmedEmail.contains("@") else { return false }

        if authMode == .signUp {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedName.isEmpty
        }

        return true
    }

    private func toggleAuthMode() {
        authMode.toggle()
        errorMessage = nil
        focusedField = authMode == .signUp ? .name : .email
    }

    @MainActor
    private func handlePrimaryAction() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            switch authMode {
            case .signUp:
                try await createAccount()
            case .signIn:
                try await signIn()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createAccount() async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: trimmedPassword)

        if !trimmedName.isEmpty {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = trimmedName
            try await changeRequest.commitChanges()
        }

        try persistProfile(name: trimmedName, email: trimmedEmail)
    }

    private func signIn() async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try await Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword)
        let resolvedName: String

        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let displayName = result.user.displayName, !displayName.isEmpty {
            resolvedName = displayName
        } else {
            resolvedName = trimmedEmail.components(separatedBy: "@").first ?? trimmedEmail
        }

        try persistProfile(name: resolvedName, email: trimmedEmail)
    }

    @MainActor
    private func persistProfile(name: String, email: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            trimmedName = trimmedEmail.components(separatedBy: "@").first ?? trimmedEmail
        }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.email == trimmedEmail }
        )

        if let existingProfile = try modelContext.fetch(descriptor).first {
            existingProfile.name = trimmedName
        } else {
            let profile = UserProfile(name: trimmedName, email: trimmedEmail)
            modelContext.insert(profile)
        }

        try modelContext.save()
    }
}

extension OnboardingView {
    private enum AuthMode {
        case signUp
        case signIn

        mutating func toggle() {
            self = self == .signUp ? .signIn : .signUp
        }

        var primaryButtonTitle: String {
            switch self {
            case .signUp: "Create account"
            case .signIn: "Sign in"
            }
        }

        var secondaryButtonTitle: String {
            switch self {
            case .signUp: "I already have an account"
            case .signIn: "Create a new account"
            }
        }
    }

    private enum FocusField {
        case name
        case email
        case password
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PreviewContainer.container)
}
