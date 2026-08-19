import Foundation

/// How far off square a place's stamp sits (ADR-005).
///
/// Derived from the place's id rather than random, for two reasons: a map that re-tilts its pins on
/// every redraw looks broken, and a place should keep its own angle the way a stamp keeps the way it
/// was stuck down.
public enum StampTilt {
    /// Degrees. Beyond about four the pin stops reading as "placed by hand" and starts reading as
    /// "laid out wrong".
    public static let limit: Double = 4

    public static func degrees(for id: String) -> Double {
        // A small deterministic hash — FNV-1a — because `hashValue` is seeded per process and would
        // give the same place a different angle on every launch.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        // 41 steps across the range, so neighbouring pins rarely share an angle.
        let step = Double(hash % 41) / 40
        return (step * 2 - 1) * limit
    }
}
