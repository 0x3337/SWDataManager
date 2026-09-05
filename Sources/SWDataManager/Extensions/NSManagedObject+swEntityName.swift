//
//  NSManagedObject+swEntityName.swift
//
//
//  Created by Mirsaid Patarov on 2026-09-05.
//

import CoreData

extension NSManagedObject {
  public static var swEntityName: String {
    if let object = self as? SWEntityNamable.Type {
      return object.entityName
    }

    return String(describing: self)
  }
}
