import SwiftUI
import Foundation

/// The drawn glyph set (ADR-005).
///
/// SF Symbols are excellent and instantly legible, which is exactly why they make an app look like
/// every other app. The map's chrome is the one place a user looks at constantly, so its marks are
/// drawn here: same silhouettes anyone would recognise, but in this app's line.
///
/// Every glyph is described in a unit square and stroked, never filled, so one shape serves any
/// size and any ink. `Shape` gives it resolution independence and lets `misregistered` reprint it.
struct FoodMark: Shape {
    enum Glyph {
        /// Add a meal: the camera.
        case camera
        /// Save a place someone told you about: a ribbon.
        case ribbon
        /// Saved places near me: a needle in its rose.
        case needle
        /// Return the map to the reader: a crosshair.
        case crosshair
        /// Nothing here yet: a bowl with its steam.
        case bowl
        /// A score: one point of a rating.
        case star
    }

    let glyph: Glyph

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Everything below is written in a unit square and mapped once, so the drawing reads as
        // proportions rather than as a table of magic numbers.
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        switch glyph {
        case .camera:
            path.addRoundedRect(
                in: CGRect(origin: point(0.04, 0.26), size: CGSize(width: rect.width * 0.92, height: rect.height * 0.58)),
                cornerSize: CGSize(width: rect.width * 0.14, height: rect.height * 0.14)
            )
            // The viewfinder hump, drawn as three strokes rather than a second rectangle so the
            // corner where it meets the body stays a single line.
            path.move(to: point(0.33, 0.26))
            path.addLine(to: point(0.38, 0.15))
            path.addLine(to: point(0.62, 0.15))
            path.addLine(to: point(0.67, 0.26))
            path.addEllipse(in: CGRect(
                x: point(0.32, 0.38).x, y: point(0.32, 0.38).y,
                width: rect.width * 0.36, height: rect.height * 0.36
            ))

        case .ribbon:
            path.move(to: point(0.24, 0.12))
            path.addLine(to: point(0.76, 0.12))
            path.addLine(to: point(0.76, 0.88))
            path.addLine(to: point(0.50, 0.66))
            path.addLine(to: point(0.24, 0.88))
            path.closeSubpath()

        case .needle:
            path.addEllipse(in: CGRect(
                x: point(0.08, 0.08).x, y: point(0.08, 0.08).y,
                width: rect.width * 0.84, height: rect.height * 0.84
            ))
            // A compass needle, not an arrow: the short tail is what makes it read as an instrument.
            path.move(to: point(0.66, 0.34))
            path.addLine(to: point(0.44, 0.44))
            path.addLine(to: point(0.34, 0.66))
            path.addLine(to: point(0.56, 0.56))
            path.closeSubpath()

        case .crosshair:
            path.addEllipse(in: CGRect(
                x: point(0.18, 0.18).x, y: point(0.18, 0.18).y,
                width: rect.width * 0.64, height: rect.height * 0.64
            ))
            path.move(to: point(0.50, 0.02))
            path.addLine(to: point(0.50, 0.30))
            path.move(to: point(0.70, 0.50))
            path.addLine(to: point(0.98, 0.50))
            path.move(to: point(0.50, 0.70))
            path.addLine(to: point(0.50, 0.98))
            path.move(to: point(0.02, 0.50))
            path.addLine(to: point(0.30, 0.50))

        case .bowl:
            path.move(to: point(0.10, 0.48))
            path.addQuadCurve(to: point(0.90, 0.48), control: point(0.50, 0.98))
            path.closeSubpath()
            // Steam: two curls, unequal, because equal ones look like a logo.
            path.move(to: point(0.38, 0.34))
            path.addQuadCurve(to: point(0.38, 0.10), control: point(0.28, 0.22))
            path.move(to: point(0.60, 0.32))
            path.addQuadCurve(to: point(0.60, 0.14), control: point(0.70, 0.23))
        case .star:
            // Five points, struck from the centre: outer radius half the square, inner a little
            // over a fifth, which is the proportion that still reads as a star at 14 pt.
            let centre = point(0.5, 0.5)
            let outer = min(rect.width, rect.height) * 0.5
            let inner = outer * 0.42
            for step in 0..<10 {
                let radius = step.isMultiple(of: 2) ? outer : inner
                // Start at the top: -90° in a coordinate space whose y grows downwards.
                let angle = -Double.pi / 2 + Double(step) * Double.pi / 5
                let vertex = CGPoint(
                    x: centre.x + CGFloat(cos(angle)) * radius,
                    y: centre.y + CGFloat(sin(angle)) * radius
                )
                if step == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
            }
            path.closeSubpath()
        }

        return path
    }
}

extension FoodMark {
    /// Stroked at a weight that holds at chrome sizes without going spindly.
    func inked(_ width: CGFloat = 1.8) -> some View {
        stroke(style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
