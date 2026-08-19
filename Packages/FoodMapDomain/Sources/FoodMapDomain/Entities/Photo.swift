import Foundation

/// A stored food photo. The domain knows only the identifiers it needs to ask storage for
/// bytes later; it never holds image data itself.
public struct Photo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var filename: String
    public var thumbnailFilename: String
    public var width: Double
    public var height: Double
    public var takenAt: Date?
    public var coordinate: Coordinate?

    public init(
        id: UUID = UUID(),
        filename: String,
        thumbnailFilename: String,
        width: Double,
        height: Double,
        takenAt: Date? = nil,
        coordinate: Coordinate? = nil
    ) {
        self.id = id
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.width = width
        self.height = height
        self.takenAt = takenAt
        self.coordinate = coordinate
    }
}

/// What the app knows about an image before it has been stored: the bytes, plus whatever
/// the file's own metadata revealed.
public struct PhotoMetadata: Equatable, Sendable {
    public var takenAt: Date?
    public var coordinate: Coordinate?

    public init(takenAt: Date? = nil, coordinate: Coordinate? = nil) {
        self.takenAt = takenAt
        self.coordinate = coordinate
    }
}
