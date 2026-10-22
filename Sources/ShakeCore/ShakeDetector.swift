import Foundation

/// Detects a horizontal "shake" from a stream of cursor positions.
///
/// A shake is a number of left/right direction reversals within a short time window.
/// A reversal only counts once the cursor has travelled back at least `minimumTravel`
/// points from its furthest position, so small jitter during a normal drag is ignored.
public struct ShakeDetector {
    /// Distance (in points) the cursor must travel in one direction for a stroke to count.
    public var minimumTravel: Double
    /// Number of direction reversals needed to register a shake.
    public var requiredReversals: Int
    /// Reversals must all happen within this many seconds.
    public var window: TimeInterval
    /// Minimum time between two reported shakes.
    public var cooldown: TimeInterval

    private var direction = 0
    private var anchorX: Double?
    private var extremeX = 0.0
    private var reversals: [TimeInterval] = []
    private var lastShake: TimeInterval = -.infinity

    public init(settings: ShakeSettings = .defaults) {
        minimumTravel = settings.minimumTravel
        requiredReversals = settings.requiredReversals
        window = settings.window
        cooldown = settings.cooldown
    }

    /// The detector's current tuning, e.g. for applying new values from the settings file.
    public var settings: ShakeSettings {
        get {
            ShakeSettings(
                minimumTravel: minimumTravel,
                requiredReversals: requiredReversals,
                window: window,
                cooldown: cooldown
            )
        }
        set {
            minimumTravel = newValue.minimumTravel
            requiredReversals = newValue.requiredReversals
            window = newValue.window
            cooldown = newValue.cooldown
        }
    }

    /// Forgets the current gesture, e.g. when the mouse button goes down or up.
    public mutating func reset() {
        direction = 0
        anchorX = nil
        extremeX = 0
        reversals.removeAll()
    }

    /// Feeds one cursor x position. Returns `true` when this sample completes a shake.
    public mutating func add(x: Double, at time: TimeInterval) -> Bool {
        guard let anchor = anchorX else {
            anchorX = x
            extremeX = x
            return false
        }

        if direction == 0 {
            if abs(x - anchor) >= minimumTravel {
                direction = x > anchor ? 1 : -1
                extremeX = x
            }
            return false
        }

        let movedPastExtreme = direction > 0 ? x > extremeX : x < extremeX
        if movedPastExtreme {
            extremeX = x
        } else if abs(extremeX - x) >= minimumTravel {
            // The stroke that just ended was at least minimumTravel long by construction
            // (we only set a direction after that much travel), so count the reversal.
            reversals.append(time)
            direction = -direction
            anchorX = extremeX
            extremeX = x
        }

        reversals.removeAll { time - $0 > window }
        if reversals.count >= requiredReversals, time - lastShake >= cooldown {
            lastShake = time
            reversals.removeAll()
            return true
        }
        return false
    }
}
