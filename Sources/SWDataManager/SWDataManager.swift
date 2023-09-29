//
//  SWDataManager.swift
//
//
//  Created by Mirsaid Patarov on 2021-08-13.
//

import CoreData

public class SWDataManager: NSObject {
  public lazy var persistentContainer: NSPersistentContainer = {
    let persistentContainer = NSPersistentContainer(name: persistentContainerName)
    let description = persistentContainer.persistentStoreDescriptions.first
    description?.shouldInferMappingModelAutomatically = false

    return persistentContainer
  }()

  public lazy var context: SWDataContext = {
    let context = persistentContainer.viewContext
    context.automaticallyMergesChangesFromParent = true

    return SWDataContext(moc: context)
  }()

  public var migrationSource: SWMigrationSource?

  private lazy var migrationManager: SWMigrationManager = {
    let migrationManager = SWMigrationManager(withPersistentContainer: persistentContainer)
    migrationManager.migrationSource = migrationSource

    return migrationManager
  }()

  private var persistentContainerName: String

  public init(withPersistentContainerName persistentContainerName: String) {
    self.persistentContainerName = persistentContainerName
  }

  public static func entityName<O: NSManagedObject>(for object: O.Type) -> String {
    if let object = object as? SWEntityNamable.Type {
      return object.entityName
    }

    return String(describing: object)
  }

  public func newBackgroundContext() -> SWDataContext {
    let context = persistentContainer.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    return SWDataContext(moc: context)
  }
}

extension SWDataManager {
  public func loadPersistentStore(completion: @escaping () -> Void) {
    migrateStoreIfNeeded { [self] in
      persistentContainer.loadPersistentStores { _, error in
        if let error = error {
          fatalError("Failed to load Core Data stack: \(error)")
        }

        completion()
      }
    }
  }

  public func migrateStoreIfNeeded(completion: @escaping () -> Void) {
    guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
        fatalError("persistentContainer was not set up properly")
    }

    if migrationManager.requiresMigration(at: storeURL) {
      DispatchQueue.global(qos: .userInitiated).async { [self] in
        migrationManager.migrateStore(at: storeURL)

        DispatchQueue.main.async {
          completion()
        }
      }
    } else {
      completion()
    }
  }
}

extension SWDataManager {
  public func insert<O: NSManagedObject>(for object: O.Type) -> O {
    return context.insert(for: object)
  }

  public func delete(_ object: NSManagedObject) {
    context.delete(object)
  }

  public func delete(by objectID: NSManagedObjectID) {
    context.delete(by: objectID)
  }

  public func delete<O: NSManagedObject>(_ object: O.Type, predicate: NSPredicate? = nil) {
    context.delete(object, predicate: predicate)
  }

  public func delete<O: NSManagedObject>(for object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) {
    context.delete(for: object, whereFormat: predicateFormat, args)
  }

  public func object(with objectID: NSManagedObjectID) -> NSManagedObject {
    return context.object(with: objectID)
  }

  public func request<O: NSManagedObject>(
    for object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> NSFetchRequest<O> {
    return context.request(for: object, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)
  }

  public func fetch<O: NSManagedObject>(
    _ object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> [O] {
    return context.fetch(object, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)
  }

  public func fetch<O: NSManagedObject>(_ object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> [O] {
    return context.fetch(object, whereFormat: predicateFormat, args)
  }

  public func fetchFirst<O: NSManagedObject>(_ object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> O? {
    return context.fetchFirst(object, whereFormat: predicateFormat, args)
  }

  public func resultsController<O: NSManagedObject>(
    for object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> NSFetchedResultsController<O> {
    return context.resultsController(for: object, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)
  }

  public func count<O: NSManagedObject>(for object: O.Type, where predicate: NSPredicate? = nil) -> Int {
    return context.count(for: object, where: predicate)
  }

  public func count<O: NSManagedObject>(for object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> Int {
    return context.count(for: object, whereFormat: predicateFormat, args)
  }

  public func aggregate<O: NSManagedObject>(
    for object: O.Type,
    attributes: [SWDataAttribute],
    where predicate: NSPredicate? = nil,
    groupBy groups: [Any]? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    having havingPredicate: NSPredicate? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> [NSDictionary] {
    return context.aggregate(
      for: object,
      attributes: attributes,
      where: predicate,
      groupBy: groups,
      orderBy: sortDescriptors,
      having: havingPredicate,
      limit: limit,
      offset: offset
    )
  }

  public func save() {
    context.save()
  }

  public func perform(_ block: @escaping () -> Void) {
    context.perform(block)
  }

  public func performAndWait(_ block: () -> Void) {
    context.performAndWait(block)
  }
}
