import Foundation
import CoreLocation
import FoodMapDomain

/// Core Location implementation of `LocationPort`.
///
/// Deliberately thin: every rule about which fixes are usable lives in `LocationFixResolver`,
/// which is testable without a device. This type only translates Core Location's vocabulary —
/// authorisation constants, `CLLocation`, delegate callbacks — into the resolver's.
///
/// Returns nil rather than throwing when a fix is unavailable, because a denied permission must
/// degrade the experience and never block logging a meal (UC-1 / E1). GPS itself is
/// satellite-based, so this keeps working with no data connection.
public final class CoreLocationAdapter: NSObject, LocationPort, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let resolver: LocationFixResolver

    public init(timeout: TimeInterval = 6) {
        let manager = self.manager
        resolver = LocationFixResolver(
            timeout: timeout,
            authorization: { Self.authorization(of: manager.authorizationStatus) },
            requestPermission: {
                #if os(iOS)
                manager.requestWhenInUseAuthorization()
                #endif
            },
            requestFix: { manager.requestLocation() }
        )
        super.init()
        manager.delegate = self
        // A request, not a promise: what actually arrives is judged on its reported accuracy.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public var isAuthorized: Bool {
        Self.authorization(of: authorizationStatus) == .granted
    }

    public func requestPermission() {
        #if os(iOS)
        manager.requestWhenInUseAuthorization()
        #endif
    }

    public func currentFix() async -> LocationFix? {
        await resolver.fix()
    }

    private static func authorization(of status: CLAuthorizationStatus) -> LocationFixResolver.Authorization {
        switch status {
        case .notDetermined:
            return .undecided
        #if os(iOS)
        case .authorizedWhenInUse, .authorizedAlways:
            return .granted
        #else
        case .authorizedAlways:
            return .granted
        #endif
        default:
            // `restricted` and `denied` are both "not going to happen" as far as the user's
            // meal is concerned.
            return .denied
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let reports = locations.map {
            LocationFixResolver.Report(
                coordinate: Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                accuracy: $0.horizontalAccuracy,
                timestamp: $0.timestamp
            )
        }
        Task { await resolver.received(reports) }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await resolver.failed() }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { await resolver.authorizationChanged() }
    }
}
