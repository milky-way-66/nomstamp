import Foundation
import FoodMapDomain

/// The rules for turning what a device reports into a fix worth using: how accurate, how fresh,
/// and what to do while permission is undecided.
///
/// Separate from `CoreLocationAdapter` so the rules are testable without a device or a
/// simulator — the adapter is left as a thin translation of Core Location's callbacks. It is an
/// actor because the fix arrives on the delegate's queue and is read from whichever task asked
/// for it; a lock around only the waiters left the cached fix racing.
actor LocationFixResolver {

    enum Authorization: Sendable {
        case undecided
        case granted
        case denied
    }

    /// A fix looser than the radius we would match a place within cannot tell two neighbouring
    /// shops apart, so it is not worth reporting at all (FR-1.13).
    static let maxAccuracy: Double = SuggestMealPlaceUseCase.radius

    /// Long enough that walking in from the street reuses the fix, short enough that a fix from
    /// the last restaurant never does (FR-1.14).
    static let maxAge: TimeInterval = 60

    struct Report: Sendable {
        let coordinate: Coordinate
        let accuracy: Double
        let timestamp: Date

        init(coordinate: Coordinate, accuracy: Double, timestamp: Date) {
            self.coordinate = coordinate
            self.accuracy = accuracy
            self.timestamp = timestamp
        }
    }

    private let timeout: TimeInterval
    private let authorization: @Sendable () -> Authorization
    private let requestPermission: @Sendable () -> Void
    private let requestFix: @Sendable () -> Void
    private let now: @Sendable () -> Date

    private var lastReport: Report?
    private var waiting: [CheckedContinuation<LocationFix?, Never>] = []

    init(
        timeout: TimeInterval = 6,
        authorization: @escaping @Sendable () -> Authorization,
        requestPermission: @escaping @Sendable () -> Void,
        requestFix: @escaping @Sendable () -> Void,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.timeout = timeout
        self.authorization = authorization
        self.requestPermission = requestPermission
        self.requestFix = requestFix
        self.now = now
    }

    func fix() async -> LocationFix? {
        if let fresh = freshFix() { return fresh }

        switch authorization() {
        case .denied:
            return nil
        case .undecided:
            // The first meal is logged seconds after the first launch, so the permission dialog
            // may still be open. Asking and waiting beats reporting "no location" to a user who
            // is about to say yes (FR-1.15).
            requestPermission()
        case .granted:
            requestFix()
        }

        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            startTimeout()
        }
    }

    /// A fix arrived. Coarse and invalid ones are dropped rather than cached: a 1.5 km
    /// cell-tower fix must not become the answer just because it came first.
    func received(_ reports: [Report]) {
        let usable = reports
            .filter { $0.accuracy >= 0 && $0.accuracy <= Self.maxAccuracy }
            .max { $0.timestamp < $1.timestamp }

        guard let usable else { return }
        lastReport = usable
        resumeWaiting(with: LocationFix(coordinate: usable.coordinate, accuracy: usable.accuracy))
    }

    /// Core Location gave up. Anything cached and still fresh is better than nothing.
    func failed() {
        resumeWaiting(with: freshFix())
    }

    func authorizationChanged() {
        guard !waiting.isEmpty else { return }
        switch authorization() {
        case .granted: requestFix()
        case .denied: resumeWaiting(with: nil)
        case .undecided: break
        }
    }

    private func freshFix() -> LocationFix? {
        guard let lastReport, now().timeIntervalSince(lastReport.timestamp) <= Self.maxAge else { return nil }
        return LocationFix(coordinate: lastReport.coordinate, accuracy: lastReport.accuracy)
    }

    private func startTimeout() {
        // The task inherits this actor's isolation, so `timedOut()` is already a call on the
        // actor by the time the sleep returns — no `await`, and no hop that could let a second
        // fix arrive between the two.
        Task { [timeout] in
            try? await Task.sleep(for: .seconds(timeout))
            self.timedOut()
        }
    }

    /// The wait is over. `freshFix()` and not `lastReport`, so a fix that has aged out during
    /// the wait is not handed back as if it were current (FR-1.14).
    private func timedOut() {
        resumeWaiting(with: freshFix())
    }

    private func resumeWaiting(with fix: LocationFix?) {
        let pending = waiting
        waiting.removeAll()
        for continuation in pending {
            continuation.resume(returning: fix)
        }
    }
}
