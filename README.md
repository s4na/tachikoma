# tachikoma

Tachikoma は macOS のメニューバーアプリです。

現在の MVP では、macOS のメニューバーに小さな `t` を表示します。
クリックすると `tachikoma です`、設定、終了項目を含むメニューが開きます。

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
swift run tachikoma --help
```

## ライセンス

MIT
