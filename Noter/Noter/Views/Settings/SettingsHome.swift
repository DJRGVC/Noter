import SwiftUI
import SwiftData

struct SettingsHome: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var email: String
    @State private var selectedModel: ModelProvider = .gpt4o
    @State private var apiKey: String = ""
    @State private var enableICloudSync = true
    @State private var noteLength: Double = 3
    @State private var remindersEnabled = false

    let activeProfile: UserProfile

    init(activeProfile: UserProfile) {
        self.activeProfile = activeProfile
        _name = State(initialValue: activeProfile.name)
        _email = State(initialValue: activeProfile.email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 64, height: 64)
                            .overlay { Image(systemName: "person.crop.circle") .font(.largeTitle) }
                        VStack(alignment: .leading) {
                            TextField("Name", text: $name)
                                .textContentType(.name)
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("AI Configuration") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(ModelProvider.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    SecureField("API Key", text: $apiKey)
                    Text("Provide an API key to enable live AI note generation and analysis.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("In production, securely store keys in the keychain and proxy requests through your backend if desired.")
                }

                Section("Sync") {
                    Toggle("Sync with iCloud", isOn: $enableICloudSync)
                    Button("Export Data") {
                        // Integrate ShareLink or custom export for JSON/Markdown packages here.
                    }
                } footer: {
                    Text("Hook into CloudKit/SwiftData sync here to keep notes up to date across devices.")
                }

                Section("Study Preferences") {
                    HStack {
                        Text("Default note length")
                        Slider(value: $noteLength, in: 1...5, step: 1)
                    }
                    Toggle("Study reminders", isOn: $remindersEnabled)
                } footer: {
                    Text("Use this section to map to Notifications + custom AI prompts for tailored study plans.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: persist)
                }
            }
        }
    }

    private func persist() {
        activeProfile.name = name
        activeProfile.email = email
        try? modelContext.save()
    }
}

private enum ModelProvider: String, CaseIterable, Identifiable {
    case gpt4o
    case claude
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: "GPT-4o"
        case .claude: "Claude 3"
        case .gemini: "Gemini Advanced"
        }
    }
}

#Preview {
    SettingsHome(activeProfile: .mockProfile())
        .modelContainer(PreviewContainer.container)
}
