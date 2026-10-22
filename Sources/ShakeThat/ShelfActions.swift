import AppKit
import ImageIO
import ShakeCore
import UniformTypeIdentifiers

/// Dropover-style quick actions for the files on the shelf. Everything runs locally.
///
/// The file actions are plain functions that block, so the shelf runs them off the main thread.
/// New files are saved next to the originals, never over an existing file.
enum ShelfActions {
    /// What a batch action did: one URL per input (the new file, or the original if that one failed),
    /// plus a message for each failure.
    struct Outcome {
        var files: [URL] = []
        var errors: [String] = []
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    enum ImageFormat: CaseIterable {
        case png, jpeg, heic, tiff

        var title: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .heic: return "HEIC"
            case .tiff: return "TIFF"
            }
        }

        var type: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .tiff: return .tiff
            }
        }

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .heic: return "heic"
            case .tiff: return "tiff"
            }
        }
    }

    /// Resize choices, as a fraction of the original's width and height.
    static let resizeScales: [Double] = [0.75, 0.5, 0.25]

    // MARK: Instant actions

    /// Puts the files' paths on the clipboard, one per line.
    static func copyPaths(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }

    static func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
    }

    static func isImage(_ url: URL) -> Bool {
        contentType(of: url)?.conforms(to: .image) ?? false
    }

    // MARK: File actions (blocking)

    /// Runs `action` on each file, carrying on past failures.
    static func each(_ urls: [URL], _ action: (URL) throws -> URL) -> Outcome {
        var outcome = Outcome()
        for url in urls {
            do {
                outcome.files.append(try action(url))
            } catch {
                outcome.files.append(url)
                outcome.errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return outcome
    }

    /// Zips the files next to the first one, named like Finder's Compress does:
    /// "name.zip" for one item and "Archive.zip" for several.
    static func compress(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw Failure("There's nothing to compress.") }
        let folder = first.deletingLastPathComponent()
        let output = availableURL(urls.count == 1 ? first.lastPathComponent + ".zip" : "Archive.zip", in: folder)

        if urls.count == 1 {
            try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, output.path])
        } else {
            // ditto zips a single item, so gather the files in a temporary folder and zip its contents.
            // The folder is on the same volume, where copies are cheap clones.
            let staging = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: folder, create: true
            )
            defer { try? FileManager.default.removeItem(at: staging) }
            for url in urls {
                try FileManager.default.copyItem(at: url, to: availableURL(url.lastPathComponent, in: staging))
            }
            try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", staging.path, output.path])
        }
        return output
    }

    /// Saves a copy of the image in another format next to it. An image already in that format is left as is.
    static func convert(_ url: URL, to format: ImageFormat) throws -> URL {
        if contentType(of: url)?.conforms(to: format.type) == true { return url }
        let source = try imageSource(at: url)
        guard var image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure("The image couldn't be read.")
        }
        // JPEG has no transparency: put see-through parts on white rather than black.
        if format == .jpeg { image = flattened(image) }
        let name = FileNaming.replacingExtension(of: url.lastPathComponent, with: format.fileExtension)
        let output = availableURL(name, in: url.deletingLastPathComponent())
        // The original's properties keep its orientation, resolution and metadata.
        try write(image, properties: CGImageSourceCopyPropertiesAtIndex(source, 0, nil), as: format.type, to: output)
        return output
    }

    /// Saves a smaller copy of the image next to it, as "name (50%).ext", in the same format when possible.
    static func resize(_ url: URL, scale: Double) throws -> URL {
        let source = try imageSource(at: url)
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width > 0, height > 0 else { throw Failure("The image's size couldn't be read.") }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int((Double(max(width, height)) * scale).rounded())),
            // Applies the orientation, so the copy is upright without orientation metadata.
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure("The image couldn't be resized.")
        }

        let writable = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        let sourceType = (CGImageSourceGetType(source) as String?).flatMap { writable.contains($0) ? UTType($0) : nil }
        let type = sourceType ?? .png
        var name = FileNaming.adding("\(Int((scale * 100).rounded()))%", to: url.lastPathComponent)
        if sourceType == nil { name = FileNaming.replacingExtension(of: name, with: "png") }
        let output = availableURL(name, in: url.deletingLastPathComponent())
        try write(image, properties: nil, as: type, to: output)
        return output
    }

    /// Moves the file into `folder`. If the name is taken there, the moved file gets a number, like Finder's Keep Both.
    static func move(_ url: URL, to folder: URL) throws -> URL {
        if url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL { return url }
        let destination = availableURL(url.lastPathComponent, in: folder)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    // MARK: Helpers

    private static func availableURL(_ name: String, in folder: URL) -> URL {
        let free = FileNaming.available(name) {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
        return folder.appendingPathComponent(free)
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw Failure(message.isEmpty ? "\(tool) failed." : message)
        }
    }

    private static func imageSource(at url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw Failure("The image couldn't be opened.")
        }
        return source
    }

    private static func write(_ image: CGImage, properties: CFDictionary?, as type: UTType, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw Failure("This Mac can't save \(type.localizedDescription ?? "that kind of") images.")
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw Failure("\(url.lastPathComponent) couldn't be saved.")
        }
    }

    /// The image drawn on white, if it has transparency.
    private static func flattened(_ image: CGImage) -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        let rgb = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
        guard let space = rgb ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }
}
