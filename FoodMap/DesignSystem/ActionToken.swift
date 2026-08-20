import SwiftUI
import FoodMapDesign

/// A round action that floats on the map (ADR-003), drawn rather than rendered (ADR-005).
///
/// The map is the app, so its actions belong on it rather than in a row the sheet has to be tall
/// enough to show. They are drawn to the cartoon rule: a flat fill, a bold dark contour, and a hard
/// shadow — the disc again in ink, moved four points down, with no blur on it. That shadow is also
/// the button's travel: pressing it moves the token onto its shadow and takes the gap away, which
/// is the whole of the press animation and needs no colour change to be felt.
///
/// No two of them are the same shape. Three discs in a column are three of one button; a wobbly
/// circle, a luggage tag and a fat blob are three characters, told apart at the edge of vision and
/// before the glyph on them is read. Each also sits at its own small angle, because nothing in a
/// drawn world is aligned to a grid.
///
/// The earlier version was a grained paper token with a faint ring and a soft drop shadow. Against
/// Apple's cartography it read as a system control that had been washed out, and at a glance the
/// three of them read as one grey smudge. Size, hit target and labelling are untouched (NFR-6.1).
struct FloatingActionButton: View {
    enum Style { case primary, secondary }

    let glyph: FoodMark.Glyph
    let label: LocalizedStringKey
    let identifier: String
    var style: Style = .secondary

    @Environment(\.isEnabled) private var isEnabled
    let action: () -> Void

    private var diameter: CGFloat {
        style == .primary ? 66 : 54
    }

    /// The silhouette this action wears, and the angle it was stuck on at. Chosen by what the
    /// button *is*: the needle points, so it keeps a round face; saving a place is a tag tied to
    /// it; the camera is the fat one, because it is the thing the app is for.
    private var character: (shape: AnyInsettableShape, tilt: Double) {
        switch glyph {
        case .needle: (AnyInsettableShape(WobbleCircle()), -3)
        case .ribbon: (AnyInsettableShape(TagShape()), 4)
        default: (AnyInsettableShape(BlobShape()), -2.5)
        }
    }

    /// How thick the contour is. The main action is drawn with a heavier pen than the two beside
    /// it, which is most of what makes it the main action.
    private var contour: CGFloat {
        style == .primary ? 3 : 2.4
    }

    var body: some View {
        Button(action: action) {
            InkToken(shape: character.shape, fill: background, contour: contour)
                .frame(width: diameter, height: diameter)
                .overlay {
                    FoodMark(glyph: glyph)
                        .inked(style == .primary ? 2.4 : 2.1)
                        .foregroundStyle(foreground)
                        // The glyph is drawn to the edge of its square, so it needs its own margin
                        // inside the disc; a third of the radius keeps every mark optically equal.
                        .padding(diameter * 0.3)
                }
        }
        .rotationEffect(.degrees(character.tilt))
        .buttonStyle(ActionTokenStyle(shape: character.shape, drop: style == .primary ? 4.5 : 3.5))
        .opacity(isEnabled ? 1 : 0.45)
        // The label is what VoiceOver reads and what the journeys look for (TC-N-11).
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var foreground: Color {
        style == .primary ? Theme.onAccent : Theme.ink
    }

    private var background: Color {
        style == .primary ? Theme.visitedInk : Theme.paperRaised
    }
}

/// The press: the token drops onto its own shadow and comes back up.
///
/// A cartoon button has no highlight and no tint change to spend on feedback — it has a gap under
/// it, and pressing it closes the gap. The shadow stays where it is while the disc moves, so the
/// thing looks pushed rather than merely darkened.
private struct ActionTokenStyle: ButtonStyle {
    let shape: AnyInsettableShape
    let drop: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(
                shape
                    .fill(Theme.ink.opacity(0.85))
                    .offset(y: drop)
            )
            .offset(y: pressed ? drop * 0.8 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
    }
}

/// A flat shape inside a bold contour — how every drawn control in the app is built.
struct InkToken: View {
    let shape: AnyInsettableShape
    let fill: Color
    var contour: CGFloat = 2.4

    var body: some View {
        shape
            .fill(fill)
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: contour))
    }
}

/// A type-erased `InsettableShape`, so a control can carry its silhouette as a value.
///
/// SwiftUI ships `AnyShape` but not this, and the contour is drawn with `strokeBorder` — which
/// needs the shape to know how to inset itself — so the erasure has to preserve that.
struct AnyInsettableShape: InsettableShape {
    private let makePath: @Sendable (CGRect) -> Path
    private let makeInset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        makePath = { shape.path(in: $0) }
        makeInset = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path { makePath(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { makeInset(amount) }
}
