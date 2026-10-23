import AppKit

/// The rounded "6 Files ⌄" button at the bottom of the shelf that opens the details panel.
@MainActor
final class CountPill: NSButton {
    var text = "" {
        didSet {
            attributedTitle = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        image = NSImage(systemSymbolName: "chevron.down.circle.fill", accessibilityDescription: "Show details")
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        contentTintColor = .secondaryLabelColor
        imagePosition = .imageTrailing
        imageHugsTitle = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: super.intrinsicContentSize.width + 18, height: 22)
    }

    // The shelf never becomes the active app, so the first click must already work.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        super.draw(dirtyRect)
    }
}
