import AVFoundation
import Foundation

@MainActor
final class VoiceInputController: NSObject {
    var onVoiceActivity: ((Bool, Float) -> Void)?
    var onSegmentFinished: ((URL) -> Void)?

    private let engine = AVAudioEngine()
    private var segmentFile: AVAudioFile?
    private var segmentURL: URL?
    private var silentFrames = 0
    private var segmentFrames = 0
    private var lastPower: Float = -160

    private let speechThreshold: Float = -45
    private let silenceDurationFrames = 16_000
    private let minimumSegmentFrames = 4_000

    var isRecording: Bool {
        engine.isRunning
    }

    func startRecording() async throws {
        guard !isRecording else { return }
        guard await requestMicrophoneAccess() else {
            throw VoiceInputError.microphonePermissionDenied
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.process(buffer: buffer, format: format)
            }
        }

        try engine.start()
        onVoiceActivity?(false, lastPower)
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onVoiceActivity?(false, -160)
        return finishSegment(force: true)
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func process(buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        let power = averagePower(for: buffer)
        lastPower = power
        let speaking = power > speechThreshold

        if speaking {
            silentFrames = 0
            if segmentFile == nil {
                startSegment(format: format)
            }
        } else if segmentFile != nil {
            silentFrames += Int(buffer.frameLength)
        }

        if segmentFile != nil {
            do {
                try segmentFile?.write(from: buffer)
                segmentFrames += Int(buffer.frameLength)
            } catch {
                finishSegment(force: true)
            }
        }

        onVoiceActivity?(speaking || segmentFile != nil, power)

        if segmentFile != nil, silentFrames >= silenceDurationFrames {
            let finishedURL = finishSegment(force: false)
            if let finishedURL {
                onSegmentFinished?(finishedURL)
            }
        }
    }

    private func startSegment(format: AVAudioFormat) {
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("tachikoma-recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
            segmentFile = try AVAudioFile(forWriting: url, settings: format.settings)
            segmentURL = url
            segmentFrames = 0
            silentFrames = 0
        } catch {
            segmentFile = nil
            segmentURL = nil
        }
    }

    @discardableResult
    private func finishSegment(force: Bool) -> URL? {
        defer {
            segmentFile = nil
            segmentURL = nil
            segmentFrames = 0
            silentFrames = 0
        }

        guard let url = segmentURL else { return nil }
        guard force || segmentFrames >= minimumSegmentFrames else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        return url
    }

    private func averagePower(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return -160
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0, channelCount > 0 else {
            return -160
        }

        var squareSum: Float = 0
        for channel in 0 ..< channelCount {
            let samples = channelData[channel]
            for frame in 0 ..< frameLength {
                let sample = samples[frame]
                squareSum += sample * sample
            }
        }

        let meanSquare = squareSum / Float(frameLength * channelCount)
        guard meanSquare > 0 else {
            return -160
        }
        return 10 * log10(meanSquare)
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
