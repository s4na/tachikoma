import Foundation

public enum VoiceAssistantState: String, CaseIterable, Equatable {
    case idle
    case listening
    case transcribing
    case thinking
    case awaitingApproval
    case executing
    case completed
    case error
}

public enum ConversationMode: String, CaseIterable, Codable, Equatable, Sendable {
    case consultation
    case instruction

    public var title: String {
        switch self {
        case .consultation:
            return "相談"
        case .instruction:
            return "命令"
        }
    }
}

public enum ConversationRole: String, Equatable {
    case user
    case assistant
    case system
}

public struct ConversationMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: ConversationRole
    public let text: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        role: ConversationRole,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

public struct ExecutionPlan: Equatable {
    public let request: String
    public let targetDirectory: String
    public let affectedFiles: [String]
    public let workItems: [String]
    public let impact: String
    public let command: String
    public let arguments: [String]

    public init(
        request: String,
        targetDirectory: String,
        affectedFiles: [String],
        workItems: [String],
        impact: String,
        command: String,
        arguments: [String]
    ) {
        self.request = request
        self.targetDirectory = targetDirectory
        self.affectedFiles = affectedFiles
        self.workItems = workItems
        self.impact = impact
        self.command = command
        self.arguments = arguments
    }
}

public struct VoiceAssistantRequest: Equatable, Sendable {
    public let id: UUID
    public let mode: ConversationMode
    public let message: String
    public let targetDirectory: String
    public let readonly: Bool
}

public struct VoiceAssistantSnapshot: Equatable {
    public let state: VoiceAssistantState
    public let isMicrophoneEnabled: Bool
    public let messages: [ConversationMessage]
    public let pendingPlan: ExecutionPlan?
    public let executionLog: String
    public let errorMessage: String?
}

public struct VoiceAssistantSession {
    public private(set) var state: VoiceAssistantState = .idle
    public private(set) var isMicrophoneEnabled = false
    public private(set) var messages: [ConversationMessage] = []
    public private(set) var pendingPlan: ExecutionPlan?
    public private(set) var executionLog = ""
    public private(set) var errorMessage: String?
    private var activeRequestID: UUID?

    public init() {}

    public var snapshot: VoiceAssistantSnapshot {
        VoiceAssistantSnapshot(
            state: state,
            isMicrophoneEnabled: isMicrophoneEnabled,
            messages: messages,
            pendingPlan: pendingPlan,
            executionLog: executionLog,
            errorMessage: errorMessage
        )
    }

    public mutating func setMicrophoneEnabled(_ enabled: Bool) {
        isMicrophoneEnabled = enabled

        switch state {
        case .transcribing, .thinking, .awaitingApproval, .executing:
            break
        default:
            state = enabled ? .listening : .idle
        }

        appendSystemMessage(enabled ? "マイクをONにしました。" : "マイクをOFFにしました。")
    }

    public mutating func beginTranscript(
        _ transcript: String,
        mode: ConversationMode,
        targetDirectory: String
    ) -> VoiceAssistantRequest? {
        guard !isBusy else {
            appendSystemMessage("処理中の依頼があります。完了、実行、またはキャンセルしてから送信してください。")
            return nil
        }

        let request = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else {
            fail("発話または入力が空です。")
            return nil
        }

        let directory = targetDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isExistingDirectory(directory) else {
            fail("対象ディレクトリが存在しません。")
            return nil
        }

        errorMessage = nil
        pendingPlan = nil
        state = .thinking
        let requestID = UUID()
        activeRequestID = requestID
        appendMessage(role: .user, text: request)

        return VoiceAssistantRequest(
            id: requestID,
            mode: mode,
            message: request,
            targetDirectory: directory,
            readonly: true
        )
    }

    public mutating func beginTranscribedVoice(
        _ transcript: String,
        mode: ConversationMode,
        targetDirectory: String
    ) -> VoiceAssistantRequest? {
        guard activeRequestID == nil else {
            appendSystemMessage("処理中の依頼があります。完了してから送信してください。")
            return nil
        }
        guard state == .transcribing else {
            return beginTranscript(transcript, mode: mode, targetDirectory: targetDirectory)
        }

        state = .idle
        return beginTranscript(transcript, mode: mode, targetDirectory: targetDirectory)
    }

    public mutating func receiveTranscript(
        _ transcript: String,
        mode: ConversationMode,
        targetDirectory: String
    ) {
        guard let request = beginTranscript(transcript, mode: mode, targetDirectory: targetDirectory) else {
            return
        }

        let response = CodexConversationResponse(message: localFallbackMessage(for: request.mode))
        complete(request: request, response: response)
    }

    public mutating func complete(request: VoiceAssistantRequest, response: CodexConversationResponse) {
        guard activeRequestID == request.id else { return }
        activeRequestID = nil

        switch request.mode {
        case .consultation:
            appendMessage(
                role: .assistant,
                text: response.message
            )
            state = .completed
        case .instruction:
            let plan = Self.makeExecutionPlan(
                for: request.message,
                targetDirectory: request.targetDirectory,
                response: response
            )
            pendingPlan = plan
            appendMessage(
                role: .assistant,
                text: response.message
            )
            state = .awaitingApproval
        }
    }

    public mutating func completeWithError(_ message: String) {
        activeRequestID = nil
        fail(message)
    }

    public mutating func markTranscribing() {
        guard state != .executing, state != .awaitingApproval else { return }
        state = .transcribing
    }

    public mutating func markExecutionStarted() -> ExecutionPlan? {
        guard state == .awaitingApproval, let plan = pendingPlan else {
            fail("承認待ちの実行計画がありません。")
            return nil
        }

        state = .executing
        executionLog = ""
        appendSystemMessage("承認されたため `codex exec` を開始します。")
        return plan
    }

    public mutating func appendExecutionLog(_ text: String) {
        executionLog += text
    }

    public mutating func markExecutionCompleted(exitCode: Int32) {
        if exitCode == 0 {
            state = .completed
            pendingPlan = nil
            activeRequestID = nil
            appendSystemMessage("`codex exec` が完了しました。")
        } else {
            state = .error
            pendingPlan = nil
            activeRequestID = nil
            errorMessage = "`codex exec` が終了コード \(exitCode) で終了しました。"
        }
    }

    public mutating func cancelPendingPlan() {
        guard state == .awaitingApproval, pendingPlan != nil else { return }

        pendingPlan = nil
        activeRequestID = nil
        state = isMicrophoneEnabled ? .listening : .idle
        appendSystemMessage("実行計画をキャンセルしました。")
    }

    private var isBusy: Bool {
        switch state {
        case .transcribing, .thinking, .awaitingApproval, .executing:
            return true
        case .idle, .listening, .completed, .error:
            return false
        }
    }

    private mutating func fail(_ message: String) {
        state = .error
        errorMessage = message
        appendSystemMessage(message)
    }

    private mutating func appendSystemMessage(_ text: String) {
        appendMessage(role: .system, text: text)
    }

    private mutating func appendMessage(role: ConversationRole, text: String) {
        messages.append(ConversationMessage(role: role, text: text))
    }

    private static func makeExecutionPlan(
        for request: String,
        targetDirectory: String,
        response: CodexConversationResponse? = nil
    ) -> ExecutionPlan {
        ExecutionPlan(
            request: request,
            targetDirectory: targetDirectory,
            affectedFiles: response?.affectedFiles ?? ["Codex App Server が実行前に調査して特定します"],
            workItems: response?.workItems ?? [
                "要求内容を再確認する",
                "必要なファイルを調査する",
                "変更を実装する",
                "可能な範囲でテストまたはビルドを実行する"
            ],
            impact: response?.impact ?? "承認後にのみファイル変更やコマンド実行が発生します。",
            command: "codex exec -- \(shellQuoted(request))",
            arguments: ["exec", "--", request]
        )
    }

    private func localFallbackMessage(for mode: ConversationMode) -> String {
        switch mode {
        case .consultation:
            return """
            相談モードとして受け付けました。Codex App Server が未接続の場合のローカルプレビュー応答です。

            実際のリポジトリ調査・コード読解・設計レビューは Codex App Server 接続後に行います。
            """
        case .instruction:
            return "命令モードとして整理しました。下の実行計画とコマンドを確認し、問題なければ実行してください。"
        }
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
