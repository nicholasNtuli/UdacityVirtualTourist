import Foundation
import MapKit

enum Settings: String {
    case currentMap
    
    static var photosPerPage: Int {
        return 20
    }
}

struct MapRectConverter {
    static func mapDict(from rect:MKMapRect) -> [String:Double] {
        let long = rect.origin.coordinate.longitude
        let lat = rect.origin.coordinate.latitude
        let width = rect.size.width
        let height = rect.size.height
        return ["longitude": long, "latitude": lat, "width": width, "height": height]
    }
    
    static func mapRect(from dict:[String:Double]) -> MKMapRect {
        let long = dict["longitude"]!
        let lat = dict["latitude"]!
        let width = dict["width"]!
        let height = dict["height"]!
        return MKMapRect(origin: MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: long)),size:MKMapSize(width: width, height: height))
    }
}

struct Radius {
    static let distances = [
        "radius=0.01",
        "radius=0.05",
        "radius=0.1",
        "radius=0.2",
        "radius=0.5",
        "radius=1.0",
        "radius=1.5",
        "radius=2.0",
        "radius=3.0",
        "radius=4.0",
        "radius=8.0",
        "radius=16.0",
        "radius=32.0"
    ]
}
