import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// The signature element: a food photograph framed like a postage stamp.
///
/// Visited and wishlist pins differ in fill, shape and glyph — never colour alone — so they
/// stay distinguishable for colour-blind users (NFR-6.3).
struct StampPin: View {
    let cluster: PlaceCluster
    var size: CGFloat = Theme.pinSize
    /// Set while the map has this pin selected: the stamp lifts off the page for the moment
    /// between the tap and the place opening, so the tap has somewhere to land.
    var isSelected: Bool = false

    private var place: Place? { cluster.representative }
    private var isVisited: Bool { cluster.containsVisited }
    /// How the place scored, rounded to the nearest star: the pin is printed in that ink, so the
    /// map shows at a glance which places were worth it (ADR-005).
    private var score: Int? { place?.averageRating.map { Int($0.rounded()) } }
    private var scoreInk: Color { score == nil ? Theme.pandan : Theme.ratingInk(score) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            stamp
            if score == 5, cluster.count == 1 {
                // Five stars is rare enough to be worth a mark of its own.
                FoodMark(glyph: .star)
                    .fill(Theme.ratingInk(5))
                    .frame(width: 13, height: 13)
                    .padding(3)
                    .background(Circle().fill(Theme.paperRaised))
                    .offset(x: 5, y: -5)
                    .accessibilityHidden(true)
            } else if cluster.count > 1 {
                badge("\(cluster.count)")
            } else if let count = place?.meals.count, count > 1 {
                // Repeat visits collapse into one pin, so the count says there is more behind it.
                badge("\(count)")
            }
        }
        .frame(minWidth: Theme.minimumTouchTarget, minHeight: Theme.minimumTouchTarget)
        // Stuck down by hand, not laid out: the angle comes from the place's id, so it never
        // changes between redraws (ADR-005, TC-N-13).
        .rotationEffect(.degrees(StampTilt.degrees(for: cluster.id)))
        .scaleEffect(isSelected ? 1.22 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isSelected)
        // One element, no children: the label is applied by whoever makes this selectable.
        .accessibilityElement(children: .ignore)
    }

    @ViewBuilder
    private var stamp: some View {
        if let photo = place?.pinPhoto, let image = PhotoImageLoader.shared.thumbnail(named: photo.thumbnailFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(StampShape())
                .overlay(StampShape().strokeBorder(Theme.paperRaised, lineWidth: 2.5))
                // The frame carries the score: a plain paper edge for an unrated place, the
                // rating's own ink around one that earned it.
                .overlay(StampShape().strokeBorder(scoreInk.opacity(score == nil ? 0 : 0.9), lineWidth: 1.2))
                // Two inks, one slightly off the other: the stamp's frame is printed, not drawn.
                .misregistered(StampShape(), ink: Theme.indigo, opacity: 0.55)
                .photoGlow(6)
        } else {
            StampShape()
                .fill(isVisited ? Theme.pandan.opacity(0.16) : Theme.paperRaised)
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(
                    Image(systemName: isVisited ? "fork.knife" : "bookmark.fill")
                        .font(.system(size: size * 0.3, weight: .semibold))
                        .foregroundStyle(isVisited ? Theme.pandan : Theme.bay)
                )
                .overlay(
                    StampShape().strokeBorder(
                        isVisited ? scoreInk : Theme.bay,
                        style: StrokeStyle(lineWidth: 2, dash: isVisited ? [] : [4, 3])
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(Theme.paperRaised)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.ink))
            .offset(x: 5, y: -4)
    }

    var accessibilityDescription: String {
        guard let place else { return "Places" }
        if cluster.count > 1 {
            return "\(cluster.count) places here"
        }
        let kind = place.kind == .visited ? "been here" : "want to try"
        let meals = place.meals.count
        return meals > 0
            ? "\(place.name), \(kind), \(meals) meal\(meals == 1 ? "" : "s")"
            : "\(place.name), \(kind)"
    }
}

/// A rounded rectangle with scalloped edges — the perforated border of a postage stamp.
struct StampShape: InsettableShape {
    var insetAmount: CGFloat = 0
    /// Roughly how many perforations run along the shorter edge.
    private let perforations: Int = 7

    func inset(by amount: CGFloat) -> StampShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let inner = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path(roundedRect: inner, cornerRadius: inner.width * 0.12)

        // Bite semicircles out of each edge to make the perforations.
        let radius = min(inner.width, inner.height) / CGFloat(perforations) / 2
        guard radius > 0.5 else { return path }

        let columns = max(Int(inner.width / (radius * 2)), 1)
        let rows = max(Int(inner.height / (radius * 2)), 1)

        for column in 0...columns {
            let x = inner.minX + inner.width * CGFloat(column) / CGFloat(columns)
            path = path.subtracting(circle(at: CGPoint(x: x, y: inner.minY), radius: radius))
            path = path.subtracting(circle(at: CGPoint(x: x, y: inner.maxY), radius: radius))
        }
        for row in 0...rows {
            let y = inner.minY + inner.height * CGFloat(row) / CGFloat(rows)
            path = path.subtracting(circle(at: CGPoint(x: inner.minX, y: y), radius: radius))
            path = path.subtracting(circle(at: CGPoint(x: inner.maxX, y: y), radius: radius))
        }
        return path
    }

    private func circle(at center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }
}
