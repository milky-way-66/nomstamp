import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// What the sky is doing, drawn over the map (ADR-006).
///
/// Effects go over the cartography and nowhere else: never over a photograph, a paragraph or a
/// control, which is the same rule the grain and the misregistration follow (ADR-005). They are
/// drawn rather than animated — this is a printed page in weather, not a screensaver — so the
/// design sweep can photograph them and they cost nothing while the map is being panned.
private struct SkyEffectKey: EnvironmentKey {
    static let defaultValue: SkyEffect = .none
}

extension EnvironmentValues {
    var skyEffect: SkyEffect {
        get { self[SkyEffectKey.self] }
        set { self[SkyEffectKey.self] = newValue }
    }
}

struct SkyEffectLayer: View {
    let effect: SkyEffect
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if effect != .none && !reduceTransparency {
            Canvas { context, size in
                switch effect {
                case .rain: drawRain(in: &context, size: size)
                case .haze: drawHaze(in: &context, size: size)
                case .bloom: drawBloom(in: &context, size: size)
                case .lanterns: drawLanterns(in: &context, size: size)
                case .none: break
                }
            }
            .allowsHitTesting(false)
            // Decoration, and never the only carrier of anything: the sky is not information the
            // app is responsible for conveying.
            .accessibilityHidden(true)
        }
    }

    /// Ink streaks, all falling the same way, thinning towards the bottom of the page.
    private func drawRain(in context: inout GraphicsContext, size: CGSize) {
        let drops = Int(size.width / 26)
        let scatter = DeckleEdge.amplitudes(count: max(drops, 8) * 2, seed: 4_207)
        let ink = Theme.printingInk.opacity(scheme == .dark ? 0.5 : 0.32)

        for drop in 0..<max(drops, 8) {
            let across = (Double(drop) + scatter[drop * 2]) / Double(max(drops, 8))
            let down = scatter[drop * 2 + 1]
            let start = CGPoint(x: across * size.width, y: down * size.height * 0.9)
            let length = size.height * (0.05 + scatter[drop * 2] * 0.06)
            var streak = Path()
            streak.move(to: start)
            // Rain that falls straight down reads as a fence; the slant is what makes it weather.
            streak.addLine(to: CGPoint(x: start.x - length * 0.22, y: start.y + length))
            context.stroke(streak, with: .color(ink), lineWidth: 1.1)
        }
    }

    /// Soft bands lying across the page, the way fog sits in a street.
    private func drawHaze(in context: inout GraphicsContext, size: CGSize) {
        let bands = 5
        let offsets = DeckleEdge.amplitudes(count: bands, seed: 9_311)
        let wash = Theme.paper.opacity(scheme == .dark ? 0.10 : 0.22)

        for band in 0..<bands {
            let y = (Double(band) + offsets[band]) / Double(bands) * size.height
            let height = size.height * (0.06 + offsets[band] * 0.08)
            let rectangle = CGRect(x: -20, y: y, width: size.width + 40, height: height)
            context.fill(Path(roundedRect: rectangle, cornerRadius: height / 2), with: .color(wash))
        }
    }

    /// The sun in the corner of the page: one wide, warm halo, no rays.
    private func drawBloom(in context: inout GraphicsContext, size: CGSize) {
        let centre = CGPoint(x: size.width * 0.82, y: size.height * 0.12)
        let radius = min(size.width, size.height) * 0.55
        let glow = Theme.visitedInk

        context.fill(
            Path(ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [glow.opacity(scheme == .dark ? 0.22 : 0.18), glow.opacity(0)]),
                center: centre,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    /// Lamps strung over a night market: small lights, each with its own halo.
    private func drawLanterns(in context: inout GraphicsContext, size: CGSize) {
        let count = 14
        let scatter = DeckleEdge.amplitudes(count: count * 2, seed: 5_150)
        let light = Theme.visitedInk

        for lantern in 0..<count {
            let x = (Double(lantern) + scatter[lantern * 2]) / Double(count) * size.width
            let y = scatter[lantern * 2 + 1] * size.height
            let radius = 2.5 + scatter[lantern * 2] * 2

            let halo = radius * 6
            context.fill(
                Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)),
                with: .radialGradient(
                    Gradient(colors: [light.opacity(0.28), light.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: halo
                )
            )
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(light.opacity(0.85))
            )
        }
    }
}
