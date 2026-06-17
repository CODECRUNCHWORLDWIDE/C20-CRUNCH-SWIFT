# Week 11 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 11 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Problems 2–5 use the `swift-composable-architecture` package. Every problem must build with **0 warnings**.

---

## Problem 1 — Find and fix three hidden dependencies

**Problem statement.** Take the starter view model below (recreate it in your repo) and refactor it so every hidden dependency becomes an injected one, then write tests that prove the previously-untestable behaviour.

```swift
@Observable @MainActor
final class GreetingModel {
    var greeting = ""
    func refresh() {
        let hour = Calendar.current.component(.hour, from: Date())   // hidden: Date + Calendar
        let id = UUID().uuidString.prefix(4)                          // hidden: UUID
        greeting = hour < 12 ? "Good morning (\(id))" : "Good day (\(id))"
    }
}
```

Identify the three hidden dependencies (the current `Date`, the `Calendar`, and `UUID`), inject them (a `DateProvider`-style struct-of-closures is fine, or accept a `Date` and a `() -> UUID`), and write a Swift Testing suite that asserts the greeting is deterministic given a fixed time and a fixed id.

**Acceptance criteria.**

- The three hidden dependencies are injected through `init`.
- At least two tests assert a deterministic greeting (e.g. a fixed 09:00 date yields "Good morning (0000)").
- 0 warnings. Committed.

**Hint.** Inject `now: Date` (or a `() -> Date`) and a `makeID: () -> String`. In tests pass `Date` components that fall before/after noon and a fixed id closure. The `Calendar` can be injected too, but for this problem accepting a precomputed `hour` or a fixed `Calendar` is enough.

**Estimated time.** 35 minutes.

---

## Problem 2 — A reducer with a guard and a TestStore

**Problem statement.** Write a `@Reducer LoginFeature` with `State { var email = ""; var password = ""; var isSubmitting = false; var errorMessage: String? }` and actions `binding`, `submitTapped`, `loginResponse(Result<Bool, LoginError>)`. The reducer must *guard* against submitting when email or password is empty (no effect fires). On a valid submit it sets `isSubmitting`, calls an injected `authClient.login`, and handles success/failure. Prove all three paths (empty → no-op, success, failure) with an exhaustive `TestStore`.

**Acceptance criteria.**

- The empty-field guard is proven by a test that does **not** override `authClient` (so an unexpected call to the unimplemented `testValue` would fail).
- A success test and a failure test, each exhaustively asserting state.
- 0 warnings. Committed.

**Hint.** The empty-field test is the important one: `await store.send(.submitTapped)` with empty fields should produce *no* state change and *no* effect. Leave `authClient` at its `unimplemented` `testValue` so a wrongly-fired login fails loudly.

**Estimated time.** 55 minutes.

---

## Problem 3 — Plain SwiftUI is the right call

**Problem statement.** Build a "preferences" screen with three `@AppStorage`-backed settings (a `Bool` for notifications, a `String` for a display name, an `enum`-backed appearance picker) using **plain SwiftUI + `@AppStorage`/`@State`** — no view model, no reducer. Then write a 3–4 sentence note in `notes/why-no-architecture.md` running the three questions to justify why no architecture is correct here.

**Acceptance criteria.**

- A working preferences screen using only `@AppStorage`/`@State`, no extra layer.
- `notes/why-no-architecture.md` runs the three questions (testability need, team size/longevity, blast radius) and concludes "no architecture."
- 0 warnings. Committed.

**Hint.** This problem grades *restraint*. If you find yourself writing a `PreferencesViewModel`, stop — that's the smell the problem is testing for. `@AppStorage("appearance") var appearance: Appearance = .system` with a `RawRepresentable` enum is the whole thing.

**Estimated time.** 35 minutes.

---

## Problem 4 — Compose two reducers with Scope

**Problem statement.** Build a parent `@Reducer AppFeature` that composes two child reducers — a `CounterFeature` (from exercise 2) and a `TimerFeature` you write (a start/stop reducer driven by `@Dependency(\.continuousClock)`) — using `Scope`. The parent's `State` holds both child states; its `Action` wraps both child actions. Write a `TestStore` test that drives the counter through the parent and confirms the timer state is untouched.

**Acceptance criteria.**

- `AppFeature.State` embeds `CounterFeature.State` and `TimerFeature.State`; `Action` wraps both via case paths.
- Two `Scope` reducers in the parent `body` route actions to the children.
- A `TestStore` test sends a counter action through the parent and asserts only the counter substate changed.
- 0 warnings. Committed.

**Hint.** `Scope(state: \.counter, action: \.counter) { CounterFeature() }`. The `@Reducer` macro generates the case-path key paths for `\.counter` / `\.timer`. Drive the child via `store.send(\.counter.incrementTapped)`.

**Estimated time.** 55 minutes.

---

## Problem 5 — The case against VIPER, in writing

**Problem statement.** Write `notes/viper-critique.md`: a one-page critique of VIPER for new SwiftUI work. Go component by component (View, Interactor, Presenter, Entity, Router), state what each solved in 2014 UIKit, and name the modern SwiftUI mechanism that makes it redundant (or note where it still has a point). Be *fair* — concede what VIPER got right — then conclude.

**Acceptance criteria.**

- All five components are addressed, each with "what it solved" and "what replaces it in SwiftUI."
- The critique concedes VIPER's 2014 validity before arguing against it for 2026 greenfield SwiftUI.
- A one-paragraph conclusion that distinguishes "inherited UIKit VIPER" (respect it) from "new SwiftUI VIPER" (don't).
- Committed.

**Hint.** Map: View → SwiftUI declarative `struct`; Presenter → `@Observable`/`@ObservableState`; Router → value-typed `NavigationStack` (Week 9); Interactor → injected view model or TCA reducer; Entity → your `@Model`/`struct`. The protocol-per-edge ceremony is the cost with no remaining payoff. (Lecture 2, §4.)

**Estimated time.** 45 minutes.

---

## Problem 6 — Write a real ADR for a real decision

**Problem statement.** Pick a real architectural decision you made (or would make) in your Hello, Notes app — e.g. "should the SwiftData store sit behind a repository abstraction or be used directly via `@Query`?" — and write a complete ADR (`adr/ADR-001-<slug>.md`) in the five-section format: status/date, context, decision, options considered, consequences.

**Acceptance criteria.**

- All five sections present and substantive (not one-liners).
- At least two rejected options, each with a reason.
- The consequences section names a concrete commitment the decision creates and a trigger to revisit it.
- Committed.

**Hint.** A good ADR is *specific*. "We use a repository because it's cleaner" is weak; "We put the SwiftData store behind a `NotesRepository` protocol so the view models inject a stub in tests, accepting one extra layer of indirection, and we'll drop the abstraction if it's still a single implementation in three months" is an ADR. State the *trade*, not a virtue. (Lecture 2, §6.)

**Estimated time.** 40 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/SwiftUI/TCA, and the written work (where asked) reasons with the three questions / the trade, in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a `@MainActor` missing, a slightly verbose dependency registration, an ADR section thin). |
| 3 | Works, but misses one criterion (e.g. a hidden dependency left un-injected, a `TestStore` assertion not exhaustive, a critique that strawmans VIPER). |
| 2 | Compiles and partially works; a core idea is wrong (a view model that still reaches for the live world; "no architecture" justified for a feature that clearly needs structure). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for adding a view model/reducer to a feature that demonstrably needs none (over-architecting is as wrong as under-architecting); **−1** for a written justification that asserts a "best practice" instead of reasoning from the three questions or the trade.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the dependency-injection seam that makes logic testable (problems 1, 2) and matching structure to stakes via the three questions (problems 3, 6) — so re-run exercises 01 and 02 before resubmitting.
