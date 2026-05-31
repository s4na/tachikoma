import Foundation

public protocol CodexExecuting: Sendable {
    func execute(
        arguments: [String],
        workingDirectory: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32
}

public struct ProcessCodexExecutor: CodexExecuting {
    public init() {}

    public func execute(
        arguments: [String],
        workingDirectory: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["codex"] + arguments
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            process.environment = Self.environment()

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                    return
                }
                onOutput(text)
            }

            process.terminationHandler = { terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let remainingData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingData.isEmpty, let text = String(data: remainingData, encoding: .utf8) {
                    onOutput(text)
                }
                continuation.resume(returning: terminatedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                onOutput("Failed to start codex exec: \(error.localizedDescription)\n")
                outputPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: 127)
            }
        }
    }

    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.npm-global/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        environment["PATH"] = (commonPaths + [existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        return environment
    }
}
