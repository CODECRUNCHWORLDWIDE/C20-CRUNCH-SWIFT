// Exercise 3 — A lightweight migration with schema versioning
//
// Goal: Seed a V1 store on disk, then open it with a V2 schema that ADDS a
//       field and RENAMES another, via a VersionedSchema + SchemaMigrationPlan.
//       Prove the V1 data survives the upgrade (the rename keeps its values,
//       the new field gets its default). This is the test most people skip and
//       then ship a data-loss bug.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite. Drop it into a test target (iOS 17+/macOS 14+).
// Unlike exercise 2 it uses an ON-DISK store at a temp URL, because a migration
// only happens when an OLDER store is opened by a NEWER schema — an in-memory
// store is always created fresh at the latest version and never migrates. That
// "in-memory never migrates" fact is itself the trap this exercise teaches.
//
//   1. Add to your test target.
//   2. Run with Cmd-U.
//   3. Read the assertions: V1 rows keep their renamed-field values, and the
//      new field is present with its default.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] `testFreshInstallStartsAtV2` passes — a new store is created at V2.
//   [ ] `testUpgradeFromV1PreservesData` passes — old data survives, renamed
//       column keeps values, new field has its default.
//   [ ] You can explain why testing ONLY a fresh install would have hidden a
//       data-loss bug.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import SwiftData
import Testing

// ----------------------------------------------------------------------------
// V1 — what shipped first. A Note with `title`, `body`, `createdAt`.
// ----------------------------------------------------------------------------

enum NotesSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Note.self] }

    @Model
    final class Note {
        var title: String
        var body: String
        var createdAt: Date

        init(title: String, body: String, createdAt: Date = .now) {
            self.title = title
            self.body = body
            self.createdAt = createdAt
        }
    }
}

// ----------------------------------------------------------------------------
// V2 — the upgrade. Two changes:
//   (1) ADD `isPinned: Bool` with a default -> additive, lightweight.
//   (2) RENAME `body` -> `content` via originalName -> lightweight, no data loss.
// ----------------------------------------------------------------------------

enum NotesSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Note.self] }

    @Model
    final class Note {
        var title: String
        @Attribute(originalName: "body") var content: String   // keeps the V1 "body" data
        var createdAt: Date
        var isPinned: Bool = false                             // new, defaulted

        init(title: String, content: String, createdAt: Date = .now, isPinned: Bool = false) {
            self.title = title
            self.content = content
            self.createdAt = createdAt
            self.isPinned = isPinned
        }
    }
}

// ----------------------------------------------------------------------------
// The migration plan: V1 -> V2 is lightweight (rename + defaulted add).
// ----------------------------------------------------------------------------

enum NotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NotesSchemaV1.self, NotesSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: NotesSchemaV1.self,
        toVersion: NotesSchemaV2.self
    )
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

/// A unique temp store URL per test run so runs don't pollute each other.
func freshStoreURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("notes-migration-\(UUID().uuidString)")
        .appendingPathExtension("store")
}

/// Open a container at `url` using ONLY the V1 schema (simulating the old app build).
@MainActor
func openV1(at url: URL) throws -> ModelContainer {
    let config = ModelConfiguration(schema: Schema([NotesSchemaV1.Note.self]), url: url)
    return try ModelContainer(for: NotesSchemaV1.Note.self, configurations: config)
}

/// Open a container at `url` using the V2 schema + migration plan (the new app build).
@MainActor
func openV2(at url: URL) throws -> ModelContainer {
    let config = ModelConfiguration(schema: Schema([NotesSchemaV2.Note.self]), url: url)
    return try ModelContainer(
        for: NotesSchemaV2.Note.self,
        migrationPlan: NotesMigrationPlan.self,
        configurations: config
    )
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

@MainActor
struct LightweightMigrationTests {

    @Test("A fresh install creates the store directly at V2")
    func freshInstallStartsAtV2() throws {
        let url = freshStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try openV2(at: url)
        let context = ModelContext(container)

        let note = NotesSchemaV2.Note(title: "Hello", content: "world", isPinned: true)
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<NotesSchemaV2.Note>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.content == "world")
        #expect(fetched.first?.isPinned == true)
    }

    @Test("Upgrading a V1 store to V2 preserves data through rename + add")
    func upgradeFromV1PreservesData() throws {
        let url = freshStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // --- Phase 1: the OLD app writes V1 data, then "ships" (we close it). ---
        do {
            let v1Container = try openV1(at: url)
            let v1Context = ModelContext(v1Container)
            v1Context.insert(NotesSchemaV1.Note(title: "Groceries", body: "milk, eggs"))
            v1Context.insert(NotesSchemaV1.Note(title: "Standup", body: "blockers?"))
            try v1Context.save()
            #expect(try v1Context.fetchCount(FetchDescriptor<NotesSchemaV1.Note>()) == 2)
        }
        // v1Container is out of scope; the store on disk is still V1.

        // --- Phase 2: the NEW app opens the same file with V2 + the plan. ---
        let v2Container = try openV2(at: url)
        let v2Context = ModelContext(v2Container)

        let migrated = try v2Context.fetch(
            FetchDescriptor<NotesSchemaV2.Note>(sortBy: [SortDescriptor(\.title)])
        )

        // The two V1 notes are STILL HERE...
        #expect(migrated.count == 2)
        // ...the renamed `body` column kept its values under the new name `content`...
        #expect(migrated.map(\.content) == ["milk, eggs", "blockers?"])
        #expect(migrated.map(\.title) == ["Groceries", "Standup"])
        // ...and the new `isPinned` field exists with its default.
        #expect(migrated.allSatisfy { $0.isPinned == false })
    }
}

// ----------------------------------------------------------------------------
// WHY testing only fresh install hides the bug (write it before reading):
//
//   A fresh install creates the store directly at the LATEST schema version, so
//   NO migration code ever runs. If your migration is broken — a rename without
//   originalName, a non-additive change marked lightweight — the fresh-install
//   path is green while every existing user's upgrade silently drops the column
//   or crashes on launch. You MUST seed an old store and open it with the new
//   schema to exercise the migration. That is what Phase 1 + Phase 2 above do.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `@Attribute(originalName: "body")` is the whole trick. Remove it and re-run
//   `upgradeFromV1PreservesData`: the `content` values come back EMPTY, because
//   without it the migration drops `body` and adds a brand-new empty `content`.
//   Seeing that failure is the lesson — try it.
//
// - The store URL must be the SAME file across Phase 1 and Phase 2. If you
//   generate a new URL in Phase 2 you create a fresh V2 store and the test
//   wrongly "passes" with zero rows. Reuse `url`.
//
// - You must let the V1 container go out of scope (the `do { }` block) before
//   opening V2, so the store isn't held open by two coordinators at once.
//
// - `Schema.Version(major, minor, patch)` — bump major for a breaking schema,
//   minor/patch for compatible tweaks. The number is recorded in the store's
//   Z_METADATA so SwiftData knows which migration stages to run.
//
// ----------------------------------------------------------------------------
