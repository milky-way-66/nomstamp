import Foundation
import MapKit
import FoodMapDomain

/// Apple Maps implementation of `PlaceSearchPort`.
///
/// Chosen after measuring Vietnam coverage rather than assuming it (ADR-001): roughly 50 food
/// places within 500 m in Hanoi, HCMC, Da Nang and Hoi An, including small local eateries.
public struct AppleMapsPlaceSearchAdapter: PlaceSearchPort {

    /// The categories a food map cares about. Apple caps nearby results at about 50.
    static let foodCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .foodMarket, .brewery, .winery
    ]

    public init() {}

    public func nearbyFoodPlaces(
        around coordinate: Coordinate,
        radius: Double
    ) async throws -> [PlaceCandidate] {
        // A category *filter*, never a category *word*. Free-text Vietnamese category terms
        // ignore the region hint entirely: "cà phê" searched in Ho Chi Minh City returned a
        // single result 1,100 km away near Hanoi (ADR-001). This is FR-7.2.
        let request = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
            radius: min(radius, MKLocalPointsOfInterestRequest.maxRadius)
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.foodCategories)

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
            .compactMap(Self.candidate(from:))
            .sorted {
                $0.coordinate.distance(to: coordinate) < $1.coordinate.distance(to: coordinate)
            }
    }

    public func search(
        matching query: String,
        near coordinate: Coordinate?
    ) async throws -> [PlaceCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest, .address]
        if let coordinate {
            // Apple honours this region bias well for names, which is the only thing
            // free-text search is used for here.
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                latitudinalMeters: 40_000,
                longitudinalMeters: 40_000
            )
        }

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap(Self.candidate(from:))
    }

    static func candidate(from item: MKMapItem) -> PlaceCandidate? {
        let location = item.placemark.coordinate
        let coordinate = Coordinate(latitude: location.latitude, longitude: location.longitude)
        guard coordinate.isValid,
              !(coordinate.latitude == 0 && coordinate.longitude == 0)
        else { return nil }

        guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }

        let identifier = item.identifier?.rawValue
        return PlaceCandidate(
            id: identifier ?? "\(name)@\(coordinate.latitude),\(coordinate.longitude)",
            name: name,
            address: shortAddress(from: item.placemark),
            coordinate: coordinate,
            providerPlaceID: identifier
        )
    }

    /// Street and district only — a full postal address is noise on a picker row.
    static func shortAddress(from placemark: MKPlacemark) -> String? {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let area = placemark.subLocality ?? placemark.locality
        let parts = [street, area].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
