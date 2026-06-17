# Week 12 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 12 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Combine and the concurrency runtime ship with the SDK; problem 4 optionally uses `swift-async-algorithms`. Every problem must build with **0 warnings**.

---

## Problem 1 — Read a Combine pipeline and explain it

**Problem statement.** Given the pipeline below (recreate it in your repo and make it compile), write `notes/pipeline-explained.md` narrating each operator in plain English, then state exactly how many times `runSearch` is called if the user types "s","sw","swi" (50 ms apart), pauses 1 s, then types "swi" again.

```swift
queryInput
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { $0.count >= 2 }
    .sink { runSearch($0) }
    .store(in: &cancellables)
```

**Acceptance criteria.**

- The pipeline compiles and runs (a harness or test driving `queryInput`).
- `notes/pipeline-explained.md` narrates each operator and answers the call-count question with reasoning.
- The answer is correct (the burst collapses to one "swi"; the pause + retype is a second "swi", but `removeDuplicates` drops it because it equals the previous emitted value — so `runSearch` is called **once**). State your reasoning even if you reach a different number — the reasoning is graded.
- Committed.

**Hint.** `removeDuplicates()` drops a value equal to the *previously emitted* one. The first burst emits "swi"; the second "swi" is identical, so it's dropped. If you'd retyped "swift" instead, it would fire again.

**Estimated time.** 35 minutes.

---

## Problem 2 — Build an `AsyncStream` from a Timer

**Problem statement.** Write a function `func ticks(every interval: Duration) -> AsyncStream<Date>` that yields the current `Date` every `interval` using an `AsyncStream` and a `Task` inside the build closure. Implement `onTermination` to cancel the producing task. Consume it in a test for ~3 ticks and assert you received roughly the right count, then prove the producer stops when you break out of the loop.

**Acceptance criteria.**

- `ticks(every:)` returns an `AsyncStream<Date>` driven by an internal `Task` that `yield`s on each interval.
- `onTermination` cancels the producing task (no leaked timer after the consumer stops).
- A test consumes ~3 ticks, breaks, and asserts the count and that no further ticks arrive.
- 0 warnings. Committed.

**Hint.** Inside the `AsyncStream { cont in ... }` closure, start `let task = Task { while !Task.isCancelled { try? await Task.sleep(for: interval); cont.yield(.now) } }` and set `cont.onTermination = { _ in task.cancel() }`. Breaking the consumer's `for await` triggers termination.

**Estimated time.** 45 minutes.

---

## Problem 3 — Bridge `NotificationCenter` to async

**Problem statement.** Pick a notification (e.g. a custom `Notification.Name`), post it a few times, and consume it via `for await NotificationCenter.default.publisher(for: name).values` inside a `Task`. Prove the loop receives the posts and stops when the task is cancelled. Write a one-sentence note in `notes/bridge.md` on why `.values` is preferable to a `.sink` + `AnyCancellable` here.

**Acceptance criteria.**

- A `Task` consuming the notification publisher via `.values` in a `for await` loop.
- A test (or harness) posting the notification and asserting receipt, plus cancellation ending the loop.
- `notes/bridge.md` states why `.values` (structural cancellation, no `AnyCancellable`) beats `.sink` here.
- 0 warnings. Committed.

**Hint.** `NotificationCenter.default.post(name: name, object: nil)`. Sleep ~20 ms after starting the task before posting, so the loop has subscribed (a `publisher` has no replay). Cancel the task to end the loop.

**Estimated time.** 40 minutes.

---

## Problem 4 — The same debounce, both ways

**Problem statement.** Implement a debounced search recorder twice — once with Combine `.debounce`, once with a hand-rolled `AsyncStream` (per-keystroke task cancellation) — behind one protocol. Write a test that drives both with the same burst ("a","ab","abc" 20 ms apart) and asserts both record exactly one search ("abc"). Note in `notes/debounce-compare.md` the line counts and one qualitative difference.

**Acceptance criteria.**

- Two implementations conforming to one protocol, both passing the same "one search per burst" test.
- `notes/debounce-compare.md` records the two line counts and at least one qualitative difference (e.g. structural cancellation vs `AnyCancellable`).
- 0 warnings. Committed.

**Hint.** This is the challenge in miniature — reuse exercise 1's Combine pipeline and exercise 2's `AsyncStream` debouncer behind a shared `protocol DebouncedSearch { func type(_:) async; func searchesRun() async -> [String] }`. Optionally add a third using `swift-async-algorithms`' `.debounce(for:)` and note the simplification.

**Estimated time.** 55 minutes.

---

## Problem 5 — Place reactivity correctly in SwiftUI

**Problem statement.** Build a small SwiftUI screen with three reactive sources placed correctly: (a) a `@Observable` model for a synchronous toggle, (b) a `.task(id:)` that re-runs an async load when a picker value changes, and (c) an `.onReceive(Timer.publish(...))` updating a clock label. Write `notes/placement.md` justifying each choice with the lecture 2, §5 rule.

**Acceptance criteria.**

- All three sources working in one screen, each using the *correct* modifier (`@Observable` / `.task(id:)` / `.onReceive`).
- `.task(id:)` demonstrably re-runs when the picker changes (verify by eye or a render print).
- `notes/placement.md` justifies each placement against the rule (synchronous state → `@Observable`; async load tied to a value → `.task(id:)`; framework Combine publisher → `.onReceive`).
- 0 warnings. Committed.

**Hint.** The mistake to avoid is using `.onReceive` for everything or doing async work in `onAppear { Task { } }` (which isn't cancelled on disappear). `.task(id: picker)` is the idiomatic "re-run when this changes" and is cancelled structurally.

**Estimated time.** 45 minutes.

---

## Problem 6 — Fill in the decision matrix for five scenarios

**Problem statement.** Write `notes/matrix.md` answering, for each of these five scenarios, which tool you'd reach for (Combine / `AsyncStream` / `async`-`await` / `@Observable` / `.task`) and a one-sentence reason: (1) a single `fetchProfile()` call; (2) a debounced search in a brand-new app; (3) consuming `Timer.publish` in a view; (4) a synchronous theme toggle; (5) extending a 40-file existing Combine codebase with one more reactive feature.

**Acceptance criteria.**

- All five scenarios answered with a tool and a one-sentence reason drawn from the matrix (lecture 2, §6).
- The answers reflect the async-first default *and* its exceptions (scenarios 3 and 5 are the exceptions).
- Committed.

**Hint.** Expected shape: (1) `async`/`await` — single result; (2) `AsyncStream` (+ async-algorithms debounce) — new code, async-first; (3) `.onReceive` or `.values` bridge — framework Combine; (4) `@Observable` — synchronous state; (5) Combine — match the existing codebase for consistency. State *why*, not just the tool.

**Estimated time.** 35 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/Combine/concurrency, and the written work (where asked) reasons from the matrix / the lifecycle rules in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a missing `onTermination`, an `AnyCancellable` stored where a `.task` would be cleaner, a matrix answer thin on reasoning). |
| 3 | Works, but misses one criterion (e.g. a debounce that fires twice for a burst, a bridge that leaks, a reactivity placement that uses `.onReceive` where `.task` was correct). |
| 2 | Compiles and partially works; a core idea is wrong (no debounce, a discarded cancellable, async work in `onAppear` that isn't cancelled). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for a debounce that fires per-keystroke instead of once per burst; **−1** for a discarded `AnyCancellable` or a missing `onTermination` cleanup.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the `AsyncStream` debounce with structural cancellation (problems 2, 4) and placing reactivity correctly / choosing the tool (problems 5, 6) — so re-run exercises 02 and 03 before resubmitting.
