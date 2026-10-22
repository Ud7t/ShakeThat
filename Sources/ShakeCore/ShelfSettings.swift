import Foundation

/// Shelf values kept in the settings file. They're edited by hand, not in the Settings window.
public struct ShelfSettings: Codable, Equatable {
    /// How many cleared shelves Recent Shelves remembers.
    public var recentShelvesLimit: Int

    public static let defaults = ShelfSettings(recentShelvesLimit: 10)

    public init(recentShelvesLimit: Int) {
        self.recentShelvesLimit = recentShelvesLimit
    }

    /// Missing keys fall back to the defaults, so the shake-only file from before still loads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recentShelvesLimit = try container.decodeIfPresent(Int.self, forKey: .recentShelvesLimit)
            ?? ShelfSettings.defaults.recentShelvesLimit
    }

    public func clamped() -> ShelfSettings {
        ShelfSettings(recentShelvesLimit: min(max(recentShelvesLimit, 1), 100))
    }

    /// Reads settings from `url`. Returns `nil` if the file is missing or isn't valid JSON.
    public static func load(from url: URL) -> ShelfSettings? {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(ShelfSettings.self, from: data)
        else { return nil }
        return settings.clamped()
    }
}
