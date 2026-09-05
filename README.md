# SWDataManager

## Testing migrations

`SWMigrationManager` doubles as the entry point for migration tests. Point it at the container name, and it loads the versioned models (`<name>.momd/<name> N.mom`) and the mapping models from the bundle — `.main` by default, which is the host app bundle when tests run with a host application.

`migratedContext(from:to:populate:)` builds a store on the source version, hands it to `populate`, saves it, runs the migration and returns a `SWDataContext` on the migrated store:

```swift
import CoreData
import SWDataManager
import Testing

struct MigrationTests {
  private let migrationManager = SWMigrationManager(name: "MyApp")

  @Test func migratesV1ToV2() throws {
    let context = migrationManager.migratedContext(from: 1, to: 2) { context in
      let account = context.insert(for: "Account")
      account.setValue("Cash", forKey: "name")
    }

    let account = try #require(context.fetchFirst("Account"))
    #expect(account.value(forKey: "id") is UUID)
  }
}
```

Entities are addressed by name — `insert(for:)`, `fetch(_:where:orderBy:limit:offset:)` and `fetchFirst(_:where:)` on `SWDataContext` return plain `NSManagedObject`s, so no generated classes are needed for versions that no longer have any.

Non-adjacent versions migrate step by step: `migratedContext(from: 1, to: 4)` runs 1 → 2 → 3 → 4 and needs a mapping model for every step. A missing model or mapping model is a `fatalError`, not a silent skip. Both stores live in the temporary directory and are left there.

The lower-level pieces are public as well: `managedObjectModel(forVersion:)`, `context(forVersion:at:)` for a store at a URL you own, and `migrateStore(at:from:to:)` which migrates one step and returns the destination URL.
