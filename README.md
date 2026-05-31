# tachikoma

Tachikoma は macOS のメニューバーアプリです。

現在の MVP では、macOS のメニューバーに小さな `t` を表示します。
クリックすると `tachikoma です`、Voice Assistant、設定、終了項目を含むメニューが開きます。

Voice Assistant では、`plan.md` の安全設計に沿って次の流れを確認できます。

* マイク ON/OFF 状態の切り替え
* 相談モードでの readonly 相談フロープレビュー
* 命令モードでの実行計画作成
* 対象ディレクトリの明示
* `codex exec` コマンドの表示
* ユーザー承認後の `codex exec` 実行
* 実行ログの表示

音声認識と Codex App Server 接続は、今後 whisper.cpp や App Server 実装を差し込むための拡張ポイントです。
現時点では、Voice Assistant ウィンドウの入力欄から文字起こし済みテキスト相当の内容を送信します。

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
