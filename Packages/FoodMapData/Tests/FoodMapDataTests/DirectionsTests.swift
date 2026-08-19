import Testing
import Foundation
import MapKit
import FoodMapDomain
@testable import FoodMapData

@Suite("Directions")
struct DirectionsTests {

    @Test("TC-3-06 a place produces a map item carrying its name and exact coordinate")
    func TC_3_06_buildsMapItem() {
        // FR-4.5. Getting the coordinate wrong here sends the user to the wrong restaurant,
        // which is a silent failure — the app looks like it worked.
        let place = Place(
            name: "Bún chả Hương Liên",
            coordinate: Coordinate(latitude: 21.0180, longitude: 105.8541),
            createdAt: Date(timeIntervalSince1970: 1_767_225_600)
        )

        let item = PlaceMapItemFactory.mapItem(for: place)

        #expect(item.name == "Bún chả Hương Liên")
        #expect(abs(item.placemark.coordinate.latitude - 21.0180) < 0.000001)
        #expect(abs(item.placemark.coordinate.longitude - 105.8541) < 0.000001)
    }

    @Test("a Vietnamese name survives into the map item unchanged")
    func preservesDiacritics() {
        let place = Place(
            name: "Cà phê Giảng",
            coordinate: Coordinate(latitude: 21.0338, longitude: 105.8535),
            createdAt: Date(timeIntervalSince1970: 1_767_225_600)
        )

        #expect(PlaceMapItemFactory.mapItem(for: place).name == "Cà phê Giảng")
    }
}
