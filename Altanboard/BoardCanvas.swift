import AppKit
import SwiftUI
import WhiteboardCore

@MainActor
struct BoardCanvas: NSViewRepresentable {
    @ObservedObject var store: BoardStore

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView(frame: .zero)
        view.onCommit = { [weak store] stroke in store?.commit(stroke) }
        return view
    }

    func updateNSView(_ view: DrawingCanvasView, context: Context) {
        view.configure(
            document: store.document,
            selectedColor: store.selectedColor,
            drawingEnabled: store.canModify
        )
    }
}

@MainActor
final class DrawingCanvasView: NSView {
    var onCommit: ((Stroke) -> Void)?

    private var document = BoardDocument()
    private var selectedColor = PencilColor.black
    private var drawingEnabled = true
    private var draft: StrokeDraft?
    private var renderedStrokes: [RenderedStroke] = []

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
        if self.drawingEnabled != drawingEnabled {
            self.drawingEnabled = drawingEnabled
            window?.invalidateCursorRects(for: self)
        }
        if !drawingEnabled { draft = nil }
        setAccessibilityValue("\(drawingEnabled ? "Edit" : "View") mode, \(document.strokes.count) strokes")
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: drawingEnabled ? .crosshair : .arrow)
    }

    // Only press/drag/release events draw. Hovering the trackpad never adds ink.
    override func mouseDown(with event: NSEvent) {
        guard drawingEnabled, let point = canvasPoint(for: event, clamped: false) else { return }
        window?.makeFirstResponder(self)
        draft = StrokeDraft(start: point, color: selectedColor)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard drawingEnabled, draft != nil,
              let point = canvasPoint(for: event, clamped: true) else { return }
        draft?.append(point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard drawingEnabled, var completed = draft else { return }
        if let point = canvasPoint(for: event, clamped: true) {
            completed.append(point, isFinal: true)
        }
        draft = nil
        onCommit?(completed.stroke)
        needsDisplay = true
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { draft = nil }
        super.viewWillMove(toWindow: newWindow)
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

    private func canvasPoint(for event: NSEvent, clamped: Bool) -> BoardPoint? {
        let location = convert(event.locationInWindow, from: nil)
        return viewport?.canvasPoint(
            fromViewPoint: BoardPoint(x: Double(location.x), y: Double(location.y)),
            clamped: clamped
        )
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Whiteboard")
        setAccessibilityHelp("In Edit mode, press and drag on the trackpad to draw. View mode is read-only.")
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
