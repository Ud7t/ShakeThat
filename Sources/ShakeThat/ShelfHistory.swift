import Foundation
import ShakeCore

/// The last few shelves that were cleared, kept across relaunches.
///
/// Files are remembered as bookmarks, not copies, so a file that was moved
/// (for example by dragging it off the shelf into a folder) is found in its new place.
@MainActor
final class ShelfHistory {
    struct Entry: Codable {
        var date: Date
        var bookmarks: [Data]
        /// File names at the time the shelf was cleared, for the menu.
        var names: [String]
    }

    private static let defaultsKey = "ShelfHistory"

    private let defaults: UserDefaults
    private(set) var entries: [Entry] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = Array(saved.prefix(Self.limit))
        }
    }

    /// `recentShelvesLimit` from the settings file, read each time so hand edits apply without a relaunch.
    private static var limit: Int {
        (ShelfSettings.load(from: ShakeSettingsStore.fileURL) ?? .defaults).recentShelvesLimit
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Adds a shelf to the top of the history, dropping the oldest beyond the limit.
    func record(bookmarks: [Data], names: [String]) {
        guard !bookmarks.isEmpty else { return }
        entries.insert(Entry(date: Date(), bookmarks: bookmarks, names: names), at: 0)
        let limit = Self.limit
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        save()
    }

    func remove(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        save()
    }

    /// The entry's files that still exist, at their current location.
    func existingFiles(of entry: Entry) -> [URL] {
        entry.bookmarks.compactMap { data in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
