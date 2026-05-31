import AppKit
import Foundation
import TachikomaCore

@MainActor
final class VoiceAssistantViewModel: ObservableObject {
    @Published private var session = VoiceAssistantSession()
    @Published var transcript = ""
    @Published var mode: ConversationMode = .consultation
    @Published var targetDirectory = FileManager.default.homeDirectoryForCurrentUser.path

    private let executor: CodexExecuting

    init(executor: CodexExecuting = ProcessCodexExecutor()) {
        self.executor = executor
    }

    var state: VoiceAssistantState { session.state }
    var isMicrophoneEnabled: Bool { session.isMicrophoneEnabled }
    var messages: [ConversationMessage] { session.messages }
    var pendingPlan: ExecutionPlan? { session.pendingPlan }
    var executionLog: String { session.executionLog }
    var errorMessage: String? { session.errorMessage }
    var acceptsInput: Bool { state != .awaitingApproval && state != .executing }

    func toggleMicrophone() {
        session.setMicrophoneEnabled(!session.isMicrophoneEnabled)
    }

    func submitTranscript() {
        session.receiveTranscript(transcript, mode: mode, targetDirectory: targetDirectory)
        transcript = ""
    }

    func cancelPendingPlan() {
        session.cancelPendingPlan()
    }

    func executePendingPlan() {
        guard let plan = session.markExecutionStarted() else { return }

        let executor = executor
        Task {
            let exitCode = await executor.execute(
                command: plan.command,
                workingDirectory: plan.targetDirectory
            ) { [weak self] output in
                Task { @MainActor in
                    self?.session.appendExecutionLog(output)
                }
            }
            session.markExecutionCompleted(exitCode: exitCode)
        }
    }

    func chooseTargetDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: targetDirectory, isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            targetDirectory = url.path
        }
    }
}
