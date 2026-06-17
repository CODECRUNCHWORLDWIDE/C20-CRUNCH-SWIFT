# Week 3 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 10/13 before moving to Week 4. Answer key at the bottom — don't peek.

---

**Q1.** What does this function's total wall-clock time most closely match, if each fetch takes 100 ms?

```swift
func load() async throws -> (A, B, C) {
    let a = try await fetchA()
    let b = try await fetchB()
    let c = try await fetchC()
    return (a, b, c)
}
```

- A) ~100 ms — `async` functions run concurrently.
- B) ~300 ms — the three `await`s are sequenced, one after another.
- C) ~33 ms — the runtime parallelises automatically.
- D) It deadlocks, because you cannot have three `await`s in one function.

---

**Q2.** You change `load()` to use `async let`:

```swift
async let a = fetchA()
async let b = fetchB()
async let c = fetchC()
return (try await a, try await b, try await c)
```

Which statement is correct?

- A) The three fetches still run sequentially; `async let` is just syntax sugar.
- B) The three child tasks start at their `async let` declarations and run concurrently; the function takes ~100 ms.
- C) The child tasks start only at the `try await`, so it's still ~300 ms.
- D) `async let` requires a `TaskGroup` to actually run concurrently.

---

**Q3.** When should you reach for a `TaskGroup` instead of `async let`?

- A) Whenever you have more than one concurrent operation.
- B) Only when the operations can throw.
- C) When the number of child tasks is dynamic (data-driven) or large, or you want to stream results as they complete.
- D) `TaskGroup` is always preferable; `async let` is deprecated.

---

**Q4.** What is the "cardinal sin" of Swift's cooperative thread pool?

- A) Creating too many `async let` bindings.
- B) Blocking a pool thread (e.g., `Thread.sleep`, `DispatchSemaphore.wait()`, synchronous blocking I/O).
- C) Using `TaskGroup` with more than 100 children.
- D) Calling an `async` function from another `async` function.

---

**Q5.** Cancellation in Swift structured concurrency is:

- A) Preemptive — the runtime forcibly stops the task immediately.
- B) Cooperative — cancellation sets a flag; the task keeps running until it checks and decides to stop.
- C) Only available for `Task.detached`.
- D) Automatic only for synchronous code.

---

**Q6.** A child task runs a long, purely synchronous loop with no `await` inside it. To make it respond to cancellation, you should:

- A) Do nothing — cancellation is automatic.
- B) Call `try Task.checkCancellation()` (or check `Task.isCancelled`) periodically inside the loop.
- C) Wrap the loop in `DispatchQueue.global().async`.
- D) Call `Thread.sleep(forTimeInterval: 0)` each iteration to yield.

---

**Q7.** What does the `onCancel` closure of `withTaskCancellationHandler(operation:onCancel:)` do?

- A) It replaces the `operation` when the task is cancelled.
- B) It runs immediately when cancellation fires (possibly on another thread) to nudge the operation toward stopping; it does **not** itself stop `operation`.
- C) It runs only after `operation` finishes normally.
- D) It blocks the cancelling task until `operation` completes.

---

**Q8.** Why does this fan-out exhaust file descriptors at scale?

```swift
await withTaskGroup(of: Result.self) { group in
    for url in tenThousandURLs { group.addTask { await check(url) } }
    for await r in group { results.append(r) }
}
```

- A) `for await` is too slow to drain results.
- B) `addTask` blocks, so the loop never finishes.
- C) `addTask` doesn't block, so all 10,000 child tasks (and their sockets) are spawned before a single result is consumed.
- D) `TaskGroup` leaks memory by design.

---

**Q9.** The idiomatic Swift fix for Q8 — capping concurrency to N — is:

- A) A `DispatchSemaphore` with value N, `wait()` before each `addTask`.
- B) The sliding-window pattern: prime N tasks, then `group.next()` one finished result and `addTask` one replacement until exhausted.
- C) Spawn 10,000 `Task.detached` tasks and hope the scheduler limits them.
- D) Set every task's priority to `.background`.

---

**Q10.** What does a `Task { }` created inside a `@MainActor` method inherit that a `Task.detached { }` does not?

- A) Nothing; they are identical.
- B) Priority, task-local values, and actor isolation (it stays on the main actor).
- C) Only the return type.
- D) Only the ability to throw.

---

**Q11.** Which of these is **not** a legitimate remaining use of GCD / `DispatchQueue` in 2026?

- A) `DispatchSource` for low-level kernel events like trapping `SIGINT`.
- B) Bridging an old framework whose callbacks hand you a `DispatchQueue`.
- C) Fanning out new feature work with `DispatchQueue.global().async` because it "feels more background-y."
- D) Leaving working, un-migrated GCD code alone until you touch that module for another reason.

---

**Q12.** How do you declare and bind a task-local value?

- A) `@TaskLocal var x = 0`, then assign `x = 5`.
- B) `@TaskLocal static var x = 0`, then bind it with `$x.withValue(5) { … }`.
- C) `Thread.current.threadDictionary["x"] = 5`.
- D) `Task.local["x"] = 5`.

---

**Q13.** You wrap a callback API with `withCheckedThrowingContinuation`. What is the iron rule?

- A) Resume the continuation at least twice for safety.
- B) Never resume; the runtime resumes it for you.
- C) Resume the continuation exactly once — resuming twice crashes, never resuming leaks the awaiting task forever.
- D) Resume only on the main thread.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — Three `await`s in a row are *sequenced*. Each waits for the previous to finish before starting. `async` changes what the thread does while waiting (it's freed, not blocked), not the order of operations. ~300 ms.
2. **B** — `async let` starts each child task at its declaration; they run concurrently and you join at the `await`. Independent work overlaps, so ~100 ms. (Lecture 1, §4.)
3. **C** — `async let` is for a small, fixed, compile-time-known set. `TaskGroup` is for a dynamic/large number of children, or when you want to stream results in completion order. Neither is deprecated. (Lecture 1, §5.)
4. **B** — The cooperative pool is sized to your core count and assumes you never block. Blocking a pool thread removes it from circulation; block enough and you deadlock. To wait, `await`; to pause, `Task.sleep`. (Lecture 1, §2.)
5. **B** — Cancellation is cooperative: it sets a flag. The task keeps running until it observes the flag (`Task.isCancelled`, `try Task.checkCancellation()`, or a cancellation-aware `await`) and decides to stop. Preemption would leave invariants broken. (Lecture 1, §7.)
6. **B** — A long synchronous loop has no suspension points, so it never observes cancellation for free. Check `Task.isCancelled` or `try Task.checkCancellation()` periodically (every few thousand iterations, not every one). (Lecture 1, §7.)
7. **B** — `onCancel` runs immediately when cancellation fires, possibly on another thread, and only touches `Sendable` state. Its job is to *nudge* the operation toward stopping (cancel the network task, signal the continuation); it does not itself stop `operation`. (Lecture 1, §7.)
8. **C** — `addTask` does not block. The `for` loop spawns all 10,000 children — each holding a socket/FD — before the consumer reads one result. Spawning is cheap; the resources each task holds are not. (Lecture 1, §8.)
9. **B** — The sliding window: prime up to N, then for each finished result from `group.next()`, add one replacement. No extra primitive needed. A `DispatchSemaphore.wait()` would block a pool thread (the cardinal sin). (Lecture 1, §8.)
10. **B** — `Task { }` inherits priority, task-local values, and actor isolation. `Task.detached` inherits none of them. Default to `Task { }`; reach for `detached` only when you can name which inheritance you're severing and why. (Lecture 2, §3.)
11. **C** — Reaching for `DispatchQueue.global().async` for new feature work because it "feels background-y" is the anti-pattern, not a legitimate use. The other three are the real remaining homes for GCD. (Lecture 2, §6.)
12. **B** — Task-locals must be `@TaskLocal static var`. You don't assign directly; you *bind* with `$name.withValue(_:operation:)`, scoped to that operation, and child tasks inherit it. (Lecture 1, §9.)
13. **C** — Resume exactly once. Twice is a `Fatal error: continuation misuse` crash; never is a permanent leak — the awaiting task hangs forever. Every path through the callback must resume exactly once. (Lecture 2, §8.)

</details>

---

If you scored under 10, re-read the lectures for the questions you missed — especially anything about sequencing vs concurrency (Q1–Q2) and cancellation (Q5–Q7), which are the heart of the week. If you scored 12 or 13, you're ready for the [homework](./06-homework.md) and the [mini-project](./07-mini-project/00-overview.md).
