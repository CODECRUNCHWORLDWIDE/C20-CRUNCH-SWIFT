# Week 22 — Exercises

Short, focused drills. Each one should take 40–60 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Swift Testing, parameterized and tagged](./exercise-01-swift-testing-parameterized.swift)** — write Swift Testing suites with `#expect`/`#require`, a parameterized `arguments:` test that covers the input space, and tagged suites you can slice on CI, against the notes logic. The foundation layer, done right. (~50 min)
2. **[Exercise 2 — XCUITest with a page object](./exercise-02-xcuitest-page-object.swift)** — drive the add-note flow through the real UI via accessibility identifiers and a page-object wrapper, launched into deterministic state, with robust waiting. The expensive layer, done robustly. (~55 min)
3. **[Exercise 3 — A GitHub Actions PR workflow](./exercise-03-github-actions-pr-workflow.md)** — author a `pull_request` workflow that runs your tests on a `macos` runner through `xcbeautify`, uploads the result bundle, and gates the merge with a branch-protection rule. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Exercises 1 and 2 run **locally in Xcode / the Simulator** (Cmd-U). Exercise 3 runs on **GitHub Actions** — you need a GitHub repo for the app; the free macOS-runner minutes cover it (public repos especially).
- The `.swift` exercises drop into your Hello, Notes app's **test targets** (a Swift Testing / XCTest unit-test target and a UI-test target). Each file's header says which.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning in a test is still a bug — tests run in parallel and the compiler is protecting you from a shared-state race.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-22` to compare.
