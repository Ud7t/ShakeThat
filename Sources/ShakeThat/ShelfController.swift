import AppKit

/// Owns the floating shelf panel and decides where it appears.
@MainActor
final class ShelfController {
    private let shelfView = ShelfView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
    private lazy var panel = makePanel()

    init() {
        shelfView.onClose = { [weak self] in self?.clear() }
        shelfView.onEmptiedByDrag = { [weak self] in self?.hide() }
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
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size.height)
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func clear() {
        shelfView.removeAll()
        hide()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: shelfView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

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
