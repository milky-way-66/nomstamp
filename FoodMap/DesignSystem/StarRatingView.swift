import SwiftUI
import FoodMapDomain

/// UC-7 — a meal's score, shown and set in the same control.
///
/// There is no rating screen: tapping a star here *is* the edit (FR-9.5), and tapping the star
/// a meal already has clears it, which is the only way to undo a mistaken score.
struct StarRatingView: View {
    let rating: Int?
    /// Nil for a read-only display, as on a place row.
    var onSelect: ((Int) -> Void)?
    var size: CGFloat = 15

    private var isInteractive: Bool { onSelect != nil }

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

    private func star(_ score: Int) -> some View {
        let filled = score <= (rating ?? 0)
        return Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: size))
            .foregroundStyle(filled ? Theme.lacquer : Theme.inkSecondary)
            .contentShape(Rectangle())
            .frame(
                // Interactive stars carry the full touch target; a read-only row does
                // not need one and should stay compact (NFR-6.1).
                minWidth: isInteractive ? Theme.minimumTouchTarget / 1.6 : size,
                minHeight: isInteractive ? Theme.minimumTouchTarget : size
            )
    }
}

/// A place's average across its rated meals (FR-9.4), for list rows.
struct AverageRatingView: View {
    let average: Double
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.lacquer)
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
