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

    /// Pandan — the green everything sweet is cooked in. Places you have been, and the actions
    /// that add to the map.
    static let pandan = dynamic(Palette.pandan)
    /// Bay, for places you still want to try.
    static let bay = dynamic(Palette.bay)
    /// The printing ink (ADR-005): ornaments, stamp frames, and the second layer of a
    /// misregistration. Never an accent — it does not mean anything on its own.
    static let indigo = dynamic(Palette.indigo)

    /// Text drawn *on* a pandan or bay fill. Not white in dark mode: the dark-mode fills are
    /// light, so white on them is 3.03:1, below AA (TC-N-07).
    static let onPandan = dynamic(Palette.onPandan)
    static let onBay = dynamic(Palette.onBay)

    static func accent(for kind: PlaceKindStyle) -> Color {
        switch kind {
        case .visited: return pandan
        case .wishlist: return bay
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

    /// Letterspaced small caps, for the labels a printed page sets that way: BEEN HERE, MEAL 03.
    static func smallCaps(_ style: Font.TextStyle = .caption) -> Font {
        .system(style).smallCaps()
    }

    /// Dates and counts, set like something stamped rather than typed.
    static func stamped(_ style: Font.TextStyle = .caption2) -> Font {
        .system(style, design: .monospaced)
    }

    // MARK: - Printing (ADR-005)

    /// How far the second ink misses the first by. Enough to see, not enough to read as a bug.
    static let inkOffset: CGSize = CGSize(width: 1.5, height: 1.5)

    /// The grain's strength over a page ground. Above this it reads as dirt (TC-N-14).
    static let grainOpacity: Double = 0.55

    /// The ink the cartography is printed in. Warm mid-tan in daylight; at night a deep indigo,
    /// so the map reads as a night market rather than a switched-off screen.
    static let mapWash = dynamic(Palette.mapWash)

    /// The ink a score paints (ADR-005, TC-N-17). An unrated meal takes the secondary ink: the
    /// absence of a score is not a low score.
    static func ratingInk(_ score: Int?) -> Color {
        guard let mood = RatingMood.mood(for: score) else { return inkSecondary }
        return dynamic(mood.ink)
    }

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
