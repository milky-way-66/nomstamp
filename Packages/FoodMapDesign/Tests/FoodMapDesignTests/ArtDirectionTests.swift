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

    /// TC-N-13 — the other half: the frame a place is dealt. Stable, spread across the whole
    /// family, and uncorrelated with the tilt, so a page is not all one shape leaning one way.
    @Test("TC-N-13 stamp cuts are deterministic and a page uses every one of them")
    func TC_N_13_stampCut() {
        let ids = (0..<200).map { "place-\($0)" }
        let cuts = ids.map { StampCut.cut(for: $0) }

        for (id, cut) in zip(ids, cuts) {
            #expect(StampCut.cut(for: id) == cut, "a place must keep the frame it was dealt")
        }

        // Every issue turns up, and none of them takes over the page.
        #expect(Set(cuts) == Set(StampCut.allCases))
        for cut in StampCut.allCases {
            let share = Double(cuts.filter { $0 == cut }.count) / Double(cuts.count)
            #expect(share > 0.08 && share < 0.4, "\(cut) is dealt \(share) of the time")
        }

        // A page of one cut must not also be a page of one angle.
        let galleryAngles = Set(ids.filter { StampCut.cut(for: $0) == .gallery }
            .map { Int(StampTilt.degrees(for: $0).rounded()) })
        #expect(galleryAngles.count >= 5)
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

    /// TC-N-22 — the point of the press ramp is that it is *ordered*: a reader learns "crooked and
    /// smudged is bad, square and crisp is good" once, and every step has to keep that promise.
    @Test("TC-N-22 the stamp press improves at every step of the score, and never backwards")
    func TC_N_22_stampPressIsOrdered() {
        let presses = (1...5).map { StampPress.press(for: $0) }

        for (worse, better) in zip(presses, presses.dropFirst()) {
            #expect(better.quality > worse.quality)
            #expect(better.tiltScale < worse.tiltScale, "a better-rated stamp must sit straighter")
            #expect(better.ruleWidth > worse.ruleWidth, "and carry a heavier rule")
            #expect(better.ruleOpacity > worse.ruleOpacity, "in more solid ink")
        }

        // The two ends are the ends: one star is the worst impression, five the best.
        #expect(presses.first?.quality == 0)
        #expect(presses.last?.quality == 1)

        // The one ornament arrives at the top of the ramp and nowhere else.
        #expect(presses.filter(\.hasInnerRule).count == 1, "an inner rule is a five-star mark")
    }

    /// The other half of TC-N-22, and the same rule `RatingMood` follows for ink: nobody has judged
    /// this place yet, so the app must not print it as though somebody had, and badly.
    @Test("TC-N-22 an unrated place prints at the competent middle, not at the bottom of the ramp")
    func TC_N_22_unratedIsNotPoor() {
        let unrated = StampPress.press(for: nil)

        #expect(unrated.quality == StampPress.unratedQuality)
        #expect(unrated.quality > StampPress.press(for: 1).quality)
        #expect(unrated.quality > StampPress.press(for: 2).quality)
        #expect(unrated.quality < StampPress.press(for: 5).quality)
        #expect(!unrated.hasInnerRule, "and is not decorated as though it had earned it")

        // Anything off the scale is unjudged too, not badly judged.
        #expect(StampPress.press(for: 0) == unrated)
        #expect(StampPress.press(for: 9) == unrated)
    }

    /// A quality is a fraction, whatever it is handed.
    @Test("a press quality is clamped to 0...1")
    func pressQualityIsClamped() {
        #expect(StampPress(quality: -3).quality == 0)
        #expect(StampPress(quality: 42).quality == 1)
    }

    /// TC-N-12 — the third ink is held to the same standard as the first two.
    @Test("TC-N-12 the printing ink is registered in the pairings the interface renders")
    func TC_N_12_printingInkIsRegistered() {
        let named = Palette.renderedPairings.filter { $0.name.contains("printing ink") }
        #expect(named.count >= 2, "the printing ink must be checked on both page grounds")
        // The contrast levels themselves are asserted for every pairing by TC-N-07.
    }

    /// TC-N-16 — a tear is torn once. The edge has to be identical between redraws, stay inside
    /// its bounds, and not collapse into a straight line.
    @Test("TC-N-16 the deckle edge is deterministic, bounded and uneven")
    func deckleEdgeIsDeterministicAndUneven() {
        let edge = DeckleEdge.amplitudes(count: 24)

        #expect(edge == DeckleEdge.amplitudes(count: 24))
        #expect(edge.count == 24)
        #expect(edge.allSatisfy { $0 >= DeckleEdge.minimumAmplitude && $0 <= DeckleEdge.maximumAmplitude })
        #expect(Set(edge).count >= 12, "A tear with a handful of distinct depths reads as a pattern")
        #expect(DeckleEdge.amplitudes(count: 24, seed: 99) != edge)
        #expect(DeckleEdge.amplitudes(count: 0).isEmpty)
    }

    /// TC-N-17 — the rating ramp. An unrated meal has no mood (absence is not a low score), the
    /// scale covers exactly 1...5, each step is a distinct ink, and every one of them is a pairing
    /// the contrast test checks.
    @Test("TC-N-17 the rating moods map the scale and are all contrast-checked")
    func ratingMoodsCoverTheScale() {
        #expect(RatingMood.mood(for: nil) == nil)
        #expect(RatingMood.mood(for: 0) == nil)
        #expect(RatingMood.mood(for: 6) == nil)
        #expect(RatingMood.mood(for: 1) == .poor)
        #expect(RatingMood.mood(for: 5) == .best)
        #expect(RatingMood.allCases.count == 5)

        let inks = RatingMood.allCases.map(\.ink)
        #expect(Set(inks.map(\.light)).count == 5, "Each step of the ramp needs its own ink")
        #expect(Set(inks.map(\.dark)).count == 5)

        for mood in RatingMood.allCases {
            #expect(
                Palette.renderedPairings.contains { $0.foreground == mood.ink },
                "The ink for \(mood) is drawn as text, so it has to be in the checked pairings"
            )
        }
    }

    /// TC-N-18 — re-inking the press must not cost anyone their legibility. Every skin is held to
    /// exactly the levels the default one is, in both appearances, so a skin that looks lovely and
    /// reads badly fails here rather than shipping (ADR-006, NFR-6.4).
    @Test("TC-N-18 every skin meets its contrast levels in both appearances", arguments: Skin.allCases, Palette.Appearance.allCases)
    func TC_N_18_everySkinIsLegible(skin: Skin, appearance: Palette.Appearance) {
        for pairing in Palette.renderedPairings(for: skin) {
            let ratio = Contrast.ratio(
                Palette.value(pairing.foreground, in: appearance),
                Palette.value(pairing.background, in: appearance)
            )
            #expect(
                ratio >= pairing.minimum,
                """
                the \(skin.rawValue) skin: \(pairing.name) in \(appearance.rawValue) mode is \
                \(String(format: "%.2f", ratio)):1, needs \(pairing.minimum):1
                """
            )
        }
    }

    /// TC-N-18 — a skin is a printing, not a repaint: the page and the rating ramp are the same on
    /// all five, and only the accents move. Without this a skin could quietly change what a score
    /// means, or make body text unreadable in a way TC-N-07 would never see.
    @Test("TC-N-18 skins re-ink the accents and leave the page alone")
    func TC_N_18_skinsChangeOnlyTheAccents() {
        for skin in Skin.allCases {
            let pairings = Palette.renderedPairings(for: skin)
            let paperPairing = pairings.first { $0.name == "ink on paper" }
            #expect(paperPairing?.background == Palette.paper, "\(skin.rawValue) must print on the same paper")
            #expect(paperPairing?.foreground == Palette.ink, "\(skin.rawValue) must use the same body ink")
            #expect(
                pairings.contains { $0.foreground == RatingMood.best.ink },
                "\(skin.rawValue) must keep the rating ramp: five stars mean the same on every printing"
            )
        }
    }

    /// TC-N-18 — the two kinds of pin must stay tellable apart by colour as well as by shape, on
    /// every skin.
    ///
    /// The measure is hue, not contrast: both accents have to clear AAA against the same paper, so
    /// their luminances are necessarily close, and a lightness test would only be re-asserting that.
    /// What has to differ is which colour they are.
    @Test("TC-N-18 visited and wishlist inks stay distinct on every skin", arguments: Skin.allCases)
    func TC_N_18_accentsAreDistinct(skin: Skin) {
        #expect(skin.visitedInk != skin.wishlistInk)
        for appearance in Palette.Appearance.allCases {
            let separation = Contrast.hueSeparation(
                Palette.value(skin.visitedInk, in: appearance),
                Palette.value(skin.wishlistInk, in: appearance)
            )
            #expect(
                separation >= 40,
                """
                \(skin.rawValue)'s accents are only \(String(format: "%.0f", separation))° apart in \
                \(appearance.rawValue): been-here and want-to-go would read as one colour
                """
            )
        }
    }
}
