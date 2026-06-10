# Week 11 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Extract a testable view model](exercise-01-extract-a-view-model.md)** — take a view with logic crammed inside it, extract an `@Observable` `@MainActor` view model with an *injected* dependency, and unit-test it with Swift Testing and zero UI. The MVVM discipline in one exercise. (~45 min)
2. **[Exercise 2 — A reducer and a TestStore](exercise-02-reducer-and-teststore.swift)** — write a small TCA `@Reducer` with value-type `State`, an `Action` enum, a `Reduce` body, and an `Effect`, then prove the whole flow with an *exhaustive* `TestStore`. (~50 min)
3. **[Exercise 3 — Dependency injection in TCA](exercise-03-dependency-injection.swift)** — register a `@Dependency` with `liveValue`/`testValue`/`previewValue`, use it in a reducer's effect, and override it in a `TestStore` so an otherwise-non-deterministic effect becomes provable. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Add the **`swift-composable-architecture`** package to your project before exercises 2 and 3: **File ▸ Add Package Dependencies ▸ `https://github.com/pointfreeco/swift-composable-architecture`**, pin to the 1.x line. Exercise 1 needs no package — it is plain SwiftUI + `@Observable`.
- The `.swift` exercises are written to drop into a Swift Testing target. Each file's header says exactly how. Run with **Cmd-U**.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — view models are `@MainActor`, reducer state is a value type, and the compiler is right.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-11` to compare.
