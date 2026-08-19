import Foundation

/// Where image bytes live. On the device, in the app's own container — never uploaded.
public protocol PhotoStoragePort: Sendable {
    /// Writes the image and returns the record describing it.
    func store(imageData: Data) throws -> Photo

    /// Removes both the full image and its thumbnail. Must not throw for an already-missing
    /// file, so cleaning up after a partial failure is safe to call blindly.
    func delete(_ photo: Photo)

    /// Reads capture time and GPS out of the image itself, without storing it.
    /// This is what lets a meal be logged after leaving the restaurant (UC-1 / 1a).
    func readMetadata(from imageData: Data) -> PhotoMetadata
}
