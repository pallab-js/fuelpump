import Foundation
import CoreData

@MainActor
public final class CoreDataStack {
    public static let shared = CoreDataStack()
    
    public let container: NSPersistentContainer
    
    private init() {
        let model = CoreDataStack.createManagedObjectModel()
        container = NSPersistentContainer(name: "FuelStationModel", managedObjectModel: model)
        
        let storeURL = appDataDirectory().appendingPathComponent("FuelStation.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                logger.error("CoreData failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
    
    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let transactionEntity = NSEntityDescription()
        transactionEntity.name = "TransactionEntity"
        transactionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        
        let txAttributes: [String: NSAttributeType] = [
            "id": .UUIDAttributeType,
            "date": .dateAttributeType,
            "pumpID": .integer64AttributeType,
            "fuelType": .stringAttributeType,
            "liters": .doubleAttributeType,
            "amount": .doubleAttributeType,
            "paymentMethod": .stringAttributeType,
            "notes": .stringAttributeType,
            "customerID": .UUIDAttributeType,
            "shiftID": .UUIDAttributeType,
            "attendantName": .stringAttributeType
        ]
        
        transactionEntity.properties = txAttributes.map { name, type in
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = true
            if name == "id" { attr.isOptional = false }
            return attr
        }
        
        let lubeSaleEntity = NSEntityDescription()
        lubeSaleEntity.name = "LubeSaleEntity"
        lubeSaleEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        
        let lubeAttributes: [String: NSAttributeType] = [
            "id": .UUIDAttributeType,
            "date": .dateAttributeType,
            "productID": .UUIDAttributeType,
            "quantity": .integer64AttributeType,
            "totalAmount": .doubleAttributeType,
            "customerID": .UUIDAttributeType,
            "attendantName": .stringAttributeType
        ]
        
        lubeSaleEntity.properties = lubeAttributes.map { name, type in
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = true
            if name == "id" { attr.isOptional = false }
            return attr
        }
        
        let blobEntity = NSEntityDescription()
        blobEntity.name = "BlobEntity"
        blobEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        
        let keyAttr = NSAttributeDescription()
        keyAttr.name = "key"
        keyAttr.attributeType = .stringAttributeType
        keyAttr.isOptional = false
        
        let dataAttr = NSAttributeDescription()
        dataAttr.name = "data"
        dataAttr.attributeType = .binaryDataAttributeType
        dataAttr.isOptional = true
        
        blobEntity.properties = [keyAttr, dataAttr]
        
        model.entities = [transactionEntity, lubeSaleEntity, blobEntity]
        return model
    }
    
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    public func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                logger.error("CoreData save error: \(nserror.localizedDescription)")
            }
        }
    }
}
