import Foundation
@testable import FoodMapDomain

/// In-memory stand-in for persistence. Lets every domain rule be tested without SwiftData,
/// which is the entire reason domain entities are plain structs (ADR-002 §2).
final class InMemoryPlaceRepository: PlaceRepositoryPort, @unchecked Sendable {
    private(set) var storage: [Place.ID: Place] = [:]
    var saveError: Error?

    init(_ places: [Place] = []) {
        for place in places { storage[place.id] = place }
    }

    func allPlaces() throws -> [Place] {
        Array(storage.values).sorted { $0.createdAt < $1.createdAt }
    }

    func place(withID id: Place.ID) throws -> Place? {
        storage[id]
    }

    func save(_ place: Place) throws {
        if let saveError { throw saveError }
        storage[place.id] = place
    }

    func deletePlace(withID id: Place.ID) throws {
        storage[id] = nil
    }

    var count: Int { storage.count }
}

/// Records what it was asked to store and delete, so tests can assert on cleanup after a
/// failure — the orphaned-file bug that TC-1-08 and TC-3-04 exist to catch.
final class FakePhotoStorage: PhotoStoragePort, @unchecked Sendable {
    var metadata = PhotoMetadata()
    /// Per-image metadata, keyed by the image data, for the cases where photos of one meal
    /// disagree about when and where it happened (TC-1-25).
    var metadataByImage: [Data: PhotoMetadata] = [:]
    /// When set, the nth call to `store` throws. 0 means the first call fails.
    var failStoreAtIndex: Int?

    private(set) var stored: [Photo] = []
    private(set) var deleted: [Photo] = []
    private var storeCallCount = 0

    func store(imageData: Data) throws -> Photo {
        defer { storeCallCount += 1 }
        if let failStoreAtIndex, storeCallCount == failStoreAtIndex {
            throw DomainError.photoStorageFailed
        }
        let id = UUID()
        let photo = Photo(
            id: id,
            filename: "\(id).jpg",
            thumbnailFilename: "\(id)_thumb.jpg",
            width: 1000,
            height: 800,
            takenAt: metadata.takenAt,
            coordinate: metadata.coordinate
        )
        stored.append(photo)
        return photo
    }

    func delete(_ photo: Photo) {
        deleted.append(photo)
    }

    func readMetadata(from imageData: Data) -> PhotoMetadata {
        metadataByImage[imageData] ?? metadata
    }

    /// Photos written but not cleaned up — must be empty after a failed save.
    var leaked: [Photo] {
        stored.filter { photo in !deleted.contains(where: { $0.id == photo.id }) }
    }
}

struct FixedClock: ClockPort {
    let now: Date
}

final class FakeLocation: LocationPort, @unchecked Sendable {
    var coordinate: Coordinate?
    /// Metres of uncertainty the fake reports. Ten metres is a good phone fix outdoors.
    var accuracy: Double = 10

    init(_ coordinate: Coordinate? = nil, accuracy: Double = 10) {
        self.coordinate = coordinate
        self.accuracy = accuracy
    }

    func currentFix() async -> LocationFix? {
        coordinate.map { LocationFix(coordinate: $0, accuracy: accuracy) }
    }
}

final class FakePlaceSearch: PlaceSearchPort, @unchecked Sendable {
    var nearby: [PlaceCandidate] = []
    var results: [PlaceCandidate] = []
    var error: Error?

    func nearbyFoodPlaces(around coordinate: Coordinate, radius: Double) async throws -> [PlaceCandidate] {
        if let error { throw error }
        return nearby
    }

    func search(matching query: String, near coordinate: Coordinate?) async throws -> [PlaceCandidate] {
        if let error { throw error }
        return results
    }
}

// MARK: - Fixtures

enum Fixture {
    /// Real Vietnamese places, so tests exercise the diacritics and density the app will meet.
    static let phoThin = Coordinate(latitude: 21.0181, longitude: 105.8554)
    static let bunChaHuongLien = Coordinate(latitude: 21.0180, longitude: 105.8541)
    static let hanoiOldQuarter = Coordinate(latitude: 21.0333, longitude: 105.8500)
    static let hcmcDistrict1 = Coordinate(latitude: 10.7769, longitude: 106.7009)

    static let epoch = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01T00:00:00Z

    /// A degree of latitude is ~111 km everywhere, which is exact enough for "a few dozen metres
    /// up the street".
    static func offset(_ coordinate: Coordinate, metresNorth: Double) -> Coordinate {
        Coordinate(latitude: coordinate.latitude + metresNorth / 111_000, longitude: coordinate.longitude)
    }

    static func place(
        id: UUID = UUID(),
        name: String = "Phở Thìn",
        at coordinate: Coordinate = phoThin,
        providerPlaceID: String? = nil,
        note: String? = nil,
        tags: [String] = [],
        meals: [Meal] = [],
        createdAt: Date = epoch
    ) -> Place {
        Place(
            id: id,
            name: name,
            coordinate: coordinate,
            providerPlaceID: providerPlaceID,
            note: note,
            tags: tags,
            createdAt: createdAt,
            meals: meals
        )
    }

    static func meal(
        id: UUID = UUID(),
        eatenAt: Date = epoch,
        photos: [Photo] = [photo()]
    ) -> Meal {
        Meal(id: id, eatenAt: eatenAt, photos: photos)
    }

    static func photo(id: UUID = UUID()) -> Photo {
        Photo(id: id, filename: "\(id).jpg", thumbnailFilename: "\(id)_t.jpg", width: 100, height: 100)
    }

    static let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
}
