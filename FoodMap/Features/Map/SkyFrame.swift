import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// The weather, as the border of the page (ADR-006).
///
/// Every version of the sky that was drawn *over* the map spent legibility to buy atmosphere, and a
/// window in the corner spent room instead — one more object on a screen that already has pins,
/// actions, a compass and a sheet. This spends neither: a printed rule just inside the screen edge,
/// in the margin the layout already leaves, ornamented by whatever the sky is doing. It never
/// covers the cartography, and it is the frame around everything rather than another thing inside
/// it.
///
/// It keeps its licence to move by being slow (`SkyMotion`, TC-N-23), by holding still under Reduce
/// Motion, and by dropping its glows under Reduce Transparency.
struct SkyFrame: View {
    let effect: SkyEffect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    private var kind: SkyEffectKind {
        // The two enumerations meet here and nowhere else, the same way `Skin`'s two halves do: the
        // domain says what the weather is, the design package says how fast it moves.
        switch effect {
        case .none: .none
        case .rain: .rain
        case .haze: .haze
        case .bloom: .bloom
        case .lanterns: .lanterns
        }
    }

    var body: some View {
        if effect != .none {
            ZStack(alignment: .topLeading) {
                rule
                    // The frame is decoration around the page; VoiceOver reads the page.
                    .accessibilityHidden(true)
                // The sky is information, and a frame is easy to miss, so it says what it is out
                // loud — from a mark in the corner rather than from an element the size of the
                // screen, which would sit between the reader and the map.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(Self.label(for: effect))
                    .padding(.leading, Theme.screenMargin)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var rule: some View {
        if reduceMotion {
            Canvas { context, size in
                draw(&context, size: size, phase: Self.stillPhase)
            }
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let period = SkyMotion.period(for: kind)
                    let seconds = timeline.date.timeIntervalSinceReferenceDate
                    draw(&context, size: size, phase: period > 0 ? (seconds / period).truncatingRemainder(dividingBy: 1) : 0)
                }
            }
        }
    }

    /// `phase` runs 0...1 once per cycle, and every routine below is a function of it and of
    /// nothing else — so the border draws the same on every device and at every frame rate, and one
    /// frozen frame of it is a sensible still image.
    private func draw(_ context: inout GraphicsContext, size: CGSize, phase: Double) {
        let frame = CGRect(origin: .zero, size: size).insetBy(dx: Self.margin, dy: Self.margin)
        guard frame.width > 0, frame.height > 0 else { return }
        let border = Path(roundedRect: frame, cornerRadius: Self.corner, style: .continuous)

        switch kind {
        case .rain: drawRain(&context, frame: frame, border: border, phase: phase)
        case .haze: drawHaze(&context, border: border, phase: phase)
        case .bloom: drawBloom(&context, frame: frame, border: border, phase: phase)
        case .lanterns: drawLanterns(&context, frame: frame, border: border, phase: phase)
        case .none: break
        }
    }

    /// Rain rules the border in ticks that travel down both sides — the frame itself running with
    /// water. The top and bottom stay a plain rule: rain falling sideways is a storm, not weather.
    private func drawRain(_ context: inout GraphicsContext, frame: CGRect, border: Path, phase: Double) {
        context.stroke(border, with: .color(ink(0.4)), lineWidth: Self.weight)

        let ticks = 14
        let run = frame.height - Self.corner * 2
        guard run > 0 else { return }
        let length = run / Double(ticks) * 0.6
        let scatter = DeckleEdge.amplitudes(count: ticks, seed: 4_207)

        for tick in 0..<ticks {
            // Each tick is offset in the cycle, so the two sides never fall as one rank.
            let travel = (Double(tick) / Double(ticks) + phase).truncatingRemainder(dividingBy: 1)
            let y = frame.minY + Self.corner + travel * run
            // Faded in at the top of the run and out at the bottom, so nothing appears at an edge.
            let fade = min(travel * 5, min((1 - travel) * 5, 1))
            let weight = 0.6 + 0.5 * scatter[tick]

            for x in [frame.minX, frame.maxX] {
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addLine(to: CGPoint(x: x, y: y + length))
                context.stroke(streak, with: .color(ink(0.7 * fade)), lineWidth: Self.weight * weight * 2)
            }
        }
    }

    /// Fog takes the edge off the rule until it has none left, and breathes. Nothing is added and
    /// nothing moves: the frame is simply less certain of where it is.
    private func drawHaze(_ context: inout GraphicsContext, border: Path, phase: Double) {
        let breath = 1 + SkyMotion.amplitude(for: .haze) * sin(phase * 2 * .pi)

        if !reduceTransparency {
            var soft = context
            soft.addFilter(.blur(radius: 4 * breath))
            soft.stroke(border, with: .color(ink(0.34)), lineWidth: Self.weight * 3)
        }
        context.stroke(border, with: .color(ink(0.22 * breath)), lineWidth: Self.weight)
    }

    /// A clear sky warms the rule and lights the top of the page, the way daylight comes into a
    /// room from above. The glow is wide and weak — a border, not a headlight.
    private func drawBloom(_ context: inout GraphicsContext, frame: CGRect, border: Path, phase: Double) {
        let breath = 1 + SkyMotion.amplitude(for: .bloom) * sin(phase * 2 * .pi)
        let glow = Theme.visitedInk

        if !reduceTransparency {
            let depth = frame.height * 0.22 * breath
            context.fill(
                Path(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: depth)),
                with: .linearGradient(
                    Gradient(colors: [glow.opacity(0.26), glow.opacity(0)]),
                    startPoint: CGPoint(x: frame.midX, y: frame.minY),
                    endPoint: CGPoint(x: frame.midX, y: frame.minY + depth)
                )
            )
        }
        context.stroke(border, with: .color(glow.opacity(0.5 * breath)), lineWidth: Self.weight)
    }

    /// After dark the border is a wire with lamps hung off it, coming up in turn. They hang from
    /// the top rule only — a lamp on the bottom edge would be a lamp on the floor — and in two runs
    /// either side of the middle, because the middle of the top edge belongs to the Dynamic Island
    /// and a lamp behind it is a lamp nobody sees.
    private func drawLanterns(_ context: inout GraphicsContext, frame: CGRect, border: Path, phase: Double) {
        context.stroke(border, with: .color(ink(0.4)), lineWidth: Self.weight)

        let perRun = 3
        let light = Theme.visitedInk
        let runStart = frame.minX + Self.corner
        let runEnd = frame.maxX - Self.corner
        guard runEnd > runStart else { return }
        // The island and its margins, as a fraction of the top edge.
        let clearance = (start: 0.34, end: 0.66)

        for (index, run) in [(runStart, runStart + (runEnd - runStart) * clearance.start),
                             (runStart + (runEnd - runStart) * clearance.end, runEnd)].enumerated() {
            for lantern in 0..<perRun {
                let across = (Double(lantern) + 1) / Double(perRun + 1)
                let x = run.0 + (run.1 - run.0) * across
                let radius = 4.5
                let drop = 16.0
                let centre = CGPoint(x: x, y: frame.minY + drop)

                var line = Path()
                line.move(to: CGPoint(x: x, y: frame.minY))
                line.addLine(to: CGPoint(x: x, y: centre.y - radius))
                context.stroke(line, with: .color(ink(0.35)), lineWidth: 0.7)

                // Staggered along the whole string, so the two runs never brighten together.
                let place = Double(index * perRun + lantern) / Double(perRun * 2)
                let turn = (phase + place).truncatingRemainder(dividingBy: 1)
                let lit = 0.5 + 0.5 * (0.5 + 0.5 * sin(turn * 2 * .pi))

                if !reduceTransparency {
                    let halo = radius * 4
                    context.fill(
                        Path(ellipseIn: CGRect(x: centre.x - halo, y: centre.y - halo, width: halo * 2, height: halo * 2)),
                        with: .radialGradient(
                            Gradient(colors: [light.opacity(0.3 * lit), light.opacity(0)]),
                            center: centre,
                            startRadius: 0,
                            endRadius: halo
                        )
                    )
                }
                // Taller than it is wide, which is most of what tells a lantern from a bulb.
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: centre.x - radius * 0.78, y: centre.y - radius,
                        width: radius * 1.56, height: radius * 2
                    )),
                    with: .color(light.opacity(0.5 + 0.5 * lit))
                )
            }
        }
    }

    private func ink(_ opacity: Double) -> Color {
        Theme.printingInk.opacity(scheme == .dark ? opacity * 1.3 : opacity)
    }

    /// How far in from the screen the rule is printed. Inside the display's own corner radius, so
    /// the frame parallels the glass rather than being clipped by it.
    static let margin: CGFloat = 7
    static let corner: CGFloat = 48
    static let weight: CGFloat = 1.2
    /// The frame Reduce Motion prints, and the one the design sweep photographs: a quarter through
    /// the cycle, where the rain is mid-fall and the lamps are not all at one brightness.
    static let stillPhase: Double = 0.25

    static func label(for effect: SkyEffect) -> LocalizedStringKey {
        switch effect {
        case .rain: "Raining"
        case .haze: "Overcast"
        case .bloom: "Clear sky"
        case .lanterns: "After dark"
        case .none: ""
        }
    }
}

/// What the sky is doing where the reader is, set once at the root (ADR-006).
private struct SkyEffectKey: EnvironmentKey {
    static let defaultValue: SkyEffect = .none
}

extension EnvironmentValues {
    var skyEffect: SkyEffect {
        get { self[SkyEffectKey.self] }
        set { self[SkyEffectKey.self] = newValue }
    }
}
