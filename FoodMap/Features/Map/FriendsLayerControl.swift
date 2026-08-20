import SwiftUI
import FoodMapDomain

/// The layer switch, drawn as the thing it switches on: a row of the actual inks.
///
/// It is a strip of perforated stamps rather than a toggle and a list, because the row *is* the
/// legend. A reader who has forgotten which ink is Minh's does not open a settings page; they
/// look at the top of the map, where his stamp is sitting next to his name (ADR-009).
///
/// Off by default, and while it is off the map is exactly what it was before the feature existed
/// (FR-12.1).
struct FriendsLayerControl: View {
    let store: FriendsStore
    let onOpenFriends: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.tight) {
            Button {
                // With nobody in the circle there is no layer to switch on, so the same button
                // is the way in rather than a control that visibly does nothing.
                guard !store.circle.friends.isEmpty else { return onOpenFriends() }
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.layerEnabled.toggle()
                    if store.layerEnabled { store.markLooked() }
                }
            } label: {
                Image(systemName: store.layerEnabled ? "person.2.fill" : "person.2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.layerEnabled ? Theme.onAccent : Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(store.layerEnabled ? Theme.visitedInk : Color.clear)
                    )
            }
            .accessibilityLabel(Text("Friends layer"))
            .accessibilityValue(store.layerEnabled ? Text("On") : Text("Off"))
            .accessibilityHint(store.circle.friends.isEmpty ? Text("Add friend") : Text("Friends layer"))
            .accessibilityIdentifier("friendsLayerToggle")

            if store.layerEnabled {
                ForEach(store.circle.friends) { friend in
                    Button {
                        if store.hiddenFriends.contains(friend.key) {
                            store.hiddenFriends.remove(friend.key)
                        } else {
                            store.hiddenFriends.insert(friend.key)
                        }
                    } label: {
                        FriendStampMark(inkSlot: friend.inkSlot, size: 24)
                            // Hidden is drawn as *unprinted*, not as greyed out: the stamp is
                            // still there, the ink simply has not been laid down.
                            .opacity(store.hiddenFriends.contains(friend.key) ? 0.22 : 1)
                    }
                    .accessibilityLabel(Text(friend.assignedName))
                    .accessibilityValue(
                        store.hiddenFriends.contains(friend.key) ? Text("Hidden") : Text("Showing")
                    )
                }

                Button(action: onOpenFriends) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(Text("Friends"))
            }
        }
        .padding(.horizontal, Theme.Space.tight)
        .padding(.vertical, Theme.Space.hairline + 2)
        .background(
            Capsule().fill(Theme.paperRaised)
        )
        .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.contour))
        .background(Capsule().fill(Theme.ink.opacity(0.7)).offset(y: 2))
    }
}

/// A pin that exists only because a friend put it there — somewhere the reader has never been.
///
/// Drawn smaller than the reader's own stamps and with no photograph. It is a place a friend
/// liked, not a memory of a meal, and the drawing should not pretend otherwise.
struct FriendOnlyPin: View {
    let group: MapStampGroup
    let store: FriendsStore

    private var inkSlot: Int {
        group.countersign.flatMap { store.friend(for: $0.friend)?.inkSlot } ?? 0
    }

    private var freshness: Double {
        group.countersign.map(store.freshness(of:)) ?? 0
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FriendStampMark(inkSlot: inkSlot, size: 30, freshness: freshness)
            if group.additionalSignatureCount > 0 {
                numeral(group.additionalSignatureCount)
            }
        }
        .frame(minWidth: Theme.minimumTouchTarget, minHeight: Theme.minimumTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(group.name))
        .accessibilityIdentifier("friendPin")
    }
}

/// The countersign printed on the reader's own stamp: *we have both been here*.
///
/// One friend's mark and a numeral for the rest, never a fan of five overlapping stamps — which
/// at pin size is the box of crayons the cap exists to prevent (FR-12.2, TC-10-06).
struct CountersignBadge: View {
    let group: MapStampGroup
    let store: FriendsStore

    var body: some View {
        if let countersign = group.countersign,
           let friend = store.friend(for: countersign.friend) {
            HStack(spacing: -6) {
                FriendStampMark(
                    inkSlot: friend.inkSlot,
                    size: 20,
                    freshness: store.freshness(of: countersign)
                )
                if group.additionalSignatureCount > 0 {
                    numeral(group.additionalSignatureCount)
                }
            }
            .offset(x: -4, y: 6)
        }
    }
}

@ViewBuilder
private func numeral(_ count: Int) -> some View {
    Text(verbatim: "+\(count)")
        .font(Theme.stamped(.caption2).bold())
        .foregroundStyle(Theme.paperRaised)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Capsule().fill(Theme.ink))
}
