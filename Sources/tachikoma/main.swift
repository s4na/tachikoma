import AppKit
import TachikomaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let startupManager = LaunchAgentManager()
    private let defaults = LaunchAgentManager.startupDefaults()
    private var startupOffItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        syncStartupRegistration()

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

        let settingsItem = NSMenuItem(title: MenuContent.settingsTitle, action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        let startupOffItem = NSMenuItem(
            title: MenuContent.startupOffTitle,
            action: #selector(toggleStartupOff),
            keyEquivalent: ""
        )
        startupOffItem.target = self
        startupOffItem.state = isStartupOff ? .on : .off
        settingsMenu.addItem(startupOffItem)
        settingsItem.submenu = settingsMenu
        self.startupOffItem = startupOffItem
        menu.addItem(settingsItem)

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

    private var isStartupOff: Bool {
        defaults.bool(forKey: LaunchAgentManager.startupOffDefaultsKey)
    }

    @objc private func toggleStartupOff() {
        let newValue = !isStartupOff
        defaults.set(newValue, forKey: LaunchAgentManager.startupOffDefaultsKey)
        startupOffItem?.state = newValue ? .on : .off
        syncStartupRegistration()
    }

    private func syncStartupRegistration() {
        do {
            try startupManager.sync(startupOff: isStartupOff)
        } catch {
            NSLog("Failed to update Tachikoma login item: \(error)")
        }
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
