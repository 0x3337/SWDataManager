//
//  File.swift
//  
//
//  Created by Mirsaid Patarov on 2023-03-14.
//

import Foundation

public protocol SWMigrationSource: NSObjectProtocol {
  func migrationSteps() -> [SWMigrationStep]
}
