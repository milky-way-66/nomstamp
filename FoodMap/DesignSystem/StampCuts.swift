import SwiftUI
import FoodMapDesign

/// The five frames a stamp can be cut with, as one shape (ADR-005).
///
/// `StampCut` in `FoodMapDesign` decides which place gets which; this draws them. They are five
/// silhouettes rather than five roundings of a rectangle, because at pin size — filled edge to edge
/// with a photograph — the outline is the only part of a frame a reader ever sees.
struct StampCutShape: InsettableShape {
    let cut: StampCut
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> StampCutShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let inner = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard inner.width > 1, inner.height > 1 else { return Path() }

        switch cut {
        case .classic: return StampShape(insetAmount: insetAmount).path(in: rect)
        case .gallery: return Self.gallery(inner)
        case .modern: return Self.modern(inner)
        case .country: return Self.country(inner)
        case .city: return Self.city(inner)
        }
    }

    /// The art issue: an arch on square shoulders. The curve is drawn as two quadratics meeting at
    /// the crown rather than as an arc, so the shoulders stay upright at any aspect ratio.
    private static func gallery(_ rect: CGRect) -> Path {
        let spring = rect.minY + rect.height * 0.38
        let shoulder = rect.minY + rect.height * 0.05
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: spring))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: spring), control: CGPoint(x: rect.maxX, y: shoulder))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    /// The future issue: two opposite corners taken off at 45°, everything else dead straight. No
    /// perforation, no rounding — the only cut in the family a machine could have made.
    private static func modern(_ rect: CGRect) -> Path {
        let chamfer = min(rect.width, rect.height) * 0.3
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + chamfer, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - chamfer))
        path.addLine(to: CGPoint(x: rect.maxX - chamfer, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + chamfer))
        path.closeSubpath()
        return path
    }

    /// The rural issue: cut out by hand, so no edge is straight and no two are torn alike. The
    /// offsets come from `DeckleEdge`, seeded, so the same stamp tears the same way every draw.
    private static func country(_ rect: CGRect) -> Path {
        let steps = 5
        let depth = min(rect.width, rect.height) * 0.075
        let strays = DeckleEdge.amplitudes(count: steps * 4, seed: 8_2026)
        // Halfway between the two extremes is a straight edge; either side of it the paper bulges
        // out or is torn in.
        let midpoint = (DeckleEdge.maximumAmplitude + DeckleEdge.minimumAmplitude) / 2
        var index = 0
        func stray() -> CGFloat {
            defer { index += 1 }
            return CGFloat((strays[index % strays.count] - midpoint)) * depth * 2
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        for step in 1...steps {  // top, left to right
            let across = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * across, y: rect.minY - stray()))
        }
        for step in 1...steps {  // right, top to bottom
            let down = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: rect.maxX + stray(), y: rect.minY + rect.height * down))
        }
        for step in 1...steps {  // bottom, right to left
            let back = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * back, y: rect.maxY + stray()))
        }
        for step in 1...steps {  // left, bottom to top
            let up = CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: rect.minX - stray(), y: rect.maxY - rect.height * up))
        }
        path.closeSubpath()
        return path
    }

    /// The metropolitan issue: square corners and a run of roofs along the top. Four blocks of
    /// unequal height — three would read as a crown, and equal ones as a battlement.
    private static func city(_ rect: CGRect) -> Path {
        let roofs: [CGFloat] = [0.18, 0.02, 0.12, 0.06]
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * roofs[0]))
        for (block, roof) in roofs.enumerated() {
            let edge = rect.minX + rect.width * CGFloat(block + 1) / CGFloat(roofs.count)
            let top = rect.minY + rect.height * roof
            path.addLine(to: CGPoint(x: edge, y: top))
            if block + 1 < roofs.count {
                path.addLine(to: CGPoint(x: edge, y: rect.minY + rect.height * roofs[block + 1]))
            }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
