import Testing
import Foundation
@testable import FoodMapDesign

/// ADR-005 — the printed-journal primitives. Pure values and pixels, so no simulator.
@Suite("Art direction — printed journal")
struct ArtDirectionTests {

    /// TC-N-13 — a street of pins should look stuck into an album, not snapped to a grid, and it
    /// must look the *same* every time the map redraws.
    @Test("TC-N-13 stamp tilt is deterministic, bounded, and varies between places")
    func TC_N_13_stampTilt() {
        let ids = (0..<200).map { "place-\($0)" }
        let angles = ids.map { StampTilt.degrees(for: $0) }

        for (id, angle) in zip(ids, angles) {
            #expect(StampTilt.degrees(for: id) == angle, "the same place must always tilt the same way")
            #expect(abs(angle) <= StampTilt.limit, "\(angle)° is beyond the ±\(StampTilt.limit)° limit")
        }

        // Not a constant, and not two values either: a spread wide enough to read as hand-placed.
        #expect(Set(angles.map { Int($0.rounded()) }).count >= 5)
    }

    @Test("a tilt is stable across the exact ids the app uses")
    func tiltIsStableForUUIDs() {
        let id = "9E7F2A44-59D1-4B41-9C21-4BD1D0D2A7F0"
        #expect(StampTilt.degrees(for: id) == StampTilt.degrees(for: id))
        #expect(StampTilt.degrees(for: id) != StampTilt.degrees(for: id.lowercased() + "x"))
    }

    /// TC-N-14 — the grain has to be visible as texture and invisible as noise.
    @Test("TC-N-14 the paper grain tile is deterministic, non-uniform and within its ink bounds")
    func TC_N_14_paperGrain() throws {
        let first = PaperTexture.tile(side: 64, seed: 20_260_819)
        let again = PaperTexture.tile(side: 64, seed: 20_260_819)
        let other = PaperTexture.tile(side: 64, seed: 1)

        #expect(first == again, "the same seed must draw the same tile, or the page shimmers on redraw")
        #expect(first != other)
        #expect(first.count == 64 * 64)

        // Texture, not fog: some ink, but a long way from a grey wash.
        let mean = Double(first.reduce(0) { $0 + Int($1) }) / Double(first.count) / 255
        #expect(mean > 0.005, "mean ink \(mean) is so light the grain would not be visible at all")
        #expect(mean < PaperTexture.maximumMeanInk, "mean ink \(mean) would read as dirt, not paper")

        // Non-uniform: at least a handful of distinct values.
        #expect(Set(first).count >= 8)
    }

    /// TC-N-12 — the third ink is held to the same standard as the first two.
    @Test("TC-N-12 the printing ink is registered in the pairings the interface renders")
    func TC_N_12_printingInkIsRegistered() {
        let named = Palette.renderedPairings.filter { $0.name.contains("indigo") }
        #expect(named.count >= 2, "indigo must be checked on both page grounds")
        // The contrast levels themselves are asserted for every pairing by TC-N-07.
    }
}
