import Foundation
import CoreData

class DataController {
    
    static let shared = DataController(ModelName: "Udacity_Virtual_Tourist")
    let persistentContainer: NSPersistentContainer
    var backgroundContext: NSManagedObjectContext!
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private init(ModelName: String) {
        persistentContainer = NSPersistentContainer(name: ModelName)
        load()
    }
    
    private func load() {
        persistentContainer.loadPersistentStores { storeDescription, error in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            self.configureContexts()
        }
    }
    
    private func configureContexts() {
        backgroundContext = persistentContainer.newBackgroundContext()
        viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext.automaticallyMergesChangesFromParent = true
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func saveContexts() {
        if viewContext.hasChanges {
            do {
                try self.viewContext.save()
            } catch {
                print("could not save viewContext: \(error)")
            }
        }
        
        if backgroundContext.hasChanges {
            do {
                try self.backgroundContext.save()
            } catch {
                print("could not save backgroundContext: \(error)")
            }
        }
    }
}
