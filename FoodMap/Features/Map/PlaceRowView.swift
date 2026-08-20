import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// One entry in the list, set as an index of places rather than as a table row (ADR-005).
///
/// The photograph is the same stamp the map draws, framed in the same rating ink, so a row and its
/// pin are recognisably one place. The name leads in display type; everything the eye only needs
/// second — the kind, the count, the score, the street — follows in small caps beneath it.
struct PlaceRowView: View {
    let place: Place
    let distance: Double?
    /// Position in the list, printed as an index number. Nil where the list is not an index — a
    /// cluster's contents, or the near-me sheet, where distance is the ordering that matters.
    var index: Int?

    private var score: Int? { place.averageRating.map { Int($0.rounded()) } }
    /// The same press the map prints this place's pin at, so a row and its pin say the same thing
    /// about the same meal (ADR-005).
    private var press: StampPress { StampPress.press(for: score) }
    private var kindInk: Color { place.kind == .visited ? Theme.ratingInk(score) : Theme.wishlistInk }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.snug) {
            stamp

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(Theme.display(.title3))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(Theme.minimumLineSpacing)
                    .lineLimit(2)

                meta

                if let subtitle {
                    Text(subtitle)
                        .font(place.kind == .wishlist && place.note != nil
                              ? Theme.displayItalic(.footnote)
                              : Theme.label(.caption))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: Theme.Space.hairline) {
                if let index {
                    // The list as a printed index: the number is set in the stamped face, quiet
                    // enough to be furniture and useful enough to count by.
                    Text(String(format: "%02d", index + 1))
                        .font(Theme.stamped(.caption2))
                        .foregroundStyle(Theme.inkSecondary.opacity(0.6))
                }
                if let distance {
                    Text(DistanceFormatter.string(fromMeters: distance))
                        .font(Theme.label(.caption).monospacedDigit())
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.vertical, Theme.Space.tight)
    }

    /// The kind, the count and the score on one small-caps line, in the place's own ink.
    private var meta: some View {
        HStack(spacing: Theme.Space.tight) {
            HStack(spacing: 4) {
                FoodMark(glyph: place.kind == .visited ? .bowl : .ribbon)
                    .inked(1.4)
                    .frame(width: 11, height: 11)
                Text(place.kind == .visited ? LocalizedStringKey("Been here") : LocalizedStringKey("Want to try"))
                    .font(Theme.smallCaps(.caption2))
                    .tracking(0.7)
            }
            .foregroundStyle(kindInk)
            .accessibilityElement(children: .combine)

            if place.kind == .visited {
                // A plural-aware key, so Vietnamese (which does not inflect) reads naturally too.
                Text("· \(place.meals.count) meals")
                    .font(Theme.smallCaps(.caption2))
                    .tracking(0.7)
                    .foregroundStyle(Theme.inkSecondary)
                if let average = place.averageRating {
                    AverageRatingView(average: average, count: place.ratedMealCount)
                }
            }
        }
    }

    /// For a wishlist place the note is the reason it exists, so it outranks the address.
    private var subtitle: String? {
        if place.kind == .wishlist, let note = place.note, !note.isEmpty { return note }
        return place.address
    }

    private static let stampSide: CGFloat = 62

    /// The same frame the map deals this place, so a stamp is recognisably itself in both places
    /// (ADR-005, TC-N-13).
    private var shape: StampCutShape { StampCutShape(cut: StampCut.cut(for: place.id.uuidString)) }
    /// The same paper the map deals this place.
    private var paper: Color { Theme.stampPaper(StampPaper.paper(for: place.id.uuidString)) }

    @ViewBuilder
    private var stamp: some View {
        if let photo = place.pinPhoto, let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.stampSide, height: Self.stampSide)
                // The same perforated frame as the pin, in the same rating ink (ADR-005).
                // The same perforated frame as the pin, in the same rating ink and at the same
                // quality of impression (ADR-005).
                .clipShape(shape)
                .stampPressed(
                    shape,
                    press: press,
                    ink: Theme.ratingInk(score),
                    showsInk: score != nil,
                    paperRule: 2,
                    paper: paper
                )
                // Halved: the list is a set page, so its stamps are calmer than the map's — but a
                // one-star place still sits visibly more crooked than a five-star one.
                .rotationEffect(.degrees(StampTilt.degrees(for: place.id.uuidString) * press.tiltScale / 2))
        } else {
            shape
                .fill(paper)
                .frame(width: Self.stampSide, height: Self.stampSide)
                .overlay(
                    FoodMark(glyph: .ribbon)
                        .inked(1.7)
                        .foregroundStyle(Theme.wishlistInk)
                        .padding(Self.stampSide * 0.3)
                )
                .overlay(
                    shape.strokeBorder(Theme.wishlistInk.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                )
                .rotationEffect(.degrees(StampTilt.degrees(for: place.id.uuidString) * press.tiltScale / 2))
        }
    }
}
