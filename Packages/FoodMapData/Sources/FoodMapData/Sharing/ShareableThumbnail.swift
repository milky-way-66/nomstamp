import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import FoodMapDomain

public enum ThumbnailRedactionError: Error, Equatable {
    case unreadableImage
    case encodingFailed
}

/// Re-encodes a thumbnail with **no metadata at all** before it is allowed to leave the device.
///
/// This is the most dangerous quiet failure in the whole feature. The photo pipeline records
/// `exif_lat` and `exif_lng` because a meal's coordinate is often the photograph's; shipping
/// those inside a shared image would leak the precise spot a reader stood for every picture they
/// take, straight past every other protection in ADR-009.
///
/// Stripping is done by **re-encoding from pixels** rather than by deleting the EXIF keys. A
/// delete-the-keys approach quietly leaves whatever the caller forgot to name — MakerNote, XMP, a
/// second GPS block in an app-specific segment. Starting from a bare `CGImage` means the only
/// thing that can be in the output is what this function put there, which is nothing (FR-11.5,
/// TC-9-16).
public enum ShareableThumbnail {
    /// NFR-8.2: the same 240 px the pin already renders. ~7–10 KB, so a 500-place map is ~5 MB.
    public static let side = 240

    public static func redacted(_ imageData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: side
              ] as CFDictionary)
        else { throw ThumbnailRedactionError.unreadableImage }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw ThumbnailRedactionError.encodingFailed }

        // The only properties written are the compression quality. No EXIF dictionary, no GPS
        // dictionary, no TIFF dictionary, no IPTC — they are not omitted by accident, they are
        // never constructed.
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailRedactionError.encodingFailed
        }
        return output as Data
    }

    /// Whether an image still says anything about *where*, *when* or *with what* it was taken.
    ///
    /// Not "does it have an EXIF dictionary". ImageIO writes one on every JPEG it encodes, holding
    /// `ColorSpace` and the image's own pixel dimensions — facts about the file in front of you,
    /// not about the reader. Demanding their absence would be a rule the encoder cannot honour,
    /// and a rule that cannot be honoured gets weakened later. So the rule names what is actually
    /// forbidden instead (FR-11.5).
    public static func carriesIdentifyingMetadata(_ imageData: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return false }

        // Whole dictionaries that exist only to describe a camera, a place or a moment.
        let forbiddenDictionaries: [CFString] = [
            kCGImagePropertyGPSDictionary,
            kCGImagePropertyIPTCDictionary,
            kCGImagePropertyExifAuxDictionary,
            kCGImagePropertyMakerAppleDictionary,
            kCGImagePropertyTIFFDictionary          // Make, Model, Software, DateTime
        ]
        if forbiddenDictionaries.contains(where: { properties[$0] != nil }) { return true }

        // And, inside the dictionary ImageIO insists on writing, anything beyond the geometry.
        let permittedExifKeys: Set<String> = [
            kCGImagePropertyExifColorSpace as String,
            kCGImagePropertyExifPixelXDimension as String,
            kCGImagePropertyExifPixelYDimension as String
        ]
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            return exif.keys.contains { !permittedExifKeys.contains($0 as String) }
        }
        return false
    }
}
