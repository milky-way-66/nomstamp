import Foundation

/// Where the user is. Returns nil rather than throwing when unavailable: a denied permission
/// must degrade the experience, never block logging a meal (UC-1 / E1).
public protocol LocationPort: Sendable {
    func currentCoordinate() async -> Coordinate?
}
