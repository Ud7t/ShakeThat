import Foundation
import ShakeCore

/// The last few shelves that were cleared, kept across relaunches.
/// Pinned shelves are kept too, outside the limit, until they're unpinned, removed or their files are gone.
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
        var isPinned = false

        init(date: Date, bookmarks: [Data], names: [String], isPinned: Bool) {
            self.date = date
            self.bookmarks = bookmarks
            self.names = names
            self.isPinned = isPinned
        }

        // Entries saved before pinning existed have no isPinned.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(Date.self, forKey: .date)
            bookmarks = try container.decode([Data].self, forKey: .bookmarks)
            names = try container.decode([String].self, forKey: .names)
            isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        }
    }

    private static let defaultsKey = "ShelfHistory"

    private let defaults: UserDefaults
    private(set) var entries: [Entry] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
            trim()
        }
    }

    /// `recentShelvesLimit` from the settings file, read each time so hand edits apply without a relaunch.
    private static var limit: Int {
        (ShelfSettings.load(from: ShakeSettingsStore.fileURL) ?? .defaults).recentShelvesLimit
    }

    static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Adds a shelf to the top of the history, dropping the oldest unpinned ones beyond the limit.
    func record(bookmarks: [Data], names: [String], isPinned: Bool = false) {
        guard !bookmarks.isEmpty else { return }
        entries.insert(Entry(date: Date(), bookmarks: bookmarks, names: names, isPinned: isPinned), at: 0)
        trim()
        save()
    }

    /// Forgets pinned shelves whose files are all gone. Unpinned ones stay, greyed out, until they age out.
    func removeMissingPinned() {
        let before = entries.count
        entries.removeAll { $0.isPinned && existingFiles(of: $0).isEmpty }
        if entries.count != before { save() }
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

    /// Pinned shelves don't count toward the limit.
    private func trim() {
        var unpinned = 0
        let limit = Self.limit
        entries.removeAll { entry in
            guard !entry.isPinned else { return false }
            unpinned += 1
            return unpinned > limit
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
