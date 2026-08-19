import SwiftUI
import FoodMapDomain

/// The signature element: a food photograph framed like a postage stamp.
///
/// Visited and wishlist pins differ in fill, shape and glyph — never colour alone — so they
/// stay distinguishable for colour-blind users (NFR-6.3).
struct StampPin: View {
    let cluster: PlaceCluster
    var size: CGFloat = Theme.pinSize

    private var place: Place? { cluster.representative }
    private var isVisited: Bool { cluster.containsVisited }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            stamp
            if cluster.count > 1 {
                badge("\(cluster.count)")
            } else if let count = place?.meals.count, count > 1 {
                // Repeat visits collapse into one pin, so the count says there is more behind it.
                badge("\(count)")
            }
        }
        .frame(minWidth: Theme.minimumTouchTarget, minHeight: Theme.minimumTouchTarget)
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
                .overlay(StampShape().strokeBorder(Theme.lacquer, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        } else {
            StampShape()
                .fill(isVisited ? Theme.lacquer.opacity(0.16) : Theme.paperRaised)
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(
                    Image(systemName: isVisited ? "fork.knife" : "bookmark.fill")
                        .font(.system(size: size * 0.3, weight: .semibold))
                        .foregroundStyle(isVisited ? Theme.lacquer : Theme.jade)
                )
                .overlay(
                    StampShape().strokeBorder(
                        isVisited ? Theme.lacquer : Theme.jade,
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
