import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import FoodMapDomain

/// Stores food photos in a directory inside the app's own container.
///
/// Nothing is ever uploaded (NFR-1.1). Each photo is written twice: a capped full-size JPEG
/// for the detail view, and a small square thumbnail for map pins, so panning the map never
/// decodes multi-megabyte images (NFR-2.4).
public final class FileSystemPhotoStorage: PhotoStoragePort, @unchecked Sendable {

    /// NFR-8.1 and NFR-8.2.
    private let fullImageMaxDimension = 2048
    private let thumbnailSide = 240

    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(forFilename filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    // MARK: - Storing

    public func store(imageData: Data) throws -> Photo {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { throw PhotoStorageError.unreadableImage }

        guard let full = downscaled(source, maxPixelSize: fullImageMaxDimension) else {
            throw PhotoStorageError.unreadableImage
        }

        let identifier = UUID()
        let filename = "\(identifier.uuidString).jpg"
        let thumbnailFilename = "\(identifier.uuidString)_thumb.jpg"

        try write(full, to: url(forFilename: filename), quality: 0.85)

        // Cropped to a square before scaling down, so a wide dish photo is not squashed
        // into a circular pin.
        guard let squareSource = downscaled(source, maxPixelSize: thumbnailSide * 2),
              let square = centreCroppedSquare(squareSource),
              let thumbnail = scaled(square, to: thumbnailSide)
        else {
            // The full image is already on disk; leaving it behind would orphan a file.
            try? fileManager.removeItem(at: url(forFilename: filename))
            throw PhotoStorageError.encodingFailed
        }
        try write(thumbnail, to: url(forFilename: thumbnailFilename), quality: 0.8)

        let metadata = ImageMetadataReader.metadata(from: imageData)
        return Photo(
            id: identifier,
            filename: filename,
            thumbnailFilename: thumbnailFilename,
            width: Double(full.width),
            height: Double(full.height),
            takenAt: metadata.takenAt,
            coordinate: metadata.coordinate
        )
    }

    // MARK: - Deleting

    /// Silent about missing files by design: cleanup after a partial failure calls this
    /// blindly, and must never itself fail.
    public func delete(_ photo: Photo) {
        try? fileManager.removeItem(at: url(forFilename: photo.filename))
        try? fileManager.removeItem(at: url(forFilename: photo.thumbnailFilename))
    }

    public func readMetadata(from imageData: Data) -> PhotoMetadata {
        ImageMetadataReader.metadata(from: imageData)
    }

    // MARK: - Image helpers

    /// `kCGImageSourceCreateThumbnailWithTransform` applies the EXIF orientation, so a photo
    /// taken sideways is stored upright rather than rotating in the UI later.
    private func downscaled(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary)
    }

    private func centreCroppedSquare(_ image: CGImage) -> CGImage? {
        let side = min(image.width, image.height)
        let rect = CGRect(
            x: (image.width - side) / 2,
            y: (image.height - side) / 2,
            width: side,
            height: side
        )
        return image.cropping(to: rect)
    }

    private func scaled(_ image: CGImage, to side: Int) -> CGImage? {
        // Never upscale: a small original stays small rather than being blurred larger.
        let target = min(side, image.width)
        guard let context = CGContext(
            data: nil,
            width: target,
            height: target,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: target, height: target))
        return context.makeImage()
    }

    private func write(_ image: CGImage, to url: URL, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw PhotoStorageError.encodingFailed }

        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw PhotoStorageError.encodingFailed
        }
    }
}

public enum PhotoStorageError: Error, Equatable {
    case unreadableImage
    case encodingFailed
}
