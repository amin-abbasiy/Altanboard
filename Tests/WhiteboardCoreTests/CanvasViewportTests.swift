import Foundation
import XCTest
import WhiteboardCore

final class CanvasViewportTests: XCTestCase {
    func testMatchingAspectRatioUsesWholeView() throws {
        let viewport = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .init(width: 600, height: 400)))
        XCTAssertEqual(viewport.scale, 0.5)
        XCTAssertEqual(viewport.offset, .init(x: 0, y: 0))
        XCTAssertEqual(viewport.canvasPoint(fromViewPoint: .init(x: 300, y: 200)), .init(x: 600, y: 400))
    }

    func testWideAndTallWindowsPreserveAspectRatio() throws {
        let wide = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .init(width: 1_600, height: 800)))
        XCTAssertEqual(wide.scale, 1)
        XCTAssertEqual(wide.offset, .init(x: 200, y: 0))
        let tall = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .init(width: 1_200, height: 1_000)))
        XCTAssertEqual(tall.scale, 1)
        XCTAssertEqual(tall.offset, .init(x: 0, y: 100))
    }

    func testPressInMarginDoesNotStartDrawing() throws {
        let viewport = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .init(width: 1_600, height: 800)))
        XCTAssertNil(viewport.canvasPoint(fromViewPoint: .init(x: 100, y: 400)))
        XCTAssertNil(viewport.canvasPoint(fromViewPoint: .init(x: 1_500, y: 400)))
        XCTAssertEqual(viewport.canvasPoint(fromViewPoint: .init(x: 200, y: 0)), .init(x: 0, y: 0))
    }

    func testDraggingOutsideClampsToCanvasEdge() throws {
        let viewport = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .init(width: 600, height: 400)))
        XCTAssertEqual(viewport.canvasPoint(fromViewPoint: .init(x: -50, y: 900), clamped: true), .init(x: 0, y: 800))
    }

    func testCoordinateRoundTripAtMultipleWindowSizes() throws {
        for size in [CanvasSize(width: 720, height: 420), .init(width: 1_920, height: 1_080), .init(width: 900, height: 1_200)] {
            let viewport = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: size))
            for index in 0...100 {
                let original = BoardPoint(x: Double(index) * 12, y: Double(index) * 8)
                let converted = try XCTUnwrap(viewport.canvasPoint(fromViewPoint: viewport.viewPoint(fromCanvasPoint: original), clamped: true))
                XCTAssertEqual(converted.x, original.x, accuracy: 0.000_001)
                XCTAssertEqual(converted.y, original.y, accuracy: 0.000_001)
            }
        }
    }

    func testInvalidSizesAndPointerCoordinatesAreRejected() throws {
        for size in [CanvasSize(width: 0, height: 1), .init(width: 1, height: -1), .init(width: .nan, height: 1), .init(width: 1, height: .infinity)] {
            XCTAssertNil(CanvasViewport(canvas: .standard, viewSize: size))
            XCTAssertNil(CanvasViewport(canvas: size, viewSize: .standard))
        }
        let viewport = try XCTUnwrap(CanvasViewport(canvas: .standard, viewSize: .standard))
        XCTAssertNil(viewport.canvasPoint(fromViewPoint: .init(x: .nan, y: 0), clamped: true))
        XCTAssertNil(viewport.canvasPoint(fromViewPoint: .init(x: 0, y: .infinity)))
    }
}
