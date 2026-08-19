import Foundation
import SwiftData
import FoodMapDomain
import FoodMapData

/// The composition root — the only place that knows every concrete type.
///
/// Everything else receives what it needs through initialisers, which is what keeps the
/// domain testable and the search provider swappable (ADR-002).
@MainActor
final class AppDependencies {

    let container: ModelContainer
    let places: PlaceRepositoryPort
    let photos: FileSystemPhotoStorage
    let search: PlaceSearchPort
    let location: CoreLocationAdapter
    let clock: ClockPort

    // Use cases
    let logMeal: LogMealUseCase
    let savePlace: SavePlaceUseCase
    let findNearby: FindPlacesNearbyUseCase
    let buildPins: BuildMapPinsUseCase
    let deleteMeal: DeleteMealUseCase
    let deletePlace: DeletePlaceUseCase
    let suggestContext: SuggestMealContextUseCase

    /// UI tests launch with `-UITestMode` so journeys run against an in-memory store and
    /// stubbed search — no live Apple Maps, no real GPS, no camera (ADR-002 §5.3).
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestMode")
    }

    init() {
        let schema = Schema([PlaceEntity.self, MealEntity.self, PhotoEntity.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: Self.isUITesting
        )
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the local food map store: \(error)")
        }

        let context = ModelContext(container)
        places = SwiftDataPlaceRepository(context: context)

        let photosDirectory = Self.photosDirectory()
        do {
            photos = try FileSystemPhotoStorage(directory: photosDirectory)
        } catch {
            fatalError("Could not prepare photo storage at \(photosDirectory): \(error)")
        }
        PhotoImageLoader.shared.configure(storage: photos)

        search = Self.isUITesting ? StubPlaceSearch() : AppleMapsPlaceSearchAdapter()
        location = CoreLocationAdapter()
        clock = SystemClock()

        logMeal = LogMealUseCase(places: places, photos: photos, clock: clock)
        savePlace = SavePlaceUseCase(places: places, clock: clock)
        findNearby = FindPlacesNearbyUseCase(places: places, location: location)
        buildPins = BuildMapPinsUseCase(places: places)
        deleteMeal = DeleteMealUseCase(places: places, photos: photos)
        deletePlace = DeletePlaceUseCase(places: places, photos: photos)
        suggestContext = SuggestMealContextUseCase(photos: photos, location: location, clock: clock)
    }

    private static func photosDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // UI test runs get a throwaway directory so journeys never touch real photos.
        let name = isUITesting ? "photos-uitest-\(UUID().uuidString)" : "photos"
        return base.appendingPathComponent(name, isDirectory: true)
    }
}

/// Fixed Vietnamese results, so UI journeys are deterministic and work offline.
struct StubPlaceSearch: PlaceSearchPort {
    private static let fixtures = [
        PlaceCandidate(
            id: "stub-1", name: "Phở Thìn", address: "13 Lò Đúc, Hai Bà Trưng",
            coordinate: Coordinate(latitude: 21.0181, longitude: 105.8554),
            providerPlaceID: "stub-1"
        ),
        PlaceCandidate(
            id: "stub-2", name: "Bún chả Hương Liên", address: "24 Lê Văn Hưu",
            coordinate: Coordinate(latitude: 21.0180, longitude: 105.8541),
            providerPlaceID: "stub-2"
        ),
        PlaceCandidate(
            id: "stub-3", name: "Bánh mì Như Lan", address: "Hàm Nghi, Quận 1",
            coordinate: Coordinate(latitude: 10.7711, longitude: 106.7041),
            providerPlaceID: "stub-3"
        )
    ]

    func nearbyFoodPlaces(around coordinate: Coordinate, radius: Double) async throws -> [PlaceCandidate] {
        Self.fixtures
    }

    func search(matching query: String, near coordinate: Coordinate?) async throws -> [PlaceCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return Self.fixtures.filter {
            PlaceMatcher.normalized($0.name).contains(PlaceMatcher.normalized(trimmed))
        }
    }
}
