import SwiftUI
import FoodMapDomain

/// UC-5 — "I am in a new city, did I save anything here?"
///
/// The payoff half of saving a recommendation, and a top-level action rather than something
/// buried in a list.
struct NearMeView: View {
    let dependencies: AppDependencies
    let onSelect: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var outcome: NearbyPlacesOutcome?
    @State private var radius: Double = 5000
    @State private var isLoading = true

    private let radiusChoices: [Double] = [1000, 5000, 20000, 100_000]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Finding you…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch outcome {
                    case .locationUnavailable, .none:
                        // Distinct from "nothing nearby" — the user must never be told they
                        // saved nothing when the truth is we cannot locate them (TC-5-04).
                        ContentUnavailableView(
                            "Can't tell where you are",
                            systemImage: "location.slash",
                            description: Text("Allow location access to see which of your saved places are nearby.")
                        )
                    case .located(let results) where results.isEmpty:
                        ContentUnavailableView(
                            "Nothing saved near here",
                            systemImage: "mappin.slash",
                            description: Text("You have no saved places within \(DistanceFormatter.string(fromMeters: radius)) of where you are.")
                        )
                    case .located(let results):
                        List(results, id: \.place.id) { entry in
                            Button {
                                onSelect(entry.place)
                            } label: {
                                PlaceRowView(place: entry.place, distance: entry.distance)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.paperRaised)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(Theme.paper)
            .safeAreaInset(edge: .top) {
                Picker("Within", selection: $radius) {
                    ForEach(radiusChoices, id: \.self) { value in
                        Text(DistanceFormatter.string(fromMeters: value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, Theme.Space.tight)
                .background(Theme.paper)
                .onChange(of: radius) { _, _ in Task { await load() } }
            }
            .navigationTitle("Near me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        outcome = try? await dependencies.findNearby.execute(radius: radius)
        isLoading = false
    }
}
