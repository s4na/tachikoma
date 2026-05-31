import AVFoundation
import Foundation

@MainActor
final class VoiceInputController: NSObject {
    var onVoiceActivity: ((Bool, Float) -> Void)?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meterTimer: Timer?
    private var silentTicks = 0

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() async throws {
        guard !isRecording else { return }
        guard await requestMicrophoneAccess() else {
            throw VoiceInputError.microphonePermissionDenied
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tachikoma-recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()

        self.recorder = recorder
        recordingURL = url
        silentTicks = 0
        startMetering()
    }

    func stopRecording() -> URL? {
        guard let recorder else { return recordingURL }
        recorder.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        self.recorder = nil
        onVoiceActivity?(false, -160)
        return recordingURL
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMeter()
            }
        }
    }

    private func updateMeter() {
        guard let recorder, recorder.isRecording else { return }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let speaking = power > -45
        silentTicks = speaking ? 0 : silentTicks + 1
        onVoiceActivity?(speaking || silentTicks < 4, power)
    }
}

enum VoiceInputError: Error, LocalizedError {
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "マイク権限が許可されていません。"
        }
    }
}
