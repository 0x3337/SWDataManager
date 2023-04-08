//
//  SWDataAttribute.swift
//  
//
//  Created by Mirsaid Patarov on 2021-08-13.
//

import CoreData

public class SWDataAttribute: NSObject, ExpressibleByStringLiteral {
  let value: String

  init(_ value: String, nameAs name: String? = nil) {
    self.value = value
  }

  required convenience public init(stringLiteral value: String) {
    self.init(value)
  }

  public class func sum(_ value: String, as name: String = "sum", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(value, as: name, function: .sum, resultType: resultType)
  }

  public class func count(_ value: String, as name: String = "count", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(value, as: name, function: .count, resultType: resultType)
  }

  public class func min(_ value: String, as name: String = "min", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(value, as: name, function: .min, resultType: resultType)
  }

  public class func max(_ value: String, as name: String = "max", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(value, as: name, function: .max, resultType: resultType)
  }
}
