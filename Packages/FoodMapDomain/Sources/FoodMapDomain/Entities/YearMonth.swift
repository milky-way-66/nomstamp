import Foundation

/// A month, with no day in it.
///
/// The type exists so that coarsening is structural rather than a formatting habit. A `Date`
/// with a day-of-month zeroed out is still a `Date` and can be printed in full by any call site;
/// a `YearMonth` has nowhere to keep the day, so no future edit can leak one (ADR-009, TC-9-04).
public struct YearMonth: Equatable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = max(1, min(12, month))
    }

    /// Uses UTC deliberately. The alternative — the device's zone — would mean a stamp shared
    /// from Hanoi and read in London could disagree about which month a meal fell in.
    public init(_ date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1)
    }

    public var description: String { String(format: "%04d-%02d", year, month) }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
