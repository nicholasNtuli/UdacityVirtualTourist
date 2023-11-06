import Foundation
import UIKit

class PhotoViewController: UIViewController {
    
    var photo = UIImage(named:"loadingIndicator")
    
    @IBOutlet weak var photoView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        photoView.image = photo
    }
}
