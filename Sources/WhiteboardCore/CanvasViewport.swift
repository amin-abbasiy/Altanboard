import Foundation

/// Aspect-fit geometry shared by rendering and input hit-testing.
public struct CanvasViewport: Equatable, Sendable {
    public let canvas: CanvasSize
    public let scale: Double
    public let offset: BoardPoint

    public init?(canvas: CanvasSize, viewSize: CanvasSize) {
        guard canvas.width.isFinite, canvas.height.isFinite,
              viewSize.width.isFinite, viewSize.height.isFinite,
              canvas.width > 0, canvas.height > 0,
              viewSize.width > 0, viewSize.height > 0 else { return nil }

        let scale = min(viewSize.width / canvas.width, viewSize.height / canvas.height)
        guard scale.isFinite, scale > 0 else { return nil }
        self.canvas = canvas
        self.scale = scale
        offset = BoardPoint(
            x: (viewSize.width - canvas.width * scale) / 2,
            y: (viewSize.height - canvas.height * scale) / 2
        )
    }

    public func canvasPoint(fromViewPoint point: BoardPoint, clamped: Bool = false) -> BoardPoint? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let x = (point.x - offset.x) / scale
        let y = (point.y - offset.y) / scale
        if clamped {
            return BoardPoint(x: min(max(x, 0), canvas.width), y: min(max(y, 0), canvas.height))
        }
        guard x >= 0, y >= 0, x <= canvas.width, y <= canvas.height else { return nil }
        return BoardPoint(x: x, y: y)
    }

    public func viewPoint(fromCanvasPoint point: BoardPoint) -> BoardPoint {
        BoardPoint(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
    }
}
