import Foundation

/// How far off square a place's stamp sits (ADR-005).
///
/// Derived from the place's id rather than random, for two reasons: a map that re-tilts its pins on
/// every redraw looks broken, and a place should keep its own angle the way a stamp keeps the way it
/// was stuck down.
public enum StampTilt {
    /// Degrees. Four was the limit while every stamp was the same shape, and at that range it read
    /// as a rendering tolerance rather than as a hand. With eight cuts on the page (`StampCut`) the
    /// eye has something to measure the angle against, so it goes to ±14° — stuck down the way a
    /// child sticks things in an album, which is the register the whole app is drawn in.
    public static let limit: Double = 14

    public static func degrees(for id: String) -> Double {
        // A small deterministic hash — FNV-1a — because `hashValue` is seeded per process and would
        // give the same place a different angle on every launch.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        // 61 steps across a wider range, so neighbouring pins rarely share an angle.
        let step = Double(hash % 61) / 60
        return (step * 2 - 1) * limit
    }
}
