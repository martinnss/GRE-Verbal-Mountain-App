---
name: swiftdata-migrations
description: "Use when: adding fields to models, versioning schema, handling data migrations, or dealing with SwiftData initialization errors. Ensures V1→V2→V3 migration path integrity."
---

# SwiftData Migration Protocol

## Current Schema Version

**IMMUTABLE**: Schema V3 is the current version. Do NOT create V4 with unchanged model checksums.

Version history:
- V1: Initial schema (legacy)
- V2: Interim schema (legacy)
- V3: Current production schema (LOCKED)

## Migration Path

**RULE**: Must follow V1→V2→V3 in sequence. Never skip versions.

### Why This Matters

SwiftData uses schema versions to detect when model changes require migration. If you:
- Create V4 without actual model changes → confuses the migration engine
- Skip a version → SwiftData cannot find migration path
- Run migrations out of order → data corruption

## When to Create V4

**Only if**:
1. You add/remove properties from any model (VocabWord, DrillSession, WordProgress)
2. You change property types
3. You modify relationships between models

**Steps**:
1. Document the change (what property changed, why)
2. Create migration handler for V3→V4
3. Test on both fresh install and upgrade from V3
4. Update AGENTS.md and recovery notes

## Model Changes Checklist

Before modifying a model:
- [ ] Is this a breaking change? (removing field, changing type)
- [ ] Have you planned the migration logic?
- [ ] Will existing users' data be preserved?
- [ ] Will you need to backfill missing fields?

### Safe Changes (No Migration Needed)
- Adding optional property with default value
- Renaming computed property
- Changing method implementation

### Unsafe Changes (Migration Required)
- Removing property
- Making property required that was optional
- Changing property type
- Changing property name

## Container Initialization Pattern

**Always use this pattern**:

```swift
import SwiftData

@main
struct GRE_VerbalApp: App {
    let modelContainer: ModelContainer
    
    init() {
        let schema = Schema([VocabWord.self, DrillSession.self, WordProgress.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
```

**Critical Rules**:
- [ ] Use `isStoredInMemoryOnly: false` (production must persist)
- [ ] List ALL models in schema
- [ ] Use `fatalError` on init failure (crash early)
- [ ] Pass container to ContentView via `.modelContainer()`

## Testing Migrations

### Test 1: Fresh Install
1. Delete app from simulator
2. Run app
3. Verify default data loads correctly

### Test 2: Upgrade from V3
1. Create simulator snapshot with V3 data
2. Install new build
3. Verify:
   - App launches without crash
   - Existing data loads correctly
   - New fields have sensible defaults
   - Analytics calculations remain correct

### Test 3: Data Integrity
```swift
func testMigration() {
    // Count words before and after
    let beforeCount = try? container.fetch(FetchDescriptor<VocabWord>()).count
    
    // Trigger migration
    // ...
    
    let afterCount = try? container.fetch(FetchDescriptor<VocabWord>()).count
    
    XCTAssertEqual(beforeCount, afterCount, "Data loss during migration!")
}
```

## Common Migration Errors

**Error**: "Cannot find model version file"
- Cause: Schema version mismatch between models and container config
- Fix: Ensure all models have correct version attributes

**Error**: "Migration failed silently"
- Cause: Migration handler not registered
- Fix: Verify migration handler is in same module as models

**Error**: "Data corruption after upgrade"
- Cause: Not using `backup` configuration or incomplete migration
- Fix: Use standard pattern above, test on real device

## SwiftData Best Practices

1. **Keep models immutable** - Use `@Attribute(.unique)` for identifiers
2. **Use weak relationships** - Prevent retain cycles with `.cascade` deletion
3. **Index frequently queried fields** - Add `@Attribute(.indexed)` to search keys
4. **Test both scenarios** - Fresh install AND upgrade paths
5. **Never delete swiftdata files manually** - Let migration handle it

## Recovery Protocol

If migration fails in production:

1. **STOP** - Don't continue modifications
2. **Restore** - Rollback to previous working schema version
3. **Diagnose** - Check CoreData logs for specific errors
4. **Test** - Create test case for the failure scenario
5. **Retry** - Fix root cause and test thoroughly before redeployment
