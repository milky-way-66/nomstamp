import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Builds real JPEG data with genuine EXIF and GPS blocks.
///
/// Generated rather than committed as binaries: the bytes are written by ImageIO, so the
/// metadata layout is exactly what a camera produces, and the fixtures stay readable and
/// reviewable in the repository instead of being opaque blobs.
enum JPEGFactory {

    static func make(
        width: Int = 1200,
        height: Int = 900,
        takenAt: Date? = nil,
        /// The zone the "camera" was in. Cameras write local wall-clock time, so the default is
        /// the device's own zone — writing UTC here would hide the bug TC-1-20 exists to catch.
        timeZone: TimeZone = .current,
        /// Whether to record `OffsetTimeOriginal`, as EXIF 2.31 cameras do.
        recordOffset: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Data {
        let image = solidImage(width: width, height: height)
        let output = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            fatalError("could not create JPEG destination")
        }

        var properties: [CFString: Any] = [:]

        if let takenAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            var exif: [CFString: Any] = [
                kCGImagePropertyExifDateTimeOriginal: formatter.string(from: takenAt)
            ]
            if recordOffset {
                let minutes = timeZone.secondsFromGMT(for: takenAt) / 60
                exif[kCGImagePropertyExifOffsetTimeOriginal] = String(
                    format: "%@%02d:%02d", minutes < 0 ? "-" : "+", abs(minutes) / 60, abs(minutes) % 60
                )
            }
            properties[kCGImagePropertyExifDictionary] = exif as CFDictionary
        }

        if let latitude, let longitude {
            // EXIF stores unsigned magnitudes plus a hemisphere reference — the encoding whose
            // mishandling TC-1-12 exists to catch.
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: abs(latitude),
                kCGImagePropertyGPSLatitudeRef: latitude < 0 ? "S" : "N",
                kCGImagePropertyGPSLongitude: abs(longitude),
                kCGImagePropertyGPSLongitudeRef: longitude < 0 ? "W" : "E"
            ] as CFDictionary
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            fatalError("could not finalise JPEG")
        }
        return output as Data
    }

    private static func solidImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.85, green: 0.35, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}

/// A temporary directory that cleans itself up, so photo tests never touch real user storage.
final class TemporaryDirectory {
    let url: URL

    init() {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("foodmap-tests-\(UUID().uuidString)")
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
