import Foundation

/// The grain that makes a page look like paper rather than a fill (ADR-005).
///
/// A tile of ink values, generated once and tiled by the interface — procedural rather than a
/// bundled image so it costs no download, has no resolution, and both appearances come free. Held
/// here in `FoodMapDesign`, with no UIKit, so the numbers are asserted rather than eyeballed.
public enum PaperTexture {
    /// Mean ink above this stops looking like fibre and starts looking like dirt on the screen.
    public static let maximumMeanInk: Double = 0.08

    /// The seed the app uses. Fixed, so every device draws the same paper.
    public static let defaultSeed: UInt64 = 20_260_819

    /// One square tile of ink values, row-major, 0 = clean paper, 255 = full ink.
    ///
    /// Two overlaid frequencies: sparse dark specks for fibre, and a fine dither so flat areas are
    /// never perfectly flat. A tile is small and repeats, which real laid paper does too.
    public static func tile(side: Int = 128, seed: UInt64 = defaultSeed) -> [UInt8] {
        precondition(side > 0)
        var random = SplitMix64(seed: seed)
        var pixels = [UInt8](repeating: 0, count: side * side)

        for index in pixels.indices {
            // Fine dither: almost everywhere, almost invisible.
            let dither = random.next(upperBound: 14)
            // Fibre: roughly one pixel in forty carries a visible speck.
            let isSpeck = random.next(upperBound: 40) == 0
            let speck = isSpeck ? 40 + random.next(upperBound: 60) : 0
            pixels[index] = UInt8(min(255, dither + speck))
        }
        return pixels
    }
}

/// A torn paper edge (ADR-005).
///
/// The amplitudes are the only thing worth deciding away from the interface: how far each point of
/// the tear strays from the straight line, as a fraction of the edge's depth. Seeded, so a given
/// edge is torn the same way every time it is drawn rather than fluttering between redraws.
public enum DeckleEdge {
    /// The deepest a tear may go, as a fraction of the edge's depth. A tear that reaches the far
    /// side stops reading as paper and starts reading as damage.
    public static let maximumAmplitude: Double = 0.85

    /// The shallowest, so the edge never flattens into a ruled line.
    public static let minimumAmplitude: Double = 0.15

    public static func amplitudes(count: Int, seed: UInt64 = PaperTexture.defaultSeed) -> [Double] {
        guard count > 0 else { return [] }
        var generator = SplitMix64(seed: seed)
        let span = maximumAmplitude - minimumAmplitude
        // 1000 steps is finer than any screen can show, and integer arithmetic keeps the values
        // identical on every architecture.
        return (0..<count).map { _ in
            minimumAmplitude + Double(generator.next(upperBound: 1001)) / 1000 * span
        }
    }
}

/// A small, explicit generator: `Int.random` uses the system source, which would give a different
/// tile on every launch and make the grain shimmer.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
