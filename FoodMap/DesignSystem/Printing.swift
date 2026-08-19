import SwiftUI
import FoodMapDesign

/// The printed-journal primitives from ADR-005: paper you can see the grain of, and ink that does
/// not quite register.

/// The grain tile, turned into an image once per process.
///
/// `PaperTexture` in `FoodMapDesign` decides the pixels (and TC-N-14 asserts them); this only wraps
/// them in a `UIImage` the interface can tile. One 128 pt tile covers any screen at any scale.
enum PaperGrain {
    static let image: Image = {
        let side = 128
        let pixels = PaperTexture.tile(side: side)
        // Ink values become the alpha of black: the grain darkens whatever page it sits on, which
        // is what ink on paper does, and it means one tile serves both appearances.
        var rgba = [UInt8](repeating: 0, count: pixels.count * 4)
        for (index, ink) in pixels.enumerated() {
            rgba[index * 4 + 3] = ink
        }
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        let cgImage = CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return Image(decorative: cgImage, scale: 1)
    }()
}

extension View {
    /// A page of paper: the ground colour with grain over it.
    ///
    /// Grounds only — never behind body text or a form field (ADR-005 rule 2). Honours Reduce
    /// Transparency, where any wash is unwelcome.
    func paperGround(_ colour: Color = Theme.paper) -> some View {
        modifier(PaperGround(colour: colour))
    }

    /// A photograph at night.
    ///
    /// Dark mode is a night market (ADR-005): the page is dark and the food is what is lit, so a
    /// photograph carries a soft glow of its own rather than sitting in a hole. In light mode this
    /// is a plain drop shadow, which is what paper does under a lamp.
    func photoGlow(_ radius: CGFloat = 10) -> some View {
        modifier(PhotoGlow(radius: radius))
    }

    /// Reprints `shape` a fraction off in a second ink, the way a two-colour press misses.
    ///
    /// Applied to ornament and chrome, never to a photograph or a paragraph.
    func misregistered<S: Shape>(
        _ shape: S,
        ink: Color = Theme.indigo,
        opacity: Double = 0.5
    ) -> some View {
        background(
            shape
                .fill(ink.opacity(opacity))
                .offset(x: Theme.inkOffset.width, y: Theme.inkOffset.height)
        )
    }
}

private struct PaperGround: ViewModifier {
    let colour: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                colour
                if !reduceTransparency {
                    PaperGrain.image
                        .resizable(resizingMode: .tile)
                        // Ink darkens paper; at night the same tile has to lift the ground instead,
                        // or the grain disappears into the dark and the page goes flat.
                        .opacity(scheme == .dark ? Theme.grainOpacity * 0.5 : Theme.grainOpacity)
                        .blendMode(scheme == .dark ? .screen : .multiply)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct PhotoGlow: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .shadow(
                color: scheme == .dark ? Theme.pandan.opacity(0.28) : .black.opacity(0.2),
                radius: radius,
                y: scheme == .dark ? 0 : 2
            )
    }
}
