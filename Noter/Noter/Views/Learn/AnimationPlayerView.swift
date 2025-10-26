import SwiftUI
import AVKit

// MARK: - Video Player View

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 12) {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 16) {
                    Button(action: replay) {
                        Label("Replay", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)

                    Button(action: shareVideo) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView("Loading video...")
                    .frame(height: 300)
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func replay() {
        player?.seek(to: .zero)
        player?.play()
    }

    private func shareVideo() {
        // Share functionality can be added here
        let activityController = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
}

// MARK: - Code Editor View

struct CodeEditorView: View {
    @Binding var code: String
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manim Code")
                    .font(.headline)

                Spacer()

                Button(action: { isEditing.toggle() }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                if isEditing {
                    TextEditor(text: $code)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxHeight: 300)

            Button(action: copyCode) {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    private func copyCode() {
        #if os(iOS)
        UIPasteboard.general.string = code
        #endif
    }
}

// MARK: - Rendering Progress View

struct RenderingProgressView: View {
    let currentAnimation: Int
    let percentage: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(percentage), total: 100) {
                Text("Rendering Animation...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)

            if currentAnimation > 0 {
                Text("Animation \(currentAnimation)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("This may take a few minutes. Please wait...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Aspect Ratio Picker

struct AspectRatioPicker: View {
    @Binding var selectedRatio: VideoAspectRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video Format")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                AspectRatioButton(ratio: .standard, selected: selectedRatio, onSelect: { selectedRatio = .standard })
                AspectRatioButton(ratio: .portrait, selected: selectedRatio, onSelect: { selectedRatio = .portrait })
                AspectRatioButton(ratio: .square, selected: selectedRatio, onSelect: { selectedRatio = .square })
            }
        }
    }
}

struct AspectRatioButton: View {
    let ratio: VideoAspectRatio
    let selected: VideoAspectRatio
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Text(ratio.description)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected == ratio ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(selected == ratio ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

// MARK: - Topic Input View

struct TopicInputView: View {
    @Binding var topic: String
    let onGenerate: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animation Topic")
                .font(.headline)

            TextField("Enter a topic or concept to animate...", text: $topic, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .disabled(isLoading)

            Button(action: onGenerate) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Generate Animation Code", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(topic.isEmpty || isLoading)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TopicInputView(
            topic: .constant("Pythagorean theorem"),
            onGenerate: {},
            isLoading: false
        )

        RenderingProgressView(currentAnimation: 2, percentage: 65)

        CodeEditorView(code: .constant("""
from manim import *

class GenScene(Scene):
    def construct(self):
        circle = Circle()
        self.play(Create(circle))
"""))
    }
    .padding()
}
