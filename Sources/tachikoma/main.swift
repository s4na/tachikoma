import AppKit
import TachikomaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = MenuContent.statusTitle
        item.button?.toolTip = "Tachikoma"
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let greetingItem = NSMenuItem(title: MenuContent.greeting, action: nil, keyEquivalent: "")
        greetingItem.isEnabled = false
        menu.addItem(greetingItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: MenuContent.quitTitle,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
enum TachikomaApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
            print(MenuContent.helpText)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
