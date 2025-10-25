import SwiftUI

struct SettingsTabView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("aiModel") private var aiModel = "GPT-4"
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("useICloudSync") private var useICloudSync = false
    @AppStorage("defaultNoteLength") private var defaultNoteLength: Double = 3
    @AppStorage("studyReminders") private var studyReminders = false

    private let models = ["GPT-4", "Claude", "Gemini", "Custom"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: 56, height: 56)
                            .overlay(Text(initials(from: userName)).font(.title3.bold()).foregroundStyle(.white))
                        VStack(alignment: .leading) {
                            TextField("Name", text: $userName)
                            TextField("Email", text: $userEmail)
                                .keyboardType(.emailAddress)
                        }
                    }
                    Text("We'll use this info on generated study plans and share with your future classmates when collaboration lands.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("AI Configuration") {
                    Picker("Model", selection: $aiModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    SecureField("API Key", text: $apiKey)
                    Text("Store provider credentials securely via the keychain in production.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Future integration: route transcripts through your AI client, stream summaries back here.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Section("Sync") {
                    Toggle("Sync with iCloud", isOn: $useICloudSync)
                    Button("Export data") {
                        // Export logic: gather StudyClass data and share using ShareLink or FileExporter.
                    }
                    .buttonStyle(.borderless)
                    Text("Hook this button up to a JSON/CSV export for backup or LMS import.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Study Preferences") {
                    Slider(value: $defaultNoteLength, in: 1...5, step: 1) {
                        Text("Default Summary Depth")
                    } minimumValueLabel: {
                        Text("Short")
                    } maximumValueLabel: {
                        Text("Detailed")
                    }
                    Toggle("Study reminders", isOn: $studyReminders)
                    Text("Use this slider to tell AI how verbose to make your generated summaries.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Reminder toggle will later connect to notification scheduling.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(footer: Text("Add more study tools (mind maps, spaced repetition) by extending LearnTabView to handle new modes.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        if initials.isEmpty {
            return "👤"
        }
        return initials.map(String.init).joined()
    }
}

#Preview {
    SettingsTabView()
}
