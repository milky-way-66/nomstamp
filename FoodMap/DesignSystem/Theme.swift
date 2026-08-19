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

    // MARK: - Spacing
    //
    // One 4 pt scale, used everywhere. Before this, views carried 6, 9, 10, 14, 18, 22 and 26
    // pt paddings picked one at a time, and nothing lined up across screens.

    enum Space {
        /// 4 — between a glyph and its own label.
        static let hairline: CGFloat = 4
        /// 8 — between items inside one component.
        static let tight: CGFloat = 8
        /// 12 — between components in a group.
        static let snug: CGFloat = 12
        /// 16 — the screen margin, and the gap between groups.
        static let regular: CGFloat = 16
        /// 24 — between unrelated blocks.
        static let loose: CGFloat = 24
        /// 32 — around a lone piece of content, such as an empty state.
        static let generous: CGFloat = 32
    }

    /// Every screen edge is this far from its content, so blocks line up across screens.
    static let screenMargin: CGFloat = Space.regular

    /// Padding inside a card or a field, which is one step tighter than the screen margin so
    /// nested edges do not read as doubled.
    static let contentInset: CGFloat = Space.snug

    // MARK: - Metrics

    static let cornerRadius: CGFloat = 12
    static let hairline: CGFloat = 1
    static let pinSize: CGFloat = 56
    /// Apple's minimum touch target; pins are never drawn smaller (NFR-6.4).
    static let minimumTouchTarget: CGFloat = 44

    /// Every photograph is presented at one ratio, filling the width it is given and cropped
    /// from the centre. 3:2 is the photographer's ratio and, unlike 4:3, a card's caption still
    /// fits above the fold of a bottom sheet (ADR-003).
    static let photoAspect: CGFloat = 3 / 2

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


/// A round action that floats on the map (ADR-003).
///
/// The map is the app, so its actions belong on it rather than in a row the sheet has to be
/// tall enough to show. Circular and shadowed to read as chrome above the cartography, at the
/// minimum touch target or larger (NFR-6.1).
struct FloatingActionButton: View {
    enum Style { case primary, secondary }

    let systemImage: String
    let label: LocalizedStringKey
    let identifier: String
    var style: Style = .secondary

    @Environment(\.isEnabled) private var isEnabled
    let action: () -> Void

    private var diameter: CGFloat {
        style == .primary ? 58 : Theme.minimumTouchTarget
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: style == .primary ? 22 : 17, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(background))
                .overlay(
                    Circle().strokeBorder(
                        style == .primary ? Color.clear : Theme.rule,
                        lineWidth: Theme.hairline
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        // The label is what VoiceOver reads and what the journeys look for (TC-N-11).
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var foreground: Color {
        style == .primary ? Theme.onLacquer : Theme.jade
    }

    private var background: Color {
        style == .primary ? Theme.lacquer : Theme.paperRaised
    }
}
