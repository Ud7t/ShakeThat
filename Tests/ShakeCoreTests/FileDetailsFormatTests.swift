import XCTest
@testable import ShakeCore

final class FileDetailsFormatTests: XCTestCase {
    func testFileCount() {
        XCTAssertEqual(FileDetailsFormat.fileCount(1), "1 File")
        XCTAssertEqual(FileDetailsFormat.fileCount(6), "6 Files")
    }

    func testDuration() {
        XCTAssertEqual(FileDetailsFormat.duration(8.2), "00:08")
        XCTAssertEqual(FileDetailsFormat.duration(754), "12:34")
        XCTAssertEqual(FileDetailsFormat.duration(3723), "1:02:03")
    }

    func testCounts() {
        XCTAssertEqual(FileDetailsFormat.pageCount(1), "1 page")
        XCTAssertEqual(FileDetailsFormat.pageCount(12), "12 pages")
        XCTAssertEqual(FileDetailsFormat.itemCount(3), "3 items")
    }

    func testJoinedSkipsMissingParts() {
        XCTAssertEqual(FileDetailsFormat.joined(["315 KB", FileDetailsFormat.dimensions(width: 900, height: 900)]), "315 KB • 900x900")
        XCTAssertEqual(FileDetailsFormat.joined(["23 KB", nil]), "23 KB")
        XCTAssertEqual(FileDetailsFormat.joined([nil, ""]), "")
    }
}
