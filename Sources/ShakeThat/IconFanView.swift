import AppKit

/// Draws the shelf's files as a hand of cards: up to `maxVisible` icons fanned out,
/// with the most recently added file on top.
@MainActor
final class IconFanView: NSView {
    static let maxVisible = 5

    var images: [NSImage] = [] {
        didSet { needsDisplay = true }
    }

    /// Degrees between neighbouring cards.
    private let angleStep: CGFloat = 9

    // Mouse handling (dragging files out, moving the shelf) belongs to the shelf view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// Frame of the top card, in this view's coordinates. Used as the drag image origin.
    var topCardFrame: NSRect {
        cardRect(count: min(images.count, Self.maxVisible))
    }

    override func draw(_ dirtyRect: NSRect) {
        let visible = Array(images.suffix(Self.maxVisible))
        guard !visible.isEmpty else { return }

        let card = cardRect(count: visible.count)
        // Rotate around a point below the cards so they spread like a hand of cards.
        let pivot = NSPoint(x: card.midX, y: card.minY - card.height * 0.6)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)

        for (index, image) in visible.enumerated() {
            let angle = (CGFloat(index) - CGFloat(visible.count - 1) / 2) * angleStep
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: pivot.x, yBy: pivot.y)
            transform.rotate(byDegrees: -angle) // positive index leans right
            transform.translateX(by: -pivot.x, yBy: -pivot.y)
            transform.concat()
            if visible.count > 1 { shadow.set() }
            image.draw(in: aspectFit(image.size, in: card), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// Cards shrink a little as the fan grows so the outer ones stay inside the view.
    private func cardRect(count: Int) -> NSRect {
        let scale: CGFloat = count > 1 ? 0.75 : 1
        let side = min(bounds.width, bounds.height) * scale
        return NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
    }

    private func aspectFit(_ size: NSSize, in rect: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
