import SwiftUI
import FoodMapDesign

/// Printing a stamp at the quality its score earned (ADR-005).
///
/// `StampPress` in `FoodMapDesign` decides the numbers and TC-N-22 asserts their order; this turns
/// them into ink. It lives in one place because the map and the list draw the same stamp, and a
/// one-star pin that looked crooked on the map but crisp in the list would say two different things
/// about the same meal.
extension View {
    /// Frames this view as a stamp: the paper edge, the rating's rule, and — at the top of the
    /// ramp — the marks of a press that was being careful.
    func stampPressed<S: InsettableShape>(
        _ shape: S,
        press: StampPress,
        ink: Color,
        showsInk: Bool,
        paperRule: Double
    ) -> some View {
        modifier(StampPrinting(shape: shape, press: press, ink: ink, showsInk: showsInk, paperRule: paperRule))
    }
}

private struct StampPrinting<S: InsettableShape>: ViewModifier {
    let shape: S
    let press: StampPress
    let ink: Color
    /// False where the place has no score to print in — the frame is still made well or badly,
    /// but in plain paper, because an unrated place must not borrow a rating's colour.
    let showsInk: Bool
    /// The white paper edge every stamp has, before any rating ink goes on it.
    let paperRule: Double

    func body(content: Content) -> some View {
        content
            .overlay(shape.strokeBorder(Theme.paperRaised, lineWidth: paperRule))
            .overlay(rules)
            // The second ink misses by however far the press was out. The offset is the house
            // direction; the score decides how badly it is missed.
            .background(
                shape
                    .fill(Theme.printingInk.opacity(0.5))
                    .offset(
                        x: (Theme.inkOffset.width < 0 ? -1 : 1) * press.misregistration,
                        y: (Theme.inkOffset.height < 0 ? -1 : 1) * press.misregistration
                    )
                    // Blurring the ink, never the photograph: a soft impression is a printing
                    // fault, and a soft photograph is just a broken image.
                    .blur(radius: press.smudge)
            )
            .shadow(
                color: .black.opacity(0.12 + 0.12 * press.quality),
                radius: press.lift,
                y: press.lift * 0.25
            )
    }

    /// The rule around the stamp, plus whatever the score has earned inside it.
    @ViewBuilder
    private var rules: some View {
        let ruleInk = (showsInk ? ink : Theme.printingInk).opacity(press.ruleOpacity)

        ZStack {
            shape.strokeBorder(
                ruleInk,
                style: StrokeStyle(
                    lineWidth: press.ruleWidth,
                    dash: (press.ruleDash ?? []).map { CGFloat($0) }
                )
            )

            // Four stars and up: a finer rule inside the first, which is the point at which a
            // stamp stops looking merely correct and starts looking intended.
            if press.hasInnerRule {
                shape
                    .inset(by: press.ruleWidth + 2)
                    .strokeBorder(ruleInk.opacity(0.6), lineWidth: 0.7)
            }

            if press.hasCornerTicks {
                CornerTicks().stroke(ruleInk, lineWidth: 1)
            }
        }
        // The ink is soft when the impression is; the perforations underneath stay sharp, so the
        // stamp still reads as a stamp at pin size.
        .blur(radius: press.smudge * 0.7)
    }
}

/// The four engraved marks a good stamp is finished with: a short right angle set into each
/// corner. Five stars only — an ornament that appeared at three would stop meaning anything.
private struct CornerTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width, rect.height) * 0.16
        let length = min(rect.width, rect.height) * 0.12
        var path = Path()

        for x in [rect.minX + inset, rect.maxX - inset] {
            for y in [rect.minY + inset, rect.maxY - inset] {
                let towardsCentreX: CGFloat = x < rect.midX ? 1 : -1
                let towardsCentreY: CGFloat = y < rect.midY ? 1 : -1
                path.move(to: CGPoint(x: x + length * towardsCentreX, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + length * towardsCentreY))
            }
        }
        return path
    }
}
