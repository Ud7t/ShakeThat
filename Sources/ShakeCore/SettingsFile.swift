import Foundation

/// Helpers for the one JSON settings file that several settings types share.
public enum SettingsFile {
    /// Writes `value`'s keys into the JSON object at `url`, keeping any other keys already there,
    /// so saving one kind of settings never drops another's. With `onlyMissing`, keys already
    /// in the file keep their values. A missing or unreadable file starts from an empty object.
    public static func merge<T: Encodable>(_ value: T, into url: URL, onlyMissing: Bool = false) throws {
        var object: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = existing
        }
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] ?? [:]
        for (key, newValue) in encoded where !onlyMissing || object[key] == nil {
            object[key] = newValue
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
