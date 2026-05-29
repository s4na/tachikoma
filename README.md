# tachikoma

Tachikoma is a macOS menu bar app.

The current MVP keeps a small `t` in the macOS menu bar. Clicking it opens a
menu with `tachikoma です` and a quit item.

## Install from Homebrew

Until the first release is tagged, install the HEAD formula:

```sh
brew install --HEAD ./Formula/tachikoma.rb
```

Then start the menu bar app:

```sh
tachikoma
```

## Development

```sh
swift build
swift run tachikoma --help
```
