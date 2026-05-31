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

public enum ConversationMode: String, CaseIterable, Equatable {
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

    public init(
        request: String,
        targetDirectory: String,
        affectedFiles: [String],
        workItems: [String],
        impact: String,
        command: String
    ) {
        self.request = request
        self.targetDirectory = targetDirectory
        self.affectedFiles = affectedFiles
        self.workItems = workItems
        self.impact = impact
        self.command = command
    }
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
        case .awaitingApproval, .executing:
            break
        default:
            state = enabled ? .listening : .idle
        }

        appendSystemMessage(enabled ? "マイクをONにしました。" : "マイクをOFFにしました。")
    }

    public mutating func receiveTranscript(
        _ transcript: String,
        mode: ConversationMode,
        targetDirectory: String
    ) {
        guard state != .executing else {
            appendSystemMessage("実行中は新しい依頼を送信できません。")
            return
        }
        guard state != .awaitingApproval else {
            appendSystemMessage("承認待ちの実行計画があります。実行またはキャンセルしてから送信してください。")
            return
        }

        let request = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else {
            fail("発話または入力が空です。")
            return
        }

        let directory = targetDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isExistingDirectory(directory) else {
            fail("対象ディレクトリが存在しません。")
            return
        }

        errorMessage = nil
        pendingPlan = nil
        state = .thinking
        appendMessage(role: .user, text: request)

        switch mode {
        case .consultation:
            appendMessage(
                role: .assistant,
                text: """
                相談モードとして受け付けました。readonly 前提で調査・読解・提案を行います。

                実行が必要になった場合は、先に命令モードで作業内容と `codex exec` コマンドを整理します。
                """
            )
            state = .completed
        case .instruction:
            let plan = Self.makeExecutionPlan(for: request, targetDirectory: directory)
            pendingPlan = plan
            appendMessage(
                role: .assistant,
                text: """
                命令モードとして整理しました。下の実行計画とコマンドを確認し、問題なければ実行してください。
                """
            )
            state = .awaitingApproval
        }
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
            appendSystemMessage("`codex exec` が完了しました。")
        } else {
            state = .error
            errorMessage = "`codex exec` が終了コード \(exitCode) で終了しました。"
        }
    }

    public mutating func cancelPendingPlan() {
        guard pendingPlan != nil else { return }

        pendingPlan = nil
        state = isMicrophoneEnabled ? .listening : .idle
        appendSystemMessage("実行計画をキャンセルしました。")
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

    private static func makeExecutionPlan(for request: String, targetDirectory: String) -> ExecutionPlan {
        ExecutionPlan(
            request: request,
            targetDirectory: targetDirectory,
            affectedFiles: ["Codex が実行前に調査して特定します"],
            workItems: [
                "要求内容を再確認する",
                "必要なファイルを調査する",
                "変更を実装する",
                "可能な範囲でテストまたはビルドを実行する"
            ],
            impact: "承認後にのみファイル変更やコマンド実行が発生します。",
            command: "codex exec \(shellQuoted(request))"
        )
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
