import Testing
import Foundation
import FoodMapDomain
@testable import FoodMapData

/// UC-1 / 3 — which device fixes are worth using (FR-1.13 … FR-1.15).
///
/// Against `LocationFixResolver` rather than `CoreLocationAdapter`, because these are the rules
/// and the adapter is only Core Location's vocabulary translated into them.
@Suite("UC-1 Location fixes")
struct LocationFixResolverTests {

    private let hanoi = Coordinate(latitude: 21.0181, longitude: 105.8554)
    private let epoch = Date(timeIntervalSince1970: 1_767_225_600)

    /// TC-1-22 / TC-1-35 — an *invalid* fix is not a fix; a *coarse* one is, and is reported
    /// with its accuracy so the caller can weigh it.
    ///
    /// This test used to assert that a coarse fix produced no coordinate. That was the bug:
    /// the 120 m ceiling belongs to place preselection (FR-1.13), and applying it here left
    /// Near Me, the appearance and the map with nothing in any ordinary restaurant
    /// (ADR-004, 21 Aug).
    @Test("An invalid fix is discarded; a coarse one is reported with its accuracy")
    func TC_1_35_coarseFixIsReportedAndInvalidIsNot() async {
        let requested = Counter()
        let sut = LocationFixResolver(
            timeout: 0.2,
            authorization: { .granted },
            requestPermission: {},
            requestFix: { requested.bump() },
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([
                .init(coordinate: hanoi, accuracy: 1_500, timestamp: epoch),
                .init(coordinate: hanoi, accuracy: -1, timestamp: epoch),
            ])
        }

        let fix = await sut.fix()
        #expect(fix?.coordinate == hanoi)
        #expect(fix?.accuracy == 1_500, "the coarse fix is the answer; the invalid one never is")
        #expect(requested.value == 1)

        // The rule FR-1.13 actually states still holds — one layer up, where it belongs.
        // TC-1-21 proves it against `SuggestMealPlaceUseCase` in the domain suite.
    }

    /// TC-1-36 — a first coarse fix must not end the request; the finer one that follows wins.
    @Test("A better fix replaces a worse one rather than ending the request")
    func TC_1_36_betterFixWins() async {
        let stopped = Counter()
        let sut = LocationFixResolver(
            timeout: 1,
            authorization: { .granted },
            requestPermission: {},
            requestFix: {},
            stopFix: { stopped.bump() },
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([.init(coordinate: hanoi, accuracy: 400, timestamp: epoch)])
            await sut.received([.init(coordinate: hanoi, accuracy: 18, timestamp: epoch.addingTimeInterval(2))])
        }

        // The waiter is resumed by the first usable fix — nobody is left waiting for perfect.
        #expect(await sut.fix()?.accuracy == 400)
        // And the finer fix has replaced it for the next caller, inside the freshness window.
        #expect(await sut.fix()?.accuracy == 18)
        #expect(stopped.value >= 1, "updates stop once somebody has their answer")
    }

    /// TC-1-37 — `kCLErrorLocationUnknown` means "still trying", not "cannot".
    @Test("A transient failure does not end the wait; a denial does")
    func TC_1_37_transientFailureDoesNotEndTheWait() async {
        let sut = LocationFixResolver(
            timeout: 1,
            authorization: { .granted },
            requestPermission: {},
            requestFix: {},
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.failed(isTerminal: false)
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([.init(coordinate: hanoi, accuracy: 25, timestamp: epoch)])
        }

        #expect(await sut.fix()?.accuracy == 25, "the transient failure must not have ended it")
    }

    @Test("A fix within the radius is reported, with its accuracy")
    func usableFixIsReported() async {
        let sut = LocationFixResolver(
            timeout: 1,
            authorization: { .granted },
            requestPermission: {},
            requestFix: {},
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([.init(coordinate: hanoi, accuracy: 12, timestamp: epoch)])
        }

        let fix = await sut.fix()
        #expect(fix?.coordinate == hanoi)
        #expect(fix?.accuracy == 12)
    }

    /// TC-1-23 — a stale fix must not survive a timeout.
    @Test("A fix older than a minute is not returned, even when the wait times out")
    func TC_1_23_staleFixIsNotReused() async {
        let clock = MutableClock(epoch)
        let sut = LocationFixResolver(
            timeout: 0.2,
            authorization: { .granted },
            requestPermission: {},
            requestFix: {},
            now: { clock.value }
        )

        // A good fix, cached.
        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([.init(coordinate: hanoi, accuracy: 12, timestamp: epoch)])
        }
        #expect(await sut.fix() != nil)

        // Five minutes and one restaurant later, the cached fix is worthless — and the wait for
        // a new one times out with nothing arriving.
        clock.value = epoch.addingTimeInterval(300)
        #expect(await sut.fix() == nil)
    }

    @Test("A fresh cached fix is reused without asking the device again")
    func freshFixIsReused() async {
        let requested = Counter()
        let clock = MutableClock(epoch)
        let sut = LocationFixResolver(
            timeout: 0.2,
            authorization: { .granted },
            requestPermission: {},
            requestFix: { requested.bump() },
            now: { clock.value }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await sut.received([.init(coordinate: hanoi, accuracy: 12, timestamp: epoch)])
        }
        _ = await sut.fix()

        clock.value = epoch.addingTimeInterval(30)
        #expect(await sut.fix()?.coordinate == hanoi)
        #expect(requested.value == 1, "the second call should not have asked the device again")
    }

    /// TC-1-24 — the permission dialog may still be open when the first meal is logged.
    @Test("An undecided permission is requested and awaited, and a later grant yields the fix")
    func TC_1_24_undecidedPermissionIsAwaited() async {
        let status = MutableAuthorization(.undecided)
        let asked = Counter()
        let sut = LocationFixResolver(
            timeout: 2,
            authorization: { status.value },
            requestPermission: { asked.bump() },
            requestFix: {},
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            status.value = .granted
            await sut.authorizationChanged()
            await sut.received([.init(coordinate: hanoi, accuracy: 12, timestamp: epoch)])
        }

        #expect(await sut.fix()?.coordinate == hanoi)
        #expect(asked.value == 1, "permission should have been requested rather than assumed lost")
    }

    @Test("A denial while waiting ends the wait immediately")
    func denialEndsTheWait() async {
        let status = MutableAuthorization(.undecided)
        let sut = LocationFixResolver(
            timeout: 5, // long, so a passing test proves the denial and not the timeout
            authorization: { status.value },
            requestPermission: {},
            requestFix: {},
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            status.value = .denied
            await sut.authorizationChanged()
        }

        #expect(await sut.fix() == nil)
    }

    @Test("An already denied permission never asks the device for a fix")
    func deniedPermissionAsksNothing() async {
        let requested = Counter()
        let sut = LocationFixResolver(
            timeout: 5,
            authorization: { .denied },
            requestPermission: {},
            requestFix: { requested.bump() },
            now: { self.epoch }
        )

        #expect(await sut.fix() == nil)
        #expect(requested.value == 0)
    }

    @Test("Every waiter is answered by one fix")
    func concurrentCallersShareOneFix() async {
        let sut = LocationFixResolver(
            timeout: 1,
            authorization: { .granted },
            requestPermission: {},
            requestFix: {},
            now: { self.epoch }
        )

        Task {
            try? await Task.sleep(for: .milliseconds(40))
            await sut.received([.init(coordinate: hanoi, accuracy: 12, timestamp: epoch)])
        }

        async let first = sut.fix()
        async let second = sut.fix()
        let fixes = await [first, second]

        #expect(fixes.allSatisfy { $0?.coordinate == hanoi })
    }
}

/// A counter shared with a `@Sendable` closure. A class, not a captured `var`, because the
/// resolver's callbacks are called from its own isolation.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func bump() {
        lock.withLock { count += 1 }
    }
}

private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) { self.date = date }

    var value: Date {
        get { lock.withLock { date } }
        set { lock.withLock { date = newValue } }
    }
}

private final class MutableAuthorization: @unchecked Sendable {
    private let lock = NSLock()
    private var status: LocationFixResolver.Authorization

    init(_ status: LocationFixResolver.Authorization) { self.status = status }

    var value: LocationFixResolver.Authorization {
        get { lock.withLock { status } }
        set { lock.withLock { status = newValue } }
    }
}
