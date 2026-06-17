# Week 19 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — One adaptive navigation, three platforms](./exercise-01-adaptive-navigation.md)** — build a single `NavigationSplitView` that's sidebar-detail on Mac/iPad and a stack on iPhone, with value-typed selection, and prove it in three simulators with **zero** platform branches. The share-via-adaptivity idea, in one exercise. (~45 min)
2. **[Exercise 2 — Platform-conditional views, the minimum-fork way](./exercise-02-platform-conditional-views.swift)** — practice `#if os` discipline: take a view that needs a few genuinely platform-specific touches and adapt the *shell* with the smallest possible forks (isolated modifiers, semantic placements, free keyboard shortcuts) while keeping the core branch-free. (~50 min)
3. **[Exercise 3 — Extract a shared core package](./exercise-03-shared-core-package.swift)** — move the model and a platform-agnostic domain function into a SwiftPM package that compiles for all five platforms, prove the compiler enforces the line (no UIKit/AppKit), and test the domain *once*. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills — and for multi-platform, the muscle memory of "reach for the adaptive container before the `#if os`" is exactly what keeps the codebase from forking.
- Run it. Exercise 1 runs in the **iPhone, iPad, and Mac** simulators/destinations (the Mac runs natively). Exercise 2 builds for multiple destinations. Exercise 3 is a **SwiftPM package** that builds for every platform and runs its tests with `swift test` or Cmd-U.
- The `.swift` exercises are written to drop into a SwiftUI app target or a package, with Swift Testing suites where they apply.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug — and for multi-platform, a `#if os` in the *shared core* is a bug too, even if it compiles.

## A multi-platform working rule

For every piece of code you write this week, ask the lecture-1 question out loud: **is the answer the same on every platform (share) or does it depend on what the user is holding (adapt)?** Exercise 1 proves navigation adapts for free. Exercise 2 proves the small forks stay small. Exercise 3 proves the shared core physically can't blur the line. If you find yourself `#if os`-ing inside business logic, stop — the platform leaked into the core, and the fix is to push the branch up into the shell.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-19` to compare.
