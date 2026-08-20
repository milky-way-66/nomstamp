/// How well a place's stamp was printed (ADR-005).
///
/// The score already picks the ink (`RatingMood`); this decides the *craft*. One star is a stamp
/// banged on crooked with a tired pad — the second ink misses, the rule around it is thin and
/// broken, the impression is soft. Five stars is the one the printer was proud of: square on the
/// page, tight registration, a full-weight rule with an inner hairline and corner ticks, lifted
/// off the paper. A reader should be able to tell the two apart at pin size, across a room, with
/// no text and no colour vision.
///
/// Everything below is read off a single `quality`, which is what keeps the five steps ordered:
/// no property may improve as the score falls (TC-N-22). It is deliberately a plain value type
/// with no SwiftUI in it, so the ramp can be asserted without a simulator.
public struct StampPress: Sendable, Equatable {
    /// 0 is the worst impression the press can make, 1 the best. Nothing outside 0...1.
    public let quality: Double

    /// What no score at all prints at.
    ///
    /// A competent middle, and deliberately *not* the bottom of the ramp: an unrated place is a
    /// place nobody has judged yet, and printing it as badly as a one-star place would be the app
    /// putting words in the reader's mouth. Same rule `RatingMood` follows for ink.
    public static let unratedQuality: Double = 0.55

    public init(quality: Double) {
        self.quality = min(max(quality, 0), 1)
    }

    /// The press a score prints at. `nil` — unrated, or a place you have only wished for — comes
    /// out at `unratedQuality`.
    public static func press(for score: Int?) -> StampPress {
        guard let mood = RatingMood.mood(for: score) else { return StampPress(quality: unratedQuality) }
        // 1...5 across the full range, so one star is the worst impression and five the best.
        return StampPress(quality: Double(mood.rawValue - 1) / 4)
    }

    // MARK: - What the press decides
    //
    // Each of these is monotonic in `quality` by construction. The constants are the two ends of
    // the ramp; nothing in between is special-cased, because a special case is how a ramp stops
    // being ordered.

    /// Multiplies the place's own tilt. A bad stamp is banged on crooked; a good one is square.
    public var tiltScale: Double { interpolate(from: 2.4, to: 0.15) }

    /// How far the second ink misses, in points. The whole point of the misregistration is that a
    /// press is a physical thing — a bad one misses by a mile.
    public var misregistration: Double { interpolate(from: 3.2, to: 0.4) }

    /// The weight of the rule printed around the stamp.
    public var ruleWidth: Double { interpolate(from: 0.8, to: 2.2) }

    /// How solid that rule comes out. A worn pad prints grey where it should print ink.
    public var ruleOpacity: Double { interpolate(from: 0.42, to: 1) }

    /// The dash pattern of the rule, in points, or `nil` for a solid one. A bad impression breaks
    /// up; from three stars the rule holds all the way round.
    public var ruleDash: [Double]? {
        switch quality {
        case ..<0.15: return [2.2, 2.6]
        case ..<0.40: return [5, 2.2]
        default: return nil
        }
    }

    /// How soft the impression is, in points of blur. A rocking hand smears the ink.
    public var smudge: Double { interpolate(from: 1.5, to: 0) }

    /// How far off the page the stamp sits: a shadow radius. A good stamp has been pressed hard
    /// enough to sit proud of the paper; a bad one lies flat and dull.
    public var lift: Double { interpolate(from: 1, to: 8) }

    /// A second, finer rule inside the first. Four stars and up — this is where a stamp starts to
    /// look deliberate rather than merely correct.
    public var hasInnerRule: Bool { quality >= 0.7 }

    /// Ticks at the four corners, the way an engraved stamp is finished. Five stars only.
    public var hasCornerTicks: Bool { quality >= 0.99 }

    private func interpolate(from worst: Double, to best: Double) -> Double {
        worst + (best - worst) * quality
    }
}
