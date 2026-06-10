# Week 10 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A ModelContainer that survives relaunch](exercise-01-model-container-survives-relaunch.md)** — define `@Model` types, wire a `ModelContainer`, insert and save records, and *prove* they survive a force-quit cold launch. The whole point of the week, in one exercise. (~40 min)
2. **[Exercise 2 — `#Predicate` vs naive in-memory filter](exercise-02-query-predicate-vs-naive.swift)** — query with `@Query` + `#Predicate` + sort descriptors, then measure a naive fetch-everything-then-filter against a predicate that runs in SQLite. You produce two numbers and explain the gap. (~50 min)
3. **[Exercise 3 — A lightweight migration with versioning](exercise-03-lightweight-migration.swift)** — seed a V1 store, add a field and rename another, register a `VersionedSchema` + `SchemaMigrationPlan`, and open the old store with the new schema without losing data. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run it on the **iOS Simulator** (or a macOS target — SwiftData runs on both). See the output. Read the error if it crashed.
- The `.swift` exercises are written to drop into a SwiftUI app target *or* run as a Swift Testing / XCTest suite using an `isStoredInMemoryOnly` container. Each file's header says which.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — `ModelContext` is not `Sendable` and the compiler is right.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-10` to compare.
