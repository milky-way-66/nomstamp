import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// The circle, and everything a reader can do to it.
///
/// Deliberately plain. Every interesting thing about the feature happens on the map; this page
/// exists to answer *who can see my stamps*, and to let a reader change the answer. A page that
/// tried to be a social screen would be selling a following, which is the thing ADR-008 refused
/// and ADR-009 kept refusing.
struct FriendsScreen: View {
    let dependencies: AppDependencies

    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var pendingRemoval: Friend?

    private var store: FriendsStore { dependencies.friends }

    var body: some View {
        NavigationStack {
            Group {
                if store.circle.friends.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No friends yet")
                        } icon: {
                            Image(systemName: "person.2")
                        }
                    } description: {
                        Text("You can only add someone you are sitting with. Both phones have to be in the same room.")
                    } actions: {
                        Button { isAdding = true } label: {
                            Text("Add someone here")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(dependencies.peerIdentity == nil)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.circle.friends) { friend in
                                FriendRow(
                                    friend: friend,
                                    stampCount: store.stampCount(for: friend.key)
                                )
                                .listRowBackground(Theme.paperRaised)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingRemoval = friend
                                    } label: {
                                        Text("Remove")
                                    }
                                }
                            }
                        } footer: {
                            capacityFooter
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.paper)
            .navigationTitle(Text("Friends"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Close") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        Label { Text("Add friend") } icon: { Image(systemName: "plus") }
                    }
                    .disabled(store.circle.isFull || dependencies.peerIdentity == nil)
                }
            }
            .sheet(isPresented: $isAdding) {
                AddFriendView(dependencies: dependencies)
            }
            .confirmationDialog(
                Text("Remove this friend?"),
                isPresented: Binding(
                    get: { pendingRemoval != nil },
                    set: { if !$0 { pendingRemoval = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let friend = pendingRemoval { store.remove(friend.key) }
                    pendingRemoval = nil
                } label: {
                    Text("Remove and delete their stamps")
                }
            } message: {
                // Symmetry stated plainly: removing is not a mute. It ends the exchange in both
                // directions, and what they already hold is theirs (ADR-009).
                Text("Their stamps leave your map and yours stop reaching them. Anything they already have stays on their phone.")
            }
        }
    }

    /// A full circle is an explanation, not an error — there is nothing to buy and no tier to
    /// upgrade to (FR-10.8).
    @ViewBuilder
    private var capacityFooter: some View {
        if store.circle.isFull {
            Text("Eight is the most. Remove someone to make room — the cap is what keeps this a circle rather than a following.")
        } else {
            Text("\(store.circle.count) of 8. You can only add someone you are sitting with.")
        }
    }
}

private struct FriendRow: View {
    let friend: Friend
    let stampCount: Int

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            FriendStampMark(inkSlot: friend.inkSlot, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.assignedName)
                    .font(Theme.display(.headline))
                    .foregroundStyle(Theme.ink)

                // Never "3 stamps, live". Everything of theirs is *as of* the last exchange, and
                // the interface may not imply otherwise (FR-12.6, FR-12.7).
                Group {
                    if let reached = friend.lastReachedAt {
                        Text("\(stampCount) stamps, as of \(reached.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("\(stampCount) stamps, not yet exchanged")
                    }
                }
                .font(Theme.label(.footnote))
                .foregroundStyle(Theme.inkSecondary)

                // The fingerprint is not decoration and not a daily concern: naming happens in
                // person, so there is nothing to spoof. It is here for the one reader who wants
                // to check, out loud, that the key on this phone is the key on that one.
                Text(friend.key.fingerprint)
                    .font(Theme.stamped(.caption2))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.hairline)
        .accessibilityElement(children: .combine)
    }
}
