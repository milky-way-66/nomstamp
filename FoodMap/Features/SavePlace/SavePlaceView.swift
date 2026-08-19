import SwiftUI
import FoodMapDomain

/// UC-4 — save somewhere you have only heard about.
struct SavePlaceView: View {
    let dependencies: AppDependencies
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [PlaceCandidate] = []
    @State private var selected: PlaceCandidate?
    @State private var note = ""
    @State private var tagText = ""
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Which place?") {
                    if let selected {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .font(Theme.display(.headline))
                                .lineSpacing(Theme.minimumLineSpacing)
                            if let address = selected.address {
                                Text(address)
                                    .font(Theme.label(.caption))
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        Button("Choose a different place") { self.selected = nil }
                            .font(Theme.label(.footnote))
                    } else {
                        if isSearching { ProgressView() }
                        ForEach(results) { candidate in
                            Button {
                                selected = candidate
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(Theme.display(.subheadline))
                                        .foregroundStyle(Theme.ink)
                                    if let address = candidate.address {
                                        Text(address)
                                            .font(Theme.label(.caption))
                                            .foregroundStyle(Theme.inkSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        if !searchText.isEmpty && results.isEmpty && !isSearching {
                            Text("Nothing found. Many street food places aren't listed anywhere — you can still pin it from the map later.")
                                .font(Theme.label(.footnote))
                                .foregroundStyle(Theme.inkSecondary)
                                .lineSpacing(Theme.minimumLineSpacing)
                        }
                    }
                }

                Section("Why are you saving it?") {
                    TextField("e.g. Lan said try the bún chả", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                    TextField("Tags, comma separated", text: $tagText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Save a place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name")
            .onChange(of: searchText) { _, query in
                Task { await search(query) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selected == nil)
                }
            }
            .alert("Already on your map", isPresented: .init(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK") { dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func search(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        isSearching = true
        results = (try? await dependencies.search.search(matching: query, near: nil)) ?? []
        isSearching = false
    }

    private func save() {
        guard let selected else { return }
        let tags = tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            let result = try dependencies.savePlace.execute(
                PlaceDraft(
                    candidate: selected,
                    note: note.isEmpty ? nil : note,
                    tags: tags
                )
            )
            onSaved()
            if result.wasExisting {
                // Saying so beats silently doing nothing (UC-4 / 3a).
                message = "\(result.place.name) was already saved. Your note has been kept."
            } else {
                dismiss()
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
