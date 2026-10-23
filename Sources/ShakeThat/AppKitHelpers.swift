import AppKit
import UniformTypeIdentifiers

extension NSPasteboard {
    private static let fileURLOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

    /// The file URLs on the pasteboard, ignoring web links and other kinds of URL.
    var fileURLs: [URL] {
        (readObjects(forClasses: [NSURL.self], options: Self.fileURLOptions) as? [URL]) ?? []
    }

    /// Whether the pasteboard holds any file URLs, without reading them all.
    var hasFileURLs: Bool {
        canReadObject(forClasses: [NSURL.self], options: Self.fileURLOptions)
    }
}

extension URL {
    /// The file's type, as Finder sees it.
    var contentType: UTType? {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType
    }

    var isImage: Bool {
        contentType?.conforms(to: .image) ?? false
    }
}

extension NSScreen {
    /// The screen that `point` (in screen coordinates) is on.
    static func containing(_ point: NSPoint) -> NSScreen? {
        screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}

extension NSPanel {
    /// A borderless, see-through panel that floats over every Space and full-screen app
    /// without ever activating the app.
    convenience init(overlayWithContentRect contentRect: NSRect) {
        self.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }
}
