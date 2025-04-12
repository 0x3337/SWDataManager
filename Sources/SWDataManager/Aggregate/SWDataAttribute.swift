//
//  SWDataAttribute.swift
//  
//
//  Created by Mirsaid Patarov on 2021-08-13.
//

import CoreData

public class SWDataAttribute: NSObject, ExpressibleByStringLiteral {
  let key: String

  init(_ key: String) {
    self.key = key
  }

  required convenience public init(stringLiteral key: String) {
    self.init(key)
  }

  public class func sum(_ key: String, as name: String = "sum", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(key, as: name, function: .sum, resultType: resultType)
  }

  public class func count(_ key: String, as name: String = "count", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(key, as: name, function: .count, resultType: resultType)
  }

  public class func min(_ key: String, as name: String = "min", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(key, as: name, function: .min, resultType: resultType)
  }

  public class func max(_ key: String, as name: String = "max", resultType: NSAttributeType) -> SWDataAttribute {
    return SWDataExpression(key, as: name, function: .max, resultType: resultType)
  }
}
