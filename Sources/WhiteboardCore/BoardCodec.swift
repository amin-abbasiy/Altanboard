import Foundation

public enum BoardFileError: Error, LocalizedError, Equatable, Sendable {
    case malformedJSON
    case fileTooLarge
    case unsupportedVersion(Int)
    case invalidCanvas
    case invalidStroke
    case invalidPoint
    case duplicateStrokeID
    case tooManyStrokes
    case tooManyPoints
    case readOnly

    public var errorDescription: String? {
        switch self {
        case .malformedJSON:
            return "This is not a valid Altanboard JSON drawing."
        case .fileTooLarge:
            return "This drawing exceeds the 32 MB file limit."
        case .unsupportedVersion(let version):
            return "Drawing format version \(version) is not supported by this app."
        case .invalidCanvas:
            return "The drawing contains invalid canvas dimensions."
        case .invalidStroke:
            return "The drawing contains an empty stroke or invalid pencil width."
        case .invalidPoint:
            return "The drawing contains an invalid point or a point outside its canvas."
        case .duplicateStrokeID:
            return "The drawing contains duplicate stroke identifiers."
        case .tooManyStrokes:
            return "The drawing contains too many strokes."
        case .tooManyPoints:
            return "The drawing contains too many points."
        case .readOnly:
            return "Switch to Edit mode to change the drawing."
        }
    }
}

public enum BoardCodec {
    public static let maximumFileBytes = 32 * 1_024 * 1_024
    public static let maximumStrokeCount = 50_000
    public static let maximumPointCount = 500_000

    public static func encode(_ document: BoardDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumFileBytes else {
            throw BoardFileError.fileTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> BoardDocument {
        guard data.count <= maximumFileBytes else {
            throw BoardFileError.fileTooLarge
        }
        let document: BoardDocument
        do {
            document = try JSONDecoder().decode(BoardDocument.self, from: data)
        } catch {
            throw BoardFileError.malformedJSON
        }
        try document.validate()
        return document
    }
}

public enum BoardFileStore {
    public static func save(_ document: BoardDocument, to url: URL) throws {
        let data = try BoardCodec.encode(document)
        // A partial write must never replace a previously saved drawing.
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> BoardDocument {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        // Bound the read itself, rather than trusting the file's reported size.
        // An untrusted or concurrently growing file cannot cause an unlimited read.
        var data = Data()
        while let chunk = try handle.read(upToCount: 64 * 1_024), !chunk.isEmpty {
            guard data.count + chunk.count <= BoardCodec.maximumFileBytes else {
                throw BoardFileError.fileTooLarge
            }
            data.append(chunk)
        }
        return try BoardCodec.decode(data)
    }
}
