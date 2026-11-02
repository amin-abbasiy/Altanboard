import Foundation

/// Committed board state. The native canvas handles Command-held drawing and drafts.
public struct BoardSession: Equatable, Sendable {
    public private(set) var document: BoardDocument
    public var selectedColor: PencilColor

    public init() {
        document = BoardDocument()
        selectedColor = .black
    }

    public mutating func append(_ stroke: Stroke) throws {
        var updated = document
        updated.strokes.append(stroke)
        try updated.validate()
        document = updated
    }

    public mutating func clear() throws {
        document = BoardDocument(canvas: document.canvas)
    }

    /// Validate before replacement so a failed load never erases the current board.
    public mutating func replaceDocument(_ replacement: BoardDocument) throws {
        try replacement.validate()
        document = replacement
    }

    public mutating func saveAndClear(to url: URL) throws {
        try BoardFileStore.save(document, to: url)
        // This line is reached only after the atomic save has succeeded.
        document = BoardDocument(canvas: document.canvas)
    }
}
