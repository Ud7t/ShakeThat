import AppKit

/// The shelf's content: accepts dropped files and lets you drag them all back out.
@MainActor
final class ShelfView: NSView, NSDraggingSource {
    /// Called when the close button is clicked.
    var onClose: (() -> Void)?
    /// Called after the files were dragged out somewhere and the shelf is now empty.
    var onEmptiedByDrag: (() -> Void)?

    private(set) var urls: [URL] = [] {
        didSet { refresh() }
    }

    private var isDropTarget = false {
        didSet { needsDisplay = true }
    }

    private let fanView = IconFanView()
    private let thumbnails = Thumbnails()
    private let label = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private var dragStarted = false
    /// Set on mouse down outside the files: the gesture moves the shelf instead of the files.
    private var moveStart: (mouse: NSPoint, windowOrigin: NSPoint)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])

        fanView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fanView)

        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close shelf")
        closeButton.isBordered = false
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),

            fanView.centerXAnchor.constraint(equalTo: centerXAnchor),
            fanView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            fanView.widthAnchor.constraint(equalToConstant: 96),
            fanView.heightAnchor.constraint(equalToConstant: 84),

            label.topAnchor.constraint(equalTo: fanView.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Tray symbol tinted to match the current appearance (the fan draws images as-is).
    private static let placeholder: NSImage = {
        let symbol = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil) ?? NSImage()
        let size = NSSize(width: symbol.size.width * 3, height: symbol.size.height * 3)
        return NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.tertiaryLabelColor.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }()

    func removeAll() {
        for url in urls { thumbnails.forget(url) }
        urls.removeAll()
    }

    private func refresh() {
        if let first = urls.first {
            fanView.images = urls.map { thumbnails.image(for: $0) { [weak self] in self?.refresh() } }
            label.stringValue = urls.count == 1 ? first.lastPathComponent : "\(urls.count) files"
        } else {
            fanView.images = [Self.placeholder]
            label.stringValue = "Drop files here"
        }
        needsDisplay = true
    }

    @objc private func closeClicked() {
        onClose?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 6), xRadius: 12, yRadius: 12)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        (isDropTarget ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).setStroke()
        path.stroke()
    }

    // MARK: Dropping files onto the shelf

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (objects as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Ignore our own drag passing back over the shelf.
        guard sender.draggingSource as? ShelfView !== self, !fileURLs(from: sender).isEmpty else { return [] }
        isDropTarget = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDropTarget ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTarget = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropTarget = false
        let dropped = fileURLs(from: sender).filter { !urls.contains($0) }
        urls.append(contentsOf: dropped)
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isDropTarget = false
    }

    // MARK: Dragging files out of the shelf

    // The shelf never becomes the active app, so the first click must already work.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
        moveStart = nil
        let point = convert(event.locationInWindow, from: nil)
        if urls.isEmpty || !fanView.frame.contains(point), let window {
            // Grabbing the shelf anywhere except its files moves the shelf.
            moveStart = (NSEvent.mouseLocation, window.frame.origin)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let moveStart, let window {
            let mouse = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(
                x: moveStart.windowOrigin.x + mouse.x - moveStart.mouse.x,
                y: moveStart.windowOrigin.y + mouse.y - moveStart.mouse.y
            ))
            return
        }
        guard !urls.isEmpty, !dragStarted else { return }
        dragStarted = true

        let cardFrame = fanView.convert(fanView.topCardFrame, to: self)
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            // Offset the images slightly so a multi-file drag looks like a stack.
            let offset = CGFloat(min(index, 4)) * 4
            item.setDraggingFrame(cardFrame.offsetBy(dx: offset, dy: -offset), contents: thumbnails.image(for: url) {})
            return item
        }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
    }

    override func mouseUp(with event: NSEvent) {
        dragStarted = false
        moveStart = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Let the destination decide: Finder moves on the same volume and copies across volumes.
        context == .outsideApplication ? [.copy, .move, .link, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragStarted = false
        guard !operation.isEmpty else { return } // cancelled, keep the files on the shelf
        removeAll()
        onEmptiedByDrag?()
    }
}
