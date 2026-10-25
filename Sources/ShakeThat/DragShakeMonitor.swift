import AppKit
import ShakeCore

/// Watches mouse drags system-wide and reports a shake while files are being dragged.
/// It also reports every move of a file drag and the mouse-up, for the drop zone.
@MainActor
final class DragShakeMonitor {
    /// Called with the cursor location (screen coordinates) when a shake is detected.
    var onShake: ((NSPoint) -> Void)?
    /// Called with the cursor location (screen coordinates) each time a file drag moves.
    var onFileDragMoved: ((NSPoint) -> Void)?
    /// Called when the mouse is released after a file drag.
    var onFileDragEnded: (() -> Void)?

    private var monitor: Any?
    private var detector = ShakeDetector()
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0
    /// Set once the current drag is known to carry files, so the pasteboard isn't read on every move.
    private var draggingFiles = false

    /// The shake-detection tuning. Changes apply to the next mouse sample.
    var settings: ShakeSettings {
        get { detector.settings }
        set { detector.settings = newValue }
    }

    func start() {
        guard monitor == nil else { return }
        // Global monitors see events sent to other apps, which is where file drags start
        // (Finder, Desktop, Mail...). Mouse events need no Accessibility permission.
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            // The drag pasteboard is rewritten when a new drag starts, so remembering its
            // change count lets us ignore files left over from an earlier drag.
            changeCountAtMouseDown = dragPasteboard.changeCount
            draggingFiles = false
            detector.reset()
        case .leftMouseDragged:
            let location = NSEvent.mouseLocation
            if !draggingFiles { draggingFiles = isDraggingFiles() }
            if detector.add(x: location.x, at: event.timestamp), draggingFiles {
                onShake?(location)
            }
            if draggingFiles { onFileDragMoved?(location) }
        case .leftMouseUp:
            detector.reset()
            if draggingFiles { onFileDragEnded?() }
            draggingFiles = false
        default:
            break
        }
    }

    private func isDraggingFiles() -> Bool {
        guard dragPasteboard.changeCount != changeCountAtMouseDown else { return false }
        return dragPasteboard.hasFileURLs
    }
}
