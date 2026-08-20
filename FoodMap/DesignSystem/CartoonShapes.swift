import SwiftUI

/// The silhouettes the app's drawn controls are built from (ADR-005, the cartoon rule).
///
/// A cartoon does not draw two objects with the same outline. Three round buttons in a column are
/// three of one button; a wobbly circle, a tag and a blob are three characters, and a reader tells
/// them apart before reading the glyph on them. None of these is a rounded rectangle with a
/// different corner radius — the difference has to be in the shape, or it is not a difference.

/// A circle drawn by a hand rather than a compass: four arcs of unequal radius, so no two quarters
/// of it match. Deliberately gentle — past a few percent it stops looking hand-drawn and starts
/// looking like a rendering fault.
struct WobbleCircle: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> WobbleCircle {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard box.width > 1, box.height > 1 else { return Path() }
        let centre = CGPoint(x: box.midX, y: box.midY)
        let radius = min(box.width, box.height) / 2
        // One number per quarter, fixed rather than random: this shape is drawn a hundred times a
        // second and a wobble that moved would be a shiver.
        let wobble: [CGFloat] = [1.0, 0.955, 1.03, 0.97]

        var path = Path()
        for quarter in 0..<4 {
            let from = Double(quarter) / 4 * 2 * .pi - .pi / 2
            let to = Double(quarter + 1) / 4 * 2 * .pi - .pi / 2
            let start = CGPoint(
                x: centre.x + CGFloat(cos(from)) * radius * wobble[quarter],
                y: centre.y + CGFloat(sin(from)) * radius * wobble[quarter]
            )
            let end = CGPoint(
                x: centre.x + CGFloat(cos(to)) * radius * wobble[(quarter + 1) % 4],
                y: centre.y + CGFloat(sin(to)) * radius * wobble[(quarter + 1) % 4]
            )
            // The control point sits out beyond the corner of the quarter, which is what turns two
            // points into an arc rather than a chord.
            let middle = (from + to) / 2
            let bulge = radius * wobble[quarter] * 1.19
            let control = CGPoint(
                x: centre.x + CGFloat(cos(middle)) * bulge,
                y: centre.y + CGFloat(sin(middle)) * bulge
            )

            if quarter == 0 { path.move(to: start) }
            path.addQuadCurve(to: end, control: control)
        }
        path.closeSubpath()
        return path
    }
}

/// A luggage tag: round-shouldered, with the top-right corner cut off where the string goes.
struct TagShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> TagShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard box.width > 1, box.height > 1 else { return Path() }
        let radius = min(box.width, box.height) * 0.28
        let cut = min(box.width, box.height) * 0.34

        var path = Path()
        path.move(to: CGPoint(x: box.minX + radius, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - cut, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY + cut))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: box.maxX - radius, y: box.maxY), control: CGPoint(x: box.maxX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + radius, y: box.maxY))
        path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY - radius), control: CGPoint(x: box.minX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + radius))
        path.addQuadCurve(to: CGPoint(x: box.minX + radius, y: box.minY), control: CGPoint(x: box.minX, y: box.minY))
        path.closeSubpath()
        return path
    }
}

/// A blob: a squircle whose four corners are all differently round, so it leans without being
/// rotated. The fattest of the three, which is why the main action wears it.
struct BlobShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> BlobShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard box.width > 1, box.height > 1 else { return Path() }
        let side = min(box.width, box.height)
        // Clockwise from the top-left. Unequal on purpose; equal ones are a squircle.
        let corners = [side * 0.48, side * 0.34, side * 0.5, side * 0.38]

        var path = Path()
        path.move(to: CGPoint(x: box.minX + corners[0], y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX - corners[1], y: box.minY))
        path.addQuadCurve(to: CGPoint(x: box.maxX, y: box.minY + corners[1]), control: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY - corners[2]))
        path.addQuadCurve(to: CGPoint(x: box.maxX - corners[2], y: box.maxY), control: CGPoint(x: box.maxX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX + corners[3], y: box.maxY))
        path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY - corners[3]), control: CGPoint(x: box.minX, y: box.maxY))
        path.addLine(to: CGPoint(x: box.minX, y: box.minY + corners[0]))
        path.addQuadCurve(to: CGPoint(x: box.minX + corners[0], y: box.minY), control: CGPoint(x: box.minX, y: box.minY))
        path.closeSubpath()
        return path
    }
}

/// The app's button, for everywhere that is not the map's floating actions (ADR-005).
///
/// Flat fill, bold contour, hard shadow, and a press that drops the button onto its own shadow.
/// It exists to keep `.borderedProminent` and `.bordered` out of the app: a stock iOS button in a
/// drawn interface is the one object on the screen nobody drew, and it is always the one the eye
/// goes to first.
struct CartoonButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary
    /// Buttons are not stuck on straight either — but a paragraph-width button leans less than a
    /// pin, or the whole page looks like it is sliding.
    var tilt: Double = -0.6

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let drop: CGFloat = 4

        return configuration.label
            .font(Theme.label(.headline))
            .foregroundStyle(kind == .primary ? Theme.onAccent : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.snug)
            .background(shape.fill(kind == .primary ? Theme.visitedInk : Theme.paperRaised))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: kind == .primary ? 2.6 : 2.2))
            .background(shape.fill(Theme.ink.opacity(0.85)).offset(y: drop))
            .offset(y: pressed ? drop * 0.8 : 0)
            .rotationEffect(.degrees(tilt))
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
    }
}
