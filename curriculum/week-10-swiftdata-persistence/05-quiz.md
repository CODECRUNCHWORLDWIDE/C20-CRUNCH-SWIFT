# Week 10 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 11. Answer key with explanations at the bottom — don't peek.

---

**Q1.** Which statement best describes SwiftData's relationship to Core Data in 2026?

- A) SwiftData is a brand-new storage engine that replaced Core Data; the two share no code.
- B) SwiftData is a Swift-macro front end over Core Data — same `NSManagedObjectContext`, coordinator, and SQLite store underneath.
- C) Core Data is a front end over SwiftData; SwiftData is the lower-level engine.
- D) They are unrelated frameworks that happen to both use SQLite.

---

**Q2.** Why must a `@Model` type be a `class` and not a `struct`?

- A) Macros can only be applied to classes.
- B) Persistence requires stable object *identity* — two references to the same row must be the same object with shared change tracking, which only a reference type provides.
- C) Structs cannot conform to `Observable`.
- D) SQLite can only store reference types.

---

**Q3.** You insert a second `Tag(name: "swift")` into a context where `Tag.name` is `@Attribute(.unique)` and a "swift" tag already exists. What happens?

- A) A runtime error is thrown for the duplicate.
- B) A second "swift" row is created.
- C) The existing row is **updated** with the new object's values (an upsert); no duplicate, no error.
- D) The insert is silently ignored and the new object is discarded.

---

**Q4.** A `Note` has a many-to-many relationship to `Tag`. You delete a `Note`. Which `deleteRule` ensures the tags survive (because other notes still use them)?

- A) `.cascade`
- B) `.deny`
- C) `.nullify`
- D) `.noAction`

---

**Q5.** What is the practical difference between these two, given a 50,000-row store, both returning the same matches?

```swift
// A
try context.fetch(FetchDescriptor<Note>()).filter { $0.topic == "swift" }
// B
try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.topic == "swift" }))
```

- A) No difference; the compiler optimizes them to the same query.
- B) A filters in memory after materialising all 50,000 objects; B filters in SQLite and materialises only the matches — B is far cheaper.
- C) B is slower because `#Predicate` has macro overhead.
- D) A is cheaper because it avoids the predicate translation step.

---

**Q6.** What is a `ModelContext` best described as?

- A) The on-disk SQLite file.
- B) The compiled schema.
- C) A unit of work — a scratchpad tracking inserts/updates/deletes that becomes durable on `save()`.
- D) A SwiftUI property wrapper.

---

**Q7.** Under Swift 6 strict concurrency, which of these is **illegal**?

- A) Reading `\.modelContext` from the environment in a `@MainActor` view.
- B) Capturing the main `ModelContext` (or a model object) inside a `Task.detached` and using it there.
- C) Passing a `ModelContainer` to a `@ModelActor`.
- D) Calling `context.save()` on the main actor.

---

**Q8.** Your `@Query var notes: [Note]` should filter by a `tagName` that comes from a parent view at runtime. How do you make the query depend on it?

- A) Mutate a `@State var tagName` and the `@Query` re-runs automatically.
- B) Re-initialise the `Query` in the view's `init` using the synthesised `_notes` backing property, so a new `tagName` rebuilds the predicate.
- C) Use `@Query` with a closure that reads `@State`.
- D) You can't; `@Query` is always static.

---

**Q9.** You add a new optional property `var isPinned: Bool = false` to a shipped model. What kind of migration is this?

- A) It requires a custom `MigrationStage` with `willMigrate`/`didMigrate`.
- B) It's a lightweight (additive) migration SwiftData can perform automatically.
- C) It's impossible without deleting the store.
- D) It requires renaming the entity.

---

**Q10.** You rename a property from `body` to `content`. Without any extra annotation, what happens to existing data on upgrade?

- A) The data is moved to the new name automatically.
- B) The `body` column is dropped and a new empty `content` column is added — the data is **lost**.
- C) The app refuses to launch until you add a custom migration.
- D) Both columns coexist with duplicated data.

---

**Q11.** Why does testing only a fresh install hide a broken migration?

- A) Fresh installs run all migration stages, so they always pass.
- B) A fresh install creates the store directly at the latest schema version, so **no** migration code runs — a broken upgrade path stays green.
- C) Fresh installs use an in-memory store that can't migrate.
- D) It doesn't; fresh install fully exercises migrations.

---

**Q12.** A `List(notes)` shows `"\(note.tags.count)"` per row and scrolling is janky on a large store. What's the cause and fix?

- A) Cause: too many SwiftUI views. Fix: use `LazyVStack`.
- B) Cause: N+1 relationship faulting — `note.tags` triggers a SQLite query per row. Fix: set `relationshipKeyPathsForPrefetching = [\Note.tags]` on the fetch.
- C) Cause: the predicate is wrong. Fix: remove the predicate.
- D) Cause: autosave. Fix: disable autosave.

---

**Q13.** You need to delete a million rows older than a year, efficiently, in an otherwise pure-SwiftData app. What's the right move?

- A) `context.delete` each object in a loop — SwiftData optimizes it.
- B) There's no way; SwiftData can't delete in bulk.
- C) Drop to the shared Core Data coordinator and use `NSBatchDeleteRequest`, which deletes in SQL without materialising the objects — possible because SwiftData and Core Data share the same store.
- D) Re-create the store from scratch.

---

## Answer key

**Q1 — B.** SwiftData is a macro front end over Core Data. The store is a Core Data SQLite store (`ZNOTE`, `Z_PK`, `Z_ENT` tables), the context wraps `NSManagedObjectContext`, and predicates lower toward `NSPredicate`. Knowing this doubles the help available when something leaks. (Lecture 1, §1.)

**Q2 — B.** Persistence is about identity: editing "the note with `persistentModelID` X" in a detail view must update the same object the list shows. Value types copy; reference types share identity and change tracking. (Lecture 1, §3.) (Macros can apply to structs too, so A is wrong.)

**Q3 — C.** `.unique` gives **upsert** semantics: a colliding insert updates the existing row. No error, no duplicate. This surprises everyone once. (Lecture 1, §3.)

**Q4 — C.** `.nullify` removes the reference but keeps the related objects. A shared tag must survive deleting one of its notes. `.cascade` would delete the tags (data-loss bug here). (Lecture 1, §3; mini-project Milestone 1.)

**Q5 — B.** A materialises all 50,000 objects across the faulting layer then keeps a handful; B pushes the filter into SQLite's `WHERE` clause so only matches become Swift objects. Same answer, vastly different cost — the week's central footgun. (Lecture 1, §6; lecture 2, §3.)

**Q6 — C.** The context is the unit of work (a `ModelContext` wraps `NSManagedObjectContext`). The container is the database; `@Query` is the property wrapper; the `.store` file is the SQLite store. (Lecture 1, §5.)

**Q7 — B.** `ModelContext` and model objects are **not** `Sendable`; capturing the main context in a `Task.detached` is a compile error. The supported background pattern is a `@ModelActor` with its own context, to which you may pass the `Sendable` `ModelContainer`. (Lecture 1, §5; lecture 2, §3.)

**Q8 — B.** `@Query`'s parameters are fixed at init. To make it dynamic you rebuild the `Query` in the view's `init` via `_notes = Query(...)`; passing a new `tagName` recreates the view and re-fetches. (Lecture 1, §6; mini-project Milestone 4.)

**Q9 — B.** Adding a property with a default (or an optional) is additive and lightweight — SwiftData infers it. (Lecture 2, §2.)

**Q10 — B.** A bare rename looks like "drop `body`, add empty `content`" — data loss. The fix is `@Attribute(originalName: "body")`, which tells SwiftData to keep the column's data under the new name. (Lecture 2, §2; exercise 03.)

**Q11 — B.** A fresh install creates the store at the latest version, so no migration runs and a broken upgrade stays green. You must seed an old store and open it with the new schema to exercise the migration. (Lecture 2, §2; exercise 03.)

**Q12 — B.** This is the N+1 relationship fault: `note.tags` faults per row. Prefetch it with `relationshipKeyPathsForPrefetching = [\Note.tags]` so SwiftData batches the load into one query. (Lecture 1, §3; lecture 2, §3.)

**Q13 — C.** SwiftData has no batch-delete API, but because it shares the store with Core Data you drop to the coordinator and use `NSBatchDeleteRequest`, which deletes in SQL without materialising objects. The lineage means Core Data is always reachable. (Lecture 2, §1.)

---

*Score 11+? On to Week 11. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the predicate-vs-naive distinction and the migration upgrade path are the two ideas this week is graded on.*
