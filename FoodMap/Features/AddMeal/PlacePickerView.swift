import SwiftUI
import FoodMapDomain

/// Choosing which restaurant this is. Three paths, in the order that costs the user least:
/// places already saved, places nearby, then typing it in yourself.
///
/// The manual path is first-class, not a fallback: much Vietnamese street food is in no
/// commercial database at all (ADR-001).
struct PlacePickerView: View {
    let dependencies: AppDependencies
    let around: Coordinate?
    let onPick: (MealTarget, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saved: [PlaceDistance] = []
    @State private var nearby: [PlaceCandidate] = []
    @State private var searchResults: [PlaceCandidate] = []
    @State private var searchText = ""
    @State private var manualName = ""
    @State private var isLoading = true
    @State private var searchFailed = false

    var body: some View {
        List {
            if !searchText.isEmpty {
                Section("Search results") {
                    if searchResults.isEmpty {
                        Text("Nothing found. You can still add it by name below.")
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    ForEach(searchResults) { candidate in
                        candidateRow(candidate)
                    }
                }
            }

            if !saved.isEmpty && searchText.isEmpty {
                // Places already on the map come first, so logging a second meal at a
                // favourite never creates a duplicate pin (UC-1 / 4b).
                Section("Your places") {
                    ForEach(saved, id: \.place.id) { entry in
                        Button {
                            onPick(.existingPlace(entry.place.id), entry.place.name)
                            dismiss()
                        } label: {
                            PlaceRowView(place: entry.place, distance: entry.distance)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if searchText.isEmpty {
                Section("Nearby") {
                    if isLoading {
                        ProgressView()
                    } else if searchFailed {
                        Text("Couldn't reach the place directory. Add it by name below — your meal will still be saved.")
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.inkSecondary)
                    } else if nearby.isEmpty {
                        Text("Nothing found nearby.")
                            .font(Theme.label(.footnote))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    ForEach(nearby) { candidate in
                        candidateRow(candidate)
                    }
                }
            }

            Section("Not listed?") {
                TextField("Type the place name", text: $manualName)
                    .font(Theme.label(.body))
                Button {
                    pickManual()
                } label: {
                    Label("Use my exact spot", systemImage: "mappin.and.ellipse")
                }
                .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty || around == nil)

                if around == nil {
                    Text("Waiting for your location — you can still pick a place from search.")
                        .font(Theme.label(.caption))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .navigationTitle("Which place?")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search by name")
        .onChange(of: searchText) { _, query in
            Task { await runSearch(query) }
        }
        .task { await load() }
    }

    private func candidateRow(_ candidate: PlaceCandidate) -> some View {
        Button {
            onPick(.newPlace(PlaceDraft(candidate: candidate)), candidate.name)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(Theme.display(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(Theme.minimumLineSpacing)
                if let address = candidate.address {
                    Text(address)
                        .font(Theme.label(.caption))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func pickManual() {
        guard let around else { return }
        let name = manualName.trimmingCharacters(in: .whitespaces)
        onPick(.newPlace(PlaceDraft(name: name, coordinate: around)), name)
        dismiss()
    }

    private func load() async {
        defer { isLoading = false }
        if let around {
            saved = ((try? dependencies.places.allPlaces()) ?? [])
                .map { PlaceDistance(place: $0, distance: $0.distance(to: around)) }
                .filter { $0.distance <= 300 }
                .sorted { $0.distance < $1.distance }

            do {
                nearby = try await dependencies.search.nearbyFoodPlaces(around: around, radius: 400)
            } catch {
                // Losing the network must never cost the user a meal (FR-7.4).
                searchFailed = true
            }
        }
    }

    private func runSearch(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchResults = (try? await dependencies.search.search(matching: query, near: around)) ?? []
    }
}
