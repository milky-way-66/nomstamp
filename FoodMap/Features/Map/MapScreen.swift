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

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: MapViewModel(dependencies: dependencies))
    }

    var body: some View {
        ZStack(alignment: .top) {
            map
            header
        }
        .sheet(isPresented: .constant(true)) {
            PlaceSheet(
                dependencies: dependencies,
                model: model,
                onFocus: focus(on:)
            )
             // The peek detent shows the actions and the search field whole; anything smaller
            // clips a list row mid-way and reads as broken.
            .presentationDetents([.height(156), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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

    private var header: some View {
        VStack(spacing: 8) {
            Text("Food Map")
                .font(Theme.display(.title3))
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.rule, lineWidth: Theme.hairline)
        )
        .padding(.horizontal)
        .padding(.top, 4)
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
