import AppKit
import SwiftUI
import WhiteboardCore

@MainActor
struct BoardCanvas: NSViewRepresentable {
    @ObservedObject var store: BoardStore

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView(frame: .zero)
        view.onCommit = { [weak store] stroke in store?.commit(stroke) }
        view.onCommandHeldChanged = { [weak store] held in store?.setCommandHeld(held) }
        return view
    }

    func updateNSView(_ view: DrawingCanvasView, context: Context) {
        view.configure(
            document: store.document,
            selectedColor: store.selectedColor,
            drawingEnabled: store.canModify
        )
    }

    static func dismantleNSView(_ nsView: DrawingCanvasView, coordinator: ()) {
        nsView.stopEventHandling()
    }
}

@MainActor
final class DrawingCanvasView: NSView {
    var onCommit: ((Stroke) -> Void)?
    var onCommandHeldChanged: ((Bool) -> Void)?

    private var document = BoardDocument()
    private var selectedColor = PencilColor.black
    private var drawingEnabled = true
    private var isCommandHeld = false
    private var draft: StrokeDraft?
    private var renderedStrokes: [RenderedStroke] = []
    private var pointerTrackingArea: NSTrackingArea?
    private var modifierMonitor: Any?

    private var isPainting: Bool { drawingEnabled && isCommandHeld }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibility()
    }

    func configure(document: BoardDocument, selectedColor: PencilColor, drawingEnabled: Bool) {
        if self.document != document {
            self.document = document
            renderedStrokes = document.strokes.map { RenderedStroke($0) }
            draft = nil
        }
        self.selectedColor = selectedColor
        self.drawingEnabled = drawingEnabled
        if !drawingEnabled { draft = nil }
        refreshInputAppearance()
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isPainting ? .crosshair : .arrow)
    }

    override func updateTrackingAreas() {
        if let pointerTrackingArea { removeTrackingArea(pointerTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow,
                      .inVisibleRect, .enabledDuringMouseDrag],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        handlePointerEvent(event)
    }

    override func mouseEntered(with event: NSEvent) {
        handlePointerEvent(event)
    }

    override func mouseExited(with event: NSEvent) {
        handleModifierFlags(event.modifierFlags, at: event.locationInWindow)
        if isPainting, let point = canvasPoint(at: event.locationInWindow, clamped: true) {
            draft?.append(point, isFinal: true)
        }
        finishStroke()
    }

    // Clicking is never required, and never draws unless Command is held.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        handlePointerEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        handlePointerEvent(event)
    }

    override func mouseUp(with event: NSEvent) {
        // Lifting a physical click must not end a Command-held stroke.
        handlePointerEvent(event)
    }

    override func flagsChanged(with event: NSEvent) {
        // Keyboard events do not provide a reliable pointer position.
        guard let window else { return }
        handleModifierFlags(event.modifierFlags, at: window.mouseLocationOutsideOfEventStream)
    }

    /// Shared by modifier events and pointer events, which also recover missed key changes.
    func handleModifierFlags(_ flags: NSEvent.ModifierFlags, at locationInWindow: NSPoint) {
        let held = flags.contains(.command)
        guard held != isCommandHeld else { return }
        isCommandHeld = held
        if isPainting, let point = canvasPoint(at: locationInWindow, clamped: false) {
            draft = StrokeDraft(start: point, color: selectedColor)
            needsDisplay = true
        } else if !held {
            // Do not append the release location: the cursor may have left the board.
            finishStroke()
        }
        refreshInputAppearance()
        onCommandHeldChanged?(held)
    }

    private func handlePointerEvent(_ event: NSEvent) {
        handleModifierFlags(event.modifierFlags, at: event.locationInWindow)
        guard isPainting else { return }
        guard let point = canvasPoint(at: event.locationInWindow, clamped: false) else {
            if let edge = canvasPoint(at: event.locationInWindow, clamped: true) {
                draft?.append(edge, isFinal: true)
            }
            finishStroke()
            return
        }
        if draft == nil {
            draft = StrokeDraft(start: point, color: selectedColor)
        } else {
            draft?.append(point)
        }
        needsDisplay = true
    }

    private func finishStroke() {
        guard let completed = draft else { return }
        draft = nil
        onCommit?(completed.stroke)
        needsDisplay = true
    }

    private func refreshInputAppearance() {
        window?.invalidateCursorRects(for: self)
        setAccessibilityValue("\(isPainting ? "Paint" : "Cursor") mode, \(document.strokes.count) strokes")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.acceptsMouseMovedEvents = true
        guard modifierMonitor == nil else { return }

        // A local monitor works even after a toolbar button takes keyboard focus.
        // Return the original event so normal macOS Command shortcuts still work.
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let window = self.window,
                      window.isKeyWindow, event.window == nil || event.window === window,
                      window.attachedSheet == nil else { return }
                self.flagsChanged(with: event)
            }
            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(inputDidLoseFocus(_:)),
            name: NSWindow.didResignKeyNotification, object: window
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(inputDidLoseFocus(_:)),
            name: NSApplication.didResignActiveNotification, object: NSApp
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: window
        )
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { stopEventHandling() }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc private func inputDidLoseFocus(_ notification: Notification) {
        handleModifierFlags([], at: .zero)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        stopEventHandling()
    }

    func stopEventHandling() {
        handleModifierFlags([], at: .zero)
        if let modifierMonitor {
            NSEvent.removeMonitor(modifierMonitor)
            self.modifierMonitor = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: NSApp)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Neutral margins appear only when the window and canvas have different
        // aspect ratios. The full white canvas remains visible at every size.
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        guard let viewport else { return }

        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(true)
        context.translateBy(x: CGFloat(viewport.offset.x), y: CGFloat(viewport.offset.y))
        context.scaleBy(x: CGFloat(viewport.scale), y: CGFloat(viewport.scale))
        let canvasRect = CGRect(
            x: 0, y: 0,
            width: CGFloat(document.canvas.width),
            height: CGFloat(document.canvas.height)
        )
        context.clip(to: canvasRect)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)

        for stroke in renderedStrokes { stroke.draw(in: context) }
        if let draft { RenderedStroke(draft.stroke).draw(in: context) }
    }

    private var viewport: CanvasViewport? {
        CanvasViewport(
            canvas: document.canvas,
            viewSize: CanvasSize(width: Double(bounds.width), height: Double(bounds.height))
        )
    }

    private func canvasPoint(at locationInWindow: NSPoint, clamped: Bool) -> BoardPoint? {
        let location = convert(locationInWindow, from: nil)
        return viewport?.canvasPoint(
            fromViewPoint: BoardPoint(x: Double(location.x), y: Double(location.y)),
            clamped: clamped
        )
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Whiteboard")
        setAccessibilityHelp("Hold Command and move the pointer to draw without clicking. Release Command for Cursor mode.")
        refreshInputAppearance()
    }
}

/// Cache committed paths so a drag doesn't rebuild every previous stroke.
@MainActor
private struct RenderedStroke {
    let path: CGPath
    let color: CGColor
    let width: CGFloat
    let isDot: Bool

    init(_ stroke: Stroke) {
        color = (stroke.color == .black ? NSColor.black : NSColor.red).cgColor
        width = CGFloat(stroke.width)
        isDot = stroke.points.count == 1
        let path = CGMutablePath()

        if let first = stroke.points.first {
            if isDot {
                path.addEllipse(in: CGRect(
                    x: CGFloat(first.x) - width / 2,
                    y: CGFloat(first.y) - width / 2,
                    width: width, height: width
                ))
            } else {
                path.move(to: CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)))
                for index in 1..<stroke.points.count {
                    let previous = stroke.points[index - 1]
                    let next = stroke.points[index]
                    path.addQuadCurve(
                        to: CGPoint(x: CGFloat((previous.x + next.x) / 2), y: CGFloat((previous.y + next.y) / 2)),
                        control: CGPoint(x: CGFloat(previous.x), y: CGFloat(previous.y))
                    )
                }
                if let last = stroke.points.last {
                    path.addLine(to: CGPoint(x: CGFloat(last.x), y: CGFloat(last.y)))
                }
            }
        }
        self.path = path
    }

    func draw(in context: CGContext) {
        context.addPath(path)
        if isDot {
            context.setFillColor(color)
            context.fillPath()
        } else {
            context.setStrokeColor(color)
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }
}
