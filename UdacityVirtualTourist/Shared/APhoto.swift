import Foundation

struct Response: Codable {
    let photos: Photos
    let stat: String
}

struct Photos: Codable {
    let photo: [APhoto]
    let pages: Int
}

struct APhoto: Codable {
    let id: String
    let secret: String
    let server: String
    let title: String
    let latitude: String
    let longitude: String
    
    static let base = "https://live.staticflickr.com/"
    
    var url: String {
        APhoto.base + "\(self.server)/\(self.id)_\(self.secret)_b.jpg"
    }
}
