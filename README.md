# tachikoma

Tachikoma は macOS のメニューバーアプリです。

現在の MVP では、macOS のメニューバーに小さな `t` を表示します。
クリックすると `tachikoma です`、設定、終了項目を含むメニューが開きます。

## Homebrew からインストール

最初のリリースタグが作られるまでは、HEAD formula としてインストールしてください。

```sh
brew tap s4na/tachikoma https://github.com/s4na/tachikoma.git
brew install --HEAD s4na/tachikoma/tachikoma
```

インストール後、Tachikoma はログイン時に自動起動するよう登録されます。
今すぐ起動する場合:

```sh
tachikoma
```

ログイン時の自動起動を止める場合は、メニューバーの `t` から `設定` を開き、`start up 起動 off` をオンにしてください。
このフラグはデフォルトではオフです。
メニューでオフにした場合、次回ログイン以降は自動起動しません。

アンインストール前に、既に読み込まれているログイン項目も停止する場合は、次のコマンドを実行してください。

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.s4na.tachikoma.plist" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.s4na.tachikoma.plist"
brew uninstall s4na/tachikoma/tachikoma
```

## 開発

```sh
swift build
swift run tachikoma --help
```

## ライセンス

MIT
