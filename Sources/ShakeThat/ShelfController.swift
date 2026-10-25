import AppKit

/// Owns the floating shelf panel and decides where it appears.
@MainActor
final class ShelfController {
    private let shelfView = ShelfView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
    private lazy var panel = makePanel()
    let history = ShelfHistory()

    init() {
        shelfView.onClose = { [weak self] in self?.clear() }
        shelfView.onDraggedOut = { [weak self] in self?.clear() }
        shelfView.onReplaceFiles = { [weak self] files in self?.replace(with: files) }
        shelfView.onTogglePin = { [weak self] in self?.shelfView.isPinned.toggle() }
    }

    /// Shows the shelf centred on `point`, so releasing the mouse right away drops the files.
    func show(near point: NSPoint) {
        let size = panel.frame.size
        var frame = NSRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let screen = NSScreen.containing(point) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size.height)
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    /// Puts `files` on the shelf and shows it centred on `point`.
    func add(_ files: [URL], near point: NSPoint) {
        shelfView.add(files)
        show(near: point)
    }

    /// Empties and hides the shelf, saving its files to the history first.
    func clear() {
        saveToHistory(isPinned: shelfView.isPinned)
        shelfView.removeAll()
        shelfView.isPinned = false
        panel.orderOut(nil)
    }

    /// Swaps the shelf's files for the result of a quick action.
    /// The previous files go into the history, so the originals are a click away.
    /// A pinned shelf stays pinned with the new files.
    func replace(with files: [URL]) {
        saveToHistory()
        shelfView.removeAll()
        shelfView.add(files)
    }

    /// Reopens a shelf from the history. Files that no longer exist are skipped.
    /// Whatever is on the shelf now goes into the history, so it isn't lost.
    func restore(historyIndex index: Int) {
        guard history.entries.indices.contains(index) else { return }
        let entry = history.entries[index]
        let files = history.existingFiles(of: entry)
        guard !files.isEmpty else { return }
        // Taken out of the history while it's on the shelf; it comes back when cleared again.
        history.remove(at: index)
        saveToHistory(isPinned: shelfView.isPinned)
        shelfView.removeAll()
        shelfView.add(files)
        shelfView.isPinned = entry.isPinned
        show(near: NSEvent.mouseLocation)
    }

    private func saveToHistory(isPinned: Bool = false) {
        let files = shelfView.bookmarkedFiles
        history.record(bookmarks: files.map(\.bookmark), names: files.map(\.name), isPinned: isPinned)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(overlayWithContentRect: shelfView.frame)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView(frame: shelfView.frame)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]

        shelfView.autoresizingMask = [.width, .height]
        background.addSubview(shelfView)
        panel.contentView = background
        return panel
    }
}
