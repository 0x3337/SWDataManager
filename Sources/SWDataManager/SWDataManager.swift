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
    let name = entityName(for: object)

    return NSEntityDescription.insertNewObject(forEntityName: name, into: context) as! O
  }
}

extension SWDataManager {
  public func count<O: NSManagedObject>(for object: O.Type, format predicateFormat: String? = nil, _ args: CVarArg...) -> Int {
    var predicate: NSPredicate?

    if let predicateFormat = predicateFormat {
      predicate = NSPredicate(format: predicateFormat, argumentArray: args)
    }

    let req = request(for: object, predicate: predicate)

    do {
      return try context.count(for: req)
    } catch {
      return 0
    }
  }

  public func object(with objectID: NSManagedObjectID) -> NSManagedObject {
    return context.object(with: objectID)
  }

  public func request<O: NSManagedObject>(for object: O.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]? = nil) -> NSFetchRequest<O> {
    let name = entityName(for: object)
    let request = NSFetchRequest<O>(entityName: name)

    request.predicate = predicate
    request.sortDescriptors = sorts

    if let limit = limit {
      request.fetchLimit = limit
    }

    return request
  }


  public func fetch<O: NSManagedObject>(for object: O.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]? = nil) -> [O] {
    let req = request(for: object, limit: limit, predicate: predicate, sorts: sorts)

    return try! context.fetch(req)
  }

  public func fetch<O: NSManagedObject>(for object: O.Type, format predicateFormat: String, _ args: CVarArg...) -> [O] {
    return fetch(for: object, predicate: NSPredicate(format: predicateFormat, argumentArray: args))
  }

  public func resultsController<O: NSManagedObject>(for object: O.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]) -> NSFetchedResultsController<O> {
    let req = request(for: object, limit: limit, predicate: predicate, sorts: sorts)
    let fetchedResultsController = NSFetchedResultsController(fetchRequest: req, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

    do {
      try fetchedResultsController.performFetch()
    } catch {
      fatalError("Failed to create FetchedResultsController: \(error)")
    }

    return fetchedResultsController
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

  public func delete<O: NSManagedObject>(for object: O.Type, predicate: NSPredicate? = nil) {
    let objects = fetch(for: object, predicate: predicate)

    for object in objects {
      delete(object)
    }
  }
}

extension SWDataManager {
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
