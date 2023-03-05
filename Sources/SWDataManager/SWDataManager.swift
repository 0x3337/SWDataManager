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
    let c = persistentContainer.viewContext
    c.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    return c
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
  private func entityName<M: NSManagedObject>(for model: M.Type) -> String {
    let entityName = String(describing: model)
    return String(entityName.dropLast(2))
  }
}

extension SWDataManager {
  public func insert<M: NSManagedObject>(for model: M.Type) -> M {
    let name = entityName(for: model)

    return NSEntityDescription.insertNewObject(forEntityName: name, into: context) as! M
  }
}

extension SWDataManager {
  public func count<M: NSManagedObject>(for model: M.Type, format predicateFormat: String? = nil, _ args: CVarArg...) -> Int {
    var predicate: NSPredicate?

    if let predicateFormat = predicateFormat {
      predicate = NSPredicate(format: predicateFormat, argumentArray: args)
    }

    let req = request(for: model, predicate: predicate)

    do {
      return try context.count(for: req)
    } catch {
      return 0
    }
  }

  public func object(with objectID: NSManagedObjectID) -> NSManagedObject {
    return context.object(with: objectID)
  }

  public func request<M: NSManagedObject>(for model: M.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]? = nil) -> NSFetchRequest<M> {
    let name = entityName(for: model)
    let request = NSFetchRequest<M>(entityName: name)

    request.predicate = predicate
    request.sortDescriptors = sorts

    if let limit = limit {
      request.fetchLimit = limit
    }

    return request
  }


  public func fetch<M: NSManagedObject>(for model: M.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]? = nil) -> [M] {
    let req = request(for: model, limit: limit, predicate: predicate, sorts: sorts)

    return try! context.fetch(req)
  }

  public func fetch<M: NSManagedObject>(for model: M.Type, format predicateFormat: String, _ args: CVarArg...) -> [M] {
    return fetch(for: model, predicate: NSPredicate(format: predicateFormat, argumentArray: args))
  }

  public func resultsController<M: NSManagedObject>(for model: M.Type, limit: Int? = nil, predicate: NSPredicate? = nil, sorts: [NSSortDescriptor]) -> NSFetchedResultsController<M> {
    let req = request(for: model, limit: limit, predicate: predicate, sorts: sorts)
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

  public func delete<M: NSManagedObject>(for type: M.Type, predicate: NSPredicate? = nil) {
    let objects = fetch(for: type, predicate: predicate)

    for object in objects {
      delete(object)
    }
  }
}

extension SWDataManager {
  public func aggregate<M: NSManagedObject>(for model: M.Type, attributes: [SWDataAttribute], predicate: NSPredicate? = nil, groupBy groups: [Any]? = nil) -> [Any] {
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

    let req = request(for: model, predicate: predicate) as! NSFetchRequest<NSFetchRequestResult>
    req.resultType = .dictionaryResultType
    req.returnsObjectsAsFaults = false
    req.propertiesToFetch = properties
    req.propertiesToGroupBy = groups

    return try! context.fetch(req)
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
