import SwiftUI
import FoodMapDesign

/// A rectangle whose bottom edge has been torn rather than cut (ADR-005).
///
/// Used where a photograph meets the page: a straight edge says "image view", a torn one says the
/// picture was pasted in. `DeckleEdge` decides how deep each tear goes and asserts it (TC-N-16);
/// this only walks those amplitudes into a path.
struct TornBottom: Shape {
    /// How far the tear may eat into the shape.
    var depth: CGFloat = 14
    /// Seeded per element, so two photographs on one page are not torn identically.
    var seed: UInt64 = PaperTexture.defaultSeed

    func path(in rect: CGRect) -> Path {
        // About one tooth every 14 pt: fine enough to read as fibre, coarse enough to be visible.
        let steps = max(8, Int(rect.width / 14))
        let amplitudes = DeckleEdge.amplitudes(count: steps + 1, seed: seed)
        let shoulder = rect.maxY - depth

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right to left along the tear, so the path closes back at the top-left corner.
        for (index, amplitude) in amplitudes.enumerated().reversed() {
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * CGFloat(index) / CGFloat(steps),
                y: shoulder + depth * CGFloat(amplitude)
            ))
        }
        path.closeSubpath()
        return path
    }
}
