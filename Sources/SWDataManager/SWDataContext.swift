//
//  SWDataContext.swift
//
//
//  Created by Mirsaid Patarov on 2023-09-29.
//

import CoreData

public class SWDataContext: NSObject {
  public let moc: NSManagedObjectContext

  public init(moc: NSManagedObjectContext) {
    self.moc = moc
  }
}

extension SWDataContext {
  public func insert<O: NSManagedObject>(for object: O.Type) -> O {
    return insert(for: O.swEntityName) as! O
  }

  public func insert(for entityName: String) -> NSManagedObject {
    return NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
  }

  public func removePersistentStores() {
    guard let coordinator = moc.persistentStoreCoordinator else {
      return
    }

    for store in coordinator.persistentStores {
      try? coordinator.remove(store)
    }
  }
}

extension SWDataContext {
  public func delete(_ object: NSManagedObject) {
    moc.delete(object)
  }

  public func delete(by objectID: NSManagedObjectID) {
    let object = moc.object(with: objectID)

    delete(object)
  }

  public func delete<O: NSManagedObject>(_ object: O.Type, predicate: NSPredicate? = nil) {
    fetch(object, where: predicate)
      .forEach { delete($0) }
  }

  public func delete<O: NSManagedObject>(for object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) {
    fetch(object, where: NSPredicate(format: predicateFormat, argumentArray: args))
      .forEach { delete($0) }
  }
}

extension SWDataContext {
  public func object(with objectID: NSManagedObjectID) -> NSManagedObject {
    return moc.object(with: objectID)
  }

  public func request<O: NSManagedObject>(
    for entityName: String,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> NSFetchRequest<O> {
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
    let request: NSFetchRequest<O> = request(for: O.swEntityName, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)

    return try! moc.fetch(request)
  }

  public func fetch(
    _ entityName: String,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> [NSManagedObject] {
    let request: NSFetchRequest<NSManagedObject> = request(for: entityName, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)

    return try! moc.fetch(request)
  }

  public func fetchFirst(_ entityName: String, where predicate: NSPredicate? = nil) -> NSManagedObject? {
    return fetch(entityName, where: predicate, limit: 1).first
  }

  public func fetch<O: NSManagedObject>(_ object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> [O] {
    return fetch(object, where: NSPredicate(format: predicateFormat, argumentArray: args))
  }

  public func fetchFirst<O: NSManagedObject>(_ object: O.Type, whereFormat predicateFormat: String, _ args: CVarArg...) -> O? {
    return fetch(object, where: NSPredicate(format: predicateFormat, argumentArray: args), limit: 1).first
  }

  public func resultsController<O: NSManagedObject>(
    for object: O.Type,
    where predicate: NSPredicate? = nil,
    orderBy sortDescriptors: [NSSortDescriptor]? = nil,
    limit: Int = 0,
    offset: Int = 0
  ) -> NSFetchedResultsController<O> {
    let request: NSFetchRequest<O> = request(for: O.swEntityName, where: predicate, orderBy: sortDescriptors, limit: limit, offset: offset)
    let fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)

    do {
      try fetchedResultsController.performFetch()
    } catch {
      fatalError("Failed to create NSFetchedResultsController: \(error)")
    }

    return fetchedResultsController
  }
}

extension SWDataContext {
  public func count<O: NSManagedObject>(for object: O.Type, where predicate: NSPredicate? = nil) -> Int {
    let request: NSFetchRequest<O> = request(for: O.swEntityName, where: predicate)

    return (try? moc.count(for: request)) ?? 0
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
        properties.append(attribute.key)
        continue
      }

      let description = NSExpressionDescription()
      description.name = expression.name
      description.expressionResultType = expression.resultType
      description.expression = NSExpression(forFunction: "\(expression.function.rawValue):", arguments: [
        NSExpression(forKeyPath: expression.key)
      ])

      properties.append(description)
    }

    let request = NSFetchRequest<NSDictionary>(entityName: O.swEntityName)
    request.predicate = predicate
    request.resultType = .dictionaryResultType
    request.returnsObjectsAsFaults = false
    request.propertiesToFetch = properties
    request.propertiesToGroupBy = groups
    request.havingPredicate = havingPredicate
    request.sortDescriptors = sortDescriptors
    request.fetchLimit = limit
    request.fetchOffset = offset

    return try! moc.fetch(request)
  }
}

extension SWDataContext {
  public func save() {
    if moc.hasChanges {
      do {
        try moc.save()
      } catch {
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }

  public func perform(_ block: @escaping () -> Void) {
    moc.perform(block)
  }

  public func performAndWait(_ block: () -> Void) {
    moc.performAndWait(block)
  }
}
