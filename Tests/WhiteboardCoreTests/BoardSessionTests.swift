import Foundation
import XCTest
import WhiteboardCore

final class BoardSessionTests: XCTestCase {
    func testStartsEmptyWithBlackPencil() {
        let session = BoardSession()
        XCTAssertEqual(session.selectedColor, .black)
        XCTAssertTrue(session.document.strokes.isEmpty)
    }

    func testAppendAndClear() throws {
        var session = BoardSession()
        try session.append(sampleDocument().strokes[0])
        XCTAssertEqual(session.document.strokes.count, 1)
        try session.clear()
        XCTAssertTrue(session.document.strokes.isEmpty)
    }

    func testInvalidStrokeDoesNotModifySession() throws {
        var session = BoardSession()
        try session.append(sampleDocument().strokes[0])
        let original = session
        assertBoardError(.invalidStroke) {
            try session.append(Stroke(color: .black, points: []))
        }
        XCTAssertEqual(session, original)
    }

    func testEditingActionsDoNotRequireAModeSwitch() throws {
        try withTemporaryDirectory { directory in
            var session = BoardSession()
            let url = directory.appendingPathComponent("drawing.json")
            try session.append(sampleDocument().strokes[0])
            try session.saveAndClear(to: url)
            XCTAssertTrue(session.document.strokes.isEmpty)
            XCTAssertEqual(try BoardFileStore.load(from: url).strokes.count, 1)
            try session.append(sampleDocument().strokes[0])
            try session.clear()
            XCTAssertTrue(session.document.strokes.isEmpty)
        }
    }

    func testLoadingPreservesSelectedColor() throws {
        var session = BoardSession()
        session.selectedColor = .red
        try session.replaceDocument(sampleDocument())
        XCTAssertEqual(session.document, sampleDocument())
        XCTAssertEqual(session.selectedColor, .red)
    }

    func testInvalidReplacementLeavesCurrentBoardIntact() throws {
        var session = BoardSession()
        try session.replaceDocument(sampleDocument())
        let original = session
        assertBoardError(.unsupportedVersion(99)) {
            try session.replaceDocument(BoardDocument(formatVersion: 99))
        }
        XCTAssertEqual(session, original)
    }

    func testSaveAndClearSavesBeforeClearingAndKeepsCanvasAndPencil() throws {
        try withTemporaryDirectory { directory in
            var session = BoardSession()
            try session.replaceDocument(sampleDocument())
            session.selectedColor = .red
            let beforeSave = session.document
            let url = directory.appendingPathComponent("drawing.json")

            try session.saveAndClear(to: url)

            XCTAssertEqual(try BoardFileStore.load(from: url), beforeSave)
            XCTAssertTrue(session.document.strokes.isEmpty)
            XCTAssertEqual(session.document.canvas, beforeSave.canvas)
            XCTAssertEqual(session.selectedColor, .red)
        }
    }

    func testFailedSaveNeverClearsBoard() throws {
        try withTemporaryDirectory { directory in
            var session = BoardSession()
            try session.replaceDocument(sampleDocument())
            let original = session
            let impossibleURL = directory.appendingPathComponent("missing/drawing.json")
            XCTAssertThrowsError(try session.saveAndClear(to: impossibleURL))
            XCTAssertEqual(session, original)
        }
    }

    func testClearPreservesLoadedCanvasSize() throws {
        var session = BoardSession()
        try session.replaceDocument(sampleDocument())
        try session.clear()
        XCTAssertEqual(session.document.canvas, sampleDocument().canvas)
        XCTAssertTrue(session.document.strokes.isEmpty)
    }
}

func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AltanboardTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory)
}
