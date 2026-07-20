# Week 10 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 10 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+ (iOS 18 for `#Index`), Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**.

---

## Problem 1 — Read the actual SQLite the macros wrote

**Problem statement.** Using the `Scratch` app from exercise 1 (or your mini-project), add at least five notes, then locate and inspect the on-disk SQLite store. Write your findings into `notes/store-anatomy.md`: the path to the `.store` file, the list of tables (`.tables`), the columns of the note table (`.schema ZNOTE` or `PRAGMA table_info(ZNOTE)`), and one sentence on what the `Z_PK`, `Z_ENT`, and `Z_OPT` columns are for. Add a second sentence: which framework wrote those tables, and how do you know?

**Acceptance criteria.**

- `notes/store-anatomy.md` exists with the path, table list, column list, and the two sentences.
- The `Z`-prefixed tables and columns are quoted from your actual store, not invented.
- Committed.

**Hint.** `DATA=$(xcrun simctl get_app_container booted <bundle-id> data)`, then `find "$DATA" -name '*.store'`, then `sqlite3 <path> '.tables'`. The `Z` prefix and the `Z_ENT` entity discriminator are Core Data's — that's your evidence for "which framework."

**Estimated time.** 30 minutes.

---

## Problem 2 — Three delete rules, three behaviours

**Problem statement.** In a test target, model a `Project` with a to-many relationship to `Task`, and write three variants in three separate `@Model` pairs (or three test runs with different `deleteRule`): `.cascade`, `.nullify`, and `.deny`. For each, insert a project with two tasks, delete the project, and assert what happens to the tasks. Write a one-line comment on each test explaining when that rule is the *correct* choice in a real app.

**Acceptance criteria.**

- Three passing tests (or three clearly-separated assertions) covering `.cascade` (tasks deleted), `.nullify` (tasks survive, relationship cleared), and `.deny` (delete throws while tasks exist).
- Each has a one-line justification of when to use it.
- Uses an `isStoredInMemoryOnly` container. 0 warnings.
- Committed.

**Hint.** For `.deny`, wrap the `context.save()` after delete in `#expect(throws:)` / `XCTAssertThrowsError` — the deny rule surfaces as a save failure when relationships still exist. For `.cascade`, after deleting the project, `fetchCount` of `Task` should be 0.

**Estimated time.** 50 minutes.

---

## Problem 3 — `fetchCount` vs `fetch().count`

**Problem statement.** Seed an in-memory store with 20,000 records. Measure (with `ContinuousClock`) the time and explain the difference between `context.fetchCount(descriptor)` and `context.fetch(descriptor).count` for getting the number of matching rows. Record both timings in `notes/count-timing.md` and state which one materialises objects and which one doesn't.

**Acceptance criteria.**

- A test or script that seeds 20,000 rows and times both approaches.
- `notes/count-timing.md` records both timings and the one-sentence explanation (`fetchCount` runs `SELECT COUNT(*)` and builds zero objects; `fetch().count` materialises every matching object to count them).
- Committed.

**Hint.** Reuse the `elapsed { }` helper from exercise 2. Make the predicate match a large fraction of rows so the cost of materialising objects in the `.count` path is visible.

**Estimated time.** 35 minutes.

---

## Problem 4 — A dynamic `@Query` view

**Problem statement.** Build a SwiftUI view `FilteredNotesView` that takes a `minViews: Int` parameter and shows only notes with `views >= minViews`, sorted by `views` descending, using a **dynamic `@Query`** (re-initialised in `init`). Drive it from a parent with a `Stepper` or `Picker` that changes `minViews`, and confirm the list re-fetches when the parameter changes.

**Acceptance criteria.**

- `FilteredNotesView(minViews:)` uses `_results = Query(filter: #Predicate { ... }, sort: [...])` in its `init`.
- A parent view changes `minViews` and the child re-fetches (verify by eye in the Simulator or with a render print).
- 0 warnings. Committed.

**Hint.** The parent holds `@State private var minViews` and passes it down: `FilteredNotesView(minViews: minViews)`. Each new value makes SwiftUI recreate the child, whose `init` rebuilds the `Query`. Don't try to mutate a `@State` *inside* the query-owning view and expect a re-fetch.

**Estimated time.** 45 minutes.

---

## Problem 5 — A custom migration stage

**Problem statement.** Extend exercise 03's schema with a **V3** that adds `var wordCount: Int = 0` to `Note` and uses a **custom** `MigrationStage` whose `didMigrate` populates `wordCount` from the `content` field for every existing note. Write a test that seeds V2 data, migrates to V3, and asserts `wordCount` is correctly computed for the migrated rows.

**Acceptance criteria.**

- `NotesSchemaV3` with `wordCount`, a `MigrationStage.custom(from: V2, to: V3, willMigrate:didMigrate:)`, and the plan updated to include V1→V2 (lightweight) and V2→V3 (custom).
- A passing test: seed V2 notes with known content, open with V3, assert `wordCount == content.split(separator: " ").count`.
- 0 warnings. Committed.

**Hint.** In `didMigrate`, `try context.fetch(FetchDescriptor<NotesSchemaV3.Note>())`, compute the count, assign, and `try context.save()`. `willMigrate` can stay empty here — there's nothing to stash before the schema changes. Remember to test the *upgrade* path (seed V2, open V3), not a fresh V3 install.

**Estimated time.** 50 minutes.

---

## Problem 6 — A background import on a `@ModelActor`

**Problem statement.** Write a `@ModelActor` named `NoteImporter` with a method `importTitles(_ titles: [String]) async throws -> Int` that inserts a `Note` per title on its own context, saves off the main thread, and returns the count. From a SwiftUI view, run an import of 1,000 titles and confirm a main-thread `@Query` list updates automatically once the import's save merges in — without you manually refreshing.

**Acceptance criteria.**

- `@ModelActor actor NoteImporter` with the described method; it returns a `Sendable` count, never a model object.
- The caller passes the `ModelContainer` (Sendable) into the actor; no `ModelContext` or `Note` crosses the actor boundary.
- The main `@Query` list reflects the imported rows after the import completes.
- Builds with **0 strict-concurrency warnings**. Committed.

**Hint.** `let importer = NoteImporter(modelContainer: container); let n = try await importer.importTitles(titles)`. `@ModelActor` synthesises the `init(modelContainer:)` and the private `modelContext`. Get the container from `\.modelContext.container` in the view, or hold it explicitly. Don't capture the view's `@Environment` context inside the actor.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/SwiftData, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. `fetch().count` left in, an unnecessary explicit `save()`, a missing `final`). |
| 3 | Works, but misses one criterion (e.g. dynamic query not actually dynamic, migration tested only on fresh install, a `Sendable` warning suppressed instead of fixed). |
| 2 | Compiles and partially works; a core idea is wrong (filters in memory where a predicate was required; rename without `originalName`). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for a destructive migration that loses data; **−1** for filtering in memory where a `#Predicate` was the point.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — predicate-in-SQLite vs filter-in-memory (problems 3, 4) and the migration upgrade path (problems 5) — so re-run exercises 02 and 03 before resubmitting.
