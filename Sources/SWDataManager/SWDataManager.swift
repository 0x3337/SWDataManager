//
//  SWDataManager.swift
//
//
//  Created by Mirsaid Patarov on 2021-08-13.
//

import CoreData

public class SWDataManager {
  public lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: persistentContainerName)

    container.loadPersistentStores() { description, error in
      if let error = error {
        fatalError("Failed to load Core Data stack: \(error)")
      }
    }

    return container
  }()

  public lazy var context: NSManagedObjectContext = {
    let context = persistentContainer.viewContext
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    return context
  }()

  public lazy var backgroundContext: NSManagedObjectContext = {
    return persistentContainer.newBackgroundContext()
  }()

  private var persistentContainerName: String

  public init(withPersistentContainerName persistentContainerName: String) {
    self.persistentContainerName = persistentContainerName
  }
}

extension SWDataManager {
  private func entityName<O: NSManagedObject>(for object: O.Type) -> String {
    let entityName = String(describing: object)
    return String(entityName.dropLast(2))
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
  ) -> [Any] {
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
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
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
  public func save() {
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }
}
