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
        paperRule: Double,
        paper: Color = Theme.paperRaised
    ) -> some View {
        modifier(StampPrinting(
            shape: shape, press: press, ink: ink,
            showsInk: showsInk, paperRule: paperRule, paper: paper
        ))
    }
}

private struct StampPrinting<S: InsettableShape>: ViewModifier {
    let shape: S
    let press: StampPress
    let ink: Color
    /// False where the place has no score to print in — the frame is still made well or badly,
    /// but in plain paper, because an unrated place must not borrow a rating's colour.
    let showsInk: Bool
    /// The paper edge every stamp has, before any rating ink goes on it.
    let paperRule: Double
    /// What colour that paper is — dealt from the place's id, and carrying no meaning (ADR-005).
    let paper: Color

    func body(content: Content) -> some View {
        content
            .overlay(shape.strokeBorder(paper, lineWidth: paperRule))
            .overlay(rules)
            // No second impression and no shadow. Both were here, and both read at pin size as a
            // heavier border rather than as printing — thirteen small shapes, each with a grey
            // ghost behind it, made a map of blots (ADR-005).
    }

    /// The rule around the stamp, and — at five stars — the hairline inside it.
    @ViewBuilder
    private var rules: some View {
        let ruleInk = (showsInk ? ink : Theme.printingInk).opacity(press.ruleOpacity)

        ZStack {
            // The contour first — the dark line every drawn object in the app is bounded by — and
            // the rating's own rule inside it, so the score is a colour held by a line rather than
            // a line of its own colour floating on the map.
            shape.strokeBorder(Theme.ink.opacity(0.85), lineWidth: 0.7)
            shape.inset(by: 0.7).strokeBorder(ruleInk, lineWidth: press.ruleWidth)

            if press.hasInnerRule {
                shape
                    .inset(by: press.ruleWidth + 2)
                    .strokeBorder(ruleInk.opacity(0.55), lineWidth: 0.8)
            }
        }
    }
}

