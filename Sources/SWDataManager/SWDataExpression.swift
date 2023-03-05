//
//  SWDataExpression.swift
//  
//
//  Created by Mirsaid Patarov on 2023-02-26.
//

import CoreData

class SWDataExpression: SWDataAttribute {
  let name: String
  let function: SWAggregateFunction
  let resultType: NSAttributeType

  init(_ value: String, as name: String, function: SWAggregateFunction, resultType: NSAttributeType) {
    self.name = name
    self.function = function
    self.resultType = resultType

    super.init(value, nameAs: name)
  }

  required convenience public init(stringLiteral value: String) {
    self.init(stringLiteral: value)
  }
}
