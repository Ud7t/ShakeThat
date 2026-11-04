import AppKit
import QuickLookThumbnailing

/// Finder-style icons for files. Image files are upgraded to a Quick Look preview of the picture,
/// and PDFs to a preview of their first page drawn as a document icon, as Finder shows them.
@MainActor
final class Thumbnails {
    private var cache: [URL: NSImage] = [:]

    /// Returns the best image available now. If a Quick Look preview isn't cached yet,
    /// one is requested and `onUpdate` is called when it arrives.
    func image(for url: URL, onUpdate: @escaping () -> Void) -> NSImage {
        if let cached = cache[url] { return cached }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[url] = icon
        let isPDF = url.isPDF
        guard url.isImage || isPDF else { return icon }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 128, height: 128),
            scale: scale,
            representationTypes: .thumbnail
        )
        // Finder draws PDF previews as a page with a border, rather than the bare page.
        request.iconMode = isPDF
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            // If no preview can be made, the file keeps its icon.
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
