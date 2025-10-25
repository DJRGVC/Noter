import SwiftUI

struct AccountSetupView: View {
    @State private var name: String
    @State private var email: String
    @State private var goal: String = ""
    @FocusState private var focusedField: Field?
    var onComplete: (String, String) -> Void

    init(name: String, email: String, onComplete: @escaping (String, String) -> Void) {
        _name = State(initialValue: name)
        _email = State(initialValue: email)
        self.onComplete = onComplete
    }

    enum Field {
        case name, email, goal
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 72))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white.opacity(0.9), .blue)
                        .padding(.bottom, 8)
                    Text("Create your study profile")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("We will personalize your AI-powered notes and study flows once you are in.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                VStack(spacing: 16) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                    TextField("Study goal (optional)", text: $goal)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .goal)
                        .submitLabel(.done)
                }
                .padding()
                .background(.thinMaterial, in: .rect(cornerRadius: 24))
                .glassBackgroundEffect()

                Button(action: continueTapped) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient, in: .capsule)
                        .foregroundStyle(.white)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || email.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)

                Spacer()
                Text("Notes are securely stored locally and sync once you enable iCloud in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .background(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private func continueTapped() {
        onComplete(name, email)
    }
}

#Preview {
    AccountSetupView(name: "", email: "") { _, _ in }
}
