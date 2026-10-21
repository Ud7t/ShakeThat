import XCTest
@testable import ShakeCore

final class ShakeDetectorTests: XCTestCase {
    /// Feeds a back-and-forth motion of `strokes` strokes, each `width` points wide,
    /// sampled every `step` points with `interval` seconds between samples.
    private func feed(
        _ detector: inout ShakeDetector,
        strokes: Int,
        width: Double = 100,
        step: Double = 10,
        interval: TimeInterval = 0.01,
        startTime: TimeInterval = 0
    ) -> Int {
        var shakes = 0
        var time = startTime
        var x = 0.0
        var direction = 1.0
        for _ in 0..<strokes {
            for _ in 0..<Int(width / step) {
                x += direction * step
                time += interval
                if detector.add(x: x, at: time) { shakes += 1 }
            }
            direction = -direction
        }
        return shakes
    }

    func testFastShakeIsDetected() {
        var detector = ShakeDetector()
        XCTAssertEqual(feed(&detector, strokes: 6), 1)
    }

    func testSlowBackAndForthIsIgnored() {
        var detector = ShakeDetector()
        XCTAssertEqual(feed(&detector, strokes: 6, interval: 0.05), 0)
    }

    func testSmallWiggleIsIgnored() {
        var detector = ShakeDetector()
        XCTAssertEqual(feed(&detector, strokes: 10, width: 20, step: 5), 0)
    }

    func testStraightDragWithJitterIsIgnored() {
        var detector = ShakeDetector()
        var time = 0.0
        var x = 0.0
        var shakes = 0
        for i in 0..<200 {
            x += (i % 3 == 2) ? -3 : 8
            time += 0.01
            if detector.add(x: x, at: time) { shakes += 1 }
        }
        XCTAssertEqual(shakes, 0)
    }

    func testCooldownPreventsRepeatedTriggers() {
        var detector = ShakeDetector()
        // Ten fast strokes last one second, which is inside the cooldown after the first shake.
        XCTAssertEqual(feed(&detector, strokes: 10), 1)
    }

    func testResetClearsProgress() {
        var detector = ShakeDetector()
        XCTAssertEqual(feed(&detector, strokes: 3), 0)
        detector.reset()
        XCTAssertEqual(feed(&detector, strokes: 3, startTime: 0.3), 0)
    }
}
