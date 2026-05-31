import Foundation

protocol SpeechTranscribing: Sendable {
    func transcribe(
        audioURL: URL,
        commandTemplate: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

struct WhisperCLITranscriber: SpeechTranscribing {
    func transcribe(
        audioURL: URL,
        commandTemplate: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let command = commandTemplate
            .replacingOccurrences(of: "{audio}", with: shellQuoted(audioURL.path))
            .replacingOccurrences(of: "{audio_basename}", with: shellQuoted(audioURL.deletingPathExtension().path))

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            let output = OutputBuffer()
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                output.append(text)
                onOutput(text)
            }

            process.terminationHandler = { terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let remainingData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingData.isEmpty, let text = String(data: remainingData, encoding: .utf8) {
                    output.append(text)
                    onOutput(text)
                }

                let finalOutput = output.value
                if terminatedProcess.terminationStatus == 0 {
                    continuation.resume(returning: Self.bestTranscript(from: finalOutput, audioURL: audioURL))
                } else {
                    continuation.resume(throwing: WhisperTranscriberError.failed(finalOutput))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func bestTranscript(from output: String, audioURL: URL) -> String {
        let candidateTextURLs = [
            URL(fileURLWithPath: audioURL.path + ".txt"),
            audioURL.deletingPathExtension().appendingPathExtension("txt")
        ]

        for textURL in candidateTextURLs {
            if let text = try? String(contentsOf: textURL, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return output
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        text += value
    }
}

enum WhisperTranscriberError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let output):
            return "whisper.cpp の文字起こしに失敗しました: \(output)"
        }
    }
}
