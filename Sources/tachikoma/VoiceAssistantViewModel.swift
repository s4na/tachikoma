import Foundation
import TachikomaCore

@MainActor
final class VoiceAssistantViewModel: ObservableObject {
    @Published private var session = VoiceAssistantSession()
    @Published var transcript = ""
    @Published var mode: ConversationMode = .consultation

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

    func toggleMicrophone() {
        session.setMicrophoneEnabled(!session.isMicrophoneEnabled)
    }

    func submitTranscript() {
        session.receiveTranscript(transcript, mode: mode)
        transcript = ""
    }

    func cancelPendingPlan() {
        session.cancelPendingPlan()
    }

    func executePendingPlan() {
        guard let plan = session.markExecutionStarted() else { return }

        Task {
            let exitCode = await executor.execute(command: plan.command) { [weak self] output in
                Task { @MainActor in
                    self?.session.appendExecutionLog(output)
                }
            }
            session.markExecutionCompleted(exitCode: exitCode)
        }
    }
}
