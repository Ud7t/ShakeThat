import AppKit
import ShakeCore

/// The shelf's content: accepts dropped files and lets you drag them all back out.
@MainActor
final class ShelfView: NSView, NSDraggingSource {
    /// Called when the close button is clicked.
    var onClose: (() -> Void)?
    /// Called after the files were dragged out somewhere, while they're still on the shelf.
    var onDraggedOut: (() -> Void)?
    /// Called when a quick action made new files (a zip, converted images) that take the shelf's place.
    var onReplaceFiles: (([URL]) -> Void)?

    private(set) var urls: [URL] = [] {
        didSet { refresh() }
    }

    private var isDropTarget = false {
        didSet { needsDisplay = true }
    }

    /// Bookmarks taken when each file was dropped, so the history can find files that are moved later.
    private var bookmarks: [URL: Data] = [:]

    private let fanView = IconFanView()
    private let thumbnails = Thumbnails()
    private let label = NSTextField(labelWithString: "")
    /// "N Files" at the bottom; click it for the details panel.
    private let countPill = CountPill()
    private let details = FileDetailsPopover()
    private let closeButton = NSButton()
    private let shareButton = NSButton()
    private var dragStarted = false
    /// True while a quick action runs, so another can't start on the same files.
    private var isBusy = false {
        didSet { refresh() }
    }
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

        countPill.target = self
        countPill.action = #selector(countClicked)
        countPill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countPill)

        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close shelf")
        closeButton.isBordered = false
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        shareButton.image = NSImage(systemSymbolName: "square.and.arrow.up.circle.fill", accessibilityDescription: "Share files")
        shareButton.isBordered = false
        shareButton.contentTintColor = .tertiaryLabelColor
        shareButton.target = self
        shareButton.action = #selector(shareClicked)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shareButton)

        NSLayoutConstraint.activate([
            // Inside the dashed outline (inset 6, corner radius 12) rather than on top of it.
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            // Mirrors the close button in the opposite corner.
            shareButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            shareButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            fanView.centerXAnchor.constraint(equalTo: centerXAnchor),
            fanView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            fanView.widthAnchor.constraint(equalToConstant: 96),
            fanView.heightAnchor.constraint(equalToConstant: 84),

            label.topAnchor.constraint(equalTo: fanView.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            countPill.topAnchor.constraint(equalTo: fanView.bottomAnchor, constant: 4),
            countPill.centerXAnchor.constraint(equalTo: centerXAnchor),
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

    /// Bookmarks and names for the files on the shelf, in shelf order.
    var bookmarkedFiles: [(bookmark: Data, name: String)] {
        urls.compactMap { url in
            (bookmarks[url] ?? ShelfHistory.bookmark(for: url)).map { ($0, url.lastPathComponent) }
        }
    }

    func add(_ newURLs: [URL]) {
        let added = newURLs.filter { !urls.contains($0) }
        for url in added { bookmarks[url] = ShelfHistory.bookmark(for: url) }
        urls.append(contentsOf: added)
    }

    func removeAll() {
        for url in urls { thumbnails.forget(url) }
        bookmarks.removeAll()
        urls.removeAll()
    }

    private func refresh() {
        label.isHidden = !urls.isEmpty
        countPill.isHidden = urls.isEmpty
        countPill.isEnabled = !isBusy
        if !urls.isEmpty {
            let images = urls.map { thumbnails.image(for: $0) { [weak self] in self?.refresh() } }
            fanView.images = images
            countPill.text = isBusy ? "Working…" : FileDetailsFormat.fileCount(urls.count)
            details.model.update(zip(urls, images).map { (url: $0, icon: $1) })
        } else {
            fanView.images = [Self.placeholder]
            label.stringValue = "Drop files here"
            details.close()
        }
        shareButton.isHidden = urls.isEmpty
        needsDisplay = true
    }

    @objc private func countClicked() {
        details.toggle(below: countPill)
    }

    @objc private func closeClicked() {
        onClose?()
    }

    /// Opens the system share sheet (AirDrop, Mail, Messages, ...) for every file on the shelf.
    @objc private func shareClicked() {
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: shareButton.bounds, of: shareButton, preferredEdge: .minY)
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
        add(fileURLs(from: sender))
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
        if event.modifierFlags.contains(.control), let menu = menu(for: event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
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
        onDraggedOut?()
    }

    // MARK: Quick actions

    /// Right-click (or Control-click) the shelf for actions on all of its files.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !urls.isEmpty, !isBusy else { return nil }
        let files = urls
        let images = files.filter(ShelfActions.isImage)
        let menu = NSMenu()

        menu.addItem(ActionMenuItem(files.count == 1 ? "Copy Path" : "Copy \(files.count) Paths") {
            ShelfActions.copyPaths(files)
        })
        menu.addItem(ActionMenuItem("Reveal in Finder") {
            ShelfActions.revealInFinder(files)
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(files.count == 1 ? "Compress “\(files[0].lastPathComponent)”" : "Compress \(files.count) Items") { [weak self] in
            self?.compress(files)
        })
        menu.addItem(ActionMenuItem("Move to Folder…") { [weak self] in
            self?.chooseFolderAndMove(files)
        })

        if !images.isEmpty {
            menu.addItem(.separator())
            let noun = images.count == 1 ? "Image" : "\(images.count) Images"
            let convert = NSMenu()
            for format in ShelfActions.ImageFormat.allCases {
                let item = ActionMenuItem(format.title) { [weak self] in
                    self?.transformImages(images) { try ShelfActions.convert($0, to: format) }
                }
                // Nothing to do if every image is already in this format.
                item.isEnabled = images.contains { ShelfActions.contentType(of: $0)?.conforms(to: format.type) != true }
                convert.addItem(item)
            }
            let convertItem = NSMenuItem(title: "Convert \(noun) To", action: nil, keyEquivalent: "")
            convertItem.submenu = convert
            menu.addItem(convertItem)

            let resize = NSMenu()
            for scale in ShelfActions.resizeScales {
                resize.addItem(ActionMenuItem("\(Int((scale * 100).rounded()))%") { [weak self] in
                    self?.transformImages(images) { try ShelfActions.resize($0, scale: scale) }
                })
            }
            let resizeItem = NSMenuItem(title: "Resize \(noun)", action: nil, keyEquivalent: "")
            resizeItem.submenu = resize
            menu.addItem(resizeItem)
        }
        // Items are enabled or disabled above, not by the responder chain.
        menu.autoenablesItems = false
        return menu
    }

    /// The zip takes the files' place on the shelf, ready to drag out.
    private func compress(_ files: [URL]) {
        runInBackground {
            do {
                return ShelfActions.Outcome(files: [try ShelfActions.compress(files)])
            } catch {
                return ShelfActions.Outcome(errors: [error.localizedDescription])
            }
        } then: { [weak self] outcome in
            guard let self, let zip = outcome.files.first else { return }
            self.onReplaceFiles?(self.urls.filter { !files.contains($0) } + [zip])
        }
    }

    /// The new images take the originals' place on the shelf. Other files stay.
    private func transformImages(_ images: [URL], _ transform: @escaping (URL) throws -> URL) {
        runInBackground {
            ShelfActions.each(images, transform)
        } then: { [weak self] outcome in
            guard let self else { return }
            let replacements = Dictionary(zip(images, outcome.files), uniquingKeysWith: { first, _ in first })
            let updated = self.urls.map { replacements[$0] ?? $0 }
            if updated != self.urls { self.onReplaceFiles?(updated) }
        }
    }

    private func chooseFolderAndMove(_ files: [URL]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move"
        panel.message = files.count == 1 ? "Move “\(files[0].lastPathComponent)” to:" : "Move \(files.count) items to:"
        // The app never activates on its own, so bring it forward for the panel.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        runInBackground {
            ShelfActions.each(files) { try ShelfActions.move($0, to: folder) }
        } then: { [weak self] outcome in
            // Same files, new places: update the shelf in place.
            guard let self else { return }
            for (old, new) in zip(files, outcome.files) where old != new {
                guard let index = self.urls.firstIndex(of: old) else { continue }
                self.thumbnails.forget(old)
                self.bookmarks[new] = self.bookmarks.removeValue(forKey: old)
                self.urls[index] = new
            }
        }
    }

    private func runInBackground(
        _ work: @escaping () -> ShelfActions.Outcome,
        then finish: @escaping (ShelfActions.Outcome) -> Void
    ) {
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = work()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isBusy = false
                    finish(outcome)
                    if !outcome.errors.isEmpty { Self.showErrors(outcome.errors) }
                }
            }
        }
    }

    private static func showErrors(_ errors: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = errors.count == 1 ? "The action couldn’t be completed." : "Some files couldn’t be processed."
        alert.informativeText = errors.joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

/// A menu item that runs a closure.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}
