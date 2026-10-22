import XCTest
@testable import ShakeCore

final class ShelfSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testShakeOnlyFileUsesDefaultLimit() throws {
        try ShakeSettings.defaults.save(to: fileURL)
        XCTAssertEqual(ShelfSettings.load(from: fileURL), .defaults)
    }

    func testOutOfRangeLimitIsClamped() {
        XCTAssertEqual(ShelfSettings(recentShelvesLimit: 0).clamped().recentShelvesLimit, 1)
        XCTAssertEqual(ShelfSettings(recentShelvesLimit: 500).clamped().recentShelvesLimit, 100)
    }

    func testSavingShakeSettingsKeepsShelfLimit() throws {
        try SettingsFile.merge(ShelfSettings(recentShelvesLimit: 25), into: fileURL)
        let shake = ShakeSettings(minimumTravel: 45, requiredReversals: 3, window: 1.2, cooldown: 0.5)
        try shake.save(to: fileURL)
        XCTAssertEqual(ShelfSettings.load(from: fileURL)?.recentShelvesLimit, 25)
        XCTAssertEqual(ShakeSettings.load(from: fileURL), shake)
    }

    func testOnlyMissingKeepsExistingValues() throws {
        try SettingsFile.merge(ShelfSettings(recentShelvesLimit: 3), into: fileURL)
        try SettingsFile.merge(ShelfSettings.defaults, into: fileURL, onlyMissing: true)
        XCTAssertEqual(ShelfSettings.load(from: fileURL)?.recentShelvesLimit, 3)
    }
}
