import Foundation

public enum BoardMode: String, CaseIterable, Sendable {
    case view
    case edit
}

/// Committed board state. Draft strokes belong to the native canvas until release.
public struct BoardSession: Equatable, Sendable {
    public private(set) var document: BoardDocument
    public var mode: BoardMode
    public var selectedColor: PencilColor

    public init() {
        document = BoardDocument()
        mode = .edit
        selectedColor = .black
    }

    public mutating func append(_ stroke: Stroke) throws {
        try requireEditing()
        var updated = document
        updated.strokes.append(stroke)
        try updated.validate()
        document = updated
    }

    public mutating func clear() throws {
        try requireEditing()
        document = BoardDocument(canvas: document.canvas)
    }

    /// Loading is allowed in View mode; it opens another drawing without editing it.
    /// Validate before replacement so a failed load never erases the current board.
    public mutating func replaceDocument(_ replacement: BoardDocument) throws {
        try replacement.validate()
        document = replacement
    }

    public mutating func saveAndClear(to url: URL) throws {
        try requireEditing()
        try BoardFileStore.save(document, to: url)
        // This line is reached only after the atomic save has succeeded.
        document = BoardDocument(canvas: document.canvas)
    }

    private func requireEditing() throws {
        guard mode == .edit else { throw BoardFileError.readOnly }
    }
}
