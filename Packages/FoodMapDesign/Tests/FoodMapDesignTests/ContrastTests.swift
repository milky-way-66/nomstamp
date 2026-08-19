import Testing
@testable import FoodMapDesign

@Suite("Non-functional — colour contrast")
struct ContrastTests {

    /// TC-N-07 / NFR-6.4 — every pairing the interface renders, in both appearances, has to
    /// meet its WCAG AA level. ADR-003 asserted this by hand; this makes it enforceable.
    @Test("TC-N-07 every rendered colour pairing meets WCAG AA", arguments: Palette.Appearance.allCases)
    func TC_N_07_paletteMeetsWCAGAA(appearance: Palette.Appearance) {
        for pairing in Palette.renderedPairings {
            let ratio = Contrast.ratio(
                Palette.value(pairing.foreground, in: appearance),
                Palette.value(pairing.background, in: appearance)
            )
            #expect(
                ratio >= pairing.minimum,
                """
                \(pairing.name) in \(appearance.rawValue) mode is \
                \(String(format: "%.2f", ratio)):1, needs \(pairing.minimum):1
                """
            )
        }
    }

    /// The maths itself, against the two values everyone can check by hand.
    @Test("contrast maths matches the known extremes")
    func knownRatios() {
        #expect(Contrast.ratio(0xFFFFFF, 0x000000) == 21)
        #expect(Contrast.ratio(0x808080, 0x808080) == 1)
    }
}
