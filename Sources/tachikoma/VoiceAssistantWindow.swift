import SwiftUI
import TachikomaCore

struct VoiceAssistantWindow: View {
    @ObservedObject var viewModel: VoiceAssistantViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            conversation
            if let plan = viewModel.pendingPlan {
                approval(plan)
            }
            if !viewModel.executionLog.isEmpty {
                logView
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            composer
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 680)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tachikoma")
                    .font(.title2.bold())
                Text("状態: \(stateTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("モード", selection: $viewModel.mode) {
                ForEach(ConversationMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            Button(viewModel.isMicrophoneEnabled ? "マイクOFF" : "マイクON") {
                viewModel.toggleMicrophone()
            }
            .disabled(viewModel.state == .awaitingApproval || viewModel.state == .executing)
        }
    }

    private var conversation: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if viewModel.messages.isEmpty {
                    Text("相談内容や実装依頼を入力してください。命令モードでは実行計画を確認してから実行できます。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(viewModel.messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: message.role))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(message.text)
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: message.role))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(minHeight: 220)
    }

    private func approval(_ plan: ExecutionPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("実行前承認")
                .font(.headline)
            Text("対象ディレクトリ: \(plan.targetDirectory)")
                .font(.caption)
                .textSelection(.enabled)
            planList("変更対象の特定方法", plan.affectedFiles)
            planList("作業内容", plan.workItems)
            Text("影響: \(plan.impact)")
                .font(.caption)
            Text(plan.command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("実行") {
                    viewModel.executePendingPlan()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.state != .awaitingApproval)
                Button("キャンセル") {
                    viewModel.cancelPendingPlan()
                }
                .disabled(viewModel.state != .awaitingApproval)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func planList(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
            ForEach(items, id: \.self) { item in
                Text("- \(item)")
                    .font(.caption)
            }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("実行ログ")
                .font(.headline)
            ScrollView {
                Text(viewModel.executionLog)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.transcript)
                .font(.body)
                .frame(height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                )
            HStack {
                TextField("対象ディレクトリ", text: $viewModel.targetDirectory)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!viewModel.acceptsInput)
                Button("選択") {
                    viewModel.chooseTargetDirectory()
                }
                .disabled(!viewModel.acceptsInput)
            }
            HStack {
                Spacer()
                Button("送信") {
                    viewModel.submitTranscript()
                }
                .disabled(
                    !viewModel.acceptsInput ||
                        viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private var stateTitle: String {
        switch viewModel.state {
        case .idle:
            return "待機中"
        case .listening:
            return "聞き取り中"
        case .transcribing:
            return "文字起こし中"
        case .thinking:
            return "応答作成中"
        case .awaitingApproval:
            return "承認待ち"
        case .executing:
            return "実行中"
        case .completed:
            return "完了"
        case .error:
            return "エラー"
        }
    }

    private func label(for role: ConversationRole) -> String {
        switch role {
        case .user:
            return "User"
        case .assistant:
            return "Codex"
        case .system:
            return "System"
        }
    }

    private func background(for role: ConversationRole) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.12)
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .system:
            return Color(nsColor: .windowBackgroundColor)
        }
    }
}
