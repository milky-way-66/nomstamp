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
            VStack(alignment: .leading, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 6) {
            Text(current.name)
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.ink)
                .lineSpacing(Theme.minimumLineSpacing)

            HStack(spacing: 6) {
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
                .padding(.top, 6)
        }
    }

    private var wishlistBody: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.lacquer)
            .foregroundStyle(Theme.onLacquer)
            .accessibilityIdentifier("iAteHereButton")
        }
    }

    private var mealsBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let note = current.note, !note.isEmpty {
                // The original recommendation survives the transition to visited (FR-8.2).
                Text("“\(note)”")
                    .font(Theme.displayItalic(.subheadline))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineSpacing(Theme.minimumLineSpacing)
            }

            ForEach(current.mealsNewestFirst) { meal in
                MealCard(meal: meal) { photo in
                    fullScreenPhoto = photo
                } onDelete: {
                    delete(meal)
                }
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
    let onDelete: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                if !meal.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meal.photos) { photo in
                                if let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 132, height: 132)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture { onTapPhoto(photo) }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let dish = meal.dishName, !dish.isEmpty {
                        Text(dish)
                            .font(Theme.display(.headline))
                            .lineSpacing(Theme.minimumLineSpacing)
                    }
                    HStack(spacing: 8) {
                        Text(meal.eatenAt.formatted(date: .abbreviated, time: .shortened))
                            .font(Theme.label(.caption))
                            .foregroundStyle(Theme.inkSecondary)
                        if let rating = meal.rating {
                            Text(String(repeating: "★", count: rating))
                                .font(Theme.label(.caption))
                                .foregroundStyle(Theme.lacquer)
                        }
                    }
                    if let note = meal.note, !note.isEmpty {
                        Text(note)
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(Theme.minimumLineSpacing)
                    }
                }
            }
            .padding(12)
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
