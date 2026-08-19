import Foundation
import CoreLocation
import FoodMapDomain

/// Core Location implementation of `LocationPort`.
///
/// Returns nil rather than throwing when a fix is unavailable, because a denied permission
/// must degrade the experience and never block logging a meal (UC-1 / E1). GPS itself is
/// satellite-based, so this keeps working with no data connection.
public final class CoreLocationAdapter: NSObject, LocationPort, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let lock = NSLock()
    private var waiting: [CheckedContinuation<Coordinate?, Never>] = []
    private var lastFix: CLLocation?

    /// How long to wait for a fix before giving up and letting the user pick a place by hand.
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 6) {
        self.timeout = timeout
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public var isAuthorized: Bool {
        // `authorizedWhenInUse` does not exist on macOS, where the package is compiled only so
        // that the rest of the data layer stays testable without a simulator.
        #if os(iOS)
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        return authorizationStatus == .authorizedAlways
        #endif
    }

    public func requestPermission() {
        #if os(iOS)
        manager.requestWhenInUseAuthorization()
        #endif
    }

    public func currentCoordinate() async -> Coordinate? {
        if let recent = lastFix, recent.timestamp.timeIntervalSinceNow > -60 {
            return Self.coordinate(from: recent)
        }
        guard isAuthorized else { return nil }

        manager.requestLocation()
        return await withCheckedContinuation { continuation in
            lock.lock()
            waiting.append(continuation)
            lock.unlock()

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.timeout ?? 6))
                self?.resumeWaiting(with: self?.lastFix)
            }
        }
    }

    private func resumeWaiting(with location: CLLocation?) {
        lock.lock()
        let pending = waiting
        waiting.removeAll()
        lock.unlock()

        let coordinate = location.map(Self.coordinate(from:))
        for continuation in pending {
            continuation.resume(returning: coordinate)
        }
    }

    private static func coordinate(from location: CLLocation) -> Coordinate {
        Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastFix = latest
        resumeWaiting(with: latest)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resumeWaiting(with: lastFix)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if !isAuthorized {
            resumeWaiting(with: nil)
        }
    }
}
