import XCTest
@testable import ShakeCore

final class DropZoneSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private func write(_ json: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(json.utf8).write(to: fileURL)
    }

    func testSaveThenLoadRoundTrips() throws {
        let settings = DropZoneSettings(dropZoneEnabled: false, dropZonePosition: .right)
        try settings.save(to: fileURL)
        XCTAssertEqual(DropZoneSettings.load(from: fileURL), settings)
    }

    func testShakeOnlyFileUsesDefaults() throws {
        try ShakeSettings.defaults.save(to: fileURL)
        XCTAssertEqual(DropZoneSettings.load(from: fileURL), .defaults)
    }

    func testUnknownPositionFallsBackToDefault() throws {
        try write(#"{"dropZoneEnabled": false, "dropZonePosition": "bottom"}"#)
        XCTAssertEqual(
            DropZoneSettings.load(from: fileURL),
            DropZoneSettings(dropZoneEnabled: false, dropZonePosition: .notch)
        )
    }

    func testSavingShakeSettingsKeepsDropZone() throws {
        let dropZone = DropZoneSettings(dropZoneEnabled: false, dropZonePosition: .left)
        try dropZone.save(to: fileURL)
        try ShakeSettings(minimumTravel: 45, requiredReversals: 3, window: 1.2, cooldown: 0.5).save(to: fileURL)
        XCTAssertEqual(DropZoneSettings.load(from: fileURL), dropZone)
    }

    func testNotchZoneIsTopCentre() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let zone = DropZoneLayout.frame(for: .notch, screen: screen, visible: visible)
        XCTAssertEqual(zone.midX, screen.midX)
        XCTAssertEqual(zone.maxY, screen.maxY)
    }

    func testNotchZoneWrapsTheNotchWithRoomForTheGlow() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 945)
        let notch = CGSize(width: 180, height: 32)
        let zone = DropZoneLayout.frame(for: .notch, screen: screen, visible: visible, notch: notch)
        XCTAssertEqual(zone.width, 180 + DropZoneLayout.glowMargin * 2)
        XCTAssertEqual(zone.height, 32 + DropZoneLayout.glowMargin)
    }

    func testEdgeZonesSitOnTheirEdgeOfASecondScreen() {
        let screen = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        let visible = CGRect(x: 1512, y: 0, width: 1920, height: 1055)
        let left = DropZoneLayout.frame(for: .left, screen: screen, visible: visible)
        let right = DropZoneLayout.frame(for: .right, screen: screen, visible: visible)
        XCTAssertEqual(left.minX, screen.minX)
        XCTAssertEqual(right.maxX, screen.maxX)
        XCTAssertEqual(left.midY, visible.midY)
    }

    func testActivationFrameReachesPastTheZone() {
        let zone = CGRect(x: 100, y: 100, width: 64, height: 220)
        let area = DropZoneLayout.activationFrame(around: zone)
        XCTAssertTrue(area.contains(CGPoint(x: 100 + 64 + 100, y: 200)))
        XCTAssertFalse(area.contains(CGPoint(x: 100 + 64 + 200, y: 200)))
    }
}
