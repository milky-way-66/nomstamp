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
    @State private var selectedCluster: PlaceCluster?
    @State private var detent: PresentationDetent = .height(MapScreen.peekHeight)

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: MapViewModel(dependencies: dependencies))
    }

    var body: some View {
        ZStack(alignment: .top) {
            map
            header
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
            // indicator and the search field whole: 104 measured on an iPhone 17.
            .presentationDetents([.height(Self.peekHeight), .fraction(0.55), .large], selection: $detent)
            // Must name a detent this sheet actually has: `.medium` is not one of them, and an
            // unmatched detent silently disables background interaction — which made the map's
            // floating buttons unreachable behind the sheet's blocking layer.
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(item: $selectedCluster) { cluster in
            ClusterSheet(cluster: cluster, dependencies: dependencies, model: model)
        }
        .task {
            dependencies.requestLocationPermission()
            model.refresh()
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(model.clusters) { cluster in
                Annotation("", coordinate: cluster.coordinate.clCoordinate, anchor: .center) {
                    StampPin(cluster: cluster)
                        .onTapGesture { select(cluster) }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .including([.restaurant, .cafe, .bakery])))
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

            FloatingActionButton(
                systemImage: "location.magnifyingglass",
                label: "Saved places near me",
                identifier: "nearMeButton"
            ) { model.action = .nearMe }
                .disabled(model.isEmpty)

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
    static let peekHeight: CGFloat = 104

    private var header: some View {
        VStack(spacing: Theme.Space.tight) {
            Text("Food Map")
                .font(Theme.display(.headline))
                .foregroundStyle(Theme.ink)

            if !model.isEmpty {
                Picker("Show", selection: Binding(
                    get: { model.filter },
                    set: { model.filter = $0 }
                )) {
                    Text("All").tag(MapFilter.all)
                    Text("Been here").tag(MapFilter.visited)
                    Text("Want to try").tag(MapFilter.wishlist)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
        }
        .padding(.horizontal, Theme.screenMargin)
        .padding(.vertical, Theme.Space.tight)
        .background(Theme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
        )
        .padding(.horizontal, Theme.screenMargin)
        .padding(.top, Theme.Space.hairline)
    }

    private func select(_ cluster: PlaceCluster) {
        if cluster.isSingle, let place = cluster.representative {
            focus(on: place)
        } else {
            selectedCluster = cluster
        }
    }

    private func focus(on place: Place) {
        withAnimation(.easeOut(duration: 0.25)) {
            camera = .region(MKCoordinateRegion(
                center: place.coordinate.clCoordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        }
    }
}

/// Tapping a cluster lists what is inside it rather than guessing which pin was meant.
private struct ClusterSheet: View {
    let cluster: PlaceCluster
    let dependencies: AppDependencies
    let model: MapViewModel

    var body: some View {
        NavigationStack {
            List(cluster.places) { place in
                NavigationLink {
                    PlaceDetailView(place: place, dependencies: dependencies, model: model)
                } label: {
                    PlaceRowView(place: place, distance: nil)
                }
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
