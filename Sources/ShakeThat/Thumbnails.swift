import AppKit
import QuickLookThumbnailing

/// Finder-style icons for files, upgraded to Quick Look previews (photos, PDFs...) when available.
@MainActor
final class Thumbnails {
    private var cache: [URL: NSImage] = [:]

    /// Returns the best image available now. If a Quick Look preview isn't cached yet,
    /// one is requested and `onUpdate` is called when it arrives.
    func image(for url: URL, onUpdate: @escaping () -> Void) -> NSImage {
        if let cached = cache[url] { return cached }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[url] = icon

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 128, height: 128),
            scale: scale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            // Files with no preview (folders, apps...) fail here and keep their icon.
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.cache[url] != nil else { return }
                    self.cache[url] = image
                    onUpdate()
                }
            }
        }
        return icon
    }

    func forget(_ url: URL) {
        cache[url] = nil
    }
}
