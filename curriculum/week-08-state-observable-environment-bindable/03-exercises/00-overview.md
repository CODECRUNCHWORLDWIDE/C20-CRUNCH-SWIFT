# Week 8 — Exercises

Three focused drills on state ownership. Each one isolates one boundary from Lecture 1 and one diagnostic skill from Lecture 2. Do them in order; later ones assume earlier ones. Budget 30–60 minutes each.

## Index

1. **[Exercise 1 — Environment injection, no prop-drilling](./exercise-01-environment-injection-no-prop-drilling.md)** — build an `@Observable` model, inject it once with `.environment(_:)` at the top of the tree, and read it from a view five levels deep with `@Environment(Type.self)` — without threading it through a single intermediate view. (~40 min)
2. **[Exercise 2 — Bindable sheet edit, propagates exactly once](./exercise-02-bindable-sheet-edit.swift)** — use `@Bindable` to two-way bind a sheet's fields to an `@Observable` model, and confirm with a render counter that an edit propagates to the list exactly once. (~45 min)
3. **[Exercise 3 — Reproduce and fix a render storm](./exercise-03-reproduce-and-fix-a-render-storm.swift)** — reproduce a storm caused by misplaced `@State` and over-broad inputs, see it with `Self._printChanges()` and a counter, fix it, and verify the count drops to the minimum. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorise.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point.
- Run it in the **iOS Simulator** (or the Xcode Canvas preview where the exercise calls for it). Watch the console — the counter output *is* the deliverable for exercises 2 and 3.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** under Xcode 16+ targeting iOS 17+. A warning is a bug this week — especially a strict-concurrency warning, which usually means you put state on the wrong actor.

## How to run the `.swift` exercises

Exercises 2 and 3 are complete SwiftUI files. The fastest way to run one:

1. In Xcode, create a fresh iOS App project (`File ▸ New ▸ Project ▸ App`, SwiftUI, iOS 17+ deployment target).
2. Replace the generated `ContentView.swift` with the exercise file's contents (or paste the file into a new Swift file and set the `@main` `App` to show the exercise's root view).
3. Run on an iPhone simulator and open the console (`View ▸ Debug Area ▸ Activate Console`).

Each file's header comment tells you which view is the entry point and what the console should print.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-08` to compare.
