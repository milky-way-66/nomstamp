/// WCAG 2.1 relative luminance and contrast ratio, on plain sRGB hex values.
///
/// No UIKit and no SwiftUI, so this is testable on macOS in microseconds.
public enum Contrast {

    /// WCAG AA: normal text.
    public static let normalTextMinimum = 4.5
    /// WCAG AA: text at 18 pt and above, and meaningful graphics.
    public static let largeTextMinimum = 3.0
    /// WCAG AAA: what body text on a surface aims at here (NFR-6.4).
    public static let enhancedTextMinimum = 7.0
    /// Non-text interface components: separators, borders, pin outlines.
    public static let componentMinimum = 3.0

    public static func relativeLuminance(_ hex: UInt32) -> Double {
        let channels = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF]
            .map { linear(Double($0) / 255) }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    public static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let first = relativeLuminance(a), second = relativeLuminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// How far apart two colours are on the colour wheel, in degrees (0…180).
    ///
    /// Contrast answers "can this be read"; this answers "is this the same colour", which is the
    /// question when two accents both have to sit on the same paper at the same legibility and
    /// still mean different things (TC-N-18).
    public static func hueSeparation(_ a: UInt32, _ b: UInt32) -> Double {
        let difference = abs(hue(a) - hue(b))
        return min(difference, 360 - difference)
    }

    /// The hue angle of a colour, in degrees. Grey has no hue, and reports 0.
    static func hue(_ hex: UInt32) -> Double {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        let highest = max(red, green, blue)
        let lowest = min(red, green, blue)
        let range = highest - lowest
        guard range > 0 else { return 0 }

        let angle: Double
        switch highest {
        case red: angle = 60 * ((green - blue) / range)
        case green: angle = 60 * (2 + (blue - red) / range)
        default: angle = 60 * (4 + (red - green) / range)
        }
        return angle < 0 ? angle + 360 : angle
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

#if canImport(Foundation)
import Foundation
#endif
