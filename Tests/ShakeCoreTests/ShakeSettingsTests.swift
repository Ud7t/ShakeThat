import XCTest
@testable import ShakeCore

final class ShakeSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testSaveThenLoadRoundTrips() throws {
        let settings = ShakeSettings(minimumTravel: 45, requiredReversals: 3, window: 1.2, cooldown: 0.5)
        try settings.save(to: fileURL)
        XCTAssertEqual(ShakeSettings.load(from: fileURL), settings)
    }

    func testMissingFileLoadsNil() {
        XCTAssertNil(ShakeSettings.load(from: fileURL))
    }

    func testInvalidJSONLoadsNil() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertNil(ShakeSettings.load(from: fileURL))
    }

    func testMissingKeysUseDefaults() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "requiredReversals": 6 }"#.utf8).write(to: fileURL)
        var expected = ShakeSettings.defaults
        expected.requiredReversals = 6
        XCTAssertEqual(ShakeSettings.load(from: fileURL), expected)
    }

    func testOutOfRangeValuesAreClamped() {
        let clamped = ShakeSettings(minimumTravel: -5, requiredReversals: 0, window: 0, cooldown: -1).clamped()
        XCTAssertEqual(clamped, ShakeSettings(minimumTravel: 1, requiredReversals: 1, window: 0.1, cooldown: 0))
    }

    func testDetectorUsesNewSettings() {
        // Default settings need 4 reversals; lowering it to 2 makes 3 fast strokes enough.
        var detector = ShakeDetector()
        detector.settings.requiredReversals = 2
        var shakes = 0
        var time = 0.0
        var x = 0.0
        for stroke in 0..<3 {
            let direction = stroke % 2 == 0 ? 1.0 : -1.0
            for _ in 0..<10 {
                x += direction * 10
                time += 0.01
                if detector.add(x: x, at: time) { shakes += 1 }
            }
        }
        XCTAssertEqual(shakes, 1)
    }
}
