import Foundation
import XCTest
import WhiteboardCore

final class BoardCodecTests: XCTestCase {
    func testEmptyDocumentRoundTrips() throws {
        let document = BoardDocument()
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(document)), document)
    }

    func testColorsPointsWidthsAndCanvasRoundTripExactly() throws {
        let document = sampleDocument()
        let data = try BoardCodec.encode(document)
        XCTAssertEqual(try BoardCodec.decode(data), document)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\n"), "Saved JSON should be human-readable.")
        XCTAssertTrue(text.contains("\"formatVersion\""))
        XCTAssertTrue(text.contains("\"black\""))
        XCTAssertTrue(text.contains("\"red\""))
        XCTAssertEqual(try BoardCodec.encode(document), data)
    }

    func testMalformedFilesAreRejected() {
        for text in ["", "not JSON", "{}", "[]", "null", "{\"formatVersion\":1", "{\"formatVersion\":\"1\"}"] {
            assertBoardError(.malformedJSON) { try BoardCodec.decode(Data(text.utf8)) }
        }
    }

    func testUnknownColorIsRejected() throws {
        let json = try XCTUnwrap(String(data: BoardCodec.encode(sampleDocument()), encoding: .utf8))
        assertBoardError(.malformedJSON) {
            try BoardCodec.decode(Data(json.replacingOccurrences(of: "\"red\"", with: "\"blue\"").utf8))
        }
    }

    func testUnsupportedVersionIsRejected() throws {
        let data = try JSONEncoder().encode(BoardDocument(formatVersion: 42))
        assertBoardError(.unsupportedVersion(42)) { try BoardCodec.decode(data) }
    }

    func testOversizedDataIsRejectedBeforeDecoding() {
        let data = Data(repeating: 32, count: BoardCodec.maximumFileBytes + 1)
        assertBoardError(.fileTooLarge) { try BoardCodec.decode(data) }
    }

    func testInvalidCanvasDimensionsAreRejected() {
        for value in [0, -1, Double.nan, .infinity, 65_537] {
            assertBoardError(.invalidCanvas) {
                try BoardDocument(canvas: CanvasSize(width: value, height: 800)).validate()
            }
            assertBoardError(.invalidCanvas) {
                try BoardDocument(canvas: CanvasSize(width: 1_200, height: value)).validate()
            }
        }
    }

    func testInvalidWidthsAndEmptyStrokesAreRejected() {
        for width in [0, -1, Double.nan, .infinity, 129] {
            assertBoardError(.invalidStroke) {
                try BoardDocument(strokes: [Stroke(color: .black, width: width, points: [.init(x: 1, y: 1)])]).validate()
            }
        }
        assertBoardError(.invalidStroke) {
            try BoardDocument(strokes: [Stroke(color: .red, points: [])]).validate()
        }
    }

    func testInvalidPointsAreRejected() {
        let points = [
            BoardPoint(x: -1, y: 0), BoardPoint(x: 0, y: -1),
            BoardPoint(x: 1_201, y: 0), BoardPoint(x: 0, y: 801),
            BoardPoint(x: .nan, y: 0), BoardPoint(x: 0, y: .infinity)
        ]
        for point in points {
            assertBoardError(.invalidPoint) {
                try BoardDocument(strokes: [Stroke(color: .black, points: [point])]).validate()
            }
        }
    }

    func testCanvasBoundaryPointsAreValid() throws {
        let document = BoardDocument(strokes: [Stroke(color: .black, points: [
            .init(x: 0, y: 0), .init(x: 1_200, y: 800)
        ])])
        try document.validate()
        XCTAssertEqual(try BoardCodec.decode(BoardCodec.encode(document)), document)
    }

    func testDuplicateIdentifiersAreRejected() {
        let stroke = Stroke(color: .black, points: [.init(x: 10, y: 10)])
        assertBoardError(.duplicateStrokeID) {
            try BoardDocument(strokes: [stroke, stroke]).validate()
        }
    }

    func testStrokeAndPointLimitsAreEnforced() {
        let stroke = Stroke(color: .black, points: [.init(x: 1, y: 1)])
        assertBoardError(.tooManyStrokes) {
            try BoardDocument(strokes: Array(repeating: stroke, count: BoardCodec.maximumStrokeCount + 1)).validate()
        }
        let longStroke = Stroke(color: .red, points: Array(
            repeating: .init(x: 1, y: 1), count: BoardCodec.maximumPointCount + 1
        ))
        assertBoardError(.tooManyPoints) {
            try BoardDocument(strokes: [longStroke]).validate()
        }
    }
}

func sampleDocument() -> BoardDocument {
    BoardDocument(canvas: CanvasSize(width: 900, height: 600), strokes: [
        Stroke(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            color: .black, width: 3,
            points: [.init(x: 10.25, y: 20.5), .init(x: 100.75, y: 200.125)]
        ),
        Stroke(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            color: .red, width: 4,
            points: [.init(x: 300, y: 400)]
        )
    ])
}

func assertBoardError<T>(
    _ expected: BoardFileError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () throws -> T
) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
        XCTAssertEqual(error as? BoardFileError, expected, file: file, line: line)
    }
}
