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
            // The house misregistration, the same on every stamp: it is what makes the frame look
            // printed rather than drawn, and it says nothing about the score.
            .misregistered(shape, ink: Theme.printingInk, opacity: 0.45)
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
    }

    /// The rule around the stamp, and — at five stars — the hairline inside it.
    @ViewBuilder
    private var rules: some View {
        let ruleInk = (showsInk ? ink : Theme.printingInk).opacity(press.ruleOpacity)

        ZStack {
            shape.strokeBorder(ruleInk, lineWidth: press.ruleWidth)

            if press.hasInnerRule {
                shape
                    .inset(by: press.ruleWidth + 2)
                    .strokeBorder(ruleInk.opacity(0.55), lineWidth: 0.6)
            }
        }
    }
}

