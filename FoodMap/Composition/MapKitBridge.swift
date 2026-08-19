import MapKit
import FoodMapDomain

/// Conversions between the domain's framework-free `Coordinate` and MapKit's types.
/// Confined to the app layer so the domain never imports MapKit.
extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension MapBounds {
    init(_ region: MKCoordinateRegion) {
        self.init(
            center: Coordinate(region.center),
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
