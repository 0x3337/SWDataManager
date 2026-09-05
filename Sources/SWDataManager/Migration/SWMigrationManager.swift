//
//  SWMigrationManager.swift
//  
//
//  Created by Mirsaid Patarov on 2023-03-14.
//

import CoreData

public class SWMigrationManager: NSObject {
  public weak var migrationSource: SWMigrationSource?

  private let name: String
  private let bundle: Bundle

  public init(name: String, bundle: Bundle = .main) {
    self.name = name
    self.bundle = bundle
  }
}

extension SWMigrationManager {
  func migrateStore(at storeURL: URL) {
    guard let migrationSteps = migrationSource?.migrationSteps() else {
      return
    }

    forceWALCheckpointingForStore(at: storeURL)

    var currentURL = storeURL

    for step in migrationSteps {
      guard
        let metadata = NSPersistentStoreCoordinator.metadata(at: currentURL),
        managedObjectModel(forVersion: step.sourceVersion).isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
      else {
        continue
      }

      let destinationURL = migrateStore(at: currentURL, from: step.sourceVersion, to: step.destinationVersion)

      if currentURL != storeURL {
        NSPersistentStoreCoordinator.destroyStore(at: currentURL)
      }

      currentURL = destinationURL
    }

    guard currentURL != storeURL else {
      return
    }

    NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)
    NSPersistentStoreCoordinator.destroyStore(at: currentURL)
  }
}

extension SWMigrationManager {
  public func managedObjectModel(forVersion version: Int) -> NSManagedObjectModel {
    let name = resourceName(forVersion: version)
    let omoURL = bundle.url(forResource: name, withExtension: "omo", subdirectory: "\(self.name).momd")
    let momURL = bundle.url(forResource: name, withExtension: "mom", subdirectory: "\(self.name).momd")

    guard let url = omoURL ?? momURL else {
      fatalError("Unable to find model v\(version) in bundle")
    }

    guard let model = NSManagedObjectModel(contentsOf: url) else {
      fatalError("Unable to load model v\(version) in bundle")
    }

    return model
  }

  public func context(forVersion version: Int, at storeURL: URL) -> SWDataContext {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel(forVersion: version))
    _ = coordinator.addPersistentStore(at: storeURL, options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])

    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator

    return SWDataContext(moc: context)
  }

  @discardableResult
  public func migrateStore(at storeURL: URL, from sourceVersion: Int, to destinationVersion: Int) -> URL {
    let sourceModel = managedObjectModel(forVersion: sourceVersion)
    let destinationModel = managedObjectModel(forVersion: destinationVersion)

    guard let mapping = NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel) else {
      fatalError("Mapping model not found for v\(sourceVersion) -> v\(destinationVersion)")
    }

    let destinationURL = temporaryStoreURL()

    do {
      try NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel).migrateStore(
        from: storeURL,
        sourceType: NSSQLiteStoreType,
        options: nil,
        with: mapping,
        toDestinationURL: destinationURL,
        destinationType: NSSQLiteStoreType,
        destinationOptions: nil
      )
    } catch let error {
      fatalError("Failed attempting to migrate from v\(sourceVersion) to v\(destinationVersion), error: \(error)")
    }

    return destinationURL
  }

  public func migratedContext(
    from sourceVersion: Int,
    to destinationVersion: Int,
    populate: (SWDataContext) throws -> Void
  ) rethrows -> SWDataContext {
    let storeURL = temporaryStoreURL()
    let sourceContext = context(forVersion: sourceVersion, at: storeURL)

    try populate(sourceContext)
    sourceContext.save()
    sourceContext.removePersistentStores()

    var currentURL = storeURL

    for version in sourceVersion..<destinationVersion {
      currentURL = migrateStore(at: currentURL, from: version, to: version + 1)
    }

    return context(forVersion: destinationVersion, at: currentURL)
  }
}

private extension SWMigrationManager {
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
      return name
    } else {
      return "\(name) \(version)"
    }
  }

  func temporaryStoreURL() -> URL {
    return FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
