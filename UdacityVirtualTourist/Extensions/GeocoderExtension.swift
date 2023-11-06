import Foundation
import MapKit

extension CLGeocoder {
    func fetchPlacemark(_ location: CLLocation, closure: @escaping (MKPlacemark) -> Void ) {
        var placeMark = MKPlacemark(coordinate: location.coordinate)
        
        reverseGeocodeLocation(location) { (placemarks, error) in
            if let place = placemarks?.first {
                placeMark = MKPlacemark(placemark: place)
            }
            
            if error != nil {
                print("An error occurred trying to reverse geocode the location: \(error as Any)")
            }
            
            DispatchQueue.main.async { closure(placeMark) }
        }
    }
}
