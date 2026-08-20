import SwiftUI
import FoodMapDesign

/// A friend's mark: a small perforated stamp printed in their ink.
///
/// Two signals, never one. The **cut** says whose stamp it is — solid for the reader, perforated
/// for a friend — and the ink says *which* friend. That division is what lets the plate of eight
/// stay fixed while the skin re-inks everything around it: hue only has to tell Lan from Minh,
/// not a friend from the reader (ADR-009, FR-12.5, TC-N-27).
struct FriendStampMark: View {
    let inkSlot: Int
    var size: CGFloat = 22
    /// How recently this stamp landed. Fresh ink sits proud of the page and dries to ordinary
    /// over three days — the thing that replaces a notification (FR-13.1a).
    var freshness: Double = 0

    private var ink: Color { Theme.friendInk(inkSlot) }

    var body: some View {
        PerforatedStamp()
            .fill(ink)
            .frame(width: size, height: size)
            .overlay(
                // A wet stamp is glossy at its edge for a day or two. It is the only animation-free
                // way to say *this is new* without a badge or a count.
                PerforatedStamp()
                    .strokeBorder(Theme.paperRaised.opacity(0.9), lineWidth: size * 0.09)
                    .opacity(freshness)
            )
            .shadow(
                color: ink.opacity(0.45 * freshness),
                radius: size * 0.18 * freshness
            )
            .accessibilityHidden(true)
    }
}

/// The friend cut: a square bitten along all four edges, at a coarser tooth than `StampShape`.
///
/// Coarser on purpose. At the sizes this is drawn — 18 to 26 points — `StampShape`'s ten fine
/// teeth blur into a soft-edged square, and the whole point of the cut is that it survives being
/// small. Nine bites per edge is the count `StampEdge` names.
struct PerforatedStamp: InsettableShape {
    var insetAmount: CGFloat = 0
    private var teeth: Int { StampEdge.perforated.perforations }

    func inset(by amount: CGFloat) -> PerforatedStamp {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let inner = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path(roundedRect: inner, cornerRadius: inner.width * 0.14)
        let radius = min(inner.width, inner.height) / CGFloat(teeth) / 2
        guard radius > 0.4 else { return path }

        for index in 0...teeth {
            let fraction = CGFloat(index) / CGFloat(teeth)
            let x = inner.minX + inner.width * fraction
            let y = inner.minY + inner.height * fraction
            path = path.subtracting(bite(at: CGPoint(x: x, y: inner.minY), radius: radius))
            path = path.subtracting(bite(at: CGPoint(x: x, y: inner.maxY), radius: radius))
            path = path.subtracting(bite(at: CGPoint(x: inner.minX, y: y), radius: radius))
            path = path.subtracting(bite(at: CGPoint(x: inner.maxX, y: y), radius: radius))
        }
        return path
    }

    private func bite(at centre: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: centre.x - radius, y: centre.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }
}

/// A friend's mark with their name beside it — the *also stamped by* row, and the friends list.
struct FriendChip: View {
    let inkSlot: Int
    let name: String
    var freshness: Double = 0

    var body: some View {
        HStack(spacing: Theme.Space.hairline + 2) {
            FriendStampMark(inkSlot: inkSlot, size: 18, freshness: freshness)
            Text(name)
                .font(Theme.label(.footnote))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Space.tight)
        .padding(.vertical, Theme.Space.hairline + 1)
        .background(
            Capsule().fill(Theme.paperRaised)
        )
        .overlay(
            Capsule().strokeBorder(Theme.ink, lineWidth: Theme.contour)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}
