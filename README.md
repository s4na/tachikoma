# tachikoma

Tachikoma は macOS のメニューバーアプリです。

現在の MVP では、macOS のメニューバーに小さな `t` を表示します。
クリックすると `tachikoma です`、Voice Assistant、設定、終了項目を含むメニューが開きます。

Voice Assistant では、`plan.md` の安全設計に沿って次の流れを確認できます。

* マイク ON/OFF 状態の切り替え
* 音声取得、音量ベースの VAD 表示、whisper.cpp CLI による文字起こし
* Codex App Server への会話送信とストリーミング応答受信
* 相談モードでの readonly 相談
* 命令モードでの要件整理と実行計画作成
* 対象ディレクトリの明示
* `codex exec` コマンドの表示
* ユーザー承認後の `codex exec` 実行
* 実行ログの表示
* 会話、文字起こし、実行、エラーのローカルログ保存

Voice Assistant ウィンドウでは、Codex App Server URL と whisper.cpp のコマンドテンプレートを指定できます。
whisper.cpp のコマンドテンプレートでは、録音した wav ファイルのパスとして `{audio}` を使えます。

Codex App Server には次の JSON を POST します。

```json
{
  "mode": "consultation",
  "message": "このリポジトリの構成を調べて",
  "targetDirectory": "/path/to/repository",
  "readonly": true
}
```

App Server は `text/event-stream`、`text/plain`、または次の JSON で応答できます。

```json
{
  "message": "確認結果または命令整理の説明",
  "affectedFiles": ["Sources/..."],
  "workItems": ["実装内容を整理する"],
  "impact": "承認後にのみ変更されます"
}
```

命令モードでは、App Server の応答をもとに実行計画を表示します。
実行ボタンを押すまで `codex exec -- <prompt>` は起動しません。
会話ログは `~/Library/Application Support/Tachikoma/Logs/` に JSON Lines 形式で保存されます。

## Homebrew からインストール

```sh
brew tap s4na/tachikoma https://github.com/s4na/tachikoma.git
brew install s4na/tachikoma/tachikoma
```

インストール後、Tachikoma をバックグラウンドで起動し、ログイン時にも自動起動する場合:

```sh
brew services start s4na/tachikoma/tachikoma
```

ログイン時の自動起動を止める場合は、メニューバーの `t` から `設定` を開き、`start up 起動 off` をオンにしてください。
このフラグはデフォルトではオフです。
このフラグをオンにした場合、次回ログイン以降は自動起動しません。

アンインストール前に、既に読み込まれているログイン項目も停止する場合は、次のコマンドを実行してください。

```sh
brew services stop s4na/tachikoma/tachikoma
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.s4na.tachikoma.plist" 2>/dev/null
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/homebrew.mxcl.tachikoma.plist" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.s4na.tachikoma.plist"
rm -f "$HOME/Library/LaunchAgents/homebrew.mxcl.tachikoma.plist"
brew uninstall s4na/tachikoma/tachikoma
```

## 開発

```sh
swift build
swift test
swift run tachikoma --help
```

## ライセンス

MIT
