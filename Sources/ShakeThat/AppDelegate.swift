import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let shelf = ShelfController()
    private let shakeMonitor = DragShakeMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "ShakeThat")
        item.menu = makeMenu()
        statusItem = item

        shakeMonitor.onShake = { [weak self] location in
            self?.shelf.show(near: location)
        }
        shakeMonitor.start()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Shelf", action: #selector(showShelf), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: "").target = self
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
}
