# Week 3 Homework

Five practice problems that revisit the week's topics. The full set should take about **5 hours**. Work in your Week 3 Git repository so each problem produces at least one commit you can point to later.

Each problem includes a short **problem statement**, **acceptance criteria** so you know when you're done, a **hint** if you get stuck, and an **estimated time**.

Every program this week must satisfy the same bar as the lectures: `swift build` is warning-free, you never block a cooperative pool thread, and anything cancellable **drains cleanly on Ctrl-C**.

---

## Problem 1 — Prove sequencing vs concurrency with a stopwatch

**Problem statement.** In a fresh executable package `homework/p1-timing/`, write a `slowEcho(_ s: String, ms: Int) async -> String` that `Task.sleep`s for `ms` milliseconds and returns `s`. Then write three functions that each call `slowEcho` three times with 200 ms each, and print the wall-clock time of each using `ContinuousClock`:

1. `runSequential()` — three `await`s in a row.
2. `runAsyncLet()` — three `async let` bindings joined at the end.
3. `runGroup()` — a `TaskGroup` with three children.

Print the elapsed time for all three. Sequential should be ~600 ms; the other two ~200 ms.

**Acceptance criteria.**

- A buildable, runnable package under `homework/p1-timing/`.
- `swift build`: no warnings, no errors.
- Output shows sequential ≈ 600 ms and both concurrent versions ≈ 200 ms.
- Uses `Task.sleep`, never `Thread.sleep`.
- Committed.

**Hint.** `let start = ContinuousClock().now; … ; print(start.duration(to: ContinuousClock().now))`. Remember `async let` joins at the `await`, so the work overlaps between declaration and join.

**Estimated time.** 45 minutes.

---

## Problem 2 — Cooperative cancellation of a synchronous loop

**Problem statement.** Write `countPrimes(below limit: Int) async throws -> Int` that counts primes below `limit` in a **synchronous** loop (no `await` inside). Make it cancellation-aware: call `try Task.checkCancellation()` every 4096 iterations. In `main`, start it as a `Task`, and a second `Task` that cancels the first after 100 ms. Print either the count (if it finished) or `"cancelled after N primes so far"`.

**Acceptance criteria.**

- A buildable, runnable package under `homework/p2-cancel-loop/`.
- With a large `limit` (e.g. 5_000_000), the run is cancelled mid-flight and prints the cancellation branch, then exits promptly.
- With a small `limit` (e.g. 1000), it finishes and prints the count.
- The cancellation check is **periodic** (every ~4096 iterations), not every iteration.
- `swift build`: no warnings, no errors. Committed.

**Hint.** Catch `CancellationError` in `main` around `try await handle.value`. To track "primes so far," accumulate into a local and, on the cancellation check, decide whether to rethrow or return a partial count — your choice, but document it.

**Estimated time.** 1 hour.

---

## Problem 3 — Bounded fan-out with a peak-in-flight assertion

**Problem statement.** Reuse the `InFlightMeter` idea from Exercise 3. Write `runBounded(count:maxConcurrent:)` using the sliding-window pattern, where each "job" increments a meter on entry and decrements on exit. After the run, assert (with a `precondition` or a Swift Testing `#expect`) that the peak in-flight never exceeded `maxConcurrent`. Run it for `count = 500`, `maxConcurrent = 10`.

**Acceptance criteria.**

- A buildable package under `homework/p3-bounded/`, with at least one Swift Testing test.
- The test confirms `peak <= maxConcurrent` for several `(count, max)` pairs.
- The checksum (sum of all job ids returned) matches `(0..<count).reduce(0,+)` — proving no work was lost.
- `swift build` and `swift test`: clean. Committed.

**Hint.** Prime `min(max, count)` tasks, then `while let r = await group.next() { … add one more if any remain … }`. The meter can be a small `final class … : @unchecked Sendable` with an `NSLock`, exactly as in Exercise 3 (actors are Week 4).

**Estimated time.** 1 hour.

---

## Problem 4 — `Task { }` vs `Task.detached`, demonstrated

**Problem statement.** Declare a `@TaskLocal static var requestID: String` on an enum. In a function, bind it to `"req-7"` with `$requestID.withValue("req-7") { … }`. Inside the binding, start **two** unstructured tasks — one `Task { }` and one `Task.detached { }` — that each print `requestID`. Show that the `Task { }` prints `"req-7"` (inherited) and the `Task.detached { }` prints the default (`"none"` or whatever you initialised it to). Await both handles.

**Acceptance criteria.**

- A buildable, runnable package under `homework/p4-detached/`.
- Output clearly shows `Task { }` inheriting the task-local and `Task.detached` not inheriting it.
- Both task handles are awaited (no fire-and-forget).
- A one-sentence comment in the file stating *why* `Task.detached` did not inherit the value.
- `swift build`: clean. Committed.

**Hint.** `enum Ctx { @TaskLocal static var requestID = "none" }`. Bind with `Ctx.$requestID.withValue("req-7") { … }`. Hold each task in a `let` and `await handle.value` so the prints happen before `main` returns.

**Estimated time.** 45 minutes.

---

## Problem 5 — Reflection: GCD to structured concurrency

**Problem statement.** Write a 300–400 word reflection at `notes/week-03-reflection.md` answering:

1. In your own words, what does "structured concurrency" mean, and what concrete guarantee does the task tree give you that `DispatchQueue.async` never did?
2. Pick one row from the GCD → structured-concurrency migration table (Lecture 2, §6) and explain *why* the structured version is better, not just *that* it is.
3. The lectures claim "never block a cooperative pool thread." Describe a specific way a beginner might violate this without realising it, and how you'd catch it in code review.
4. After building (or scaffolding) the link-checker, what was the hardest part of making Ctrl-C drain cleanly? What would happen if one leaf task ignored cancellation?

**Acceptance criteria.**

- File exists, 300–400 words, each numbered question in its own paragraph.
- Committed.

**Hint.** This is for *you*, not a grade. Be specific and honest. Future-you, sitting in a senior iOS interview being asked "how does Swift cancellation work," will be glad you wrote this down.

**Estimated time.** 30 minutes.

---

## Time budget recap

| Problem | Estimated time |
|--------:|--------------:|
| 1 | 45 min |
| 2 | 1 h 0 min |
| 3 | 1 h 0 min |
| 4 | 45 min |
| 5 | 30 min |
| **Total** | **~4 h 0 min** |

---

## Rubric

| Criterion | Weight | What "great" looks like |
|----------|-------:|-------------------------|
| Correctness | 30% | Every program builds warning-free and produces the expected output / timings |
| Concurrency discipline | 25% | No blocked pool threads; cancellation is cooperative and periodic; no fire-and-forget tasks left unawaited |
| Back-pressure (P3) | 15% | Peak-in-flight assertion holds; checksum proves no work lost |
| Inheritance understanding (P4) | 15% | Correctly demonstrates and explains `Task { }` vs `Task.detached` task-local inheritance |
| Reflection quality (P5) | 15% | Specific, honest, demonstrates the mental model rather than restating the lecture |

When you've finished all five, push your repo and open the [mini-project](./07-mini-project/00-overview.md).
