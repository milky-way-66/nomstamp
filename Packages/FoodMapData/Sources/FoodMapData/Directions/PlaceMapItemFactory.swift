import Foundation
import MapKit
import FoodMapDomain

/// Turns a saved place into something Apple Maps can navigate to (FR-4.5).
///
/// Kept out of the view so the coordinate handling is testable: getting it wrong sends the
/// user to the wrong restaurant, and the app still looks like it worked.
public enum PlaceMapItemFactory {

    public static func mapItem(for place: Place) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: place.coordinate.clLocationCoordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = place.name
        return item
    }

    public static func openInMaps(_ place: Place) {
        mapItem(for: place).openInMaps(
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }
}

extension Coordinate {
    /// Conversion lives here rather than in the domain, which must not import MapKit.
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
