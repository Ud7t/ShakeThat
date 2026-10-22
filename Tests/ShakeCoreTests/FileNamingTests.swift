import XCTest
@testable import ShakeCore

final class FileNamingTests: XCTestCase {
    func testFreeNameIsKept() {
        XCTAssertEqual(FileNaming.available("Archive.zip") { _ in false }, "Archive.zip")
    }

    func testTakenNameGetsTheNextNumber() {
        let taken: Set = ["Archive.zip", "Archive 2.zip"]
        XCTAssertEqual(FileNaming.available("Archive.zip") { taken.contains($0) }, "Archive 3.zip")
    }

    func testNameWithoutExtension() {
        XCTAssertEqual(FileNaming.available("Folder") { $0 == "Folder" }, "Folder 2")
    }

    func testReplacingExtension() {
        XCTAssertEqual(FileNaming.replacingExtension(of: "photo.png", with: "jpg"), "photo.jpg")
        XCTAssertEqual(FileNaming.replacingExtension(of: "my.photo.png", with: "heic"), "my.photo.heic")
        XCTAssertEqual(FileNaming.replacingExtension(of: "photo", with: "png"), "photo.png")
    }

    func testAddingNote() {
        XCTAssertEqual(FileNaming.adding("50%", to: "photo.png"), "photo (50%).png")
        XCTAssertEqual(FileNaming.adding("50%", to: "photo"), "photo (50%)")
    }

    func testDotFileHasNoExtension() {
        XCTAssertEqual(FileNaming.split(".zshrc").ext, "")
        XCTAssertEqual(FileNaming.split("name.").stem, "name.")
    }
}
