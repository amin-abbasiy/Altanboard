import Foundation

/// A draft is created only by a trackpad press, never by pointer movement.
public struct StrokeDraft: Sendable {
    public private(set) var stroke: Stroke

    public init(start: BoardPoint, color: PencilColor, width: Double = 3) {
        stroke = Stroke(color: color, width: width, points: [start])
    }

    /// Ignore sub-pixel jitter while keeping the exact last point on release.
    public mutating func append(_ point: BoardPoint, isFinal: Bool = false) {
        guard point.x.isFinite, point.y.isFinite,
              let previous = stroke.points.last else { return }
        let dx = point.x - previous.x
        let dy = point.y - previous.y
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared > 0,
              isFinal || distanceSquared >= 0.25 * 0.25,
              stroke.points.count < BoardCodec.maximumPointCount else { return }
        stroke.points.append(point)
    }
}
