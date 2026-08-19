import SwiftUI
import FoodMapDomain

/// The bottom sheet: the app's only navigation surface. At its smallest detent it shows the
/// search field alone; pulled up it becomes the full list. The actions live on the map itself
/// (`MapScreen`), so this sheet never has to be tall enough to hold a row of buttons.
struct PlaceSheet: View {
    let dependencies: AppDependencies
    let model: MapViewModel
    let onFocus: (Place) -> Void
    @Binding var detent: PresentationDetent

    @State private var path: [Place] = []
    @State private var searchText = ""

    /// Tall enough to read a place, short enough to leave its pin on screen.
    private static let readingDetent: PresentationDetent = .fraction(0.55)

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
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if !model.isEmpty { searchField }
                content
            }
            .background(Theme.paper)
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place, dependencies: dependencies, model: model)
            }
            // Opening a place moves the map to its pin and lifts the sheet to the middle
            // detent — not to full height, because the whole point is to see the pin the map
            // just centred on (FR-4.6). Going back returns the sheet to its peek and leaves the
            // map where the place put it.
            .onChange(of: path) { _, stack in
                if let place = stack.last {
                    onFocus(place)
                }
                withAnimation {
                    detent = stack.isEmpty ? .height(MapScreen.peekHeight) : Self.readingDetent
                }
            }
            .navigationBarHidden(true)
            // The map's floating buttons set `model.action`; the presentation happens here,
            // because the map is already presenting this sheet and cannot present another.
            .sheet(item: Binding(get: { model.action }, set: { model.action = $0 })) { action in
                switch action {
                case .addMeal:
                    AddMealView(dependencies: dependencies, preselected: nil) { model.refresh() }
                case .savePlace:
                    SavePlaceView(dependencies: dependencies) { model.refresh() }
                case .nearMe:
                    NearMeView(dependencies: dependencies) { place in
                        model.action = nil
                        onFocus(place)
                    }
                }
            }
        }
    }

    /// An explicit field rather than `.searchable`: inside a sheet with a hidden navigation
    /// bar, the system search field lands on top of the first list row.
    private var searchField: some View {
        HStack(spacing: Theme.Space.tight) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
            TextField("Search your places", text: $searchText)
                .accessibilityIdentifier("placeSearchField")
                .font(Theme.label(.body))
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        // Inner padding matches the screen margin, so the glyph sits as far from the capsule's
        // edge as the capsule sits from the screen's.
        .padding(.horizontal, Theme.screenMargin)
        .frame(height: Theme.minimumTouchTarget)
        .background(Theme.paperRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: Theme.hairline))
        .padding(.horizontal, Theme.screenMargin)
        // Clear of the drag indicator above and the first row below, rather than crowding both.
        .padding(.top, Theme.Space.regular)
        .padding(.bottom, Theme.Space.snug)
    }

    @ViewBuilder
    private var content: some View {
        if model.isEmpty {
            emptyState
        } else {
            List {
                ForEach(shown) { place in
                    NavigationLink(value: place) {
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
            VStack(spacing: Theme.Space.snug) {
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
            .padding(.horizontal, Theme.Space.loose)
            .padding(.vertical, Theme.Space.loose)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
