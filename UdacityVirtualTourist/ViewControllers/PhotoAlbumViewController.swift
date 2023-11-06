import Foundation
import CoreData
import UIKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate {

    let dataController = DataController.shared
    var pin: Pin!
    var fetchedPhotos: NSFetchedResultsController<Photo>!
    let defaultImage = UIImage(named:"loadingIndicator")
    var feedbackGenerator: UIImpactFeedbackGenerator? = nil
    
    @IBOutlet weak var photoAlbum: UICollectionView!
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var reloadButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "\(pin.title ?? "Somewhere") Photos"
        updateLabelText()
        reloadButton.isEnabled = (pin.numberOfPages > 1)
        
        let photoFetch:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "photoAlbum == %@", pin)
        photoFetch.predicate = predicate
        
        let sortDescriptor = NSSortDescriptor(key: "distance", ascending: true)
        photoFetch.sortDescriptors = [sortDescriptor]
        
        self.fetchedPhotos = NSFetchedResultsController(fetchRequest: photoFetch, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin.id)")
        do {
            try self.fetchedPhotos.performFetch()
        } catch {
            assertionFailure("Unable to fetch photos from core data.")
        }
        
        photoAlbum.delegate = self
        fetchedPhotos.delegate = self
    }
    
    deinit {
        photoAlbum.delegate = nil
    }
    
    func updateLabelText() {
        pageLabel.text = "\(pin.subtitle ?? "")."
    }
    
    @IBAction func displayNewPage(_ sender: Any) {
        if let photos = fetchedPhotos.fetchedObjects {
            for photo in photos {
                DataController.shared.viewContext.delete(photo)
                pin.numberOfPhotos -= 1
                DataController.shared.saveContexts()
            }
            PhotoClient.findPhotos(pin) {self.updateLabelText()}
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let count = fetchedPhotos.fetchedObjects?.count {
            return count
        } else {
            return 0
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoAlbumCell
        
        let longPress = UILongPressGestureRecognizer(target:self, action: #selector(displayPhoto(_:)))
        longPress.delegate = self
        cell.imageView.addGestureRecognizer(longPress)
        
        if let imageData = fetchedPhotos.object(at: indexPath).image {
            let image = UIImage(data:imageData)
            cell.imageView.image = image
        } else {
            cell.imageView.image = defaultImage
            
            if let urlString = fetchedPhotos.object(at: indexPath).url {
                if let url = URL(string:urlString) {
                    PhotoClient.returnImage(url: url) {(success: Bool, error: Error?, image: Data?) in
                        if success {
                            self.fetchedPhotos.object(at: indexPath).image = image
                            self.dataController.saveContexts()
                        } else {
                            print("image has failed to load: \(String(describing: error))")
                        }
                    }
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let photos = fetchedPhotos.fetchedObjects {
            let photoToDelete = photos[indexPath.item]
            DataController.shared.viewContext.delete(photoToDelete)
            pin.numberOfPhotos -= 1
            DataController.shared.saveContexts()
        }
    }
    
    @objc private func displayPhoto(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }

        guard let view = sender.view as? UIImageView else {
            return assertionFailure("Gestured Failed: View is not an ImageView. \(type(of: view))")
        }
        
        guard let photo = view.image else {
            return assertionFailure("Gesture Failed: no Image")
        }
        
        feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        feedbackGenerator?.prepare()
        
        if let photoViewController = storyboard?.instantiateViewController(withIdentifier: "PhotoView") as? PhotoViewController {
            photoViewController.photo = photo
            feedbackGenerator?.impactOccurred()
            feedbackGenerator = nil
            navigationController?.pushViewController(photoViewController, animated: true)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            photoAlbum.insertItems(at: [newIndexPath!])
        case .delete:
            photoAlbum.deleteItems(at: [indexPath!])
        case .update:
            photoAlbum.reloadItems(at: [indexPath!])
        case .move:
            photoAlbum.moveItem(at: indexPath!, to: newIndexPath!)
        @unknown default:
            break
        }
    }
}
