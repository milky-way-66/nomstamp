import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// UC-7 — a meal's score, shown and set in the same control.
///
/// There is no rating screen: tapping a star here *is* the edit (FR-9.5), and tapping the star
/// a meal already has clears it, which is the only way to undo a mistaken score.
///
/// Rating is the one judgement the app asks for, so the control answers it (ADR-005): the stars are
/// drawn marks rather than symbols, they stamp into place one at a time, the ink shifts along the
/// `RatingMood` ramp as the score rises, and a finger dragged across the row rates continuously
/// instead of demanding five separate taps.
struct StarRatingView: View {
    let rating: Int?
    /// Nil for a read-only display, as on a place row.
    var onSelect: ((Int) -> Void)?
    var size: CGFloat = 15

    /// The score under the finger, which is not committed until it lifts.
    @State private var dragging: Int?

    private var isInteractive: Bool { onSelect != nil }
    private var shown: Int? { dragging ?? rating }
    private var ink: Color { Theme.ratingInk(shown) }

    /// The width a star occupies while it is a control, used both for layout and to turn an x
    /// position into a score.
    private var slot: CGFloat { isInteractive ? Theme.minimumTouchTarget / 1.6 : size }

    var body: some View {
        if isInteractive {
            HStack(spacing: 3) {
                ForEach(RateMealUseCase.range, id: \.self) { score in
                    Button {
                        onSelect?(score)
                    } label: {
                        star(score)
                    }
                    .buttonStyle(.plain)
                    // Each star is its own control: one tap sets the score, and assistive
                    // technology can name the score it would set.
                    .accessibilityLabel("\(score) stars")
                    .accessibilityIdentifier("star\(score)")
                }
            }
            // A minimum distance, so a tap still belongs to the button underneath.
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in dragging = score(at: value.location.x) }
                    .onEnded { value in
                        let final = score(at: value.location.x)
                        dragging = nil
                        onSelect?(final)
                    }
            )
            // Every star crossed under the finger is felt, not just the one released on.
            .sensoryFeedback(.selection, trigger: dragging)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Rate this meal")
            .accessibilityIdentifier("starRating")
        } else {
            HStack(spacing: 3) {
                ForEach(RateMealUseCase.range, id: \.self) { score in
                    star(score)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rating")
            .accessibilityValue(rating.map { "\($0)" } ?? "not rated")
            .accessibilityIdentifier("starRating")
        }
    }

    private func score(at x: CGFloat) -> Int {
        let index = Int(x / (slot + 3)) + 1
        return min(RateMealUseCase.range.upperBound - 1, max(RateMealUseCase.range.lowerBound, index))
    }

    private func star(_ score: Int) -> some View {
        let filled = score <= (shown ?? 0)
        // Contoured like everything else the app draws: an empty star is a bold outline waiting to
        // be filled, not a faint one (ADR-005, the cartoon rule). The line stays on when the star
        // fills, so scoring a meal colours a shape in rather than swapping one shape for another.
        return FoodMark(glyph: .star)
            .fill(filled ? ink : Theme.paperRaised)
            .overlay(
                FoodMark(glyph: .star)
                    .stroke(
                        Theme.ink.opacity(filled ? 0.9 : 0.5),
                        style: StrokeStyle(lineWidth: max(1.6, size / 7), lineJoin: .round)
                    )
            )
            .frame(width: size, height: size)
            // Struck by hand, so each star sits at its own slight angle — the same angle every
            // time, because it comes from the star's position rather than from chance.
            .rotationEffect(.degrees(StampTilt.degrees(for: "star-\(score)")))
            // A filled star lands: it arrives a little large and settles.
            .scaleEffect(filled ? 1 : 0.86)
            .animation(.spring(response: 0.26, dampingFraction: 0.55), value: filled)
            .contentShape(Rectangle())
            .frame(
                // Interactive stars carry the full touch target; a read-only row does
                // not need one and should stay compact (NFR-6.1).
                minWidth: isInteractive ? slot : size,
                minHeight: isInteractive ? Theme.minimumTouchTarget : size
            )
    }
}

/// The word for a score, which is what a person would actually say about the meal. Shown while
/// rating, so the scale means something before it is committed.
struct RatingWord: View {
    let score: Int?

    var body: some View {
        if let mood = RatingMood.mood(for: score) {
            Text(Self.word(for: mood))
                .font(Theme.smallCaps(.subheadline))
                .tracking(0.9)
                .foregroundStyle(Theme.ratingInk(score))
                .transition(.opacity.combined(with: .offset(y: 4)))
                .id(mood)
        }
    }

    /// Two separate literals per case, never a ternary: a ternary of two string literals inside a
    /// `Text` resolves to `String` and silently skips translation.
    static func word(for mood: RatingMood) -> LocalizedStringKey {
        switch mood {
        case .poor: return "Not for me"
        case .fair: return "It was fine"
        case .good: return "Good"
        case .great: return "Really good"
        case .best: return "Best in town"
        }
    }
}

/// A place's average across its rated meals (FR-9.4), for list rows.
struct AverageRatingView: View {
    let average: Double
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            FoodMark(glyph: .star)
                .fill(Theme.ratingInk(Int(average.rounded())))
                .frame(width: 11, height: 11)
            Text(average.formatted(.number.precision(.fractionLength(0...1))))
                .font(Theme.label(.caption))
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Average rating")
        .accessibilityValue("\(average.formatted(.number.precision(.fractionLength(0...1)))) from \(count) rated meals")
    }
}
