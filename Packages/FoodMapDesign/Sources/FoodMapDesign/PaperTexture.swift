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
