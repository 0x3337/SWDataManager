//
//  SWDataExpression.swift
//  
//
//  Created by Mirsaid Patarov on 2023-02-26.
//

import CoreData

extension SWDataExpression {
  enum AggregateFunction: String {
    case min
    case max
    case sum
    case count
  }
}

class SWDataExpression: SWDataAttribute {
  let name: String
  let function: AggregateFunction
  let resultType: NSAttributeType

  init(_ value: String, as name: String, function: AggregateFunction, resultType: NSAttributeType) {
    self.name = name
    self.function = function
    self.resultType = resultType

    super.init(value, nameAs: name)
  }
  
  required convenience public init(stringLiteral value: String) {
    fatalError("init(stringLiteral:) has not been implemented")
  }
}
