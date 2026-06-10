# Week 3 — Swift Concurrency I: async / await and Structured Concurrency

Welcome to Week 3 of **C20 · Crunch Swift**. Weeks 1 and 2 made you fluent in the language and the type system. This week we make you fluent in *time*. By Friday you should be able to fan out hundreds of network calls from a single function, cap how many run at once, cancel the whole tree cleanly on Ctrl-C, and explain — to a skeptical senior in code review — why you did not reach for `DispatchQueue`.

We assume you finished Weeks 1–2: you can scaffold a SwiftPM executable, write a Swift Testing target, and read `some`/`any`, generics, and `Result`. If that's you, this week is not "learn threading." It is "learn the *structured* concurrency model" — a model where every concurrent task has a parent, cancellation flows down the tree, and the compiler will not let a child outlive the scope that spawned it unless you explicitly ask for that.

The one idea to internalize up front:

> **Structured concurrency means the lifetime of a concurrent task is bounded by a lexical scope.** When the scope exits — normally, by `throw`, or by cancellation — every child task it spawned is guaranteed to be finished or cancelled. No leaked work. No orphaned callbacks. No "fire and forget and hope." This is the opposite of `DispatchQueue.async { }`, where the closure you submit has no relationship to the code that submitted it.

This is the Swift 6 model, current as of the Swift 6.1 toolchain shipping in 2026. Everything here runs on the open-source toolchain from `swift.org`, on Linux or macOS — no Xcode required. The mini-project is a real, runnable CLI.

## Learning objectives

By the end of this week, you will be able to:

- **Distinguish** sequencing from concurrency — and explain why `await` does *not* mean "run in parallel."
- **Distinguish** structured tasks (`async let`, `TaskGroup`) from unstructured ones (`Task { }`, `Task.detached`), and pick the right one deliberately.
- **Fan out** independent async work with `async let` for a fixed, small set, and with `withThrowingTaskGroup` for a dynamic, large set.
- **Propagate** cancellation through a task tree, and respond to it cooperatively with `Task.checkCancellation()`, `Task.isCancelled`, and `withTaskCancellationHandler`.
- **Implement back-pressure** by capping concurrency in a `TaskGroup` to a configurable maximum, and measure the throughput difference.
- **Set and read** task priority, and explain priority escalation.
- **Use** `@TaskLocal` to thread a value (a request ID, a deadline) implicitly down a task tree without polluting every signature.
- **Argue**, with concrete reasons, why `DispatchQueue` is the past for new code — and where it still legitimately appears.
- **Ship** a parallel link-checker CLI that respects `--timeout`, `--concurrency`, and a graceful Ctrl-C.

## Prerequisites

This week assumes you have completed **C20 Weeks 1–2**, or have equivalent Swift fluency. Specifically:

- You can scaffold a SwiftPM executable: `swift package init --type executable`, `swift build`, `swift run`.
- You can write and run a **Swift Testing** target (`import Testing`, `@Test`, `#expect`).
- You understand `throws` / `try` / `try?`, `Result<Success, Failure>`, and custom `Error` enums (Week 2).
- You understand `some` vs `any`, generics, and protocols with `associatedtype` (Week 2).
- You can read and write basic Git.

You do **not** need any prior concurrency experience in *any* language. If you have written GCD (`DispatchQueue`), threads, callbacks, or Combine, you will need to unlearn a couple of reflexes; we will flag them as we go. If you have written `async`/`await` in C#, JavaScript, Python, or Rust, the mechanics will feel familiar — but Swift's *structured* model (task trees, automatic cancellation propagation) goes further than most of them, so read carefully.

> **Toolchain note.** Everything this week runs on the open-source Swift 6.1 toolchain on **Linux or macOS**. No Mac required, no Xcode required. Verify with `swift --version` (you want 6.0 or newer). Actors, `Sendable`, and the full strict-concurrency story are **Week 4** — this week we stay on the structured-task half of the model and lean on value types to sidestep data races.

## Topics covered

- **Sequencing vs concurrency.** `await` suspends; it does not parallelize. Two `await`s in a row run one after the other. You opt into concurrency explicitly.
- **`async` functions and `await`.** What suspension actually means: the function yields the thread back to the cooperative pool, and resumes — possibly on a different thread — when its awaited work completes.
- **The cooperative thread pool.** Swift Concurrency runs on a pool sized to your core count, not "spawn a thread per task." Blocking a pool thread is the cardinal sin.
- **`async let`** — concurrent bindings for a small, fixed set of children, joined at the next `await`.
- **`TaskGroup` / `withThrowingTaskGroup`** — a dynamic set of children, results streamed as they complete, errors and cancellation handled at the group boundary.
- **Structured vs unstructured tasks.** `async let` and task groups are structured (scope-bound). `Task { }` and `Task.detached { }` are unstructured (you own the lifetime).
- **`Task { }` vs `Task.detached { }`** — the former inherits priority, task-locals, and (on the actor side, Week 4) isolation; the latter inherits nothing. Why `detached` is almost always the wrong default.
- **Cancellation.** Cooperative, not preemptive. `Task.isCancelled`, `try Task.checkCancellation()`, `withTaskCancellationHandler(operation:onCancel:)`, and how cancellation propagates down a task tree.
- **Priority.** `TaskPriority` (`.high`, `.medium`, `.low`, `.background`, `.utility`), priority inheritance, and priority escalation.
- **`@TaskLocal`** — task-local values: how to declare one, bind it with `$value.withValue(_:operation:)`, and read it deep in a tree.
- **Back-pressure.** Why an unbounded `TaskGroup` will exhaust file descriptors / sockets / memory, and the bounded-window pattern that fixes it.
- **Why `DispatchQueue` is the past.** A concrete migration table and the three places GCD still legitimately lives.
- **Bridging.** `withCheckedThrowingContinuation` to wrap a legacy callback API in `async` (a glance — full coverage with `AsyncStream` is Week 12).

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract.

| Day       | Focus                                                          | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Sequencing vs concurrency; async/await; the cooperative pool   |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `async let`, `TaskGroup`, fan-out; structured vs unstructured  |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     5.5h    |
| Wednesday | Cancellation, `withTaskCancellationHandler`, priority          |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Back-pressure, bounded concurrency, `@TaskLocal`; why not GCD  |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project: link-checker scaffold + fan-out                  |    0h    |    0h     |     1h     |    0.5h   |   1h     |     3h       |    0.5h    |     6h      |
| Saturday  | Mini-project deep work: cancellation, report, polish           |    0h    |    0h     |     0h     |    0h     |   0h     |     3.5h     |    0h      |     3.5h    |
| Sunday    | Quiz, review, README + submission                              |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                | **6h**   | **6.5h**  | **4h**     | **3.5h**  | **5h**   | **12.5h**    | **2h**     | **35.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Curated Swift.org, evolution proposals, WWDC, and book links — all current to 2026 |
| [lecture-notes/01-structured-concurrency-task-trees-and-cancellation.md](./lecture-notes/01-structured-concurrency-task-trees-and-cancellation.md) | The structured model: sequencing vs concurrency, `async let`, `TaskGroup`, task trees, cancellation propagation, back-pressure, `@TaskLocal` |
| [lecture-notes/02-task-vs-detached-and-why-dispatchqueue-is-the-past.md](./lecture-notes/02-task-vs-detached-and-why-dispatchqueue-is-the-past.md) | `Task { }` vs `Task.detached`, unstructured lifetimes, priority, the GCD migration table, and the three places GCD still lives |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-async-let-vs-taskgroup.md](./exercises/exercise-01-async-let-vs-taskgroup.md) | Fan out the same workload two ways and compare `async let` against a `TaskGroup` |
| [exercises/exercise-02-cooperative-cancellation.swift](./exercises/exercise-02-cooperative-cancellation.swift) | Implement cooperative cancellation with `withTaskCancellationHandler` and verify it propagates through a tree |
| [exercises/exercise-03-bounded-concurrency.swift](./exercises/exercise-03-bounded-concurrency.swift) | Cap a `TaskGroup` to a configurable max and measure the throughput effect of back-pressure |
| [challenges/README.md](./challenges/README.md) | Index of weekly challenges |
| [challenges/challenge-01-retry-with-bounded-concurrency.md](./challenges/challenge-01-retry-with-bounded-concurrency.md) | Add a `--retry` flag to the link-checker with bounded concurrency and clean drain on Ctrl-C |
| [mini-project/README.md](./mini-project/README.md) | Full spec for the parallel **link-checker** CLI |
| [quiz.md](./quiz.md) | 13 questions with an answer key |
| [homework.md](./homework.md) | Five practice problems with a rubric |

## The "drains clean" promise

C20's concurrency weeks have a recurring acceptance bar. Every concurrent program you write this week must satisfy:

```
^C
Cancelled. Drained 7 in-flight requests in 41 ms. No leaked tasks.
```

If your program hangs on Ctrl-C, leaks a task past its scope, or prints "Fatal error: task continuation misuse" — you are not done. A structured-concurrency program that does not cancel cleanly is a bug, the same way a nullable warning was a bug in Week 1. We treat a hung Ctrl-C as a failing test.

## Stretch goals

If you finish the regular work early and want to push further:

- Read **SE-0304 "Structured concurrency"** in full — the proposal that introduced task groups and `async let`: <https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md>.
- Read **SE-0317 "`async let` bindings"**: <https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md>.
- Watch WWDC21 **"Explore structured concurrency in Swift"** (session 10134) and **"Swift concurrency: Behind the scenes"** (session 10254). Behind-the-scenes is the one that explains the cooperative pool.
- Trace the cooperative pool with `SWIFT_DETERMINISTIC_HASHING=1` and `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`, then run your bounded-concurrency exercise and watch the thread count stay flat.
- Read the `swift-async-algorithms` package README and find one operator (`merge`, `debounce`, `chunked`) you wish you had this week: <https://github.com/apple/swift-async-algorithms>.

## Up next

Week 4 is **Swift Concurrency II — Actors, `Sendable`, and strict concurrency**. This week you stayed safe by passing value types between tasks. Next week the compiler stops trusting you: strict concurrency makes every cross-task data flow prove it is `Sendable`, and actors become how you protect mutable state. The link-checker you build this week is the warm-up; in Week 4 you will make its result aggregator an actor.

Continue to **Week 4 — Actors, Sendable, strict concurrency** once you have pushed the mini-project to your GitHub.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
