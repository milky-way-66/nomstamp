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
    /// Ties a row's stamp to the cover it opens, so the photograph grows into the page rather than
    /// the page sliding over it.
    @Namespace private var opening
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
                if !model.isEmpty {
                    searchField
                    // Only once the sheet is up: at the peek the tabs would fill the whole fold and
                    // push every row off it, and filtering is a question the user asks while
                    // reading the list, not while looking at the map (design review, 19 Aug).
                    if !isPeeking { filterTabs }
                }
                content
            }
            .paperGround()
            // A pin tap arrives here rather than on the map, because pushing belongs to this
            // sheet's navigation stack (FR-3.10).
            .onChange(of: model.placeToOpen) { _, place in
                guard let place else { return }
                path = [place]
                model.placeToOpen = nil
            }
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place, dependencies: dependencies, model: model)
                    // A pin tap has no source in this stack, and SwiftUI falls back to the ordinary
                    // push for it — which is right: nothing on screen was zoomed from.
                    .navigationTransition(.zoom(sourceID: place.id, in: opening))
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
                case .cluster(let cluster):
                    ClusterSheet(cluster: cluster, dependencies: dependencies, model: model) { place in
                        model.action = nil
                        model.placeToOpen = place
                    }
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
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, place in
                    // A tap gesture rather than a NavigationLink or a Button: the link's disclosure
                    // chevron is the one piece of stock furniture this index cannot absorb (the row
                    // already carries its own number on that side), and a Button fires on a drag
                    // that starts on the row — which is exactly how the sheet is pulled up.
                    PlaceRowView(place: place, distance: nil, index: index)
                        .matchedTransitionSource(id: place.id, in: opening)
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(place) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    .listRowBackground(Theme.paper)
                    // The rules between entries are drawn, not stock separators, and stop short
                    // of the margins the way a printed index does.
                    .listRowSeparator(.hidden)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.rule.opacity(0.35))
                            .frame(height: Theme.hairline)
                            .padding(.horizontal, Theme.screenMargin)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            // At the peek detent the sheet's bottom edge falls in the middle of the first row and
            // sliced it clean through, which read as a rendering fault. Fading the list into the
            // page instead says "there is more here" without pretending the fold is not there.
            .mask(isPeeking ? AnyView(peekFade) : AnyView(Rectangle()))
            .overlay {
                if shown.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    /// FR-3.8 — filtering lives here rather than over the map. As a header over the
    /// cartography it cost the map a strip of its height on every screen, to answer a question
    /// the user only asks while reading the list.
    ///
    /// Drawn rather than segmented (ADR-005): see `InkTabs`.
    private var filterTabs: some View {
        InkTabs(
            tabs: [
                .init(value: MapFilter.all, title: "All"),
                .init(value: MapFilter.visited, title: "Been here"),
                .init(value: MapFilter.wishlist, title: "Want to try")
            ],
            selection: Binding(get: { model.filter }, set: { model.filter = $0 })
        )
        .padding(.horizontal, Theme.screenMargin)
        // Air under the row, so the chip never touches the first place on the list.
        .padding(.bottom, Theme.Space.snug)
        .background(Theme.paper)
    }

    /// True while the sheet is at its smallest detent.
    private var isPeeking: Bool {
        detent == .height(MapScreen.peekHeight)
    }

    /// Opaque until the last stretch, then out — long enough to dissolve a row, short enough that
    /// nothing above the fold looks washed.
    private var peekFade: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black.opacity(0.9), location: 0.35),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
                    .foregroundStyle(Theme.pandan)
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
