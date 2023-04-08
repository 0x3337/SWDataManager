//
//  SWMigrationManager.swift
//  
//
//  Created by Mirsaid Patarov on 2023-03-14.
//

import CoreData

class SWMigrationManager: NSObject {
  public weak var migrationSource: SWMigrationSource?

  private let persistentContainer: NSPersistentContainer

  init(withPersistentContainer persistentContainer: NSPersistentContainer) {
    self.persistentContainer = persistentContainer
  }
}

extension SWMigrationManager {
  func requiresMigration(at storeURL: URL) -> Bool {
    guard
      let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil),
      let lastVersion = migrationSource?.migrationSteps().last?.destinationVersion
    else {
      return false
    }

    return !managedObjectModel(forVersion: lastVersion).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
  }

  func migrateStore(at storeURL: URL) {
    guard
      let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
      let migrationSteps = migrationSource?.migrationSteps()
    else {
      return
    }

    forceWALCheckpointingForStore(at: storeURL)

    var currentURL = storeURL

    for step in migrationSteps {
      let sourceModel = managedObjectModel(forVersion: step.sourceVersion)
      let destinationModel = managedObjectModel(forVersion: step.destinationVersion)

      guard let mapping = NSMappingModel(from: [Bundle.main], forSourceModel: sourceModel, destinationModel: destinationModel) else {
        fatalError("Mapping model not found")
      }

      if !sourceModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
        continue
      }

      let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
      let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)

      do {
          try manager.migrateStore(
            from: currentURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mapping,
            toDestinationURL: destinationURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
          )
      } catch let error {
          fatalError("Failed attempting to migrate from v\(step.sourceVersion) to v\(step.destinationVersion), error: \(error)")
      }

      if currentURL != storeURL {
          // Destroy intermediate step's store
          NSPersistentStoreCoordinator.destroyStore(at: currentURL)
      }

      currentURL = destinationURL
    }

    NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

    if (currentURL != storeURL) {
      NSPersistentStoreCoordinator.destroyStore(at: currentURL)
    }
  }
}

private extension SWMigrationManager {
  func managedObjectModel(forVersion version: Int) -> NSManagedObjectModel {
    let name = resourceName(forVersion: version)
    let omoURL = Bundle.main.url(forResource: name, withExtension: "omo", subdirectory: "\(persistentContainer.name).momd")
    let momURL = Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: "\(persistentContainer.name).momd")

    guard let url = omoURL ?? momURL else {
        fatalError("Unable to find model in bundle")
    }

    guard let model = NSManagedObjectModel(contentsOf: url) else {
        fatalError("Unable to load model in bundle")
    }

    return model
  }

  func managedObjectModel(compatibleWithStoreMetadata metadata: [String : Any]) -> NSManagedObjectModel? {
    guard let migrationSteps = migrationSource?.migrationSteps() else {
      return nil
    }

    for step in migrationSteps {
      let model = managedObjectModel(forVersion: step.sourceVersion)

      if model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
        return model
      }
    }

    return nil
  }

  func resourceName(forVersion version: Int) -> String {
    if version == 1 {
        return persistentContainer.name
    } else {
        return "\(persistentContainer.name) \(version)"
    }
  }

  func forceWALCheckpointingForStore(at storeURL: URL) {
    guard
      let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
      let model = managedObjectModel(compatibleWithStoreMetadata: metadata) else {
        return
    }

    do {
      let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

      let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
      let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
      try persistentStoreCoordinator.remove(store)
    } catch let error {
      fatalError("Failed to force WAL checkpointing, error: \(error)")
    }
  }
}
