import AppKit
import Foundation
import TachikomaCore

@MainActor
final class VoiceAssistantViewModel: ObservableObject {
    @Published private var session = VoiceAssistantSession()
    @Published var transcript = ""
    @Published var mode: ConversationMode = .consultation
    @Published var targetDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var appServerEndpoint = "http://127.0.0.1:17390/conversation"
    @Published var whisperCommand = "whisper-cli -m ~/models/ggml-small.bin -f {audio} -nt -otxt"
    @Published var voiceLevel: Float = -160
    @Published var voiceDetected = false
    @Published var connectionStatus = "未接続"

    private let executor: CodexExecuting
    private let appServer: CodexAppServerConnecting
    private let logStore: ConversationLogStore
    private let voiceInput: VoiceInputController
    private let transcriber: SpeechTranscribing

    init(
        executor: CodexExecuting = ProcessCodexExecutor(),
        appServer: CodexAppServerConnecting = CodexAppServerClient(),
        logStore: ConversationLogStore = ConversationLogStore(),
        voiceInput: VoiceInputController = VoiceInputController(),
        transcriber: SpeechTranscribing = WhisperCLITranscriber()
    ) {
        self.executor = executor
        self.appServer = appServer
        self.logStore = logStore
        self.voiceInput = voiceInput
        self.transcriber = transcriber
        self.voiceInput.onVoiceActivity = { [weak self] detected, level in
            self?.voiceDetected = detected
            self?.voiceLevel = level
        }
    }

    var state: VoiceAssistantState { session.state }
    var isMicrophoneEnabled: Bool { session.isMicrophoneEnabled }
    var messages: [ConversationMessage] { session.messages }
    var pendingPlan: ExecutionPlan? { session.pendingPlan }
    var executionLog: String { session.executionLog }
    var errorMessage: String? { session.errorMessage }
    var acceptsInput: Bool { state != .awaitingApproval && state != .executing }

    func toggleMicrophone() {
        if voiceInput.isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    func submitTranscript() {
        let text = transcript
        transcript = ""
        Task {
            await send(text)
        }
    }

    func cancelPendingPlan() {
        session.cancelPendingPlan()
    }

    func executePendingPlan() {
        guard let plan = session.markExecutionStarted() else { return }

        let executor = executor
        Task {
            let exitCode = await executor.execute(
                arguments: plan.arguments,
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

    private func startRecording() {
        Task {
            do {
                try await voiceInput.startRecording()
                session.setMicrophoneEnabled(true)
                connectionStatus = "録音中"
                try? logStore.append(ConversationLogEntry(kind: "voice", text: "recording started"))
            } catch {
                session.completeWithError(error.localizedDescription)
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard let audioURL = voiceInput.stopRecording() else {
            session.setMicrophoneEnabled(false)
            return
        }

        session.setMicrophoneEnabled(false)
        session.markTranscribing()
        connectionStatus = "文字起こし中"

        let commandTemplate = whisperCommand
        Task {
            do {
                let text = try await transcriber.transcribe(audioURL: audioURL, commandTemplate: commandTemplate) { [weak self] output in
                    Task { @MainActor in
                        self?.session.appendExecutionLog(output)
                    }
                }
                transcript = text
                try? logStore.append(ConversationLogEntry(kind: "transcript", text: text))
                await send(text)
            } catch {
                session.completeWithError(error.localizedDescription)
            }
        }
    }

    private func send(_ text: String) async {
        guard let request = session.beginTranscript(text, mode: mode, targetDirectory: targetDirectory) else {
            return
        }

        try? logStore.append(ConversationLogEntry(kind: "user", text: request.message))
        connectionStatus = "Codex App Serverへ送信中"

        do {
            let response = try await appServer.send(
                CodexConversationRequest(
                    mode: request.mode,
                    message: request.message,
                    targetDirectory: request.targetDirectory,
                    readonly: request.readonly
                ),
                endpoint: appServerEndpoint
            ) { [weak self] delta in
                Task { @MainActor in
                    self?.connectionStatus = "応答受信中"
                    self?.session.appendExecutionLog(delta)
                }
            }

            session.complete(request: request, response: response)
            connectionStatus = "応答完了"
            try? logStore.append(ConversationLogEntry(kind: "assistant", text: response.message))
        } catch {
            session.completeWithError(error.localizedDescription)
            connectionStatus = "接続エラー"
            try? logStore.append(ConversationLogEntry(kind: "error", text: error.localizedDescription))
        }
    }
}
