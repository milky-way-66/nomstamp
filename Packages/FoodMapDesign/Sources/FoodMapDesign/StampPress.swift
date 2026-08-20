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
    // Three moves, and no more. An earlier version reached for the whole vocabulary of a bad print
    // — a broken rule, a smudged impression, a second ink missing by three points — and the result
    // read as a rendering fault at one star and as a badge at five. Each of these is monotonic in
    // `quality` by construction, and nothing in between is special-cased, because a special case is
    // how a ramp stops being ordered.

    /// Multiplies the place's own tilt. A stamp nobody was thinking about goes on slightly askew.
    /// Small numbers on purpose: the tilt is a hint, and past a few degrees it reads as breakage.
    public var tiltScale: Double { interpolate(from: 1.3, to: 0.2) }

    /// The weight of the rule printed around the stamp. Heavy even at the bottom of the ramp: the
    /// app is drawn with a contour around everything (ADR-005, the cartoon rule), and a bad print is
    /// a wobbly bold line, not a faint one.
    public var ruleWidth: Double { interpolate(from: 1.6, to: 3) }

    /// How solid that rule comes out — pale at the bottom of the ramp, full ink at the top.
    public var ruleOpacity: Double { interpolate(from: 0.7, to: 1) }

    /// A second, finer rule set inside the first. Five stars alone: an ornament that arrived at
    /// three would stop meaning anything.
    public var hasInnerRule: Bool { quality >= 0.99 }

    private func interpolate(from worst: Double, to best: Double) -> Double {
        worst + (best - worst) * quality
    }
}
