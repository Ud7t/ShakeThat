import Foundation

/// Text for the shelf's file count and the details panel.
public enum FileDetailsFormat {
    /// "1 File", "6 Files".
    public static func fileCount(_ count: Int) -> String {
        count == 1 ? "1 File" : "\(count) Files"
    }

    /// "315 KB", "2.7 MB", like Finder.
    public static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Pixel size of an image: "900x900".
    public static func dimensions(width: Int, height: Int) -> String {
        "\(width)x\(height)"
    }

    /// Length of a video or sound: "00:08", "12:34", "1:02:03".
    public static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total / 60 % 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    /// "1 page", "12 pages".
    public static func pageCount(_ count: Int) -> String {
        count == 1 ? "1 page" : "\(count) pages"
    }

    /// "3 items" for a folder.
    public static func itemCount(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }

    /// The non-empty parts joined with a middle dot: "315 KB • 900x900".
    public static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
    }
}
