import Foundation
import TachikomaCore

@main
enum TachikomaCoreExecutableTests {
    static func main() throws {
        try consultationDoesNotCreateExecutionPlan()
        try instructionRequiresApprovalBeforeExecution()
        try instructionUsesAppServerPlanDetails()
        try cancelPendingPlanReturnsToIdle()
        missingDirectoryIsRejected()
        try busyRequestBlocksNewTranscript()
        try microphoneToggleDoesNotBreakApprovalState()
        try executionCanOnlyStartAfterApproval()
        try commandEscapesSingleQuotes()
        try optionLikeRequestsArePassedAsPromptArguments()
        try failedExecutionClearsPendingPlan()
        try cancelDoesNotInterruptExecutingPlanState()
    }

    static func consultationDoesNotCreateExecutionPlan() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("この設計案どう思う？", mode: .consultation, targetDirectory: directory)

        assert(session.state == .completed)
        assert(session.pendingPlan == nil)
    }

    static func instructionRequiresApprovalBeforeExecution() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)

        assert(session.state == .awaitingApproval)
        assert(session.pendingPlan?.targetDirectory == directory)
        assert(session.pendingPlan?.command == "codex exec -- 'テストを書いて'")
        assert(session.pendingPlan?.arguments == ["exec", "--", "テストを書いて"])
    }

    static func instructionUsesAppServerPlanDetails() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        guard let request = session.beginTranscript("APIを作って", mode: .instruction, targetDirectory: directory) else {
            throw TestFailure("request was not created")
        }
        assert(request.readonly)
        session.complete(
            request: request,
            response: CodexConversationResponse(
                message: "実行計画を整理しました。",
                affectedFiles: ["Sources/API.swift"],
                workItems: ["APIエンドポイントを追加する"],
                impact: "API surface が増えます。"
            )
        )

        assert(session.state == .awaitingApproval)
        assert(session.pendingPlan?.affectedFiles == ["Sources/API.swift"])
        assert(session.pendingPlan?.workItems == ["APIエンドポイントを追加する"])
        assert(session.pendingPlan?.impact == "API surface が増えます。")
    }

    static func cancelPendingPlanReturnsToIdle() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        session.cancelPendingPlan()

        assert(session.state == .idle)
        assert(session.pendingPlan == nil)
    }

    static func missingDirectoryIsRejected() {
        var session = VoiceAssistantSession()

        session.receiveTranscript(
            "テストを書いて",
            mode: .instruction,
            targetDirectory: "/tmp/tachikoma-missing-\(UUID().uuidString)"
        )

        assert(session.state == .error)
        assert(session.pendingPlan == nil)
    }

    static func busyRequestBlocksNewTranscript() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        let request = session.beginTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        let blocked = session.beginTranscript("別の変更をして", mode: .instruction, targetDirectory: directory)

        assert(request != nil)
        assert(blocked == nil)
        assert(session.state == .thinking)
    }

    static func microphoneToggleDoesNotBreakApprovalState() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        session.setMicrophoneEnabled(true)

        assert(session.state == .awaitingApproval)
        assert(session.pendingPlan != nil)
    }

    static func executionCanOnlyStartAfterApproval() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        assert(session.markExecutionStarted() == nil)
        assert(session.state == .error)

        session = VoiceAssistantSession()
        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        let plan = session.markExecutionStarted()

        assert(plan?.targetDirectory == directory)
        assert(session.state == .executing)
    }

    static func commandEscapesSingleQuotes() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("Bob's testを直して", mode: .instruction, targetDirectory: directory)

        assert(session.pendingPlan?.command == "codex exec -- 'Bob'\\''s testを直して'")
        assert(session.pendingPlan?.arguments == ["exec", "--", "Bob's testを直して"])
    }

    static func optionLikeRequestsArePassedAsPromptArguments() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("--help", mode: .instruction, targetDirectory: directory)

        assert(session.pendingPlan?.command == "codex exec -- '--help'")
        assert(session.pendingPlan?.arguments == ["exec", "--", "--help"])
    }

    static func failedExecutionClearsPendingPlan() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        _ = session.markExecutionStarted()
        session.markExecutionCompleted(exitCode: 1)

        assert(session.state == .error)
        assert(session.pendingPlan == nil)
    }

    static func cancelDoesNotInterruptExecutingPlanState() throws {
        var session = VoiceAssistantSession()
        let directory = try temporaryDirectory()

        session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
        _ = session.markExecutionStarted()
        session.cancelPendingPlan()

        assert(session.state == .executing)
        assert(session.pendingPlan != nil)
    }

    static func temporaryDirectory() throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tachikoma-executable-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
