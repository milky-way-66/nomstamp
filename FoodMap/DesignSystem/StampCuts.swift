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
        case .lego: return Self.lego(inner)
        case .country: return Self.country(inner)
        case .city: return Self.city(inner)
        case .ticket: return Self.ticket(inner)
        case .seaside: return Self.seaside(inner)
        case .pennant: return Self.pennant(inner)
        case .comic: return Self.comic(inner)
        case .arcade: return Self.arcade(inner)
        case .painting: return Self.painting(inner)
        case .bunting: return Self.bunting(inner)
        case .television: return Self.television(inner)
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

    /// A lego brick: a squared-off body with three studs along the top. The studs are unioned
    /// rather than drawn, so the contour runs round them and the photograph fills them too.
    private static func lego(_ rect: CGRect) -> Path {
        let studs = 3
        let radius = rect.width / CGFloat(studs) * 0.3
        let body = rect.insetBy(dx: 0, dy: radius * 0.5).offsetBy(dx: 0, dy: radius * 0.5)
        var path = Path(roundedRect: body, cornerRadius: min(rect.width, rect.height) * 0.06)

        for stud in 0..<studs {
            let x = body.minX + body.width * (CGFloat(stud) + 0.5) / CGFloat(studs)
            path = path.union(Path(ellipseIn: CGRect(
                x: x - radius, y: body.minY - radius,
                width: radius * 2, height: radius * 2
            )))
        }
        return path
    }

    /// The moulding round an old oil painting: every side scooped inwards, and a block left at each
    /// corner where the mitre is. Concave sides are the whole trick — a frame is the one rectangle
    /// in the world whose edges curve the wrong way.
    private static func painting(_ rect: CGRect) -> Path {
        let scoop = min(rect.width, rect.height) * 0.1
        let block = min(rect.width, rect.height) * 0.2
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + block, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - block, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + scoop * 2)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + block))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - block),
            control: CGPoint(x: rect.maxX - scoop * 2, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - block, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + block, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - scoop * 2)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - block))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + block),
            control: CGPoint(x: rect.minX + scoop * 2, y: rect.midY)
        )
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

    /// The transport issue: torn off a roll, so both sides carry the bite that did it. Square-ish
    /// corners, because a ticket is cut by a machine and not by a hand.
    private static func ticket(_ rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.08)
        let radius = min(rect.width, rect.height) * 0.16
        for centre in [CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY)] {
            path = path.subtracting(Path(ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            )))
        }
        return path
    }

    /// The holiday issue: waves along the top and the bottom, straight down the sides — the edge a
    /// pair of pinking scissors leaves, rounded rather than toothed.
    private static func seaside(_ rect: CGRect) -> Path {
        let lobes = 4
        let depth = rect.height * 0.07
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        for lobe in 0..<lobes {  // top, left to right
            let from = rect.minX + rect.width * CGFloat(lobe) / CGFloat(lobes)
            let to = rect.minX + rect.width * CGFloat(lobe + 1) / CGFloat(lobes)
            path.addQuadCurve(
                to: CGPoint(x: to, y: rect.minY + depth),
                control: CGPoint(x: (from + to) / 2, y: rect.minY - depth * 1.6)
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for lobe in 0..<lobes {  // bottom, right to left
            let from = rect.maxX - rect.width * CGFloat(lobe) / CGFloat(lobes)
            let to = rect.maxX - rect.width * CGFloat(lobe + 1) / CGFloat(lobes)
            path.addQuadCurve(
                to: CGPoint(x: to, y: rect.maxY - depth),
                control: CGPoint(x: (from + to) / 2, y: rect.maxY + depth * 1.6)
            )
        }
        path.closeSubpath()
        return path
    }

    /// The festival issue: a flag. Square shoulders, and a V taken out of the bottom deep enough to
    /// read as a swallowtail at pin size rather than as a chip in the paper.
    private static func pennant(_ rect: CGRect) -> Path {
        let notch = rect.height * 0.26
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    /// The comic issue: a burst. Alternating long and short spikes around the whole rim, which is
    /// the difference between a panel that shouts and a cog.
    private static func comic(_ rect: CGRect) -> Path {
        let spikes = 14
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = CGPoint(x: rect.width / 2, y: rect.height / 2)
        var path = Path()

        for point in 0..<(spikes * 2) {
            let angle = Double(point) / Double(spikes * 2) * 2 * .pi - .pi / 2
            // Every other point pulled in: out is the spike, in is the notch between two spikes.
            let reach = point.isMultiple(of: 2) ? 1.0 : 0.76
            let next = CGPoint(
                x: centre.x + cos(angle) * outer.x * reach,
                y: centre.y + sin(angle) * outer.y * reach
            )
            if point == 0 { path.move(to: next) } else { path.addLine(to: next) }
        }
        path.closeSubpath()
        return path
    }

    /// The arcade issue: the corners stepped down in square pixels, the way a low-resolution
    /// sprite rounds a corner. Three steps — two read as a chamfer, four as a curve — and each step
    /// turns twice, because a staircase drawn with diagonals is just a chamfer with extra points.
    private static func arcade(_ rect: CGRect) -> Path {
        let pixel = min(rect.width, rect.height) * 0.1
        let steps = 3
        let reach = pixel * CGFloat(steps)
        var path = Path()

        // The same staircase at each corner, walked clockwise and turned a quarter each time.
        let corners: [(start: CGPoint, alongX: CGFloat, alongY: CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY + reach), 1, -1),
            (CGPoint(x: rect.maxX - reach, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY - reach), -1, 1),
            (CGPoint(x: rect.minX + reach, y: rect.maxY), -1, -1),
        ]
        for (index, corner) in corners.enumerated() {
            var point = corner.start
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            for _ in 0..<steps {
                point.x += pixel * corner.alongX
                path.addLine(to: point)
                point.y += pixel * corner.alongY
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    /// The travel issue: all four corners taken off square. An octagon reads as a document that has
    /// been through an office — a visa, a receipt, a seal.
    private static func passport(_ rect: CGRect) -> Path {
        let corner = min(rect.width, rect.height) * 0.22
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }

    /// The street-party issue: a row of little flags along the bottom edge. Shallow, and four of
    /// them: deeper reads as a bite out of the paper, and fewer as damage rather than as a rhythm.
    private static func bunting(_ rect: CGRect) -> Path {
        let flags = 4
        let hang = rect.height * 0.14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - hang))
        for flag in 0..<flags {
            let width = rect.width / CGFloat(flags)
            let right = rect.maxX - width * CGFloat(flag)
            path.addLine(to: CGPoint(x: right - width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: right - width, y: rect.maxY - hang))
        }
        path.closeSubpath()
        return path
    }

    /// An old television: a tube screen, which is a rectangle that has been inflated slightly and
    /// has corners far rounder than any of the paper cuts.
    private static func television(_ rect: CGRect) -> Path {
        let bulge = min(rect.width, rect.height) * 0.09
        let corner = min(rect.width, rect.height) * 0.26
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - corner, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - bulge)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + corner),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - corner),
            control: CGPoint(x: rect.maxX + bulge, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + corner, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY + bulge)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - corner),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + corner),
            control: CGPoint(x: rect.minX - bulge, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + corner, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
