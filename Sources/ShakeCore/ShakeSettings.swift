import Foundation

/// The tunable shake-detection values, stored as a human-readable JSON file.
public struct ShakeSettings: Codable, Equatable {
    /// Distance (in points) the cursor must travel in one direction for a stroke to count.
    public var minimumTravel: Double
    /// Number of direction reversals needed to register a shake.
    public var requiredReversals: Int
    /// Reversals must all happen within this many seconds.
    public var window: TimeInterval
    /// Minimum time (in seconds) between two reported shakes.
    public var cooldown: TimeInterval

    public static let defaults = ShakeSettings(
        minimumTravel: 20,
        requiredReversals: 4,
        window: 0.8,
        cooldown: 1.0
    )

    public init(minimumTravel: Double, requiredReversals: Int, window: TimeInterval, cooldown: TimeInterval) {
        self.minimumTravel = minimumTravel
        self.requiredReversals = requiredReversals
        self.window = window
        self.cooldown = cooldown
    }

    /// Missing keys fall back to the defaults, so a hand-edited file with only some values still loads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = ShakeSettings.defaults
        minimumTravel = try container.decodeIfPresent(Double.self, forKey: .minimumTravel) ?? d.minimumTravel
        requiredReversals = try container.decodeIfPresent(Int.self, forKey: .requiredReversals) ?? d.requiredReversals
        window = try container.decodeIfPresent(TimeInterval.self, forKey: .window) ?? d.window
        cooldown = try container.decodeIfPresent(TimeInterval.self, forKey: .cooldown) ?? d.cooldown
    }

    /// The same settings with out-of-range values pulled back to something the detector can use.
    public func clamped() -> ShakeSettings {
        ShakeSettings(
            minimumTravel: min(max(minimumTravel, 1), 1000),
            requiredReversals: min(max(requiredReversals, 1), 20),
            window: min(max(window, 0.1), 10),
            cooldown: min(max(cooldown, 0), 10)
        )
    }

    /// Reads settings from `url`. Returns `nil` if the file is missing or isn't valid JSON.
    public static func load(from url: URL) -> ShakeSettings? {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(ShakeSettings.self, from: data)
        else { return nil }
        return settings.clamped()
    }

    /// Writes settings to `url` as pretty-printed JSON, creating the folder if needed.
    /// Other keys in the file (such as the shelf settings) are kept.
    public func save(to url: URL) throws {
        try SettingsFile.merge(self, into: url)
    }
}
