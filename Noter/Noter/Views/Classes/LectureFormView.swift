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
    @State private var recordings: [LectureRecording] = []
    @State private var isPersistingFiles = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var importIntent: ImportIntent = .recording
    @State private var didCommitChanges = false

    @StateObject private var recorder = AudioRecorder()

    let studyClass: StudyClass

    private enum ImportIntent {
        case recording
        case supplemental
    }

    private var allowedContentTypes: [UTType] {
        switch importIntent {
        case .recording:
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
                if recordings.isEmpty {
                    Text("Record a lecture or import existing audio to build a library of study-ready recordings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                } else {
                    ForEach(recordings) { recording in
                        RecordingSummaryRow(recording: recording) {
                            removeRecording(recording)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { recordings[$0].id }
                        ids.forEach { id in
                            if let recording = recordings.first(where: { $0.id == id }) {
                                removeRecording(recording)
                            }
                        }
                    }
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

                Button(action: beginRecordingImport) {
                    Label("Import Recording", systemImage: "square.and.arrow.down")
                }
                .disabled(isPersistingFiles)

                Button(action: beginSupplementalImport) {
                    Label("Import Supplemental Files", systemImage: "paperclip")
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

            if !attachments.isEmpty {
                Section("Supplemental Files") {
                    ForEach(attachments) { attachment in
                        AttachmentRow(attachment: attachment) {
                            removeAttachment(withID: attachment.id, deletingFile: true)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { attachments[$0].id }
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
                cleanupStoredRecordings()
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
            let duration = recorder.elapsedTime
            do {
                let recordingURL = try recorder.finishRecording()
                tempURL = recordingURL
                isPersistingFiles = true
                defer { isPersistingFiles = false }
                let attachment = try LectureMediaStore.shared.persistRecording(
                    from: recordingURL,
                    suggestedName: "\(trimmedTitle.isEmpty ? "Lecture Recording" : trimmedTitle).m4a"
                )
                let recording = makeRecording(from: attachment, duration: duration)
                recordings.insert(recording, at: 0)
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
                case .recording:
                    guard let url = urls.first else { return }
                    let attachment = try storeAttachment(from: url)
                    guard attachment.type == .audio else {
                        throw LectureMediaStoreError.invalidSource
                    }
                    let recording = makeRecording(from: attachment, duration: nil)
                    recordings.insert(recording, at: 0)
                case .supplemental:
                    for url in urls {
                        let attachment = try storeAttachment(from: url)
                        if attachment.type == .audio {
                            let recording = makeRecording(from: attachment, duration: nil)
                            recordings.insert(recording, at: 0)
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

    private func removeAttachment(withID id: UUID, deletingFile: Bool) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        let removed = attachments.remove(at: index)
        if deletingFile, let stored = removed.storedFileName {
            LectureMediaStore.shared.removeStoredFile(named: stored)
        }
    }

    private func removeRecording(_ recording: LectureRecording) {
        recordings.removeAll { $0.id == recording.id }
        if let stored = recording.storedFileName {
            LectureMediaStore.shared.removeStoredFile(named: stored)
        }
        if recording.remoteURL != nil || recording.storagePath != nil {
            Task {
                do {
                    try await FirebaseLectureRecordingStore.shared.deleteRemoteArtifacts(for: recording.remoteReference)
                } catch {
                    print("Failed to delete remote recording: \(error.localizedDescription)")
                }
            }
        }
    }

    private func makeRecording(from attachment: LectureAttachment, duration: TimeInterval?) -> LectureRecording {
        LectureRecording(
            storedFileName: attachment.storedFileName,
            originalFileName: attachment.displayName,
            fileSize: attachment.fileSize,
            contentType: attachment.contentType,
            duration: duration
        )
    }

    private func beginRecordingImport() {
        importIntent = .recording
        showingFileImporter = true
    }

    private func beginSupplementalImport() {
        importIntent = .supplemental
        showingFileImporter = true
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
            slideReference: slideURL,
            attachments: attachments,
            recordings: recordings
        )
        studyClass.addLecture(lecture, context: modelContext)
        try? modelContext.save()
        didCommitChanges = true
        let context = modelContext
        let classID = studyClass.id
        let pendingRecordings = recordings
        if !pendingRecordings.isEmpty {
            Task { @MainActor in
                for recording in pendingRecordings {
                    do {
                        let result = try await FirebaseLectureRecordingStore.shared.sync(
                            context: recording.syncContext,
                            lectureID: lecture.id,
                            classID: classID
                        )
                        recording.remoteURLString = result.remoteURLString
                        recording.storagePath = result.storagePath
                        try? context.save()
                    } catch {
                        print("Failed to sync recording: \(error.localizedDescription)")
                    }
                }
            }
        }
        dismiss()
    }

    private func cancel() {
        cleanupStoredAttachments()
        cleanupStoredRecordings()
        dismiss()
    }

    private func cleanupStoredAttachments() {
        attachments.forEach { attachment in
            if let stored = attachment.storedFileName {
                LectureMediaStore.shared.removeStoredFile(named: stored)
            }
        }
    }

    private func cleanupStoredRecordings() {
        recordings.forEach { recording in
            if let stored = recording.storedFileName {
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

private struct RecordingSummaryRow: View {
    let recording: LectureRecording
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.displayName)
                    .font(.body)

                if let duration = recording.formattedDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let size = recording.formattedFileSize {
                    Text(size)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(recording.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shareURL = recording.shareableURL {
                if shareURL.isFileURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "arrow.up.forward.app")
                            .imageScale(.medium)
                    }
                } else {
                    Link(destination: shareURL) {
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
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        LectureFormView(studyClass: StudyClass.mockClasses().first!)
    }
    .modelContainer(PreviewContainer.container)
}
