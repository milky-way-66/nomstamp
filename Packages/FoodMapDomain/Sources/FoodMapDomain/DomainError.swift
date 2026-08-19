import Foundation

public enum DomainError: Error, Equatable {
    case notImplemented
    case placeNotFound
    case mealNotFound
    case noPhotosProvided
    case photoStorageFailed
}
