import CoreData
import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {
    
    var fetchedPins: NSFetchedResultsController<Pin>!
    let geocoder = CLGeocoder()
    var feedbackGenerator: UIImpactFeedbackGenerator? = nil
    
    @IBOutlet weak var longPress:UILongPressGestureRecognizer!
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var mapRect = MKMapRect()
        
        if let dict = UserDefaults.standard.dictionary(forKey: Settings.currentMap.rawValue) as? [String:Double] {
            mapRect = MapRectConverter.mapRect(from: dict)
        } else {
            mapRect = MKMapRect(origin: MKMapRect.world.origin, size: MKMapRect.world.size)
        }
        
        let pinFetch:NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        
        pinFetch.sortDescriptors = [sortDescriptor]
        
        self.fetchedPins = NSFetchedResultsController(fetchRequest: pinFetch, managedObjectContext: DataController.shared.viewContext, sectionNameKeyPath: nil, cacheName: "pincache")
        do {
            try self.fetchedPins.performFetch()
        } catch {
            assertionFailure("Unable to fetch pins from core data.")
        }
        
        mapView.setVisibleMapRect(mapRect, animated: true)
        
        if let pins = fetchedPins.fetchedObjects {
            mapView.addAnnotations(pins)
        } else {
            print("No map pins exist.")
        }
        
        mapView.delegate = self
        longPress.delegate = self
        fetchedPins.delegate = self
    }
    
    deinit {
        mapView.delegate = nil
        longPress.delegate = nil
    }
    
    @IBAction func deletePinsInView(_ sender: Any) {
        guard let pins = fetchedPins.fetchedObjects else {
            return
        }
        
        let pinsToDelete = pins.filter {mapView.visibleMapRect.contains(MKMapPoint($0.coordinate))}
        let alert = UIAlertController(title: "Delete Pins", message: "You're about to delete \(pinsToDelete.count) pins on the map along with any photos associated with those pins.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: UIAlertAction.Style.destructive, handler: { [self]_ in
            mapView.removeAnnotations(pinsToDelete)
            for pin in pinsToDelete {
                DataController.shared.viewContext.delete(pin)
            }
            DataController.shared.saveContexts()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: {_ in
            self.dismiss(animated: true)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func pinDrop(_ sender: UIGestureRecognizer) {
        switch sender.state {
        case .began:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator?.prepare()
            
            let touchLocation = longPress.location(in:mapView)
            let locationCoordinate = mapView.convert(touchLocation, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude)
            
            feedbackGenerator?.impactOccurred()
            findPlacemark(at: location) {name, placemark in
                self.createPinTitles(poiName: name, place: placemark) {title, subtitle in
                    self.createPin(at: placemark, title: title, subtitle: subtitle)
                }
            }
            
        case .cancelled, .ended, .failed:
            sender.reset()
            feedbackGenerator = nil
            
        default:
            break
        }
    }
    
    @objc private func deletePinAlert(_ sender: UILongPressGestureRecognizer) {
        guard let view = sender.view as? MKMarkerAnnotationView else {
            return assertionFailure("Gestured Failed: View is not MLMarkerAnnotationView")
        }
        
        guard let pin = view.annotation as? Pin else {
            return assertionFailure("Gesture Failed: AnnotationView is not a Pin")
        }
        
        if sender.state == .began {
            let alert = UIAlertController(title: "Delete Pin at \(pin.title ?? "Untitled Pin")", message: "You will delete this map pin along with \(pin.numberOfPhotos) photos.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertAction.Style.destructive, handler: { [self] _ in
                mapView.removeAnnotation(pin)
                DataController.shared.viewContext.delete(pin)
                DataController.shared.saveContexts()
            }))
            
            alert.addAction(UIAlertAction(title: "Nevermind", style: UIAlertAction.Style.cancel, handler: {_ in
                self.dismiss(animated: true)
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc private func gotoPhotoPage(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view as? MKMarkerAnnotationView else {
            return assertionFailure("Gesture Failed: View is not MKMarkerAnnotationView")
        }
        
        guard let pin = view.annotation as? Pin else {
            return assertionFailure("Gesture Failed: AnnotationView is not a Pin")
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let photoAlbumView = storyboard.instantiateViewController(withIdentifier: "PhotoAlbum") as? PhotoAlbumViewController else {
            return
        }
        
        if pin.numberOfPhotos == 0 {
            PhotoClient.findPhotos(pin, nil)
        }
        
        photoAlbumView.pin = pin
        navigationController?.pushViewController(photoAlbumView, animated: true)
    }

    fileprivate func createPin (at location: MKPlacemark, title: String, subtitle: String) {
        let pin = Pin(context:DataController.shared.viewContext)
        
        pin.longitude = location.coordinate.longitude
        pin.latitude = location.coordinate.latitude
        pin.title = title
        pin.subtitle = subtitle
        
        DataController.shared.saveContexts()
        PhotoClient.findPhotos(pin, nil)
        mapView.addAnnotation(pin)
    }

    fileprivate func createPinTitles(poiName: String?, place: CLPlacemark, closure: (String,String) -> Void) {
        var title = "B.F. Nowhere"
        var subtitle = ""

        let name = poiName ?? ""
        let city = place.locality ?? ""
        let neighborhood = place.subLocality ?? ""
        let state = place.administrativeArea ?? ""
        var country = place.country ?? "Planet Earth"
        country = (country == "United States") ? "USA" : country
        let cityComma = (city == "") ? ("") : (state == "") ? (city) : (city + ", ")
        let stateComma = (state == "") ? ("") : (state + ", ")
        let inOn = (country == "Planet Earth" && state == "" && city == "") ? "on" : "in"
        
        if name != "" {
            title = name
            subtitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if neighborhood != "" {
            title = neighborhood
            subtitle = "\(inOn) \(cityComma)\(stateComma)\(country)"
        } else if city != "" {
            title = city
            subtitle = "\(inOn) \(stateComma)\(country)"
        } else if state != "" {
            title = state
            subtitle = "\(inOn) \(country)"
        } else {
            title = "Somewhere"
            subtitle = "\(inOn) \(country)"
        }
        
        closure(title, subtitle)
    }

    fileprivate func searchPOI (_ location: CLLocation, completion: @escaping (Bool,String,MKPlacemark) -> Void) {
        let maxZoom = 0.065
        let searchRadius = 75.0
        
        var found = false
        var name = ""
        var place = MKPlacemark(coordinate: location.coordinate)
        
        guard self.mapView.region.span.longitudeDelta < maxZoom else {
            completion(found,name,place)
            return
        }
        
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: searchRadius)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            guard error == nil else {
                print(error as Any)
                completion(found,name,place)
                return
            }
            
            if let POIs = response?.mapItems {
                let sortedPOIs = POIs.sorted { (item1, item2) -> Bool in
                    let distance1 = location.distance(from: CLLocation(latitude: item1.placemark.coordinate.latitude, longitude: item1.placemark.coordinate.longitude))
                    let distance2 = location.distance(from: CLLocation(latitude: item2.placemark.coordinate.latitude, longitude: item2.placemark.coordinate.longitude))
                    return distance1 < distance2
                }
                
                found = true
                name = sortedPOIs.first?.name ?? "A place with no name."
                if let placeMark = sortedPOIs.first?.placemark {
                    place = placeMark
                }
            }
            completion(found,name,place)
        }
    }
    
    fileprivate func findPlacemark(at location: CLLocation, makePinTitles: @escaping (String?, MKPlacemark) -> Void) {
        searchPOI(location) {found, name, placemark in
            if found {
                makePinTitles(name, placemark)
            } else {
                self.geocoder.fetchPlacemark(location) {placemark in
                    makePinTitles(nil, placemark)
                }
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view === mapView && otherGestureRecognizer.view is MKMarkerAnnotationView
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        UserDefaults.standard.set(MapRectConverter.mapDict(from:mapView.visibleMapRect), forKey:Settings.currentMap.rawValue)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        let pin = annotation as! Pin
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: reuseId)
            pinView!.subtitleVisibility = .visible
            pinView!.titleVisibility = .visible
            let longPress = UILongPressGestureRecognizer(target:self, action: #selector(deletePinAlert(_:)))
            // Delegate method allows more than one longPress to respond.
            longPress.delegate = self
            let tap = UITapGestureRecognizer(target: self, action: #selector(gotoPhotoPage(_:)))
            pinView!.addGestureRecognizer(longPress)
            pinView!.addGestureRecognizer(tap)
            pinView!.isUserInteractionEnabled = true
            pinView!.canShowCallout = false
        }
        
        pinView!.annotation = pin
        pinView!.glyphText = "\(pin.numberOfPhotos)"
        return pinView
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("insert at \(String(describing: indexPath))")
        case .delete:
            print("delete at \(String(describing: indexPath))")
            
        case .update:
            guard let indexPath = indexPath else {
                break
            }
            let pin = fetchedPins.object(at: indexPath)
            mapView.removeAnnotation(pin)
            mapView.addAnnotation(pin)
            
        case .move:
            print("move at \(String(describing: indexPath))")
        @unknown default:
            print("other at \(String(describing: indexPath))")
        }
    }
}
