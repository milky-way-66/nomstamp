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

    /// Freshness and validity are properties of the *fix*, and belong here. Precision is a
    /// property of the *question* — only place preselection needs 120 m — and belongs to
    /// `SuggestMealPlaceUseCase`. Filtering coarse fixes out here left Near Me, the appearance
    /// and the map with no position at all in any ordinary restaurant (ADR-004, 21 Aug).

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
    private let stopFix: @Sendable () -> Void
    private let now: @Sendable () -> Date

    private var lastReport: Report?
    private var waiting: [CheckedContinuation<LocationFix?, Never>] = []

    init(
        timeout: TimeInterval = 6,
        authorization: @escaping @Sendable () -> Authorization,
        requestPermission: @escaping @Sendable () -> Void,
        requestFix: @escaping @Sendable () -> Void,
        stopFix: @escaping @Sendable () -> Void = {},
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.timeout = timeout
        self.authorization = authorization
        self.requestPermission = requestPermission
        self.requestFix = requestFix
        self.stopFix = stopFix
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

    /// A fix arrived. Only Core Location's own invalid marker — a negative accuracy — is
    /// dropped. A coarse fix is reported *with* its accuracy so the caller can weigh it; it is
    /// not withheld. Withholding it is what left a reader with permission granted, GPS working
    /// and no position (ADR-004, 21 Aug).
    ///
    /// Updates keep arriving until the request is satisfied, so a first coarse fix is replaced
    /// by the finer one that follows a few seconds later rather than ending the request.
    func received(_ reports: [Report]) {
        let arrived = reports
            .filter { $0.accuracy >= 0 }
            .max { $0.timestamp < $1.timestamp }

        guard let arrived else { return }
        guard isBetter(arrived, than: lastReport) else { return }

        lastReport = arrived
        resumeWaiting(with: LocationFix(coordinate: arrived.coordinate, accuracy: arrived.accuracy))
    }

    /// Newer wins outright; at equal age, tighter wins. A fix that is both older and looser than
    /// what we hold is not an improvement and must not overwrite it.
    private func isBetter(_ candidate: Report, than held: Report?) -> Bool {
        guard let held else { return true }
        if candidate.timestamp > held.timestamp { return true }
        return candidate.timestamp == held.timestamp && candidate.accuracy < held.accuracy
    }

    /// Core Location reported a failure. `kCLErrorLocationUnknown` is documented as transient —
    /// the framework is still trying — so only a denial ends the wait. Everything else lets the
    /// timeout do its job, because ending here turns a delay into a failure (ADR-004, 21 Aug).
    func failed(isTerminal: Bool = false) {
        guard isTerminal else { return }
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
        // Updates run only while somebody is asking: this is a foreground app that wants a
        // position now, not a tracker.
        if !pending.isEmpty { stopFix() }
        for continuation in pending {
            continuation.resume(returning: fix)
        }
    }
}
