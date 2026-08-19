import Testing
import Foundation
@testable import FoodMapDomain

/// NFR-2.2 — the map has to stay smooth with a real collection behind it. The frame rate
/// itself can only be measured on a device; what a unit test *can* pin is the amount of work
/// the pin pipeline does per frame, which is what would cause a dropped frame.
@Suite("Non-functional — map performance")
struct MapPerformanceTests {

    /// Places spread over roughly the whole of Hanoi, so clustering has real work to do
    /// rather than collapsing everything into one bucket.
    private func places(_ count: Int) -> [Place] {
        (0..<count).map { index in
            let row = Double(index / 40), column = Double(index % 40)
            let coordinate = Coordinate(
                latitude: 20.95 + row * 0.004,
                longitude: 105.75 + column * 0.006
            )
            // Half visited, half wishlist, and the visited ones carry a meal each, which is
            // what pin rendering has to look through for a photo.
            let meals = index.isMultiple(of: 2)
                ? [Meal(eatenAt: Date(timeIntervalSince1970: 1_767_225_600), photos: [
                    Photo(filename: "\(index).jpg", thumbnailFilename: "\(index)-t.jpg",
                          width: 2048, height: 1536)
                  ])]
                : []
            return Place(
                name: "Quán \(index)",
                coordinate: coordinate,
                createdAt: Date(timeIntervalSince1970: 1_767_225_600),
                meals: meals
            )
        }
    }

    private let hanoi = MapBounds(
        center: Coordinate(latitude: 21.02, longitude: 105.88),
        latitudeDelta: 0.20,
        longitudeDelta: 0.32
    )

    /// TC-N-03 — 500 places is the figure NFR-2.2 names. One 60 fps frame is 16.6 ms, and the
    /// pin pipeline is only part of that frame, so the budget here is deliberately the whole
    /// frame: if this fails, smoothness is definitely gone.
    @Test("TC-N-03 the pin pipeline for 500 places fits inside one frame")
    func TC_N_03_pinPipelineFitsInAFrame() throws {
        let repository = InMemoryPlaceRepository()
        for place in places(500) { try repository.save(place) }
        let sut = BuildMapPinsUseCase(places: repository)

        // Warm the caches first; the first call also pays for lazy allocation.
        _ = try sut.execute(bounds: hanoi, filter: .all)

        var slowest = Duration.zero
        for _ in 0..<10 {
            let elapsed = try ContinuousClock().measure {
                _ = try sut.execute(bounds: hanoi, filter: .all)
            }
            slowest = max(slowest, elapsed)
        }

        #expect(
            slowest < .milliseconds(16),
            "slowest of 10 pin builds took \(slowest), one 60 fps frame is 16 ms (NFR-2.2)"
        )
    }

    /// TC-N-04 — ten times the required size, to show the cost grows sensibly rather than
    /// quadratically, and that nothing is dropped on the way.
    @Test("TC-N-04 clustering 5,000 places stays quick and loses nothing")
    func TC_N_04_clusteringScales() {
        let all = places(5_000)

        var slowest = Duration.zero
        var result: [PlaceCluster] = []
        for _ in 0..<5 {
            let elapsed = ContinuousClock().measure {
                result = PlaceClusterer.cluster(places: all, in: hanoi)
            }
            slowest = max(slowest, elapsed)
        }

        #expect(
            slowest < .milliseconds(250),
            "slowest of 5 clustering runs took \(slowest), budget is 250 ms"
        )
        // Correctness at scale, not just speed: TC-2-09 proves this at 200 places.
        #expect(result.reduce(0) { $0 + $1.count } == 5_000, "clustering lost or duplicated places")
    }
}

/// NFR-1 — the privacy promise is the product. It is worth an automated guard rather than a
/// line in a document, because the failure mode is silent.
@Suite("Non-functional — privacy")
struct PrivacyGuardTests {

    /// TC-N-08 — no third-party dependency anywhere, and no networking code outside the one
    /// adapter that is allowed to talk to Apple Maps.
    @Test("TC-N-08 nothing sends data anywhere except the place-search adapter")
    func TC_N_08_noUnexpectedNetworkingOrDependencies() throws {
        let root = repositoryRoot()
        let fileManager = FileManager.default

        // 1. No remote dependency, so no third-party analytics can be present. Local path
        // dependencies between our own packages are expected and harmless.
        for manifest in ["Packages/FoodMapDomain/Package.swift", "Packages/FoodMapData/Package.swift"] {
            let source = try String(contentsOf: root.appending(path: manifest), encoding: .utf8)
            let remote = source
                .split(separator: "\n")
                .filter { $0.contains(".package(") && !$0.contains(".package(path:") }
            #expect(remote.isEmpty, "\(manifest) declares a remote dependency: \(remote)")
        }

        // 2. No networking or tracking API outside the search adapter.
        let banned = ["URLSession", "URLRequest", "NSURLConnection", "ASIdentifierManager", "Analytics"]
        let allowed = ["AppleMapsPlaceSearchAdapter.swift"]
        var offenders: [String] = []

        for directory in ["Packages/FoodMapDomain/Sources", "Packages/FoodMapData/Sources", "FoodMap"] {
            let base = root.appending(path: directory)
            guard let walker = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else {
                Issue.record("could not read \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                if allowed.contains(url.lastPathComponent) { continue }
                let source = try String(contentsOf: url, encoding: .utf8)
                for symbol in banned where source.contains(symbol) {
                    offenders.append("\(url.lastPathComponent): \(symbol)")
                }
            }
        }

        #expect(offenders.isEmpty, "networking or tracking outside the search adapter: \(offenders)")
    }

    /// Walk up from this file to the repository root, so the test does not depend on the
    /// working directory the runner happens to use.
    private func repositoryRoot(file: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(file)")
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appending(path: "project.yml").path) {
                return url
            }
        }
        fatalError("could not find the repository root from \(file)")
    }
}
