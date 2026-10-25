import AppKit

/// The "Recent Shelves" submenu, rebuilt each time it opens so times and missing files are current.
/// It also makes the pinned shelf items that the menu bar menu lists directly, like Dropover.
///
/// Holding Option turns each entry into "Remove “name”", so the change shows before the click.
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
    private let pinImage = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")

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

    /// Items for the pinned shelves, each followed by its Option alternate.
    /// The menu holding them must not autoenable items.
    func pinnedItems() -> [NSMenuItem] {
        history.removeMissingPinned()
        return history.entries.indices.filter { history.entries[$0].isPinned }.flatMap { items(for: $0) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let pinned = pinnedItems()
        let recent = history.entries.indices.filter { !history.entries[$0].isPinned }.flatMap { items(for: $0) }
        guard !pinned.isEmpty || !recent.isEmpty else {
            menu.addItem(withTitle: "No Recent Shelves", action: nil, keyEquivalent: "").isEnabled = false
            return
        }
        for item in pinned { menu.addItem(item) }
        if !pinned.isEmpty, !recent.isEmpty { menu.addItem(.separator()) }
        for item in recent { menu.addItem(item) }
    }

    /// The entry's item, then the alternate that replaces it while Option is held.
    private func items(for index: Int) -> [NSMenuItem] {
        let entry = history.entries[index]
        let image = entry.isPinned ? pinImage : nil

        let restore = NSMenuItem(title: title(for: entry), action: #selector(restore(_:)), keyEquivalent: "")
        restore.target = self
        restore.tag = index
        restore.image = image
        restore.keyEquivalentModifierMask = []
        // Shelves whose files are all gone can't be reopened.
        restore.isEnabled = !history.existingFiles(of: entry).isEmpty

        let remove = NSMenuItem(title: "Remove “\(files(of: entry))”", action: #selector(remove(_:)), keyEquivalent: "")
        remove.target = self
        remove.tag = index
        remove.image = image
        remove.keyEquivalentModifierMask = .option
        remove.isAlternate = true
        return [restore, remove]
    }

    private func files(of entry: ShelfHistory.Entry) -> String {
        let first = entry.names.first ?? "Untitled"
        return entry.names.count == 1 ? first : "\(first) + \(entry.names.count - 1) more"
    }

    private func title(for entry: ShelfHistory.Entry) -> String {
        "\(files(of: entry)) · \(relativeTime.localizedString(for: entry.date, relativeTo: Date()))"
    }

    @objc private func restore(_ sender: NSMenuItem) {
        onRestore(sender.tag)
    }

    @objc private func remove(_ sender: NSMenuItem) {
        history.remove(at: sender.tag)
    }
}
