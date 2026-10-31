import Foundation
import XCTest
import WhiteboardCore

final class BoardFileStoreTests: XCTestCase {
    func testFileRoundTripAndOverwrite() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("drawing.json")
            try BoardFileStore.save(sampleDocument(), to: url)
            XCTAssertEqual(try BoardFileStore.load(from: url), sampleDocument())
            try BoardFileStore.save(BoardDocument(), to: url)
            XCTAssertEqual(try BoardFileStore.load(from: url), BoardDocument())
        }
    }

    func testInvalidDocumentCannotOverwriteExistingFile() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("drawing.json")
            try BoardFileStore.save(sampleDocument(), to: url)
            let originalBytes = try Data(contentsOf: url)
            assertBoardError(.invalidCanvas) {
                try BoardFileStore.save(BoardDocument(canvas: .init(width: 0, height: 1)), to: url)
            }
            XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        }
    }

    func testMissingFileThrows() throws {
        try withTemporaryDirectory { directory in
            XCTAssertThrowsError(try BoardFileStore.load(from: directory.appendingPathComponent("missing.json")))
        }
    }

    func testMalformedFileThrows() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("bad.json")
            try Data("{broken".utf8).write(to: url)
            assertBoardError(.malformedJSON) { try BoardFileStore.load(from: url) }
        }
    }

    func testBoundedFileReadRejectsOversizedFiles() throws {
        try withTemporaryDirectory { directory in
            let url = directory.appendingPathComponent("large.json")
            XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: UInt64(BoardCodec.maximumFileBytes + 1))
            try handle.close()
            assertBoardError(.fileTooLarge) { try BoardFileStore.load(from: url) }
        }
    }
}
