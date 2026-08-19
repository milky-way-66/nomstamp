import SwiftUI
import FoodMapDesign

/// A round action that floats on the map (ADR-003), printed rather than rendered (ADR-005).
///
/// The map is the app, so its actions belong on it rather than in a row the sheet has to be tall
/// enough to show. What changed with the art direction is only the surface: a paper token with
/// visible grain, a drawn `FoodMark` instead of an SF Symbol, and a second ink reprinted a fraction
/// off — so the three buttons read as one printed family sitting on the map rather than as system
/// chrome floating above it. Size, hit target and labelling are untouched (NFR-6.1).
struct FloatingActionButton: View {
    enum Style { case primary, secondary }

    let glyph: FoodMark.Glyph
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
            InkDisc(fill: background, ring: ring, grained: style == .secondary)
                .frame(width: diameter, height: diameter)
                .overlay {
                    FoodMark(glyph: glyph)
                        .inked(style == .primary ? 2.1 : 1.9)
                        .foregroundStyle(foreground)
                        // The glyph is drawn to the edge of its square, so it needs its own margin
                        // inside the disc; a third of the radius keeps every mark optically equal.
                        .padding(diameter * 0.3)
                }
                // The token is a printed thing: the indigo underprint shows at its edge.
                .misregistered(Circle(), ink: Theme.indigo, opacity: style == .primary ? 0.55 : 0.4)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        // The label is what VoiceOver reads and what the journeys look for (TC-N-11).
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var foreground: Color {
        style == .primary ? Theme.onPandan : Theme.bay
    }

    private var background: Color {
        style == .primary ? Theme.pandan : Theme.paperRaised
    }

    /// The primary token is solid ink, so a ring on it would only muddy its edge.
    private var ring: Color? {
        style == .primary ? nil : Theme.ink.opacity(0.55)
    }
}

/// A disc of inked paper: ground, grain, and an optional double rule at its edge.
struct InkDisc: View {
    let fill: Color
    var ring: Color?
    /// Grain is what paper has. On the solid-ink token it only read as dust, so the primary
    /// action is printed flat (ADR-005: texture belongs to the page, not to the ink).
    var grained: Bool = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Circle()
            .fill(fill)
            .overlay {
                if grained && !reduceTransparency {
                    PaperGrain.image
                        .resizable(resizingMode: .tile)
                        .opacity(Theme.grainOpacity)
                        .blendMode(.multiply)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if let ring {
                    // Two rules, unequal, close together: the mark of a hand-set frame rather than
                    // of a stroked border.
                    Circle().strokeBorder(ring, lineWidth: 1.4)
                    Circle().inset(by: 3).strokeBorder(ring.opacity(0.5), lineWidth: 0.7)
                }
            }
    }
}
