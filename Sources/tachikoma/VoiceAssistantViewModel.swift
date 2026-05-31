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
    private var pendingSegmentURLs: [URL] = []
    private var isTranscribingSegment = false

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
            if self?.isMicrophoneEnabled == true, self?.state == .listening {
                self?.connectionStatus = detected ? "発話検出中" : "待受中"
            }
        }
        self.voiceInput.onSegmentFinished = { [weak self] audioURL in
            self?.transcribeSegment(audioURL)
        }
    }

    var state: VoiceAssistantState { session.state }
    var isMicrophoneEnabled: Bool { session.isMicrophoneEnabled }
    var messages: [ConversationMessage] { session.messages }
    var pendingPlan: ExecutionPlan? { session.pendingPlan }
    var executionLog: String { session.executionLog }
    var errorMessage: String? { session.errorMessage }
    var acceptsInput: Bool {
        switch state {
        case .transcribing, .thinking, .awaitingApproval, .executing:
            return false
        case .idle, .listening, .completed, .error:
            return true
        }
    }

    func toggleMicrophone() {
        if voiceInput.isRecording {
            stopListening()
        } else if acceptsInput {
            startListening()
        }
    }

    func submitTranscript() {
        let text = transcript
        guard let request = session.beginTranscript(text, mode: mode, targetDirectory: targetDirectory) else {
            return
        }

        transcript = ""
        Task {
            await send(request)
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
                    try? self?.logStore.append(ConversationLogEntry(kind: "execution-output", text: output))
                }
            }
            session.markExecutionCompleted(exitCode: exitCode)
            try? logStore.append(ConversationLogEntry(kind: "execution-finished", text: "exitCode=\(exitCode)"))
        }
    }

    func stopVoiceInputForWindowClose() {
        if voiceInput.isRecording {
            _ = voiceInput.stopRecording()
            session.setMicrophoneEnabled(false)
            try? logStore.append(ConversationLogEntry(kind: "voice", text: "listening stopped because window closed"))
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

    private func startListening() {
        Task {
            do {
                try await voiceInput.startRecording()
                session.setMicrophoneEnabled(true)
                connectionStatus = "待受中"
                try? logStore.append(ConversationLogEntry(kind: "voice", text: "listening started"))
            } catch {
                session.completeWithError(error.localizedDescription)
                try? logStore.append(ConversationLogEntry(kind: "error", text: error.localizedDescription))
            }
        }
    }

    private func stopListening() {
        let audioURL = voiceInput.stopRecording()
        session.setMicrophoneEnabled(false)
        voiceDetected = false
        voiceLevel = -160
        connectionStatus = "待機中"
        try? logStore.append(ConversationLogEntry(kind: "voice", text: "listening stopped"))

        if let audioURL {
            transcribeSegment(audioURL)
        }
    }

    private func transcribeSegment(_ audioURL: URL) {
        pendingSegmentURLs.append(audioURL)
        processNextSegmentIfNeeded()
    }

    private func processNextSegmentIfNeeded() {
        guard !isTranscribingSegment, !pendingSegmentURLs.isEmpty else { return }

        isTranscribingSegment = true
        let audioURL = pendingSegmentURLs.removeFirst()
        let shouldReflectTranscription = acceptsInput
        if shouldReflectTranscription {
            session.markTranscribing()
            connectionStatus = "文字起こし中"
        }

        let commandTemplate = whisperCommand
        Task {
            do {
                let text = try await transcriber.transcribe(audioURL: audioURL, commandTemplate: commandTemplate) { [weak self] output in
                    Task { @MainActor in
                        self?.session.appendExecutionLog(output)
                    }
                }
                appendTranscriptSegment(text)
                if shouldReflectTranscription {
                    session.finishTranscribing()
                    connectionStatus = voiceInput.isRecording ? "待受中" : "待機中"
                }
                try? logStore.append(ConversationLogEntry(kind: "transcript", text: text))
            } catch {
                if shouldReflectTranscription {
                    session.completeWithError(error.localizedDescription)
                }
                try? logStore.append(ConversationLogEntry(kind: "error", text: error.localizedDescription))
            }

            isTranscribingSegment = false
            processNextSegmentIfNeeded()
        }
    }

    private func appendTranscriptSegment(_ text: String) {
        let segment = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !segment.isEmpty else { return }

        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            transcript = segment
        } else {
            transcript += "\n" + segment
        }
    }

    private func send(_ request: VoiceAssistantRequest) async {
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
