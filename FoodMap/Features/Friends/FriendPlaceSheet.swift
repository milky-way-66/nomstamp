import SwiftUI
import FoodMapDomain

/// A place the reader has never been, shown because a friend has.
///
/// The scarcity is the point. A shared stamp is a place, not a meal — a name, roughly where it
/// is, how a friend rated it to the half star, how often they went, the last dish and the month.
/// There is no price, no per-meal score, no exact date and no full-size photograph, because
/// those never left the other phone (FR-11.3, ADR-009).
struct FriendPlaceSheet: View {
    let group: MapStampGroup
    let store: FriendsStore

    @Environment(\.dismiss) private var dismiss

    private var stamp: SharedStamp? { group.countersign?.stamp }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.loose) {
                    signatories

                    if let stamp {
                        details(stamp)
                        if let note = stamp.note {
                            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                                SectionHeading(text: "Their note")
                                Text(note)
                                    .font(Theme.displayItalic())
                                    .foregroundStyle(Theme.ink)
                                    .lineSpacing(Theme.minimumLineSpacing)
                            }
                        }
                    }

                    asOfLine
                }
                .padding(Theme.screenMargin)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.paper)
            .navigationTitle(Text(group.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Close") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var signatories: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            SectionHeading(text: "Stamped by")
            FlowingChips(stamps: group.friendStamps, store: store)
        }
    }

    private func details(_ stamp: SharedStamp) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            if let rating = stamp.averageRating {
                // To the half star. A friend does not get the exact mean of someone's private
                // scores, and the interface should not print one.
                detail(label: Text("Their rating"), value: Text(rating.formatted(.number.precision(.fractionLength(0...1)))) + Text(" of 5"))
            }
            detail(
                label: Text("Times they went"),
                value: Text(stamp.visitCount.formatted())
            )
            if let dish = stamp.latestDish {
                detail(label: Text("Last dish"), value: Text(dish))
            }
            // A month, never a day. The type has nowhere to keep one (FR-11.3, TC-9-04).
            detail(label: Text("Last visit"), value: Text(stamp.lastVisitedMonth.description))
        }
    }

    private func detail(label: Text, value: Text) -> some View {
        HStack(alignment: .firstTextBaseline) {
            label
                .font(Theme.smallCaps())
                .foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: Theme.Space.regular)
            value
                .font(Theme.label(.body))
                .foregroundStyle(Theme.ink)
        }
    }

    /// Staleness belongs to the friend, and the interface may never say what a friend shares
    /// *now* — only what was held as of the last exchange (FR-12.6, FR-12.7).
    @ViewBuilder
    private var asOfLine: some View {
        if let key = group.countersign?.friend,
           let friend = store.friend(for: key),
           let reached = friend.lastReachedAt {
            Text("As of \(reached.formatted(date: .abbreviated, time: .omitted))")
                .font(Theme.label(.footnote))
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}

/// The signatories, wrapping onto as many lines as they need. Eight is the most there can ever
/// be, so a flow layout is enough and a scroll view would be theatre.
struct FlowingChips: View {
    let stamps: [FriendStamp]
    let store: FriendsStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            VStack(alignment: .leading, spacing: Theme.Space.tight) { row }
        }
    }

    private var row: some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(stamps, id: \.friend) { stamp in
                if let friend = store.friend(for: stamp.friend) {
                    FriendChip(
                        inkSlot: friend.inkSlot,
                        name: friend.assignedName,
                        freshness: store.freshness(of: stamp)
                    )
                }
            }
        }
    }
}
