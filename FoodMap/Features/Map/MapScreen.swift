import SwiftUI
import MapKit
import FoodMapDomain

/// The app is the map. Lists and detail arrive in a bottom sheet rather than behind a tab bar,
/// so the map is never more than a swipe away (ADR-003).
struct MapScreen: View {
    /// What the sky is doing where the reader is, set at the root (ADR-006).
    @Environment(\.skyEffect) private var skyEffect
    /// Day or night: the map is re-inked differently in each, see `map`.
    @Environment(\.colorScheme) private var scheme

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
    /// Bumped on every camera frame so the wash's mask keeps up with the pins as the map moves.
    @State private var cameraTick: UInt64 = 0

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
            select(cluster)
            // Cleared a beat later, not at once: the stamp's lift is the answer to the tap, and
            // clearing the selection in the same frame swallows it.
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                if selectedPinID == id { selectedPinID = nil }
            }
        }
        .task {
            dependencies.requestLocationPermission()
            model.refresh()
        }
    }

    private var map: some View {
        // The reader is here for the wash's mask, not for the map: it is the only way to ask where
        // a coordinate has landed on screen, and the wash has to know that to stay off the stamps.
        MapReader { proxy in
            mapBody(proxy)
        }
    }

    private func mapBody(_ proxy: MapProxy) -> some View {
        Map(position: $camera, selection: $selectedPinID) {
            UserAnnotation()
            ForEach(model.clusters) { cluster in
                Annotation("", coordinate: cluster.coordinate.clCoordinate, anchor: .center) {
                    StampPin(cluster: cluster, isSelected: selectedPinID == cluster.id)
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
        // The cartography is re-inked, not covered. The wash lends its own hue and saturation and
        // leaves the map's luminance alone, so no strength of it can make the day map darker than
        // Apple's — it only decides what colour the light comes out.
        //
        // That distinction is the whole fix for how this used to read. The old wash was a dark,
        // desaturated teal, and mixing it into a cream-and-white day map pulled block, park and
        // street towards one cool grey: the brightness survived, but the colour differences did
        // not, and a city with no colour differences left reads as a city with a sheet over it.
        .overlay {
            Theme.mapWash
                // Night keeps the gentler mix: the dark cartography is nearly monochrome already,
                // so it takes far less ink before the bay and the streets are one tone.
                .opacity(scheme == .dark ? 0.45 : 0.85)
                .blendMode(.color)
                .mask(washMask(proxy))
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        // Day only: the punch, and the reason the map has more contrast than Apple's rather than
        // less. Apple's day map sits almost entirely above the midtone, so every blend that keys
        // off 50% grey — `.overlay`, `.softLight` — can only screen it, and a `.multiply` scales
        // the whole range down together; all three spend contrast. A burn darkens in proportion to
        // how dark a thing already is, so the river, the park edges and the arterials drop away
        // from the blocks instead of towards them, and the streets stay paper-white. It saturates
        // as it goes, which is the second half of what it is for.
        .overlay {
            if scheme != .dark {
                Theme.mapWash
                    // Measured against Apple's own cartography, and this is where the numbers turn
                    // in our favour: from 0.18 the map holds more tonal spread than it started
                    // with, at nearly the brightness it started with. Past about 0.3 the blocks
                    // start to fill in and the small parks are lost inside them.
                    .opacity(0.18)
                    .blendMode(.colorBurn)
                    .mask(washMask(proxy))
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        // The weather, printed over the cartography and nowhere else (ADR-006).
        .overlay {
            SkyEffectLayer(effect: skyEffect)
                .ignoresSafeArea()
        }
        .mapControls { MapCompass() }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.boundsChanged(to: MapBounds(context.region))
        }
        // The mask has to follow the pins while the map is being dragged, which the end-of-gesture
        // callback above is far too late for. Only a counter changes, so the map itself is not
        // rebuilt — the mask is.
        .onMapCameraChange(frequency: .continuous) { _ in
            cameraTick &+= 1
        }
        .ignoresSafeArea()
    }

    /// The wash, everywhere except the stamps.
    ///
    /// ADR-005 rule 1: a wash goes over the cartography and never over a photograph. The wash is a
    /// SwiftUI overlay and the pins are content the map hosts underneath it, so without this the
    /// ink lands on the food as well as on the streets — and at the strength the day map is printed
    /// at, that turned every meal the colour of the skin. The mask punches each stamp back out.
    ///
    /// The holes are soft-edged and only just larger than the stamp. A hard rectangle of unwashed
    /// cartography read as a card slipped under the pin — the eye found the patch before it found
    /// the photograph. Blurred, the ink simply fades out as it reaches the stamp, which is what a
    /// wash does around something laid on top of it. The blur doubles as slack for the tilt and for
    /// the frame or two the mask can lag behind MapKit's own annotation layer mid-drag.
    private func washMask(_ proxy: MapProxy) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .destinationOut

            for cluster in model.clusters {
                guard let point = proxy.convert(cluster.coordinate.clCoordinate, to: .local) else { continue }
                let side = Theme.pinSize * (selectedPinID == cluster.id ? 1.24 : 1.0)
                let hole = CGRect(
                    x: point.x - side / 2,
                    y: point.y - side / 2,
                    width: side,
                    height: side
                )
                context.fill(Path(roundedRect: hole, cornerRadius: side * 0.22), with: .color(.black))
            }
        }
        .blur(radius: 7)
        // Nothing here is information; it exists so the photographs keep their own colour.
        .accessibilityHidden(true)
        // Redrawn as the camera moves: `Canvas` would otherwise keep the holes where the pins were
        // when the view was built.
        .id(cameraTick)
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
                    glyph: .needle,
                    label: "Saved places near me",
                    identifier: "nearMeButton"
                ) { model.action = .nearMe }
            }

            FloatingActionButton(
                glyph: .ribbon,
                label: "Save a place",
                identifier: "savePlaceButton"
            ) { model.action = .savePlace }

            FloatingActionButton(
                glyph: .camera,
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

