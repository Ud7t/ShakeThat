import AppKit
import ShakeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private lazy var recentShelves = RecentShelvesMenu(history: shelf.history) { [weak self] index in
        self?.shelf.restore(historyIndex: index)
    }
    private let shelf = ShelfController()
    private let shakeMonitor = DragShakeMonitor()
    private let shakeSettings = ShakeSettingsStore()
    private lazy var settingsWindow = ShakeSettingsWindowController(store: shakeSettings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.menu = makeMenu()
        statusItem = item

        shakeMonitor.onShake = { [weak self] location in
            self?.shelf.show(near: location)
        }
        shakeSettings.onChange = { [weak self] settings in
            self?.shakeMonitor.settings = settings
        }
        shakeSettings.reload()
        shakeMonitor.start()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Shelf", action: #selector(showShelf), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: "").target = self
        menu.addItem(recentShelves.item)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Shake Settings…", action: #selector(showShakeSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ShakeThat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func showShelf() {
        shelf.show(near: NSEvent.mouseLocation)
    }

    @objc private func clearShelf() {
        shelf.clear()
    }

    @objc private func showShakeSettings() {
        settingsWindow.show()
    }
}
