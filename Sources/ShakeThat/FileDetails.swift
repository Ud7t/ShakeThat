import AppKit
import AVFoundation
import ImageIO
import ShakeCore
import UniformTypeIdentifiers

/// One file in the details panel.
struct FileDetails: Identifiable {
    let url: URL
    let icon: NSImage
    let size: Int64?
    /// Image dimensions, video length, page count or folder item count, once loaded.
    let detail: String?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var subtitle: String { FileDetailsFormat.joined([size.map(FileDetailsFormat.size), detail]) }
}

/// What the details panel shows. Details are read in the background and cached per file.
@MainActor
final class FileDetailsModel: ObservableObject {
    enum Layout: String {
        case grid, list
    }

    private static let layoutKey = "detailsLayout"

    @Published private(set) var files: [FileDetails] = [] {
        didSet { onResize?() }
    }

    @Published var layout = Layout(rawValue: UserDefaults.standard.string(forKey: FileDetailsModel.layoutKey) ?? "") ?? .grid {
        didSet {
            UserDefaults.standard.set(layout.rawValue, forKey: Self.layoutKey)
            onResize?()
        }
    }

    /// Called when the panel's size may have changed (files added or removed, layout switched).
    var onResize: (() -> Void)?

    private var order: [URL] = []
    private var icons: [URL: NSImage] = [:]
    private var sizes: [URL: Int64?] = [:]
    /// "" once loaded for a file that has no detail, so it isn't loaded again.
    private var details: [URL: String] = [:]

    var header: String {
        let total = files.compactMap(\.size).reduce(0, +)
        return FileDetailsFormat.joined([FileDetailsFormat.fileCount(files.count), FileDetailsFormat.size(total)])
    }

    /// Shows `items` (each file with the icon the shelf uses for it), loading any details not seen before.
    func update(_ items: [(url: URL, icon: NSImage)]) {
        order = items.map(\.url)
        let current = Set(order)
        sizes = sizes.filter { current.contains($0.key) }
        details = details.filter { current.contains($0.key) }
        icons = Dictionary(items.map { ($0.url, $0.icon) }, uniquingKeysWith: { first, _ in first })

        for url in current where sizes[url] == nil {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            // Folders have no size of their own; adding up their contents could take a while.
            let size = values?.isDirectory == true ? nil : values?.fileSize.map(Int64.init)
            sizes[url] = .some(size)
        }
        for url in current where details[url] == nil {
            details[url] = ""
            Task { [weak self] in
                let detail = await FileDetailsLoader.detail(for: url)
                guard let self, self.details[url] != nil, let detail else { return }
                self.details[url] = detail
                self.rebuild()
            }
        }
        rebuild()
    }

    private func rebuild() {
        files = order.compactMap { url in
            guard let icon = icons[url] else { return nil }
            let detail = details[url].flatMap { $0.isEmpty ? nil : $0 }
            return FileDetails(url: url, icon: icon, size: sizes[url] ?? nil, detail: detail)
        }
    }
}

/// Reads the per-type detail shown under a file's size.
enum FileDetailsLoader {
    static func detail(for url: URL) async -> String? {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey, .isPackageKey])
        if values?.isDirectory == true {
            // An app or other package shows like a file, without the count of what's inside.
            guard values?.isPackage != true else { return nil }
            let contents = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            )
            return contents.map { FileDetailsFormat.itemCount($0.count) }
        }
        guard let type = values?.contentType else { return nil }
        if type.conforms(to: .image) {
            return imageDimensions(url)
        }
        if type.conforms(to: .pdf) {
            return CGPDFDocument(url as CFURL).map { FileDetailsFormat.pageCount($0.numberOfPages) }
        }
        if type.conforms(to: .audiovisualContent) {
            guard let duration = try? await AVURLAsset(url: url).load(.duration), duration.isNumeric else { return nil }
            return FileDetailsFormat.duration(duration.seconds)
        }
        return nil
    }

    /// Pixel size as the image is displayed, so rotated photos show their upright size.
    private static func imageDimensions(_ url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        // EXIF orientations 5 to 8 are rotated a quarter turn.
        let rotated = (properties[kCGImagePropertyOrientation] as? Int ?? 1) >= 5
        return rotated
            ? FileDetailsFormat.dimensions(width: height, height: width)
            : FileDetailsFormat.dimensions(width: width, height: height)
    }
}
