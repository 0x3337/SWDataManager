//
//  SWMigrationStep.swift
//  
//
//  Created by Mirsaid Patarov on 2023-03-14.
//

import CoreData

public struct SWMigrationStep {
  let sourceVersion: Int
  let destinationVersion: Int

  public init(sourceVersion: Int, destinationVersion: Int) {
    self.sourceVersion = sourceVersion
    self.destinationVersion = destinationVersion
  }
}
