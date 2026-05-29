# tachikoma

Tachikoma is a macOS menu bar app.

The current MVP keeps a small `t` in the macOS menu bar. Clicking it opens a
menu with `tachikoma です` and a quit item.

## Install from Homebrew

Until the first release is tagged, install the HEAD formula:

```sh
brew tap s4na/tachikoma https://github.com/s4na/tachikoma.git
brew install --HEAD s4na/tachikoma/tachikoma
```

Then start the menu bar app:

```sh
tachikoma
```

To start Tachikoma now and launch it automatically at login, use Homebrew
services:

```sh
brew services start s4na/tachikoma/tachikoma
```

To remove the login item before uninstalling:

```sh
brew services stop s4na/tachikoma/tachikoma
brew uninstall s4na/tachikoma/tachikoma
```

## Development

```sh
swift build
swift run tachikoma --help
```
