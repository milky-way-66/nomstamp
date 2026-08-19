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

        let formatter = exifDateFormatter
        // EXIF 2.31 cameras — every recent iPhone — record the offset the photograph was taken
        // at. Where it is present it is the truth; where it is not, the device's own zone is the
        // best guess, and it is the one the Photos app makes too (FR-1.3).
        formatter.timeZone = offset(from: exif) ?? .current
        return formatter.date(from: raw)
    }

    /// `OffsetTimeOriginal` looks like "+07:00".
    private static func offset(from exif: [CFString: Any]) -> TimeZone? {
        guard let raw = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String else { return nil }
        let sign = raw.hasPrefix("-") ? -1 : 1
        let digits = raw.dropFirst().split(separator: ":").compactMap { Int($0) }
        guard digits.count == 2 else { return nil }
        return TimeZone(secondsFromGMT: sign * (digits[0] * 3600 + digits[1] * 60))
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
        guard coordinate.isValid else { return nil }
        // Cameras write 0, 0 in place of a missing fix, and the Gulf of Guinea has no phở
        // (FR-1.17).
        guard coordinate.latitude != 0 || coordinate.longitude != 0 else { return nil }
        return coordinate
    }

    /// `DateTimeOriginal` is local wall-clock time with no zone of its own, so the zone is
    /// supplied per photograph by `captureDate`. A fresh formatter each time, because setting the
    /// zone on a shared one is not safe across concurrent reads.
    private static var exifDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
