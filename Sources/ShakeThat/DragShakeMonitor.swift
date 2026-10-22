import AppKit
import ShakeCore

/// Watches mouse drags system-wide and reports a shake while files are being dragged.
@MainActor
final class DragShakeMonitor {
    /// Called with the cursor location (screen coordinates) when a shake is detected.
    var onShake: ((NSPoint) -> Void)?

    private var monitor: Any?
    private var detector = ShakeDetector()
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0

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

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            // The drag pasteboard is rewritten when a new drag starts, so remembering its
            // change count lets us ignore files left over from an earlier drag.
            changeCountAtMouseDown = dragPasteboard.changeCount
            detector.reset()
        case .leftMouseDragged:
            let location = NSEvent.mouseLocation
            if detector.add(x: location.x, at: event.timestamp), isDraggingFiles() {
                onShake?(location)
            }
        case .leftMouseUp:
            detector.reset()
        default:
            break
        }
    }

    private func isDraggingFiles() -> Bool {
        guard dragPasteboard.changeCount != changeCountAtMouseDown else { return false }
        return dragPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }
}
