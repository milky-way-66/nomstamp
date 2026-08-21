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
                // Names made every entry roughly four times wider, and eight of them cannot fit
                // across a phone in one row at any readable size. `ViewThatFits` keeps the strip
                // hugging its contents while they fit — two or three friends look exactly as they
                // did before names arrived — and falls back to a scrolling row when the circle
                // outgrows the screen (FR-12.9, TC-10-23).
                //
                // Measuring the row and capping the scroll view to it was tried instead, and is a
                // trap: the measurement comes from inside the container whose width the
                // measurement sets, and the loop settles with every name squeezed to nothing.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Space.tight) { legend }
                    ScrollView(.horizontal) {
                        HStack(spacing: Theme.Space.tight) { legend }
                    }
                    .scrollIndicators(.hidden)
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
        // The capsule floats over the map, so nothing else would stop it growing past the edge.
        .padding(.horizontal, Theme.screenMargin)
        // And this is what gives `ViewThatFits` above a real width to fit *into*. Without it the
        // strip is proposed an unbounded width, every candidate "fits", and the first one — the
        // non-scrolling row — wins however wide it has become.
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var legend: some View {
        ForEach(store.circle.friends) { friend in
            FriendLegendChip(friend: friend, store: store)
        }
    }
}

/// One friend in the legend: their stamp, their name, and the two ways to filter by them.
///
/// Its own view rather than a closure inside the strip, because the strip is already a switch, a
/// row and an overflow button, and SwiftUI's type checker gives up on the lot in one expression.
private struct FriendLegendChip: View {
    let friend: Friend
    let store: FriendsStore

    private var isHidden: Bool { store.isHidden(friend.key) }

    var body: some View {
        HStack(spacing: 3) {
            FriendStampMark(inkSlot: friend.inkSlot, size: 24)
            // The name, drawn and not merely announced. This strip is the only place the
            // ink-to-person mapping is taught, and eight unlabelled colours teach nothing
            // (FR-12.9).
            Text(friend.assignedName)
                .font(Theme.label(.caption))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                // A long name must not push the other friends off the strip; the stamp beside it
                // stays the anchor either way.
                .frame(maxWidth: 68, alignment: .leading)
        }
        // Hidden is drawn as *unprinted*, not as greyed out: the stamp is still there, the ink
        // simply has not been laid down.
        .opacity(isHidden ? 0.22 : 1)
        .contentShape(Rectangle())
        // Two gestures on a plain view rather than a Button with a press modifier bolted on. A
        // Button keeps its own tap whatever else is attached, so a long press arrived as *both*
        // an isolate and a hide, and the second undid the first — the entry could be isolated but
        // never restored.
        .onLongPressGesture {
            withAnimation(.easeInOut(duration: 0.2)) { store.toggleIsolation(friend.key) }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { store.toggleHidden(friend.key) }
        }
        // Gestures are invisible to assistive technology, so the traits and both actions are
        // spelled out rather than inherited from a control that no longer exists (FR-12.12).
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(friend.assignedName))
        .accessibilityValue(isHidden ? Text("Hidden") : Text("Showing"))
        .accessibilityAction {
            store.toggleHidden(friend.key)
        }
        .accessibilityAction(named: isolationActionName) {
            store.toggleIsolation(friend.key)
        }
        .accessibilityIdentifier("friendLegend")
    }

    /// One control, two sentences — the reader should never have to work out which state they are
    /// in before choosing the action.
    private var isolationActionName: Text {
        store.isIsolated(friend.key)
            ? Text("Show everyone")
            : Text("Show only \(friend.assignedName)")
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

    private var accessibilitySentence: String {
        guard let attribution = FriendAttribution.sentence(for: group, store: store, isOwnPin: false) else {
            return group.name
        }
        return "\(group.name), \(attribution)"
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
        // The place *and* whose it is. A pin that says only where it is tells a VoiceOver reader
        // nothing the map layer was switched on for (FR-12.10, TC-10-18).
        .accessibilityLabel(Text(accessibilitySentence))
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
