import Foundation

/// Picks names for files the shelf creates, without overwriting anything.
public enum FileNaming {
    /// `fileName` if it's free, otherwise "name 2.ext", "name 3.ext", ... like Finder's "Keep Both".
    public static func available(_ fileName: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(fileName) else { return fileName }
        let (stem, ext) = split(fileName)
        var number = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(ext)"
            if !isTaken(candidate) { return candidate }
            number += 1
        }
    }

    /// Replaces the extension, or adds one: "photo.png" with "jpg" is "photo.jpg".
    public static func replacingExtension(of fileName: String, with ext: String) -> String {
        "\(split(fileName).stem).\(ext)"
    }

    /// Adds a note before the extension: "photo.png" with "50%" is "photo (50%).png".
    public static func adding(_ note: String, to fileName: String) -> String {
        let (stem, ext) = split(fileName)
        return ext.isEmpty ? "\(stem) (\(note))" : "\(stem) (\(note)).\(ext)"
    }

    /// Splits off the last extension. A leading dot (".zshrc") isn't an extension.
    static func split(_ fileName: String) -> (stem: String, ext: String) {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return (fileName, "") }
        let ext = fileName[fileName.index(after: dot)...]
        guard !ext.isEmpty else { return (fileName, "") }
        return (String(fileName[..<dot]), String(ext))
    }
}
