import SwiftUI
import FoodMapDomain

/// The bottom sheet: the app's only navigation surface. At its smallest detent it shows just
/// the two actions; pulled up it becomes the full list.
struct PlaceSheet: View {
    let dependencies: AppDependencies
    let model: MapViewModel
    let onFocus: (Place) -> Void

    @State private var searchText = ""
    @State private var isAddingMeal = false
    @State private var isSavingPlace = false
    @State private var isShowingNearMe = false

    private var shown: [Place] {
        model.allPlaces
            .filter(model.filter.matches)
            .filter { place in
                searchText.isEmpty
                    || PlaceMatcher.normalized(place.name).contains(PlaceMatcher.normalized(searchText))
                    || PlaceMatcher.normalized(place.note ?? "").contains(PlaceMatcher.normalized(searchText))
                    || place.tags.contains { PlaceMatcher.normalized($0).contains(PlaceMatcher.normalized(searchText)) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                actions
                if !model.isEmpty { searchField }
                content
            }
            .background(Theme.paper)
            .navigationBarHidden(true)
            .sheet(isPresented: $isAddingMeal) {
                AddMealView(dependencies: dependencies, preselected: nil) { model.refresh() }
            }
            .sheet(isPresented: $isSavingPlace) {
                SavePlaceView(dependencies: dependencies) { model.refresh() }
            }
            .sheet(isPresented: $isShowingNearMe) {
                NearMeView(dependencies: dependencies) { place in
                    isShowingNearMe = false
                    onFocus(place)
                }
            }
        }
    }

    /// An explicit field rather than `.searchable`: inside a sheet with a hidden navigation
    /// bar, the system search field lands on top of the first list row.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary)
            TextField("Search your places", text: $searchText)
                .accessibilityIdentifier("placeSearchField")
                .font(Theme.label(.body))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rule, lineWidth: Theme.hairline)
        )
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    /// Icons rather than labels, at the minimum touch target and no larger: this row sits on
    /// top of the map at every detent, so it has to earn its height (NFR-4.1, NFR-6.1).
    private var actions: some View {
        HStack(spacing: 10) {
            ActionButton(
                systemImage: "camera.fill",
                label: "Add meal",
                identifier: "addMealButton",
                style: .primary
            ) { isAddingMeal = true }

            ActionButton(
                systemImage: "bookmark",
                label: "Save a place",
                identifier: "savePlaceButton",
                style: .secondary
            ) { isSavingPlace = true }

            ActionButton(
                systemImage: "location.magnifyingglass",
                label: "Saved places near me",
                identifier: "nearMeButton",
                style: .secondary
            ) { isShowingNearMe = true }
            .disabled(model.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if model.isEmpty {
            emptyState
        } else {
            List {
                ForEach(shown) { place in
                    NavigationLink {
                        PlaceDetailView(place: place, dependencies: dependencies, model: model)
                    } label: {
                        PlaceRowView(place: place, distance: nil)
                    }
                    .listRowBackground(Theme.paperRaised)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .overlay {
                if shown.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    /// UC-2 / 1a — never a blank screen (NFR-4.3).
    ///
    /// In a ScrollView because the sheet's smallest detent is shorter than this content: a
    /// partly visible card that scrolls reads as more to come, where a clipped one reads as
    /// broken.
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.lacquer)
                Text("Your food map is empty")
                    .font(Theme.display(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Photograph a meal where you are, or save a place someone told you about.")
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.minimumLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
