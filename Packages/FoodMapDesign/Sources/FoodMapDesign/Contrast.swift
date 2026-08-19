/// WCAG 2.1 relative luminance and contrast ratio, on plain sRGB hex values.
///
/// No UIKit and no SwiftUI, so this is testable on macOS in microseconds.
public enum Contrast {

    /// WCAG AA: normal text.
    public static let normalTextMinimum = 4.5
    /// WCAG AA: text at 18 pt and above, and meaningful graphics.
    public static let largeTextMinimum = 3.0

    public static func relativeLuminance(_ hex: UInt32) -> Double {
        let channels = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF]
            .map { linear(Double($0) / 255) }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    public static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let first = relativeLuminance(a), second = relativeLuminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

#if canImport(Foundation)
import Foundation
#endif
