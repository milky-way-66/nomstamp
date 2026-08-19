import SwiftUI
import FoodMapDomain

struct PlaceRowView: View {
    let place: Place
    let distance: Double?

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            thumbnail
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                Text(place.name)
                    .font(Theme.display(.headline))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(Theme.minimumLineSpacing)
                    .lineLimit(1)

                HStack(spacing: Theme.Space.tight) {
                    Image(systemName: place.kind == .visited ? "fork.knife" : "bookmark.fill")
                        .font(.caption2)
                    Text(place.kind == .visited ? LocalizedStringKey("Been here") : LocalizedStringKey("Want to try"))
                        .font(Theme.label(.caption))
                    if place.kind == .visited {
                        // A plural-aware key, so Vietnamese (which does not inflect) reads naturally too.
                        Text("· \(place.meals.count) meals")
                            .font(Theme.label(.caption))
                            .foregroundStyle(Theme.inkSecondary)
                        if let average = place.averageRating {
                            AverageRatingView(average: average, count: place.ratedMealCount)
                        }
                    }
                }
                .foregroundStyle(place.kind == .visited ? Theme.lacquer : Theme.jade)

                if let subtitle {
                    Text(subtitle)
                        .font(place.kind == .wishlist && place.note != nil
                              ? Theme.displayItalic(.caption)
                              : Theme.label(.caption))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let distance {
                Text(DistanceFormatter.string(fromMeters: distance))
                    .font(Theme.label(.caption).monospacedDigit())
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, Theme.Space.hairline)
    }

    /// For a wishlist place the note is the reason it exists, so it outranks the address.
    private var subtitle: String? {
        if place.kind == .wishlist, let note = place.note, !note.isEmpty { return note }
        return place.address
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = place.pinPhoto, let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.rule, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill((place.kind == .visited ? Theme.lacquer : Theme.jade).opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: place.kind == .visited ? "fork.knife" : "bookmark.fill")
                        .foregroundStyle(place.kind == .visited ? Theme.lacquer : Theme.jade)
                )
        }
    }
}
