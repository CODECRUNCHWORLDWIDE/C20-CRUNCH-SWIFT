# Week 19 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 19 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 18 / macOS 15 / watchOS 11 / visionOS 2, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. The watchOS/visionOS problems run in their simulators (no hardware required).

A standing rule for the week: **every piece of code lives on one side of the share/adapt line, and you can say which.** Several problems ask for it explicitly; do it for the rest anyway.

---

## Problem 1 — The four-ways-onto-the-Mac decision

**Problem statement.** Write `notes/mac-strategy.md` describing the four ways to run an app on the Mac (Catalyst "Scale to fit iPad," Catalyst "Optimize for Mac," native SwiftUI multiplatform, dedicated macOS target). For each, give one sentence on what it is and one on when it's the right choice. Then state which you'd pick for Notes Pro and why, and how you'd detect Catalyst at compile time.

**Acceptance criteria.**

- All four approaches described with what/when.
- A justified choice (native SwiftUI multiplatform) for a SwiftUI app.
- The `#if targetEnvironment(macCatalyst)` check noted.
- Committed.

**Hint.** For a SwiftUI app, native is the default; Catalyst is the bridge for a big UIKit app. The "Designed for iPad" Mac destination is the Catalyst path — avoid it for new SwiftUI work.

**Estimated time.** 30 minutes.

---

## Problem 2 — Refactor a forked view to adaptive

**Problem statement.** Given a view whose `body` is fully forked with `#if os(iOS)` / `#if os(macOS)` (write the bad version first — a `NavigationStack` on iOS and a `NavigationSplitView` on macOS with duplicated content), refactor it to a *single* `NavigationSplitView` with the platform-specific bits (e.g. window min size) isolated in one named `ViewModifier`. Prove it builds and renders on both.

**Acceptance criteria.**

- The "before" forked version and the "after" adaptive version, both committed.
- The "after" has at most one small, named `#if os` (window sizing), zero in the `body`.
- It renders as a stack on iPhone and a split view on Mac (verify by running both).
- A one-line note on why the refactor is better (no drift, one code path).
- Committed.

**Hint.** `NavigationSplitView` collapses to a stack on iPhone for free — that's why the fork was unnecessary. Isolate the genuine macOS-only `.frame(minWidth:)` in a `ViewModifier`.

**Estimated time.** 45 minutes.

---

## Problem 3 — A shared domain package with a single test pass

**Problem statement.** Build a `NotesCore` SwiftPM package (platforms: iOS/macOS/watchOS/visionOS) with a `Note` model and three pure domain functions: `recent(_:limit:)`, `summary(_:)`, and `matching(_:query:)`. Write a Swift Testing suite covering all three. Confirm the package has zero UIKit/AppKit imports, then deliberately add a `import UIKit` and observe the build break, then remove it.

**Acceptance criteria.**

- A package declared for all four platforms with three `public` domain functions.
- A passing test suite covering recent/summary/matching.
- A note in the commit that adding `import UIKit` broke the build (proving the boundary).
- 0 warnings. Committed.

**Hint.** This is exercise 3, owned. `public` everything that crosses the boundary. The UIKit import fails because the package targets watchOS/macOS, which don't have UIKit — that failure is the lesson.

**Estimated time.** 45 minutes.

---

## Problem 4 — A watchOS glance view

**Problem statement.** Build a watchOS app target that imports your `NotesCore` and shows the three most recent notes in a `NavigationStack`, with a read-only detail. Run it in the watchOS simulator. Write `notes/watch.md` stating which parts are shared (the model, the query, the `recent` logic) and which adapt (the stack, the prefix(3), the read-only detail), with the share/adapt line for each.

**Acceptance criteria.**

- A watchOS target showing three recent notes via the shared `recent`/`@Query`.
- A read-only detail (no editor on the wrist).
- `notes/watch.md` classifying each part as shared or adapted.
- Runs in the watchOS simulator. 0 warnings. Committed.

**Hint.** watchOS uses the same SwiftUI `App` protocol. `NavigationStack`, not split view. `notes.prefix(3)` for the glance. The detail is a `ScrollView { Text }`, not a `TextField`.

**Estimated time.** 50 minutes.

---

## Problem 5 — A watch complication

**Problem statement.** Add a WidgetKit extension to your watchOS app with a complication showing the note count (from `NotesCore`), supporting at least `.accessoryCircular` and `.accessoryRectangular`. Add it to a watch face in the simulator. Wire `WidgetCenter.reloadTimelines` so adding a note refreshes the face.

**Acceptance criteria.**

- A `Widget` with a `TimelineProvider` reading the count from the shared core.
- At least two accessory families supported, rendering correctly.
- A `reloadTimelines` call on note change.
- A screenshot of the complication on a watch face. 0 warnings. Committed.

**Hint.** This is challenge 1, part 1. `ViewThatFits` lets one view render in multiple families. `StaticConfiguration`, `supportedFamilies([.accessoryCircular, .accessoryRectangular])`. The count comes from `NotesDomain.summary` or a count function in the core.

**Estimated time.** 50 minutes.

---

## Problem 6 — A visionOS window + the parity matrix

**Problem statement.** Add a visionOS surface (a destination of the iOS target or its own target) that renders your `NotesRootView` as a `.windowStyle(.plain)` window. Run it in the visionOS simulator. Then write `notes/parity.md` with a feature × platform matrix (iPhone/iPad/Mac/Watch/Vision) and a "Behavior shared?" column citing the `NotesCore` path for each feature, with at least one honest "absent by design" cell.

**Acceptance criteria.**

- A visionOS window rendering the shared root layout (a window, not an immersion).
- A comment noting where immersion *would* fit and why you didn't build it.
- `notes/parity.md` with a matrix of at least four platforms, a "Behavior shared?" column, and an "absent by design" cell with justification.
- Runs in the visionOS simulator. 0 warnings. Committed.

**Hint.** `WindowGroup { NotesRootView() }.windowStyle(.plain)` — the platform renders your existing layout spatially for free. The matrix is challenge 1, part 2; cite the shared `NotesCore` function for each behavior to prove the sharing.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings on every relevant platform, code is idiomatic multi-platform SwiftUI, and the share/adapt classification (where asked) is correct. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a `#if os` that could have been an adaptive container, a missing `public`). |
| 3 | Works, but misses one criterion (e.g. the core has a platform branch, a forked view not refactored, the complication doesn't reload). |
| 2 | Compiles and partially works; a core idea is wrong (forks the whole view; puts UI in the shared package; treats the watch as a tiny iPhone). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any `#if os` or UI-framework import inside the shared core; **−2** for forking a whole view where an adaptive container would do; **−1** for treating a platform as a literal port (a tiny-iPhone watch, an immersive notes app); **−1** for any suppressed Swift 6 concurrency warning.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — navigation-adapts-for-free / `#if os`-is-a-scalpel (problems 2, 4) and the package-enforces-the-line / test-once (problems 3, 6) — so re-run exercises 01 and 03 before resubmitting.
