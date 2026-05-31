import Foundation
import Testing
@testable import TachikomaCore

@Test func consultationDoesNotCreateExecutionPlan() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("この設計案どう思う？", mode: .consultation, targetDirectory: directory)

    #expect(session.state == .completed)
    #expect(session.pendingPlan == nil)
    #expect(session.messages.contains { $0.text.contains("プレビュー") })
}

@Test func instructionRequiresApprovalBeforeExecution() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)

    #expect(session.state == .awaitingApproval)
    #expect(session.pendingPlan?.targetDirectory == directory)
    #expect(session.pendingPlan?.command == "codex exec -- 'テストを書いて'")
    #expect(session.pendingPlan?.arguments == ["exec", "--", "テストを書いて"])
}

@Test func instructionUsesAppServerPlanDetails() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    let request = session.beginTranscript(
        "APIを作って",
        mode: .instruction,
        targetDirectory: directory
    )
    #expect(request != nil)
    session.complete(
        request: request!,
        response: CodexConversationResponse(
            message: "実行計画を整理しました。",
            affectedFiles: ["Sources/API.swift"],
            workItems: ["APIエンドポイントを追加する"],
            impact: "API surface が増えます。"
        )
    )

    #expect(session.state == .awaitingApproval)
    #expect(session.pendingPlan?.affectedFiles == ["Sources/API.swift"])
    #expect(session.pendingPlan?.workItems == ["APIエンドポイントを追加する"])
    #expect(session.pendingPlan?.impact == "API surface が増えます。")
}

@Test func cancelPendingPlanReturnsToIdle() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    session.cancelPendingPlan()

    #expect(session.state == .idle)
    #expect(session.pendingPlan == nil)
}

@Test func missingDirectoryIsRejected() {
    var session = VoiceAssistantSession()

    session.receiveTranscript(
        "テストを書いて",
        mode: .instruction,
        targetDirectory: "/tmp/tachikoma-missing-\(UUID().uuidString)"
    )

    #expect(session.state == .error)
    #expect(session.pendingPlan == nil)
}

@Test func pendingPlanBlocksNewTranscriptWithoutClearingPlan() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    let firstPlan = session.pendingPlan
    session.receiveTranscript("別の変更をして", mode: .instruction, targetDirectory: directory)

    #expect(session.state == .awaitingApproval)
    #expect(session.pendingPlan == firstPlan)
}

@Test func microphoneToggleDoesNotBreakApprovalState() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    session.setMicrophoneEnabled(true)

    #expect(session.state == .awaitingApproval)
    #expect(session.pendingPlan != nil)
}

@Test func finishedTranscriptionReturnsToListeningWhenMicrophoneIsOn() {
    var session = VoiceAssistantSession()

    session.setMicrophoneEnabled(true)
    session.markTranscribing()
    session.finishTranscribing()

    #expect(session.state == .listening)
    #expect(session.isMicrophoneEnabled)
}

@Test func executionCanOnlyStartAfterApproval() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    #expect(session.markExecutionStarted() == nil)
    #expect(session.state == .error)

    session = VoiceAssistantSession()
    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    let plan = session.markExecutionStarted()

    #expect(plan?.targetDirectory == directory)
    #expect(session.state == .executing)
}

@Test func commandEscapesSingleQuotes() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("Bob's testを直して", mode: .instruction, targetDirectory: directory)

    #expect(session.pendingPlan?.command == "codex exec -- 'Bob'\\''s testを直して'")
    #expect(session.pendingPlan?.arguments == ["exec", "--", "Bob's testを直して"])
}

@Test func optionLikeRequestsArePassedAsPromptArguments() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("--help", mode: .instruction, targetDirectory: directory)

    #expect(session.pendingPlan?.command == "codex exec -- '--help'")
    #expect(session.pendingPlan?.arguments == ["exec", "--", "--help"])
}

@Test func failedExecutionClearsPendingPlan() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    _ = session.markExecutionStarted()
    session.markExecutionCompleted(exitCode: 1)

    #expect(session.state == .error)
    #expect(session.pendingPlan == nil)
}

@Test func cancelDoesNotInterruptExecutingPlanState() throws {
    var session = VoiceAssistantSession()
    let directory = try temporaryDirectory()

    session.receiveTranscript("テストを書いて", mode: .instruction, targetDirectory: directory)
    _ = session.markExecutionStarted()
    session.cancelPendingPlan()

    #expect(session.state == .executing)
    #expect(session.pendingPlan != nil)
}

private func temporaryDirectory() throws -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("tachikoma-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}
