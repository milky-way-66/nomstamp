import SwiftUI
import FoodMapDesign

/// The design tokens from ADR-003. No view hard-codes a colour or a size.
///
/// The hex values live in `FoodMapDesign.Palette`, where TC-N-07 checks every pairing the
/// interface renders against WCAG AA in both appearances (NFR-6.4). This type only turns
/// them into SwiftUI colours.
enum Theme {

    // MARK: - Colour

    /// Warm paper in light mode, deep ink at night.
    static let paper = dynamic(Palette.paper)
    static let paperRaised = dynamic(Palette.paperRaised)
    static let ink = dynamic(Palette.ink)
    static let inkSecondary = dynamic(Palette.inkSecondary)
    static let rule = dynamic(Palette.rule)

    /// Vietnamese lacquerware rather than an arbitrary red — used for places you have been.
    static let lacquer = dynamic(Palette.lacquer)
    /// Jade, for places you still want to try.
    static let jade = dynamic(Palette.jade)

    /// Text drawn *on* a lacquer or jade fill. Not white in dark mode: the dark-mode fills are
    /// light, so white on them is 3.03:1, below AA (TC-N-07).
    static let onLacquer = dynamic(Palette.onLacquer)
    static let onJade = dynamic(Palette.onJade)

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

    private static func dynamic(_ color: PaletteColor) -> Color {
        Color(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? color.dark : color.light)
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

/// The sheet's action row: one icon, one job, always at the minimum touch target.
struct ActionButton: View {
    enum Style { case primary, secondary }

    let systemImage: String
    let label: LocalizedStringKey
    let identifier: String
    var style: Style = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: Theme.minimumTouchTarget)
                .foregroundStyle(style == .primary ? Theme.onLacquer : Theme.jade)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(style == .primary ? Theme.lacquer : Theme.paperRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(
                            style == .primary ? Color.clear : Theme.rule,
                            lineWidth: Theme.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        // The label is what VoiceOver reads and what the journeys look for (TC-N-11).
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
