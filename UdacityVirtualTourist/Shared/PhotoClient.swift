import Foundation
import MapKit
import SwiftUI

class PhotoClient {
    
    enum Endpoints {
        static let base = "https://www.flickr.com/services/rest/"
        static let photoBase = "https://live.staticflickr.com/"
        static let apiKey = "166ffffddfab4f8cf28281297d06b3e2"
        
        case searchPhotos
        case returnPhoto
        
        var urlString: String {
            switch self {
            case .searchPhotos:
                return Endpoints.base + "?method=flickr.photos.search&api_key=\(Endpoints.apiKey)"
            case .returnPhoto:
                return Endpoints.photoBase
            }
        }
    }
    
    class func searchURL(lat: Double, lon: Double, geoArea: String, page: Int) -> URL {
        let string = Endpoints.searchPhotos.urlString + "&lat=\(lat)&lon=\(lon)&\(geoArea)&per_page=20&page=\(page)&extras=geo&format=json"
        
        if let url = URL(string: string) {
            return url
        } else {
            fatalError("Invalid URL for photo search.")
        }
    }
    
    class func photoSearch(_ pin: Pin, completion: @escaping (Bool,Error?,[APhoto]?,Pin) -> Void) {
        let lat = pin.coordinate.latitude
        let lon = pin.coordinate.longitude
        let geoArea = Radius.distances[Int(pin.radius)]
        let page = Int(pin.currentPage)
        let url = searchURL(lat: lat, lon: lon, geoArea: geoArea, page: page)
        let request = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            
            if let data = data {
                var newData = data
                
                if let responseString = String(data:data, encoding: .utf8) {
                    let prefix = "jsonFlickrApi("
                    let suffix = ")"
                    
                    if responseString.hasPrefix(prefix) && responseString.hasSuffix(suffix) {
                        let startIndex = responseString.index(responseString.startIndex, offsetBy: prefix.count)
                        let endIndex = responseString.index(responseString.endIndex, offsetBy: -suffix.count)
                        let jsonSubstring = responseString[startIndex..<endIndex]
                        
                        if let jsonData = jsonSubstring.data(using: .utf8) {
                            newData = jsonData
                        }
                    }
                }
                
                let decoder = JSONDecoder()
                
                do {
                    let response = try decoder.decode(Response.self, from: newData)
                    let photos = response.photos.photo
                    pin.numberOfPages = Int16(response.photos.pages)
                    DispatchQueue.main.async {completion(true, nil, photos, pin)}
                } catch {
                    DispatchQueue.main.async {completion(false, error, nil, pin)}
                }
            } else {
                DispatchQueue.main.async {completion(false, error, nil, pin)}
            }
        }
        task.resume()
    }
    
    class func returnImage(url: URL, completion: @escaping (Bool,Error?,Data?) -> Void) {
        let request = URLRequest(url: url)
        let session = URLSession.shared
        
        let task = session.dataTask(with: request) { data, response, error in
            
            if let data = data {
                DispatchQueue.main.async {completion(true,nil,data)}
                
            } else {
                DispatchQueue.main.async {completion(false,error,nil)}
            }
        }
        task.resume()
    }
    
    class func addPhotosToPin(photos:[APhoto],pin:Pin) {
        for photo in photos {
            
            let newPhoto = Photo(context:DataController.shared.viewContext)
            newPhoto.photoAlbum = pin
            newPhoto.title = photo.title
            
            if let lat = Double(photo.latitude), let lon = Double(photo.longitude) {
                let locationPin = CLLocation(latitude:pin.latitude, longitude:pin.longitude)
                let locationPhoto = CLLocation(latitude: lat, longitude: lon)
                newPhoto.distance = locationPhoto.distance(from: locationPin)
            }
            
            let urlString = PhotoClient.Endpoints.returnPhoto.urlString + "\(photo.server)/\(photo.id)_\(photo.secret)_b.jpg"
            newPhoto.url = urlString
            
            if let url = URL(string: urlString) {
                returnImage(url: url) {success, error, data in
                    if success {
                        newPhoto.image = data
                        pin.numberOfPhotos += 1
                        DataController.shared.saveContexts()
                    } else {
                        print("error loading photo: \(String(describing: error))")
                    }
                }
            }
            
            DataController.shared.saveContexts()
        }
    }
    
    class func findPhotos(_ pin: Pin, _ closure: (() -> Void)?) {
        if pin.new == false {
            pin.currentPage += 1
            
            if pin.currentPage > pin.numberOfPages {
                pin.currentPage = 1
            }
            
            PhotoClient.photoSearch(pin) {success,error,photos,pin in
                
                if let photos = photos {
                    PhotoClient.addPhotosToPin(photos: photos, pin: pin)
                } else {
                    pin.new = true
                    pin.currentPage = 1
                }
            }
        } else {
            PhotoClient.photoSearch(pin) {success,error,photos,pin in
                
                if success {
                    if let photos = photos {

                        if photos.count < Settings.photosPerPage {

                            if pin.radius + 1 < Radius.distances.count {
                                pin.radius += 1
                                self.findPhotos(pin, nil)
                            }

                        } else {
                            pin.new = false
                            PhotoClient.addPhotosToPin(photos: photos, pin: pin)
                        }
                    }
                } else {
                    print("There was an error finding photos for this pin: \(String(describing: error))")
                }
            }
        }
        if let closure = closure {
            closure()
        }
    }
}
