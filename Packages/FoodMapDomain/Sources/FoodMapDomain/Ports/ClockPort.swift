import Foundation

/// Time as an injected input rather than an ambient global.
///
/// Without this, "a meal logged today sorts above yesterday's" cannot be tested, because the
/// test cannot control what `Date()` returns (TC-X-01).
public protocol ClockPort: Sendable {
    var now: Date { get }
}

public struct SystemClock: ClockPort {
    public init() {}
    public var now: Date { Date() }
}
