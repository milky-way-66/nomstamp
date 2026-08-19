import Foundation
import ImageIO
import FoodMapDomain

/// Reads capture time and GPS from an image's own metadata.
///
/// Uses ImageIO rather than UIKit, so it compiles and is testable on macOS — which is why
/// these tests need no simulator.
public enum ImageMetadataReader {

    public static func metadata(from data: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return PhotoMetadata() }

        return PhotoMetadata(
            takenAt: captureDate(from: properties),
            coordinate: coordinate(from: properties)
        )
    }

    private static func captureDate(from properties: [CFString: Any]) -> Date? {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        return exifDateFormatter.date(from: raw)
    }

    private static func coordinate(from properties: [CFString: Any]) -> Coordinate? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }

        // EXIF stores unsigned magnitudes plus a hemisphere reference. Ignoring the reference
        // puts every southern or western photo in the wrong hemisphere (TC-1-12).
        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N").uppercased()
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E").uppercased()

        let coordinate = Coordinate(
            latitude: latitudeRef == "S" ? -latitude : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )
        return coordinate.isValid ? coordinate : nil
    }

    /// EXIF timestamps have no time zone, so they are read in the device's current zone —
    /// the same convention the Photos app uses.
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
