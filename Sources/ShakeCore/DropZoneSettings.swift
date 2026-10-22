import CoreGraphics
import Foundation

/// Where the drop zone appears while files are being dragged.
public enum DropZonePosition: String, Codable, CaseIterable {
    /// Top centre of the screen, around the notch on MacBooks that have one.
    case notch
    case left
    case right
}

/// The drop zone values in the settings file, edited in the Shake Settings window.
public struct DropZoneSettings: Codable, Equatable {
    /// Whether the drop zone appears at all.
    public var dropZoneEnabled: Bool
    public var dropZonePosition: DropZonePosition

    public static let defaults = DropZoneSettings(dropZoneEnabled: true, dropZonePosition: .notch)

    public init(dropZoneEnabled: Bool, dropZonePosition: DropZonePosition) {
        self.dropZoneEnabled = dropZoneEnabled
        self.dropZonePosition = dropZonePosition
    }

    /// Missing keys, or a position that isn't one of the known ones, fall back to the defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = DropZoneSettings.defaults
        dropZoneEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .dropZoneEnabled)) ?? d.dropZoneEnabled
        dropZonePosition = (try? container.decodeIfPresent(DropZonePosition.self, forKey: .dropZonePosition))
            ?? d.dropZonePosition
    }

    /// Reads settings from `url`. Returns `nil` if the file is missing or isn't valid JSON.
    public static func load(from url: URL) -> DropZoneSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DropZoneSettings.self, from: data)
    }

    /// Writes these keys into the settings file, keeping the other keys there.
    public func save(to url: URL) throws {
        try SettingsFile.merge(self, into: url)
    }
}

/// Where the drop zone sits on a screen, and how close the cursor must come for it to appear.
public enum DropZoneLayout {
    /// Size of the zone along its edge.
    public static let length: CGFloat = 220
    /// Size of the zone out from its edge. The notch zone is taller so its content clears the notch.
    public static let thickness: CGFloat = 64
    public static let notchThickness: CGFloat = 84
    /// How far from the zone the cursor can be and still make it appear.
    public static let reach: CGFloat = 120

    /// The zone's frame on a screen. `screen` is the whole screen and `visible` the part
    /// outside the menu bar and Dock, both in the same (bottom-left origin) coordinates.
    public static func frame(for position: DropZonePosition, screen: CGRect, visible: CGRect) -> CGRect {
        switch position {
        case .notch:
            return CGRect(
                x: screen.midX - length / 2,
                y: screen.maxY - notchThickness,
                width: length,
                height: notchThickness
            )
        case .left:
            return CGRect(x: screen.minX, y: visible.midY - length / 2, width: thickness, height: length)
        case .right:
            return CGRect(x: screen.maxX - thickness, y: visible.midY - length / 2, width: thickness, height: length)
        }
    }

    /// The area the cursor must be in, while dragging files, for the zone to show.
    public static func activationFrame(around zone: CGRect) -> CGRect {
        zone.insetBy(dx: -reach, dy: -reach)
    }

    /// Where to put the shelf after files are dropped on the zone: just off the zone, toward the screen's middle.
    public static func shelfPoint(for position: DropZonePosition, zone: CGRect, shelfSize: CGFloat = 160) -> CGPoint {
        let gap = shelfSize / 2 + 12
        switch position {
        case .notch: return CGPoint(x: zone.midX, y: zone.minY - gap)
        case .left: return CGPoint(x: zone.maxX + gap, y: zone.midY)
        case .right: return CGPoint(x: zone.minX - gap, y: zone.midY)
        }
    }
}
