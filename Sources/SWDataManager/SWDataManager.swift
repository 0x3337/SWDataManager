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

  public lazy var context: NSManagedObjectContext = {
    let context = persistentContainer.viewContext
    context.automaticallyMergesChangesFromParent = true

    return context
  }()

  public lazy var backgroundContext: NSManagedObjectContext = {
    let context = persistentContainer.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    return context
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
}

extension SWDataManager {
  private func entityName<O: NSManagedObject>(for object: O.Type) -> String {
    if let object = object as? SWEntityNamable.Type {
      return object.entityName
    }

    return String(describing: object)
  }
}

extension SWDataManager {
  public func insert<O: NSManagedObject>(for object: O.Type) -> O {
    let entityName = entityName(for: object)

    return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! O
  }
}

extension SWDataManager {
  public func delete(_ object: NSManagedObject) {
    context.delete(object)
  }

  public func delete(by objectID: NSManagedObjectID) {
    let object = context.object(with: objectID)

    delete(object)
  }

  public func delete<O: NSManagedObject>(_ object: O.Type, predicate: NSPredicate? = nil) {
    let objects = fetch(object, where: predicate)

    for object in objects {
      delete(object)
    }
  }
}

extension SWDataManager {
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
    let entityName = entityName(for: object)
    let request = NSFetchRequest<O>(entityName: entityName)
    request.predicate = predicate
    request.sortDescriptors = sortDescriptors
    request.fetchLimit = limit
    request.fetchOffset = offset

    return request
  }

  public func fetch<O: NSManagedObject>(
    _ object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> [O] {
    let request = request(for: object, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)

    return try! context.fetch(request)
  }

  public func fetch<O: NSManagedObject>(_ object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> [O] {
    return fetch(object, where: NSPredicate(format: predicateFormat, argumentArray: args))
  }

  public func resultsController<O: NSManagedObject>(
    for object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> NSFetchedResultsController<O> {
    let request = request(for: object, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)
    let fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

    do {
      try fetchedResultsController.performFetch()
    } catch {
      fatalError("Failed to create FetchedResultsController: \(error)")
    }

    return fetchedResultsController
  }
}

extension SWDataManager {
  public func count<O: NSManagedObject>(for object: O.Type, where predicate: NSPredicate? = nil) -> Int {
    let request = request(for: object, where: predicate)

    return (try? context.count(for: request)) ?? 0
  }

  public func count<O: NSManagedObject>(for object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> Int {
    return count(for: object, where: NSPredicate(format: predicateFormat, argumentArray: args))
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
    var properties = [Any]()

    for attribute in attributes {
      guard let expression = attribute as? SWDataExpression else {
        properties.append(attribute.value)
        continue
      }

      let description = NSExpressionDescription()
      description.name = expression.name
      description.expressionResultType = expression.resultType
      description.expression = NSExpression(forFunction: "\(expression.function.rawValue):", arguments: [
        NSExpression(forKeyPath: expression.value)
      ])

      properties.append(description)
    }

    let entityName = entityName(for: object)
    let request = NSFetchRequest<NSDictionary>(entityName: entityName)
    request.predicate = predicate
    request.resultType = .dictionaryResultType
    request.returnsObjectsAsFaults = false
    request.propertiesToFetch = properties
    request.propertiesToGroupBy = groups
    request.havingPredicate = havingPredicate
    request.sortDescriptors = sortDescriptors
    request.fetchLimit = limit
    request.fetchOffset = offset

    return try! context.fetch(request)
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

  public func save() {
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
}
