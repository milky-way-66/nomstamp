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

    /// Re-read from the model so the view updates after a meal is added or removed.
    private var current: Place {
        model.place(withID: place.id) ?? place
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.regular) {
                heading
                if current.kind == .wishlist {
                    wishlistBody
                } else {
                    mealsBody
                }
            }
            .padding()
        }
        .background(Theme.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
            .foregroundStyle(current.kind == .visited ? Theme.lacquer : Theme.jade)

            if let address = current.address {
                Text(address)
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Rectangle()
                .fill(Theme.rule)
                .frame(height: 1)
                .padding(.top, Theme.Space.tight)
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.snug)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.lacquer)
            .foregroundStyle(Theme.onLacquer)
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

            ForEach(current.mealsNewestFirst) { meal in
                MealCard(
                    meal: meal,
                    onTapPhoto: { fullScreenPhoto = $0 },
                    onRate: { score in rate(meal, score) },
                    onDelete: { delete(meal) }
                )
            }

            Button {
                isLoggingMeal = true
            } label: {
                Label("Add another meal", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Theme.lacquer)
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .onTapGesture { onTapPhoto(photo) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Photograph of this meal")
        }
    }

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                if let first = meal.photos.first {
                    // The dish is the point of the card, so the first photograph fills its
                    // width at one editorial ratio. A 132 pt square left two thirds of the card
                    // empty, which read as a loading failure rather than a layout (ADR-003).
                    hero(first)
                }
                if meal.photos.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.tight) {
                            ForEach(meal.photos.dropFirst()) { photo in
                                if let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: Self.stripSide, height: Self.stripSide)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture { onTapPhoto(photo) }
                                }
                            }
                        }
                    }
                    // The strip may be one photo short of scrolling; without this it jitters
                    // against the card's inset.
                    .scrollDisabled(meal.photos.count <= 4)
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
                        StarRatingView(rating: meal.rating, onSelect: onRate, size: 14)
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
