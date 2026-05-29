# tachikoma

Tachikoma は macOS のメニューバーアプリです。

現在の MVP では、macOS のメニューバーに小さな `t` を表示します。
クリックすると `tachikoma です` と終了項目を含むメニューが開きます。

## Homebrew からインストール

最初のリリースタグが作られるまでは、HEAD formula としてインストールしてください。

```sh
brew tap s4na/tachikoma https://github.com/s4na/tachikoma.git
brew install --HEAD s4na/tachikoma/tachikoma
```

その後、メニューバーアプリの起動方法を選びます。

現在のセッションだけで起動する場合:

```sh
tachikoma
```

今すぐ起動し、ログイン時にも自動起動する場合:

```sh
brew services start s4na/tachikoma/tachikoma
```

アンインストール前にログイン項目を削除する場合:

```sh
brew services stop s4na/tachikoma/tachikoma
brew uninstall s4na/tachikoma/tachikoma
```

## 開発

```sh
swift build
swift run tachikoma --help
```
