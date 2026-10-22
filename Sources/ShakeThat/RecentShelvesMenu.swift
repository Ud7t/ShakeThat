import AppKit

/// The "Recent Shelves" submenu, rebuilt each time it opens so times and missing files are current.
@MainActor
final class RecentShelvesMenu: NSObject, NSMenuDelegate {
    let item = NSMenuItem(title: "Recent Shelves", action: nil, keyEquivalent: "")

    private let history: ShelfHistory
    private let onRestore: (Int) -> Void
    private let relativeTime: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    init(history: ShelfHistory, onRestore: @escaping (Int) -> Void) {
        self.history = history
        self.onRestore = onRestore
        super.init()
        let submenu = NSMenu(title: "Recent Shelves")
        submenu.delegate = self
        // Entries are enabled by hand, depending on whether their files still exist.
        submenu.autoenablesItems = false
        item.submenu = submenu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard !history.entries.isEmpty else {
            menu.addItem(withTitle: "No Recent Shelves", action: nil, keyEquivalent: "").isEnabled = false
            return
        }
        for (index, entry) in history.entries.enumerated() {
            let item = NSMenuItem(title: title(for: entry), action: #selector(restore(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            // Shelves whose files are all gone can't be reopened.
            item.isEnabled = !history.existingFiles(of: entry).isEmpty
            menu.addItem(item)
        }
    }

    private func title(for entry: ShelfHistory.Entry) -> String {
        let first = entry.names.first ?? "Untitled"
        let files = entry.names.count == 1 ? first : "\(first) + \(entry.names.count - 1) more"
        return "\(files) · \(relativeTime.localizedString(for: entry.date, relativeTo: Date()))"
    }

    @objc private func restore(_ sender: NSMenuItem) {
        onRestore(sender.tag)
    }
}
