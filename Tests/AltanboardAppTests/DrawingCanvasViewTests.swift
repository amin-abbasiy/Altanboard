import AppKit
import XCTest
import WhiteboardCore
@testable import Altanboard

/// Native event tests run on macOS through the shared Altanboard Xcode scheme.
final class DrawingCanvasViewTests: XCTestCase {
    @MainActor
    func testCursorModeMovementAndClicksNeverDraw() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 100, y: 100))
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 200, y: 200))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 200, y: 200))
        XCTAssertTrue(fixture.committed.isEmpty)
        XCTAssertTrue(fixture.modeChanges.isEmpty)
        XCTAssertEqual(fixture.view.accessibilityValue() as? String, "Cursor mode, 0 strokes")
    }

    @MainActor
    func testCommandAndPointerMovementDrawWithoutClicking() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 250, modifiers: .command))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 300, y: 400, modifiers: .command))
        XCTAssertTrue(fixture.committed.isEmpty, "A stroke is committed on Command release, not pointer movement.")
        XCTAssertEqual(fixture.view.accessibilityValue() as? String, "Paint mode, 0 strokes")
        try fixture.releaseCommand()
        let stroke = try XCTUnwrap(fixture.committed.first)
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(stroke.points, [.init(x: 100, y: 100), .init(x: 200, y: 250), .init(x: 300, y: 400)])
        XCTAssertEqual(stroke.color, .black)
        XCTAssertEqual(fixture.modeChanges, [true, false])
    }

    @MainActor
    func testCommandTapCreatesDotWithoutClick() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.first?.points, [.init(x: 100, y: 100)])
    }

    @MainActor
    func testReleasingAndReholdingCommandNeverConnectsStrokes() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: .command))
        try fixture.releaseCommand()
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 700, y: 600))
        fixture.commandDown(x: 700, y: 600)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 800, y: 700, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 2)
        let first = try XCTUnwrap(fixture.committed.first)
        let second = try XCTUnwrap(fixture.committed.dropFirst().first)
        XCTAssertEqual(first.points, [.init(x: 100, y: 100), .init(x: 200, y: 200)])
        XCTAssertEqual(second.points, [.init(x: 700, y: 600), .init(x: 800, y: 700)])
        XCTAssertNotEqual(first.id, second.id)
    }

    @MainActor
    func testMouseUpDoesNotEndCommandHeldStroke() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseDown(with: try fixture.event(.leftMouseDown, x: 100, y: 100, modifiers: .command))
        fixture.view.mouseDragged(with: try fixture.event(.leftMouseDragged, x: 200, y: 200, modifiers: .command))
        fixture.view.mouseUp(with: try fixture.event(.leftMouseUp, x: 300, y: 300, modifiers: .command))
        XCTAssertTrue(fixture.committed.isEmpty)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 400, y: 400, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(fixture.committed.first?.points.last, .init(x: 400, y: 400))
    }

    @MainActor
    func testOtherModifierChangesDoNotSplitCommandHeldStroke() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.handleModifierFlags([.command, .shift], at: fixture.location(x: 150, y: 150))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: [.command, .shift]))
        fixture.view.handleModifierFlags(.command, at: fixture.location(x: 200, y: 200))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(fixture.modeChanges, [true, false])
    }

    @MainActor
    func testNonCommandModifiersNeverPaint() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.handleModifierFlags([.shift, .option, .control], at: fixture.location(x: 100, y: 100))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: [.shift, .option]))
        try fixture.releaseCommand()
        XCTAssertTrue(fixture.committed.isEmpty)
        XCTAssertTrue(fixture.modeChanges.isEmpty)
    }

    @MainActor
    func testPointerEventsRecoverMissedModifierChanges() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 100, y: 100, modifiers: .command))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: .command))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 700, y: 700))
        XCTAssertEqual(fixture.committed.first?.points, [.init(x: 100, y: 100), .init(x: 200, y: 200)])
        XCTAssertEqual(fixture.modeChanges, [true, false])
    }

    @MainActor
    func testBusyCanvasIgnoresDrawingEvents() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.configure(document: BoardDocument(), selectedColor: .red, drawingEnabled: false)
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertTrue(fixture.committed.isEmpty)
        XCTAssertEqual(fixture.view.accessibilityValue() as? String, "Cursor mode, 0 strokes")
    }

    @MainActor
    func testDisablingDrawingDiscardsIncompleteGesture() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: false)
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: true)
        try fixture.releaseCommand()
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testReplacingDocumentDiscardsOldDraft() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        let replacement = BoardDocument(strokes: [Stroke(color: .red, points: [.init(x: 500, y: 500)])])
        fixture.view.configure(document: replacement, selectedColor: .black, drawingEnabled: true)
        try fixture.releaseCommand()
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testStrokeKeepsColorSelectedAtCommandPress() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.view.configure(document: BoardDocument(), selectedColor: .red, drawingEnabled: true)
        fixture.commandDown(x: 100, y: 100)
        fixture.view.configure(document: BoardDocument(), selectedColor: .black, drawingEnabled: true)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.first?.color, .red)
    }

    @MainActor
    func testCommandOutsideWhiteCanvasDoesNotStartStroke() async throws {
        let fixture = CanvasFixture(width: 1_600, height: 800)
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 150, y: 200, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertTrue(fixture.committed.isEmpty)
    }

    @MainActor
    func testEnteringCanvasWhileCommandHeldStartsAtEntry() async throws {
        let fixture = CanvasFixture(width: 1_600, height: 800)
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 300, y: 200, modifiers: .command))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 400, y: 200, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.first?.points, [.init(x: 100, y: 200), .init(x: 200, y: 200)])
    }

    @MainActor
    func testMovingBeyondCanvasClampsAndEndsStroke() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 1_400, y: 900, modifiers: .command))
        XCTAssertEqual(fixture.committed.first?.points.last, .init(x: 1_200, y: 800))
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 700, y: 500, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 2)
        XCTAssertEqual(try XCTUnwrap(fixture.committed.dropFirst().first).points, [.init(x: 700, y: 500)])
        try BoardDocument(strokes: fixture.committed).validate()
    }

    @MainActor
    func testExitingAndReenteringViewDoesNotConnectStrokes() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseExited(with: try fixture.event(.mouseExited, x: 1_250, y: 300, modifiers: .command))
        fixture.view.mouseEntered(with: try fixture.event(.mouseEntered, x: 700, y: 600, modifiers: .command))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 2)
        XCTAssertEqual(fixture.committed.first?.points.last, .init(x: 1_200, y: 300))
        XCTAssertEqual(try XCTUnwrap(fixture.committed.dropFirst().first).points.first, .init(x: 700, y: 600))
    }

    @MainActor
    func testLosingWindowFocusEndsStrokeAndRestoresCursorMode() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 200, y: 200, modifiers: .command))
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: fixture.window)
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(fixture.modeChanges, [true, false])
        fixture.view.mouseMoved(with: try fixture.event(.mouseMoved, x: 700, y: 700))
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 1)
    }

    @MainActor
    func testSwitchingAppsEndsStrokeAndResetsMode() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(fixture.modeChanges, [true, false])
        try fixture.releaseCommand()
        XCTAssertEqual(fixture.committed.count, 1)
    }

    @MainActor
    func testDetachingCanvasEndsStrokeAndResetsMode() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        fixture.commandDown(x: 100, y: 100)
        fixture.window.contentView = NSView()
        XCTAssertEqual(fixture.committed.count, 1)
        XCTAssertEqual(fixture.modeChanges, [true, false])
    }

    @MainActor
    func testCommandFlagsWorkWhenToolbarControlHasFocus() async throws {
        let fixture = CanvasFixture()
        defer { fixture.window.close() }
        let container = NSView(frame: fixture.view.frame)
        fixture.window.contentView = container
        container.addSubview(fixture.view)
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        container.addSubview(textField)
        fixture.window.makeKeyAndOrderFront(nil)
        XCTAssertTrue(fixture.window.isKeyWindow)
        XCTAssertTrue(fixture.window.makeFirstResponder(textField))
        NSApp.sendEvent(try fixture.modifierEvent(.command, keyCode: 54))
        XCTAssertEqual(fixture.modeChanges.last, true, "The right Command key works without canvas keyboard focus.")
        NSApp.sendEvent(try fixture.modifierEvent([], keyCode: 54))
        XCTAssertEqual(fixture.modeChanges.last, false)
    }

    @MainActor
    func testStoreAllowsToolbarActionsInCursorMode() async throws {
        let store = BoardStore()
        XCTAssertTrue(store.canModify)
        XCTAssertFalse(store.isPainting)
        store.selectColor(.red)
        store.commit(Stroke(color: .red, points: [.init(x: 100, y: 100)]))
        XCTAssertEqual(store.selectedColor, .red)
        XCTAssertEqual(store.document.strokes.count, 1)
        store.clear()
        XCTAssertTrue(store.document.strokes.isEmpty)
    }

    @MainActor
    func testModeIndicatorFollowsCommandAndDisablesPaintingDuringErrors() async throws {
        let store = BoardStore()
        store.setCommandHeld(true)
        XCTAssertTrue(store.isPainting)
        store.presentedError = BoardAlert(title: "Test", message: "Test")
        XCTAssertFalse(store.isPainting)
        XCTAssertFalse(store.canModify)
        store.setCommandHeld(false)
        store.presentedError = nil
        XCTAssertFalse(store.isPainting)
        XCTAssertTrue(store.canModify)
    }
}

@MainActor
private final class CanvasFixture {
    let window: NSWindow
    let view: DrawingCanvasView
    var committed: [Stroke] = []
    var modeChanges: [Bool] = []

    init(width: CGFloat = 1_200, height: CGFloat = 800) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        view = DrawingCanvasView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        window.contentView = view
        view.onCommit = { [weak self] in self?.committed.append($0) }
        view.onCommandHeldChanged = { [weak self] in self?.modeChanges.append($0) }
    }

    func location(x: CGFloat, y: CGFloat) -> NSPoint {
        view.convert(NSPoint(x: x, y: y), to: nil)
    }

    func commandDown(x: CGFloat, y: CGFloat) {
        // Modifier handling reads the live cursor in production; supply a deterministic
        // window position here without moving the user's system pointer during tests.
        view.handleModifierFlags(.command, at: location(x: x, y: y))
    }

    func releaseCommand() throws {
        view.flagsChanged(with: try modifierEvent([]))
    }

    func modifierEvent(_ flags: NSEvent.ModifierFlags, keyCode: UInt16 = 55) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode
        ))
    }

    func event(
        _ type: NSEvent.EventType, x: CGFloat, y: CGFloat,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        // AppKit uses a distinct event factory for tracking-area entry/exit events.
        if type == .mouseEntered || type == .mouseExited {
            return try XCTUnwrap(NSEvent.enterExitEvent(
                with: type, location: location(x: x, y: y), modifierFlags: modifiers,
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil
            ))
        }
        return try XCTUnwrap(NSEvent.mouseEvent(
            with: type,
            location: location(x: x, y: y),
            modifierFlags: modifiers, timestamp: 0,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }
}
