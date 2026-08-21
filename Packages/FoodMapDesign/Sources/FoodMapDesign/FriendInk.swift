/// The eight inks friends are printed in, and the cut that says whose stamp this is.
///
/// **The plate is fixed, and the skin does not touch it.** ADR-006 re-inks the press with the
/// weather and the day, but its own principle is that some things stay constant so what a reader
/// reads never moves — the page, the body ink, the rating ramp. A friend's identity belongs in
/// that class: if Lan changed colour when it rained, the ink would stop being an identity
/// (ADR-009, TC-N-26).
///
/// Eight is not an arbitrary supply. Every ink has to clear the AAA floor over paper in both
/// appearances while still reading as part of one palette, and eight is about where a curated set
/// holds before it starts to look like a box of crayons. That the circle is also capped at eight
/// is the same decision seen from the other side.
public enum FriendInk {
    /// Chosen at even visual weight — every one lands within a whisker of 8:1 on paper — so no
    /// friend is louder on the map than another. Spread around the wheel with at least 28° of
    /// separation, in the same register as the skins' own accents, so a fixed plate still reads
    /// as this journal's box of inks rather than as a foreign object on the page.
    public static let plate: [PaletteColor] = [
        PaletteColor(light: 0x6B4023, dark: 0xEAB38E),  // rust
        PaletteColor(light: 0x524B1E, dark: 0xCEC060),  // gold
        PaletteColor(light: 0x2A541B, dark: 0x8AD070),  // leaf
        PaletteColor(light: 0x175442, dark: 0x68D1B2),  // jade
        PaletteColor(light: 0x1B515E, dark: 0x99C6D1),  // teal
        PaletteColor(light: 0x254694, dark: 0xA8BEF4),  // harbour
        PaletteColor(light: 0x761E94, dark: 0xDDAEEC),  // violet
        PaletteColor(light: 0x852552, dark: 0xF0ABCB)   // rose
    ]

    /// Names for the inks, so a failure message and a VoiceOver label can both say which one.
    public static let names = ["rust", "gold", "leaf", "jade", "teal", "harbour", "violet", "rose"]

    public static var slotCount: Int { plate.count }

    /// Wraps rather than traps: an out-of-range slot is a bug upstream, but a map that refuses to
    /// draw is worse than one that draws a friend in the wrong ink.
    public static func ink(forSlot slot: Int) -> PaletteColor {
        plate[((slot % plate.count) + plate.count) % plate.count]
    }

    public static func name(forSlot slot: Int) -> String {
        names[((slot % names.count) + names.count) % names.count]
    }
}

/// The cut of a friend's mark, where one is drawn at all.
///
/// ADR-009 used this to answer *mine or theirs* on the map: the reader's own stamps kept a solid
/// edge and friends' a perforated one. ADR-010 removed that question from the map entirely — a
/// friend's place is drawn exactly as the reader's own — so `forOwner` is gone rather than left
/// as a rule nothing applies. What remains is the shape of the mark itself, in the legend and in
/// lists, where a name sits beside it.
///
/// NFR-6.3 is now carried by `names` above and by the spoken attribution built on it: every ink
/// has a word, so nothing on this map is said in hue alone (ADR-010, TC-N-27).
public enum StampEdge: String, CaseIterable, Sendable {
    case solid
    case perforated

    /// Teeth per edge for a perforated cut; zero for a solid one. A drawn value rather than a
    /// boolean so the renderer has something to lay out.
    public var perforations: Int {
        switch self {
        case .solid: return 0
        case .perforated: return 9
        }
    }
}
