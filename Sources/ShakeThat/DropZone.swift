import AppKit
import ShakeCore

/// A drop target at the notch or a screen edge that appears while files are dragged near it.
/// Dropping files on it puts them on the shelf, as an alternative to shaking.
@MainActor
final class DropZoneController {
    /// Called with the dropped files and the point (screen coordinates) to show the shelf at.
    var onDrop: (([URL], NSPoint) -> Void)?

    var settings = DropZoneSettings.defaults {
        didSet { if !settings.dropZoneEnabled { hide() } }
    }

    private let zoneView = DropZoneView()
    private lazy var panel = makePanel()
    private var zoneFrame = NSRect.zero
    private var pendingHide: Task<Void, Never>?

    init() {
        zoneView.onDrop = { [weak self] urls in
            guard let self else { return }
            let point = DropZoneLayout.shelfPoint(for: self.settings.dropZonePosition, zone: self.zoneFrame)
            self.hide()
            self.onDrop?(urls, point)
        }
        zoneView.onDragEnded = { [weak self] in self?.hideSoon() }
    }

    /// Called as the cursor moves during a file drag. Shows the zone when the cursor is near it.
    func fileDragMoved(to point: NSPoint) {
        guard settings.dropZoneEnabled,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
        else { return }
        let frame = DropZoneLayout.frame(for: settings.dropZonePosition, screen: screen.frame, visible: screen.visibleFrame)
        if DropZoneLayout.activationFrame(around: frame).contains(point) {
            pendingHide?.cancel()
            if !panel.isVisible || zoneFrame != frame {
                zoneFrame = frame
                zoneView.position = settings.dropZonePosition
                panel.setFrame(frame, display: true)
            }
            panel.orderFrontRegardless()
        } else if panel.isVisible, !zoneView.isDropTarget {
            hide()
        }
    }

    /// Called when the mouse is released. The drop itself is delivered just after the mouse-up,
    /// so the zone stays up for a moment or the files would have nowhere to land.
    func dragEnded() {
        hideSoon()
    }

    private func hideSoon() {
        pendingHide?.cancel()
        pendingHide = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        pendingHide?.cancel()
        pendingHide = nil
        panel.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = DropZonePanel(
            contentRect: NSRect(x: 0, y: 0, width: DropZoneLayout.length, height: DropZoneLayout.thickness),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Above the menu bar, so the notch zone isn't hidden behind it.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = zoneView
        return panel
    }
}

/// Keeps the zone where it's put: windows are normally pushed below the menu bar.
private final class DropZonePanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// The zone's look and its drop handling.
@MainActor
private final class DropZoneView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onDragEnded: (() -> Void)?

    var position = DropZonePosition.notch {
        didSet { updateLayout() }
    }

    private(set) var isDropTarget = false {
        didSet { needsDisplay = true }
    }

    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "Drop for shelf")
    private let stack = NSStackView()
    private var stackConstraints: [NSLayoutConstraint] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])

        icon.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Drop zone")
        icon.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        icon.contentTintColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white

        stack.orientation = .vertical
        stack.spacing = 4
        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        updateLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateLayout() {
        NSLayoutConstraint.deactivate(stackConstraints)
        // The edge zones are too narrow for the label.
        label.isHidden = position != .notch
        stackConstraints = [stack.centerXAnchor.constraint(equalTo: centerXAnchor)]
        if position == .notch {
            // Keep the content in the lower part, clear of the notch and menu bar.
            stackConstraints.append(stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10))
        } else {
            stackConstraints.append(stack.centerYAnchor.constraint(equalTo: centerYAnchor))
        }
        NSLayoutConstraint.activate(stackConstraints)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Round only the corners away from the screen edge, by letting the shape run past that edge.
        let radius: CGFloat = 16
        var shape = bounds
        switch position {
        case .notch: shape.size.height += radius
        case .left: shape.origin.x -= radius; shape.size.width += radius
        case .right: shape.size.width += radius
        }
        let path = NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius)
        NSColor.black.withAlphaComponent(0.88).setFill()
        path.fill()
        if isDropTarget {
            let outline = NSBezierPath(roundedRect: shape.insetBy(dx: 1.5, dy: 1.5), xRadius: radius, yRadius: radius)
            outline.lineWidth = 3
            NSColor.controlAccentColor.setStroke()
            outline.stroke()
        }
    }

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (objects as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
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
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isDropTarget = false
        onDragEnded?()
    }
}
