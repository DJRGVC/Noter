import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LectureFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var summary: String = ""
    @State private var slideURLString: String = ""
    @State private var attachments: [LectureAttachment] = []
    @State private var primaryAudioID: UUID?
    @State private var isPersistingFiles = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var importIntent: ImportIntent = .supplemental
    @State private var didCommitChanges = false

    @StateObject private var recorder = AudioRecorder()

    let studyClass: StudyClass

    private enum ImportIntent {
        case primaryAudio
        case supplemental
    }

    private var primaryAudioAttachment: LectureAttachment? {
        attachments.first(where: { $0.id == primaryAudioID })
    }

    private var supplementalAttachments: [LectureAttachment] {
        attachments.filter { $0.id != primaryAudioID }
    }

    private var allowedContentTypes: [UTType] {
        switch importIntent {
        case .primaryAudio:
            return [.audio]
        case .supplemental:
            return [.audio, .pdf]
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        trimmedTitle.isEmpty || recorder.state == .recording || isPersistingFiles
    }

    var body: some View {
        Form {
            Section("Lecture Info") {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Summary", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                if let audio = primaryAudioAttachment {
                    PrimaryAudioSummary(attachment: audio, onRemove: removePrimaryAudio)
                        .padding(.bottom, 4)
                } else {
                    Text("Record a lecture or import an existing audio file to make it available for transcription and study aides.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                RecordingInterfaceView(
                    recorder: recorder,
                    isPersisting: isPersistingFiles,
                    onStart: startRecording,
                    onPause: recorder.pause,
                    onResume: recorder.resume,
                    onFinish: finalizeRecording,
                    onDiscard: recorder.discardRecording
                )
                .padding(.vertical, 4)

                Button {
                    importIntent = primaryAudioAttachment == nil ? .primaryAudio : .supplemental
                    showingFileImporter = true
                } label: {
                    Label(primaryAudioAttachment == nil ? "Import Audio" : "Import Media", systemImage: "square.and.arrow.down")
                }
                .disabled(isPersistingFiles)

                if isPersistingFiles {
                    ProgressView("Saving media…")
                        .font(.footnote)
                }
            } header: {
                Text("Lecture Media")
            } footer: {
                if recorder.state == .recording {
                    Text("Finish or pause the recording before saving the lecture.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !supplementalAttachments.isEmpty {
                Section("Supplemental Files") {
                    ForEach(supplementalAttachments) { attachment in
                        AttachmentRow(attachment: attachment) {
                            removeAttachment(withID: attachment.id, deletingFile: true)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { supplementalAttachments[$0].id }
                        ids.forEach { removeAttachment(withID: $0, deletingFile: true) }
                    }
                }
            }

            Section("Slides & Links") {
                TextField("Slides URL", text: $slideURLString)
                    .keyboardType(.URL)
                    .textContentType(.URL)
            }
        }
        .navigationTitle("New Lecture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(isSaveDisabled)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: importIntent == .supplemental
        ) { result in
            switch result {
            case .success(let urls):
                handleImportedFiles(urls)
            case .failure(let error):
                presentError(error.localizedDescription)
            }
        }
        .alert("Media Error", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .onDisappear {
            if recorder.state != .idle {
                recorder.discardRecording()
            }
            if !didCommitChanges {
                cleanupStoredAttachments()
            }
        }
    }

    private func startRecording() {
        Task {
            do {
                try await recorder.prepareAndStart()
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func finalizeRecording() {
        Task {
            var tempURL: URL?
            do {
                let recordingURL = try recorder.finishRecording()
                tempURL = recordingURL
                isPersistingFiles = true
                defer { isPersistingFiles = false }
                let attachment = try LectureMediaStore.shared.persistRecording(from: recordingURL, suggestedName: "\(trimmedTitle.isEmpty ? "Lecture Recording" : trimmedTitle).m4a")
                setPrimaryAudioAttachment(attachment)
            } catch {
                if let tempURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                presentError(error.localizedDescription)
            }
        }
    }

    private func handleImportedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isPersistingFiles = true
        Task {
            defer { isPersistingFiles = false }
            do {
                switch importIntent {
                case .primaryAudio:
                    guard let url = urls.first else { return }
                    let attachment = try storeAttachment(from: url)
                    guard attachment.type == .audio else {
                        throw LectureMediaStoreError.invalidSource
                    }
                    setPrimaryAudioAttachment(attachment)
                case .supplemental:
                    for url in urls {
                        let attachment = try storeAttachment(from: url)
                        if attachment.type == .audio && primaryAudioID == nil {
                            setPrimaryAudioAttachment(attachment)
                        } else {
                            attachments.append(attachment)
                        }
                    }
                }
            } catch {
                presentError(error.localizedDescription)
            }
            importIntent = .supplemental
        }
    }

    private func storeAttachment(from url: URL) throws -> LectureAttachment {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        return try LectureMediaStore.shared.persistImportedFile(at: url)
    }

    private func setPrimaryAudioAttachment(_ attachment: LectureAttachment) {
        if let existingID = primaryAudioID {
            removeAttachment(withID: existingID, deletingFile: true)
        }
        attachments.append(attachment)
        primaryAudioID = attachment.id
    }

    private func removePrimaryAudio() {
        if let primaryAudioID {
            removeAttachment(withID: primaryAudioID, deletingFile: true)
            self.primaryAudioID = nil
        }
    }

    private func removeAttachment(withID id: UUID, deletingFile: Bool) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        let removed = attachments.remove(at: index)
        if deletingFile, let stored = removed.storedFileName {
            LectureMediaStore.shared.removeStoredFile(named: stored)
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func save() {
        let slideURL = URL(string: slideURLString.trimmingCharacters(in: .whitespacesAndNewlines))
        let lecture = Lecture(
            title: trimmedTitle,
            date: date,
            summary: summary,
            audioReference: primaryAudioAttachment?.resolvedURL,
            slideReference: slideURL
        )
        lecture.attachments = attachments
        studyClass.addLecture(lecture, context: modelContext)
        try? modelContext.save()
        didCommitChanges = true
        dismiss()
    }

    private func cancel() {
        cleanupStoredAttachments()
        dismiss()
    }

    private func cleanupStoredAttachments() {
        attachments.forEach { attachment in
            if let stored = attachment.storedFileName {
                LectureMediaStore.shared.removeStoredFile(named: stored)
            }
        }
    }
}

private struct RecordingInterfaceView: View {
    @ObservedObject var recorder: AudioRecorder
    var isPersisting: Bool
    var onStart: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onFinish: () -> Void
    var onDiscard: () -> Void

    private var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: recorder.elapsedTime) ?? "00:00"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Recorder", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                StatusBadge(state: recorder.state)
            }

            Text(formattedTime)
                .font(.system(.title, design: .monospaced, weight: .medium))

            AudioLevelView(power: recorder.averagePower)
                .frame(height: 12)

            HStack(spacing: 12) {
                switch recorder.state {
                case .idle:
                    Button(action: onStart) {
                        Label("Start Recording", systemImage: "record.circle")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPersisting)
                case .recording:
                    Button(action: onPause) {
                        Label("Pause", systemImage: "pause.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onFinish) {
                        Label("Finish", systemImage: "stop.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel, action: onDiscard) {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                case .paused:
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onFinish) {
                        Label("End Recording", systemImage: "stop.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel, action: onDiscard) {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.45), .purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
        }
    }
}

private struct StatusBadge: View {
    let state: AudioRecorder.RecorderState

    var body: some View {
        switch state {
        case .idle:
            Text("Ready")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        case .recording:
            Label("Recording", systemImage: "dot.circle.and.hand.point.up.left.fill")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2), in: Capsule())
                .foregroundStyle(.red)
        case .paused:
            Label("Paused", systemImage: "pause.circle")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(.orange)
        }
    }
}

private struct AudioLevelView: View {
    var power: Float

    private var normalized: CGFloat {
        let clamped = max(-60, min(0, power))
        return CGFloat((clamped + 60) / 60)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * normalized)
                    .animation(.easeInOut(duration: 0.2), value: normalized)
            }
        }
    }
}

private struct AttachmentRow: View {
    let attachment: LectureAttachment
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol(for: attachment.type))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.displayName)
                if let size = attachment.formattedFileSize {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let url = attachment.resolvedURL {
                if url.isFileURL {
                    ShareLink(item: url) {
                        Image(systemName: "arrow.up.forward.app")
                            .imageScale(.medium)
                    }
                } else {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.forward.app")
                            .imageScale(.medium)
                    }
                }
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func symbol(for type: LectureAttachment.AttachmentType) -> String {
        switch type {
        case .audio: return "waveform"
        case .document: return "doc.text"
        case .link: return "link"
        case .other: return "paperclip"
        }
    }
}

private struct PrimaryAudioSummary: View {
    let attachment: LectureAttachment
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Primary Audio", systemImage: "headphones")
                    .font(.headline)
                Spacer()
                if let url = attachment.resolvedURL {
                    if url.isFileURL {
                        ShareLink(item: url) {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.forward.app")
                        }
                    }
                }
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            Text(attachment.displayName)
                .font(.body)

            if let size = attachment.formattedFileSize {
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        LectureFormView(studyClass: StudyClass.mockClasses().first!)
    }
    .modelContainer(PreviewContainer.container)
}
