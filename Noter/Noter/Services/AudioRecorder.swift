import Foundation
import AVFoundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    enum RecorderState: Equatable {
        case idle
        case recording
        case paused
    }

    @Published private(set) var state: RecorderState = .idle
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var averagePower: Float = -160

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentRecordingURL: URL?

    deinit {
        stopMonitoring()
        recorder?.stop()
        recorder?.delegate = nil
        recorder = nil
    }


    func prepareAndStart() async throws {
        guard state == .idle else { return }
        let session = AVAudioSession.sharedInstance()
        try await ensurePermission(session: session)
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("lecture-\(UUID().uuidString).m4a")
        currentRecordingURL = temporaryURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: temporaryURL, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.delegate = self
        elapsedTime = 0
        averagePower = -160
        recorder?.record()
        startMonitoring()
        state = .recording
    }

    func pause() {
        guard state == .recording else { return }
        recorder?.pause()
        stopMonitoring()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        recorder?.record()
        startMonitoring()
        state = .recording
    }

    func finishRecording() throws -> URL {
        guard let recorder, let url = currentRecordingURL else {
            throw LectureMediaStoreError.invalidSource
        }
        recorder.stop()
        stopMonitoring()
        state = .idle
        recorder.delegate = nil
        self.recorder = nil
        currentRecordingURL = nil
        return url
    }

    func discardRecording() {
        guard let url = currentRecordingURL else {
            reset()
            return
        }
        stopMonitoring()
        recorder?.stop()
        recorder?.delegate = nil
        recorder = nil
        currentRecordingURL = nil
        try? FileManager.default.removeItem(at: url)
        reset()
    }

    private func reset() {
        elapsedTime = 0
        averagePower = -160
        state = .idle
    }

    private func startMonitoring() {
        stopMonitoring() // always clear existing timer first

        // Create a local weak reference to avoid implicit capture of self
        weak var weakSelf = self

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let strongSelf = weakSelf else { return }

            Task { @MainActor in
                strongSelf.recorder?.updateMeters()
                strongSelf.elapsedTime = strongSelf.recorder?.currentTime ?? strongSelf.elapsedTime
                strongSelf.averagePower = strongSelf.recorder?.averagePower(forChannel: 0) ?? -160
            }
        }

        if let meterTimer {
            RunLoop.main.add(meterTimer, forMode: .common)
        }
    }


    private func stopMonitoring() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func ensurePermission(session: AVAudioSession) async throws {
        let granted: Bool

        if #available(iOS 17, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }

        guard granted else {
            throw LectureMediaStoreError.microphoneAccessDenied
        }
    }

}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        // hop back to main actor for UI-related cleanup
        Task { @MainActor in
            discardRecording()
        }
    }
}

