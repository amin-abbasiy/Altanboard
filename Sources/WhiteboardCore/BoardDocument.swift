import Foundation

public enum PencilColor: String, Codable, CaseIterable, Sendable {
    case black
    case red
}

public struct BoardPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public static let standard = CanvasSize(width: 1_200, height: 800)

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct Stroke: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let color: PencilColor
    public let width: Double
    public var points: [BoardPoint]

    public init(
        id: UUID = UUID(),
        color: PencilColor,
        width: Double = 3,
        points: [BoardPoint]
    ) {
        self.id = id
        self.color = color
        self.width = width
        self.points = points
    }
}

/// Coordinates and pencil widths are in logical canvas points, not screen pixels.
/// The canvas is uniformly scaled to fit the window, without distorting the notes.
public struct BoardDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let formatVersion: Int
    public let canvas: CanvasSize
    public var strokes: [Stroke]

    public init(
        formatVersion: Int = BoardDocument.currentVersion,
        canvas: CanvasSize = .standard,
        strokes: [Stroke] = []
    ) {
        self.formatVersion = formatVersion
        self.canvas = canvas
        self.strokes = strokes
    }

    public func validate() throws {
        guard formatVersion == Self.currentVersion else {
            throw BoardFileError.unsupportedVersion(formatVersion)
        }
        guard canvas.width.isFinite, canvas.height.isFinite,
              canvas.width >= 1, canvas.height >= 1,
              canvas.width <= 65_536, canvas.height <= 65_536 else {
            throw BoardFileError.invalidCanvas
        }
        guard strokes.count <= BoardCodec.maximumStrokeCount else {
            throw BoardFileError.tooManyStrokes
        }

        var identifiers = Set<UUID>()
        var pointCount = 0
        for stroke in strokes {
            guard identifiers.insert(stroke.id).inserted else {
                throw BoardFileError.duplicateStrokeID
            }
            guard stroke.width.isFinite, stroke.width > 0, stroke.width <= 128,
                  !stroke.points.isEmpty else {
                throw BoardFileError.invalidStroke
            }
            pointCount += stroke.points.count
            guard pointCount <= BoardCodec.maximumPointCount else {
                throw BoardFileError.tooManyPoints
            }
            for point in stroke.points {
                guard point.x.isFinite, point.y.isFinite,
                      point.x >= 0, point.y >= 0,
                      point.x <= canvas.width, point.y <= canvas.height else {
                    throw BoardFileError.invalidPoint
                }
            }
        }
    }
}
