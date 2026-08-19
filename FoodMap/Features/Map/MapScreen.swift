import SwiftUI
import MapKit
import FoodMapDomain

/// The app is the map. Lists and detail arrive in a bottom sheet rather than behind a tab bar,
/// so the map is never more than a swipe away (ADR-003).
struct MapScreen: View {
    let dependencies: AppDependencies

    @State private var model: MapViewModel
    @State private var camera: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542),
            latitudinalMeters: 4000,
            longitudinalMeters: 4000
        ))
    )
    @State private var selectedPinID: PlaceCluster.ID?
    @State private var detent: PresentationDetent = .height(MapScreen.peekHeight)

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: MapViewModel(dependencies: dependencies))
    }

    var body: some View {
        ZStack(alignment: .top) {
            map
            floatingActions
        }
        .sheet(isPresented: .constant(true)) {
            PlaceSheet(
                dependencies: dependencies,
                model: model,
                onFocus: focus(on:),
                detent: $detent
            )
            // With the actions on the map, the peek detent only has to clear the drag
            // indicator and the search field whole, with its own margins: 116 on an iPhone 17.
            .presentationDetents([.height(Self.peekHeight), .fraction(0.55), .large], selection: $detent)
            // Must name a detent this sheet actually has: `.medium` is not one of them, and an
            // unmatched detent silently disables background interaction — which made the map's
            // floating buttons unreachable behind the sheet's blocking layer.
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onChange(of: selectedPinID) { _, id in
            guard let id, let cluster = model.clusters.first(where: { $0.id == id }) else { return }
            selectedPinID = nil
            select(cluster)
        }
        .task {
            dependencies.requestLocationPermission()
            model.refresh()
        }
    }

    private var map: some View {
        Map(position: $camera, selection: $selectedPinID) {
            UserAnnotation()
            ForEach(model.clusters) { cluster in
                Annotation("", coordinate: cluster.coordinate.clCoordinate, anchor: .center) {
                    StampPin(cluster: cluster)
                        .accessibilityLabel(StampPin(cluster: cluster).accessibilityDescription)
                        .accessibilityIdentifier("mapPin")
                }
                // Selection is MapKit's own, not a Button or a tap gesture on the pin: with the
                // bottom sheet presented, touches never reach content hosted inside the map, so
                // only the map's native hit testing can open a pin (FR-3.10).
                .tag(cluster.id)
            }
        }
        // The only food on this map is the user's. Apple's own restaurant pins read louder than
        // our stamps and, on an empty map, were the *only* food shown — which undercuts the whole
        // premise (ADR-005).
        // No points of interest at all. Excluding only the food categories backfired — Apple
        // filled the space with piers, hotels and schools — and every borrowed pin competes with
        // the user's own stamps, which are the only marks this map is for (ADR-005).
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        // A paper wash, so the cartography and the sheet belong to one printed object rather than
        // meeting as grey concrete against cream.
        // A printed map, not a satellite one: the wash takes the cartography's hue and leaves its
        // luminance, so streets, parks and water survive as tones of one warm ink. A cream
        // multiply was invisible at any opacity that kept the map legible.
        .overlay {
            Theme.mapWash
                // Not full strength: at 0.72 the bay and the streets became one olive tone and the
                // map stopped being readable as a place. This leaves water faintly blue.
                .opacity(0.55)
                .blendMode(.color)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .mapControls { MapCompass() }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.boundsChanged(to: MapBounds(context.region))
        }
        .ignoresSafeArea()
    }

    /// UC-1, UC-4, UC-5 — the three things you do to a map, on the map.
    ///
    /// Anchored above the sheet's peek detent. The sheet insets the map's safe area, but only
    /// partly — measured on an iPhone 17, a plain margin leaves the camera button behind the
    /// sheet, so the peek height is added explicitly. Stacked vertically so each keeps a full
    /// touch target on the narrowest iPhone.
    private var floatingActions: some View {
        VStack(spacing: Theme.Space.snug) {
            Spacer(minLength: 0)

            // Hidden, not disabled: on an empty map a ghosted button read as a rendering fault
            // rather than as "nothing saved yet" (design review, 19 Aug).
            if !model.isEmpty {
                FloatingActionButton(
                    systemImage: "location.magnifyingglass",
                    label: "Saved places near me",
                    identifier: "nearMeButton"
                ) { model.action = .nearMe }
            }

            FloatingActionButton(
                systemImage: "bookmark",
                label: "Save a place",
                identifier: "savePlaceButton"
            ) { model.action = .savePlace }

            FloatingActionButton(
                systemImage: "camera.fill",
                label: "Add meal",
                identifier: "addMealButton",
                style: .primary
            ) { model.action = .addMeal }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, Theme.screenMargin)
        .padding(.bottom, Self.peekHeight + Theme.screenMargin)
        .ignoresSafeArea(.keyboard)
    }

    /// The sheet's smallest detent, in points. Shared with `floatingActions` so the buttons
    /// sit just above it by construction rather than by a guessed constant.
    static let peekHeight: CGFloat = 116

    /// A pin is a way into its place, not decoration (FR-3.10). A cluster has to be resolved to
    /// one place first, so it lists what is inside it.
    private func select(_ cluster: PlaceCluster) {
        if cluster.isSingle, let place = cluster.representative {
            model.placeToOpen = place
        } else {
            model.action = .cluster(cluster)
        }
    }

    /// Centres the map on a place, biased upwards.
    ///
    /// The sheet covers the lower half of the screen, so a pin at the geometric centre of the
    /// map is a pin behind the sheet. Shifting the region's centre south of the place lifts the
    /// pin into the visible band above it (FR-4.6).
    private func focus(on place: Place) {
        let span: CLLocationDistance = 600
        // A degree of latitude is ~111 km everywhere, which is close enough for a nudge.
        let metresPerDegree: CLLocationDistance = 111_000
        let shift = span * Self.sheetBias / metresPerDegree

        withAnimation(.easeOut(duration: 0.3)) {
            camera = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: place.coordinate.latitude - shift,
                    longitude: place.coordinate.longitude
                ),
                latitudinalMeters: span,
                longitudinalMeters: span
            ))
        }
    }

    /// How far up the screen a focused pin should sit, as a fraction of the visible span.
    /// 0.3 puts it a little above centre, clear of the sheet at its reading detent.
    private static let sheetBias: Double = 0.3
}

/// Tapping a cluster lists what is inside it rather than guessing which pin was meant.
struct ClusterSheet: View {
    let cluster: PlaceCluster
    let dependencies: AppDependencies
    let model: MapViewModel
    let onOpen: (Place) -> Void

    var body: some View {
        NavigationStack {
            List(cluster.places) { place in
                Button {
                    onOpen(place)
                } label: {
                    PlaceRowView(place: place, distance: nil)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.paperRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("\(cluster.count) places here")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
