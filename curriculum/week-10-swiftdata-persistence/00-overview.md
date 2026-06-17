# Week 10 — SwiftData: the modern persistence story

Welcome to Week 10 of **C20 · Crunch Swift**. For nine weeks your data has lived in RAM. The `NotesStore` you built in Week 8 and grew in Week 9 is an `@Observable` array — fast, simple, and gone the instant the user swipes the app away and the OS reclaims the process. This week the data stops disappearing. By Friday your notes survive a relaunch, a reboot, and a low-memory kill, because they live in a SQLite database on disk that SwiftData manages for you.

SwiftData is Apple's 2023 persistence framework, and in 2026 it is the default answer for on-device storage in a new SwiftUI app. It is a thin, macro-driven, Swift-native layer **over Core Data** — the same `NSManagedObjectContext`, the same `NSPersistentStoreCoordinator`, the same SQLite file underneath. That lineage is the most important fact about SwiftData and the thing this week hammers on. SwiftData is not a new engine. It is a new *front end* on a fifteen-year-old engine, and almost everything that confuses people about SwiftData — why a fetch is slow, why a relationship faults lazily, why a migration fails, why a background write does not show up on the main thread — is explained by what Core Data is doing one layer down. We teach SwiftData as the thing you write and Core Data as the thing you debug.

The mental shift this week is from "I hold an array of structs" to "I declare a *schema* of reference-type model objects, and a *context* tracks my changes and flushes them to a store." A `@Model` class is not a struct — it is a managed object whose properties are backed by the database, faulted in on access, and tracked for changes. A `ModelContainer` is the database: it owns the schema, the on-disk file, and the configuration. A `ModelContext` is your unit of work: a scratchpad of inserts, updates, and deletes that becomes durable when it saves. `@Query` is the SwiftUI-native way to pull rows into a view and re-run automatically when the store changes. And `#Predicate` is the macro that compiles a Swift closure into something SQLite can run *in the database*, instead of dragging every row into memory so you can filter it in Swift — which is the performance footgun this week makes you commit on purpose and then fix.

We close the week by migrating **Hello, Notes** off the in-memory `NotesStore` and onto SwiftData. You will define a `Note` `@Model`, add a `Tag` `@Model` with a **many-to-many** relationship, query notes by tag with a `#Predicate`, and prove — by force-quitting the app and relaunching from cold — that the data is still there. You will also introduce a schema change (adding a field) and apply a **lightweight migration** with an explicit `VersionedSchema` and `SchemaMigrationPlan`, because "it worked on my machine, then I shipped v2 and everyone's data vanished" is a real crash report, and avoiding it is the actual skill this week earns.

## Learning objectives

By the end of this week, you will be able to:

- **Explain** SwiftData's relationship to Core Data — that it is a macro-driven front end over the same `NSManagedObjectContext` / SQLite stack — and predict which SwiftData behaviours (faulting, lazy relationships, context isolation) are inherited from that layer.
- **Model** a persistent schema with the `@Model` macro, tune storage with `@Attribute` (`.unique`, `.externalStorage`, `.preserveValueOnDeletion`), and wire object graphs with `@Relationship`, including a many-to-many and an explicit `inverse:` and `deleteRule:`.
- **Configure** a `ModelContainer` (in-app via the `.modelContainer(for:)` scene modifier, and standalone via `ModelConfiguration`) and obtain a `ModelContext` from the environment or by constructing one yourself.
- **Persist** records that survive an app relaunch — insert into a context, save, and verify durability by force-quitting and reopening.
- **Query** with `@Query` using a `#Predicate` and `SortDescriptor`s, and explain why the predicate runs in SQLite while a Swift `.filter` runs in memory.
- **Measure** the cost of a naive in-memory filter versus an indexed predicate-driven fetch, and read the difference in `signpost`/`OSLog` timing.
- **Apply** a lightweight migration: define `VersionedSchema`s, register a `SchemaMigrationPlan`, and ship a schema change without destroying user data.
- **Recognise** SwiftData's footguns — main-thread fetch storms, relationship N+1 faults, unbounded `@Query`, the `@Attribute(.unique)` upsert surprise — and the production fallbacks to raw Core Data when SwiftData hides too much.

## Prerequisites

This week assumes you have completed **C20 weeks 1–9**, or have equivalent fluency. Specifically:

- You can read and write idiomatic Swift — value vs reference types, `let` vs `var`, optionals, closures, generics — Weeks 1–2. The `struct`-vs-`class` distinction is load-bearing this week: `@Model` types are **classes**, and understanding why is half the lecture.
- You understand `Sendable`, `@MainActor`, and actor isolation — Week 4. `ModelContext` is **not** `Sendable`; a context belongs to the thread that created it, and the compiler under Swift 6 strict concurrency will hold you to it.
- You can name the owner of any piece of SwiftUI state and reach for `@State`, `@Binding`, `@Environment`, or `@Bindable` correctly — Week 8. `@Query` is a new state primitive that slots into that same ownership model.
- You have the **Hello, Notes** app from Weeks 7–9 checked into Git, with its `NavigationStack`/`NavigationSplitView` layout and the in-memory `@Observable` `NotesStore`. This week's mini-project compounds directly on it — you swap the store, the navigation stays.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. SwiftData requires iOS 17 / macOS 14 as the deployment floor, and several APIs you will use (`#Index`, `#Unique`, the `Schema.Version` ergonomics) are iOS 18+; we target iOS 18 for the new APIs and flag the iOS 17 fallbacks as we go. Everything this week runs in the Simulator — no device, no Apple Developer membership.

## Topics covered

- **The Core Data lineage.** What SwiftData is (a Swift-macro front end), what it is over (Core Data, `NSManagedObject`, SQLite), and which behaviours are inherited: object faulting, lazy relationship loading, per-context isolation, the parent/child context tree, and change-tracking via `NSManagedObjectContext`.
- **The `@Model` macro.** What it generates — `PersistentModel` conformance, an `@Observable`-style change-tracking shell, `PersistentIdentifier`, and the stored-property backing. Why a `@Model` is a reference type and what that means for SwiftUI.
- **`@Attribute`.** `.unique` (the upsert semantics, and the footgun), `.externalStorage` for blobs, `.preserveValueOnDeletion`, `.spotlight`, custom `originalName:` for renames, and `Codable`/transformable value types.
- **`@Relationship`.** To-one, to-many, and many-to-many; the `inverse:` keypath and why you usually want it explicit; `deleteRule:` (`.cascade`, `.nullify`, `.deny`, `.noAction`) and choosing the right one; relationship faulting and the N+1 problem.
- **`ModelContainer`.** The schema, the on-disk store URL, `ModelConfiguration` (in-memory for tests, `allowsSave`, `cloudKitDatabase`), the `.modelContainer(for:)` scene modifier, and constructing a container by hand.
- **`ModelContext`.** The unit of work: `insert`, `delete`, `save`, `rollback`, `hasChanges`, autosave, `mainContext` vs a fresh background context, and why a context is not `Sendable`.
- **`@Query`.** The SwiftUI property wrapper that fetches and auto-updates; passing a `#Predicate` and `[SortDescriptor]`; dynamic queries via `init` re-construction; `FetchDescriptor` for imperative fetches; `fetchCount` and `fetchLimit`.
- **`#Predicate`.** What the macro compiles to (an `NSPredicate`-equivalent the store evaluates), what Swift it accepts and rejects, why string `localizedStandardContains` works but an arbitrary closure does not, and the in-SQLite vs in-memory distinction.
- **`#Index` and `#Unique`.** Declaring a composite index (iOS 18+), what an index buys you on a sorted/filtered query, and measuring it.
- **Migrations.** Lightweight vs custom; `VersionedSchema`; `SchemaMigrationPlan` with migration stages; `originalName:` for renames; what counts as "lightweight" (additive) and what forces a custom migration.
- **Performance footguns.** Fetch-everything-then-filter-in-Swift, unbounded `@Query` driving a `List`, relationship N+1 faults, redundant saves, and the main-thread write that janks a scroll.
- **Core Data interop.** Reading a SwiftData store as a Core Data `NSManagedObjectModel`, the co-existence pattern for a legacy Core Data app, and when to drop to raw Core Data (heavy migrations, `NSBatchDeleteRequest`, derived attributes, fine-grained fetch control).

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                          | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | The Core Data lineage; `@Model`, `@Attribute`, container/context |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `@Relationship`; `@Query` + `#Predicate` + sort descriptors     |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Performance: naive vs indexed; `#Index`; footguns               |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Migrations + schema versioning; Core Data co-existence; challenge |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — migrate Hello, Notes to SwiftData; `Tag` model    |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; relaunch + tag-query verification        |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                      |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's SwiftData docs, the WWDC SwiftData sessions, Core Data lineage reading, and the canonical community writing on migrations and performance |
| [lecture-notes/01-swiftdata-and-the-core-data-lineage.md](./02-lecture-notes/01-swiftdata-and-the-core-data-lineage.md) | SwiftData end to end: what it solves, what it still hides, the `@Model`/`@Attribute`/`@Relationship` macros, container/context, `@Query`, `#Predicate`, faulting, and where it leaks Core Data |
| [lecture-notes/02-coexistence-migrations-and-footguns.md](./02-lecture-notes/02-coexistence-migrations-and-footguns.md) | The SwiftData / Core Data co-existence pattern, lightweight vs custom migrations with `VersionedSchema`, and the performance footguns with measured before/after |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-model-container-survives-relaunch.md](./03-exercises/exercise-01-model-container-survives-relaunch.md) | Define `@Model` types, wire a `ModelContainer`, persist records, and prove they survive a force-quit relaunch |
| [exercises/exercise-02-query-predicate-vs-naive.swift](./03-exercises/exercise-02-query-predicate-vs-naive.swift) | Query with `@Query` + `#Predicate` + sort descriptors and measure naive-in-memory vs predicate-in-SQLite cost |
| [exercises/exercise-03-lightweight-migration.swift](./03-exercises/exercise-03-lightweight-migration.swift) | Introduce a schema change and apply a lightweight migration with `VersionedSchema` + `SchemaMigrationPlan` |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-footgun-then-refactor.md](./04-challenges/challenge-01-footgun-then-refactor.md) | Plant a deliberate fetch-everything-then-filter footgun, refactor it into a `#Predicate`-driven query, and document the before/after timing |
| [quiz.md](./05-quiz.md) | 13 questions on the lineage, macros, container/context, `@Query`/`#Predicate`, migrations, and footguns |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for "Hello, Notes — SwiftData edition": migrate off `NotesStore`, add a `Tag` many-to-many, query by tag, survive relaunch |

## The "survives a cold launch" promise

Week 8 gave you "renders exactly once." Week 9 gave you "restores from a cold launch." Week 10 adds the persistence contract a senior reviewer actually checks:

> **State the user created must survive the process dying.** Create a note, force-quit the app from the app switcher (not just background it — kill it), relaunch from the home screen, and the note is still there, with its tags, in the right sort order. If a relaunch loses data, the persistence layer is broken, no matter how clean the code looks.

You will *prove* this by force-quitting in the Simulator (long-press the app card and swipe up, or `xcrun simctl terminate`) and relaunching cold. "It stayed when I backgrounded it" is not the test — backgrounding keeps the process alive and the in-memory array intact, which is exactly the bug SwiftData fixes. Kill the process.

## A note on what's not here

Week 10 is the *on-device persistence* week. It deliberately does **not** cover:

- **CloudKit sync.** SwiftData can sync to a private CloudKit database with a one-line `ModelConfiguration` change, but multi-device sync, conflict resolution, and the schema constraints CloudKit imposes (no `.unique`, all relationships optional) are their own topic. We flag the `cloudKitDatabase:` parameter and move on; sync proper comes in Phase IV.
- **Networking and the Vapor backend.** The notes app is offline-only this week. Wiring SwiftData to a server, an outbox/sync queue, and conflict resolution against the Vapor service is Phase III (networking) and Phase IV (sync).
- **App architecture.** We use plain SwiftUI + `@Query` + a thin context wrapper. Whether the data layer belongs behind a repository, a TCA dependency, or a MVVM view-model is Week 11. This week the point is the *engine*, not the architecture around it.

The point of Week 10 is narrow and deep: one schema, the macros that declare it, the container and context that persist it, the query that reads it efficiently, and the migration that keeps it alive across a version bump.

## Up next

Continue to **Week 11 — App architecture: MVVM, TCA, and the case against VIPER** once you have shipped this week's mini-project and proven a cold-launch survival. Week 11 takes the data layer you built this week and asks where it should *live* — behind a repository, inside a view-model, as a TCA dependency — and why the answer is almost never "scattered through the views." The notes app keeps growing: Week 11 puts an architecture around the SwiftData store, Week 12 reconciles Combine with `async/await`, and by the end of Phase II it is a polished, persistent, well-architected multi-platform app. Every one of those weeks assumes you can model a schema and query it efficiently. Earn that this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
