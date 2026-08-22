import SwiftUI
import MapKit
import FoodMapDomain
import FoodMapData

/// UC-3 — everything eaten at one place, newest first. For a place not yet visited, the note
/// explaining why it was saved takes that space instead (UC-3 / 2a).
struct PlaceDetailView: View {
    let place: Place
    let dependencies: AppDependencies
    let model: MapViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isLoggingMeal = false
    @State private var fullScreenPhoto: Photo?
    @State private var confirmingDelete = false
    /// The page's own title, once the cover has scrolled away.
    @State private var isTitleStuck = false

    /// The place's own ink: how it scored, averaged over its rated meals. Everything the page
    /// rules and marks with follows it, so a five-star place reads differently from a two (ADR-005).
    private var placeInk: Color {
        guard let average = current.averageRating else { return Theme.visitedInk }
        return Theme.ratingInk(Int(average.rounded()))
    }

    /// Re-read from the model so the view updates after a meal is added or removed.
    private var current: Place {
        model.place(withID: place.id) ?? place
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.regular) {
                // Outside the padding: the cover is the width of the page, torn in rather than
                // cropped into a card (ADR-005).
                cover
                VStack(alignment: .leading, spacing: Theme.Space.regular) {
                    heading
                    alsoStampedBy
                    if current.kind == .wishlist {
                        wishlistBody
                    } else {
                        mealsBody
                    }
                    sharing
                }
                .padding()
            }
        }
        .paperGround()
        // Once the name has scrolled off the page it comes back in the bar, so the reader never
        // loses track of which place they are in (design review, 19 Aug).
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 140
        } action: { _, isPast in
            withAnimation(.easeOut(duration: 0.2)) { isTitleStuck = isPast }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // The navigation bar stays the system's. A drawn token was tried here and the bar wrapped
        // it in its own glass capsule, so the paper disc read as a grey blob inside a pill — worse
        // than the stock control it replaced (design note, 20 August).
        .toolbar {
            ToolbarItem(placement: .principal) {
                if isTitleStuck {
                    Text(current.name)
                        .font(Theme.display(.headline))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        openDirections()
                    } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete place", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete \(current.name)?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete place and its meals", role: .destructive) { deletePlace() }
        } message: {
            Text("This also deletes the photos you took there. It can't be undone.")
        }
        .sheet(isPresented: $isLoggingMeal) {
            AddMealView(dependencies: dependencies, preselected: current) {
                model.refresh()
            }
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            PhotoFullScreenView(photo: photo)
        }
    }

    /// The newest photograph of the newest meal: the page opens on the food, not on a header.
    ///
    /// A place with nothing photographed yet gets no cover — a placeholder rectangle would be a
    /// promise the page cannot keep.
    @ViewBuilder
    private var cover: some View {
        if let photo = current.mealsNewestFirst.first?.photos.first,
           let image = PhotoImageLoader.shared.fullImage(named: photo.filename)
            ?? PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
            Color.clear
                .aspectRatio(Theme.photoAspect, contentMode: .fit)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
                // Torn along the bottom, so the paper below is the same sheet the picture is on.
                .clipShape(TornBottom())
                .photoGlow(16)
                .contentShape(Rectangle())
                .onTapGesture { fullScreenPhoto = photo }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Photograph of this meal")
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Theme.Space.hairline) {
            Text(current.name)
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.ink)
                .lineSpacing(Theme.minimumLineSpacing)

            HStack(spacing: Theme.Space.tight) {
                Image(systemName: current.kind == .visited ? "fork.knife" : "bookmark.fill")
                Text(current.kind == .visited ? LocalizedStringKey("Been here") : LocalizedStringKey("Want to try"))
            }
            .accessibilityIdentifier("placeKindLabel")
            .font(Theme.label(.subheadline))
            .foregroundStyle(current.kind == .visited ? placeInk : Theme.wishlistInk)

            if let address = current.address {
                Text(address)
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSecondary)
            }

            HStack(spacing: Theme.Space.tight) {
                // A rated place rules its page in its own ink, and says the word out loud.
                if let average = current.averageRating {
                    RatingWord(score: Int(average.rounded()))
                    Rectangle()
                        .fill(placeInk.opacity(0.5))
                        .frame(height: 2)
                } else {
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: 1)
                }
            }
            .padding(.top, Theme.Space.tight)
        }
    }

    /// *We have both been here* — the reason the feature exists, said on the page for the place
    /// it happened at (FR-12.8).
    ///
    /// Shown whether or not the map layer is on. The switch governs the drawing; a page the
    /// reader opened deliberately is a different question, and hiding a countersign here would
    /// mean the one moment the feature is for stayed invisible to anyone who prefers a quiet map.
    @ViewBuilder
    private var alsoStampedBy: some View {
        let stamps = dependencies.friends.alsoStamped(current)
        if !stamps.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("Also stamped by")
                    .font(Theme.smallCaps())
                    .foregroundStyle(Theme.inkSecondary)
                FlowingChips(stamps: stamps, store: dependencies.friends)
            }
            .accessibilityIdentifier("alsoStampedBy")
        }
    }

    /// Place projections are shared automatically after a friend is connected; notes remain a
    /// separate opt-in because they are personal writing (FR-11.1, FR-11.4).
    @ViewBuilder
    private var sharing: some View {
        if !dependencies.friends.circle.friends.isEmpty, let note = current.note, !note.isEmpty {
            let store = dependencies.friends
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("Your place details are shared automatically with connected friends. Photos, prices and exact dates stay private.")
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSecondary)

                Toggle(isOn: Binding(
                    get: { store.sharesNote(for: current) },
                    set: { store.setSharesNote($0, for: current) }
                )) {
                    Text("Include my note")
                }
                .accessibilityIdentifier("shareNoteToggle")
                Text(note)
                    .font(Theme.displayItalic(.footnote))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.top, Theme.Space.loose)
        }
    }

    private var wishlistBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if let note = current.note, !note.isEmpty {
                PaperCard {
                    Text("“\(note)”")
                        .font(Theme.displayItalic(.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(Theme.minimumLineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }

            if !current.tags.isEmpty {
                Text(current.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(Theme.label(.caption))
                    .foregroundStyle(Theme.inkSecondary)
            }

            // One tap from "want to try" to "been here" (UC-6).
            Button {
                isLoggingMeal = true
            } label: {
                Label("I ate here", systemImage: "camera.fill")
            }
            // Drawn, not stock: a bordered iOS button here was the one thing on the page nobody
            // had drawn (ADR-005, the cartoon rule).
            .buttonStyle(CartoonButtonStyle(kind: .primary))
            .accessibilityIdentifier("iAteHereButton")
        }
    }

    private var mealsBody: some View {
        VStack(alignment: .leading, spacing: Theme.Space.regular) {
            if let note = current.note, !note.isEmpty {
                // The original recommendation survives the transition to visited (FR-8.2).
                Text("“\(note)”")
                    .font(Theme.displayItalic(.subheadline))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineSpacing(Theme.minimumLineSpacing)
            }

            ForEach(Array(current.mealsNewestFirst.enumerated()), id: \.element.id) { index, meal in
                MealCard(
                    meal: meal,
                    // The newest meal's first photograph is already the page's cover; showing it
                    // again immediately below it read as a duplicate upload.
                    showsHero: index > 0,
                    onTapPhoto: { fullScreenPhoto = $0 },
                    onRate: { score in rate(meal, score) },
                    onDelete: { delete(meal) }
                )
            }

            Button {
                isLoggingMeal = true
            } label: {
                Label("Add another meal", systemImage: "plus")
            }
            .buttonStyle(CartoonButtonStyle(kind: .secondary, tilt: 0.6))
        }
    }

    /// UC-7 — score a meal already logged, without leaving this screen.
    private func rate(_ meal: Meal, _ score: Int) {
        do {
            try dependencies.rateMeal.execute(placeID: current.id, mealID: meal.id, score: score)
            model.refresh()
        } catch {
            // A rating is not worth an alert: log nothing, change nothing, keep the screen calm.
        }
    }

    private func delete(_ meal: Meal) {
        _ = try? dependencies.deleteMeal.execute(placeID: current.id, mealID: meal.id)
        model.refresh()
    }

    private func deletePlace() {
        try? dependencies.deletePlace.execute(placeID: current.id)
        model.refresh()
        dismiss()
    }

    private func openDirections() {
        // Coordinate handling lives in FoodMapData where it is unit-tested (TC-3-06).
        PlaceMapItemFactory.openInMaps(current)
    }
}

private struct MealCard: View {
    let meal: Meal
    var showsHero: Bool = true
    let onTapPhoto: (Photo) -> Void
    let onRate: (Int) -> Void
    let onDelete: () -> Void

    static let stripSide: CGFloat = 76

    /// The hero comes from the full-size file, not the 240 px square thumbnail: at this width a
    /// thumbnail is upscaled fourfold, which is the blur the square layout used to hide.
    @ViewBuilder
    private func hero(_ photo: Photo) -> some View {
        if let image = PhotoImageLoader.shared.fullImage(named: photo.filename)
            ?? PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
            // Ratio on a clear container, image filling it: setting both a frame and an aspect
            // ratio on the image itself makes the two rules fight, and the loser is the crop.
            Color.clear
                .aspectRatio(Theme.photoAspect, contentMode: .fit)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                // A photograph is an object on the page too, so it carries the contour every
                // other object does — and no glow, which was the page's last soft edge.
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.65), lineWidth: Theme.contour)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .onTapGesture { onTapPhoto(photo) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Photograph of this meal")
        }
    }

    private var mealInk: Color { Theme.ratingInk(meal.rating) }

    var body: some View {
        PaperCard(edge: meal.rating == nil ? nil : mealInk) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                if showsHero, let first = meal.photos.first {
                    // The dish is the point of the card, so the first photograph fills its
                    // width at one editorial ratio. A 132 pt square left two thirds of the card
                    // empty, which read as a loading failure rather than a layout (ADR-003).
                    hero(first)
                }
                if meal.photos.count > (showsHero ? 1 : 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.tight) {
                            ForEach(showsHero ? Array(meal.photos.dropFirst()) : meal.photos) { photo in
                                if let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: Self.stripSide, height: Self.stripSide)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Theme.ink.opacity(0.65), lineWidth: Theme.contour)
                                        )
                                        .contentShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture { onTapPhoto(photo) }
                                }
                            }
                        }
                    }
                    // The strip may be one photo short of scrolling; without this it jitters
                    // against the card's inset.
                    .scrollDisabled(meal.photos.count <= (showsHero ? 5 : 4))
                }

                VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                    if let dish = meal.dishName, !dish.isEmpty {
                        Text(dish)
                            .font(Theme.display(.headline))
                            .lineSpacing(Theme.minimumLineSpacing)
                    }
                    HStack(spacing: Theme.Space.tight) {
                        Text(meal.eatenAt.formatted(date: .abbreviated, time: .shortened))
                            .font(Theme.label(.caption))
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer(minLength: 0)
                        // Tapping a star here is the edit — there is no rating screen (FR-9.5).
                        StarRatingView(rating: meal.rating, onSelect: onRate, size: 16)
                    }
                    if let note = meal.note, !note.isEmpty {
                        Text(note)
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(Theme.minimumLineSpacing)
                    }
                }
            }
            .padding(Theme.contentInset)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete this meal", systemImage: "trash")
            }
        }
    }
}

private struct PhotoFullScreenView: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = PhotoImageLoader.shared.fullImage(named: photo.filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
