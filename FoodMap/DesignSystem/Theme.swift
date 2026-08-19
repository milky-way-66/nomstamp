import SwiftUI

/// The design tokens from ADR-003. No view hard-codes a colour or a size.
///
/// Every pairing here was contrast-checked; the weakest is 5.21:1, comfortably past WCAG AA
/// (NFR-6.4).
enum Theme {

    // MARK: - Colour

    /// Warm paper in light mode, deep ink at night.
    static let paper = dynamic(light: 0xF5EFE3, dark: 0x1A1714)
    static let paperRaised = dynamic(light: 0xFDFAF3, dark: 0x241F1B)
    static let ink = dynamic(light: 0x2A2521, dark: 0xF0E9DC)
    static let inkSecondary = dynamic(light: 0x6B6259, dark: 0xA79C8D)
    static let rule = dynamic(light: 0xDCD2C0, dark: 0x3A332C)

    /// Vietnamese lacquerware rather than an arbitrary red — used for places you have been.
    static let lacquer = dynamic(light: 0xA8402F, dark: 0xD97A66)
    /// Jade, for places you still want to try.
    static let jade = dynamic(light: 0x2F6152, dark: 0x6FAF97)

    static func accent(for kind: PlaceKindStyle) -> Color {
        switch kind {
        case .visited: return lacquer
        case .wishlist: return jade
        }
    }

    // MARK: - Type
    //
    // Serif is display-only. Anything functional uses the system sans face, because serif at
    // map-label sizes is the specific way this style fails (ADR-003).

    static func display(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif)
    }

    static func displayItalic(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif).italic()
    }

    static func label(_ style: Font.TextStyle = .subheadline) -> Font {
        .system(style)
    }

    /// Stacked Vietnamese diacritics (ế, ộ, ữ) are clipped by tight leading, so line spacing
    /// never drops below this.
    static let minimumLineSpacing: CGFloat = 4

    // MARK: - Metrics

    static let cornerRadius: CGFloat = 12
    static let hairline: CGFloat = 1
    static let pinSize: CGFloat = 56
    /// Apple's minimum touch target; pins are never drawn smaller (NFR-6.4).
    static let minimumTouchTarget: CGFloat = 44

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum PlaceKindStyle {
    case visited
    case wishlist
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Shared building blocks

/// The paper card used throughout: flat warmth, a hairline rule, no heavy shadow. The language
/// is printed paper, not floating glass.
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Theme.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
            )
    }
}

struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.display(.headline))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
