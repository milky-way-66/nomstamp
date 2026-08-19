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
    let location: any LocationPort
    let clock: ClockPort

    /// Nil under UI testing, where location is stubbed and there is nothing to ask for.
    private let coreLocation: CoreLocationAdapter?

    // Use cases
    let logMeal: LogMealUseCase
    let savePlace: SavePlaceUseCase
    let findNearby: FindPlacesNearbyUseCase
    let buildPins: BuildMapPinsUseCase
    let rateMeal: RateMealUseCase
    let deleteMeal: DeleteMealUseCase
    let deletePlace: DeletePlaceUseCase
    let suggestContext: SuggestMealContextUseCase
    let suggestPlace: SuggestMealPlaceUseCase

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

        if Self.isUITesting {
            search = StubPlaceSearch()
            location = StubLocation()
            coreLocation = nil
        } else {
            search = AppleMapsPlaceSearchAdapter()
            let adapter = CoreLocationAdapter()
            location = adapter
            coreLocation = adapter
        }
        clock = SystemClock()

        logMeal = LogMealUseCase(places: places, photos: photos, clock: clock)
        savePlace = SavePlaceUseCase(places: places, clock: clock)
        findNearby = FindPlacesNearbyUseCase(places: places, location: location)
        buildPins = BuildMapPinsUseCase(places: places)
        rateMeal = RateMealUseCase(places: places)
        deleteMeal = DeleteMealUseCase(places: places, photos: photos)
        deletePlace = DeletePlaceUseCase(places: places, photos: photos)
        suggestContext = SuggestMealContextUseCase(photos: photos, location: location, clock: clock)
        suggestPlace = SuggestMealPlaceUseCase(places: places, search: search)

        // Seeding belongs here, not in a view's `.task`: done later, it raced the map's first
        // load and the demo places sometimes never appeared at all.
        if DemoSeed.isRequested {
            DemoSeed.apply(to: self)
        }
    }

    func requestLocationPermission() {
        coreLocation?.requestPermission()
    }

    /// A generated JPEG standing in for the camera, which the simulator does not have.
    /// Only reachable under `-UITestMode` (ADR-002 §5.3).
    func testPhotoData() -> Data {
        DemoSeed.placeholderJPEG(hue: 0.09)
    }

    private static func photosDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // UI test runs get a throwaway directory so journeys never touch real photos.
        let name = isUITesting ? "photos-uitest-\(UUID().uuidString)" : "photos"
        return base.appendingPathComponent(name, isDirectory: true)
    }
}

/// A fixed position, so "near me" journeys do not depend on real GPS. `-StubLocationFar`
/// moves the user to Ho Chi Minh City while the saved places stay in Hanoi, which is the
/// "I am in a city where I saved nothing" case (UC-5 / 2a).
struct StubLocation: LocationPort {
    let coordinate: Coordinate

    init() {
        let far = ProcessInfo.processInfo.arguments.contains("-StubLocationFar")
        coordinate = far
            ? Coordinate(latitude: 10.7769, longitude: 106.7009)
            : Coordinate(latitude: 21.0333, longitude: 105.8500)
    }

    /// Ten metres: a good outdoor fix, well inside the preselection radius, so the journeys
    /// exercise the accuracy gate's pass rather than its refusal (FR-1.13).
    func currentFix() async -> LocationFix? {
        LocationFix(coordinate: coordinate, accuracy: 10)
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
        ),
        // Right where `StubLocation` puts the user, so the "the app already knows the place"
        // path (FR-1.11) is exercised end to end.
        PlaceCandidate(
            id: "stub-4", name: "Cà phê Giảng", address: "39 Nguyễn Hữu Huân",
            coordinate: Coordinate(latitude: 21.0333, longitude: 105.8501),
            providerPlaceID: "stub-4"
        )
    ]

    func nearbyFoodPlaces(around coordinate: Coordinate, radius: Double) async throws -> [PlaceCandidate] {
        // Honouring the radius the way a real provider does; otherwise a journey in Hanoi
        // would be offered a Saigon bánh mì.
        Self.fixtures.filter { $0.coordinate.distance(to: coordinate) <= radius }
    }

    func search(matching query: String, near coordinate: Coordinate?) async throws -> [PlaceCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return Self.fixtures.filter {
            PlaceMatcher.normalized($0.name).contains(PlaceMatcher.normalized(trimmed))
        }
    }
}
