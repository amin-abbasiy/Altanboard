import AppKit
import XCTest
import WhiteboardCore
@testable import Altanboard

/// Native event tests run on macOS through the shared Altanboard Xcode scheme.
final class DrawingCanvasViewTests: XCTestCase {
    @MainActor
    func testHoverAndDragWithoutPressDoNotDraw() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 100, y: 100))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 200, y: 200))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 200, y: 200))
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testPressDragAndReleaseCommitsOneStroke() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 200, y: 250))
        XCTAssertTrue(fixture.committed.isEmpty, "A stroke is committed only on release.")
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 300, y: 400))
        let stroke = try XCTUnwrap(fixture.committed.first)
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(stroke.points, [.init(x: 100, y: 100), .init(x: 200, y: 250), .init(x: 300, y: 400)])
        XCTAssertEqual(stroke.color, .black)
    }

    @MainActor
    func testClickWithoutDragCreatesDot() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 100, y: 100))
        XCTAssertEqual(fixture.committed.first?.points, [.init(x: 100, y: 100)])
    }

    @MainActor
    func testViewModeIgnoresAllDrawingEvents() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.configure(document: BoardDocument(), selectedColor: .red, drawingEnabled: false)
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 200, y: 200))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 300, y: 300))
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testDisablingEditingDiscardsIncompleteGesture() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: false)
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: true)
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 200, y: 200))
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testStrokeKeepsColorSelectedAtPress() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.configure(document: BoardDocument(), selectedColor: .red, drawingEnabled: true)
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: true)
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 200, y: 200))
        XCTAssertEqual(fixture.committed.first?.color, .red)
    }

    @MainActor
    func testPressOutsideWhiteCanvasDoesNotStartStroke() async throws {
        let fixture = CanvasFixture(width: 1_600, height: 800)
        defer { fixture.window.close() }
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 300, y: 200))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 400, y: 200))
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testDraggingBeyondCanvasClampsPoint() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 1_400, y: 900))
        XCTAssertEqual(fixture.committed.first?.points.last, .init(x: 1_200, y: 800))
        try BoardDocument(strokes: fixture.committed).validate()
    }
}

@MainActor
private final class CanvasFixture {
    let window: NSWindow
    let view: DrawingCanvasView
    var committed: [Stroke] = []

    init(width: CGFloat = 1_200, height: CGFloat = 800) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        view = DrawingCanvasView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        window.contentView = view
        view.onCommit = { [weak self] in self?.committed.append($0) }
    }

    func event(_ type: NSEvent.EventType, x: CGFloat, y: CGFloat) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type,
            location: view.convert(NSPoint(x: x, y: y), to: nil),
            modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }
}
