//
//  SWDataAttribute.swift
//  
//
//  Created by Mirsaid Patarov on 2021-08-13.
//

import CoreData

public class SWDataAttribute: NSObject, ExpressibleByStringLiteral {
  let value: String
  let name: String?
  let function: SWAggregateFunction?
  let resultType: NSAttributeType?

  required convenience public init(stringLiteral value: String) {
    self.init(value)
  }

  init(_ value: String, withFunction function: SWAggregateFunction? = nil, nameAs name: String? = nil, resultType: NSAttributeType? = nil) {
    self.value = value
    self.name = name
    self.function = function
    self.resultType = resultType
  }

  public class func sum(_ value: String, nameAs name: String? = "sum", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataAttribute(value, withFunction: .sum, nameAs: name, resultType: resultType)
  }

  public class func count(_ value: String, nameAs name: String? = "count", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataAttribute(value, withFunction: .count, nameAs: name, resultType: resultType)
  }

  public class func min(_ value: String, nameAs name: String? = "min", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataAttribute(value, withFunction: .min, nameAs: name, resultType: resultType)
  }

  public class func max(_ value: String, nameAs name: String? = "max", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataAttribute(value, withFunction: .max, nameAs: name, resultType: resultType)
  }
}

