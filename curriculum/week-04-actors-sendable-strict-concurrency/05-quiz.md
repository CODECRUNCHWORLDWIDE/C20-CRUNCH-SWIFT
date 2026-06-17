# Week 4 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 10/13 before moving to Week 5. Answer key at the bottom — don't peek.

---

**Q1.** What is the single mechanism that makes an `actor`'s mutable state safe without an explicit lock?

- A) The compiler inserts an `NSLock` around every property access.
- B) The actor has an associated serial executor; all isolated work runs on it one at a time.
- C) Actor properties are copied on every access, so no two callers share memory.
- D) Swift compiles actor methods to atomic CPU instructions.

---

**Q2.** Given:

```swift
actor Cache {
    let id = UUID()
    private var storage: [String: Int] = [:]
    func get(_ k: String) -> Int? { storage[k] }
}

let c = Cache()
```

Which of these compiles **without** an `await`?

- A) `c.get("x")`
- B) `c.storage["x"]`
- C) `c.id`
- D) All three.

---

**Q3.** How many actor hops occur in the single expression `await cache.get("feed")`, called from a `@MainActor` method, where `cache` is a different actor?

- A) Zero — `await` does not hop unless the actor is busy.
- B) One — into the cache actor.
- C) Two — into the cache actor to run `get`, then back to the main actor to resume.
- D) Four — two each way for the argument and the return.

---

**Q4.** Which statement about Swift's actor **reentrancy** is correct?

- A) Actors are non-reentrant: a second call blocks until the first returns.
- B) Actors are reentrant: while one call is suspended at an `await`, another call may run, so state can change across the suspension.
- C) Reentrancy is a bug in the Swift runtime that strict concurrency fixes.
- D) Reentrancy only happens with `@MainActor`, never with custom actors.

---

**Q5.** Which type is **not** automatically (implicitly) `Sendable`?

- A) `struct Point { let x: Int; let y: Int }`
- B) `enum Direction { case north, south }`
- C) `final class Box { var value: Int }`
- D) `actor Counter { var n = 0 }`

---

**Q6.** You write `final class Config { let timeout: Int; let retries: Int }` and the compiler refuses to let you pass it across an actor boundary. What is the **correct** fix?

- A) Add `@unchecked Sendable` to `Config`.
- B) Declare `final class Config: Sendable` — all stored properties are immutable and `Sendable`, so the conformance is honest.
- C) Wrap every access in an `NSLock`.
- D) Make `Config` an `actor`.

---

**Q7.** What does `@Sendable` on a closure parameter forbid?

- A) Calling `async` functions inside the closure.
- B) Capturing non-`Sendable` values, and capturing mutable `var` state by reference.
- C) Returning a value from the closure.
- D) Using the closure more than once.

---

**Q8.** A `Task { ... }` closure requires `@Sendable`. Why?

- A) Because `Task` always runs on the main actor.
- B) Because the task body may run on any thread in the cooperative pool, so anything it captures crosses an isolation boundary.
- C) Because `@Sendable` makes the task run faster.
- D) It does not — `Task` closures are never `@Sendable`.

---

**Q9.** What is the difference between the Swift 6 **toolchain** and the Swift 6 **language mode**?

- A) Nothing; they are two names for the same thing.
- B) The toolchain is the compiler version; the language mode is a per-target setting (`swiftLanguageModes: [.v6]`) that turns data-race checking from warnings into errors.
- C) The language mode is the compiler version; the toolchain is set in `Package.swift`.
- D) The toolchain only exists on macOS; the language mode only exists on Linux.

---

**Q10.** This actor method has a reentrancy bug:

```swift
func load(_ url: URL) async -> Data {
    if let cached = cache[url] { return cached }
    let data = await download(url)   // suspends
    cache[url] = data
    return data
}
```

What is the standard fix so two concurrent calls for the same URL download only once?

- A) Mark the method `nonisolated`.
- B) Hold a lock across the `await download(url)`.
- C) Store the in-flight `Task` in the cache **before** the first `await`, so reentrant callers join it.
- D) Add `@MainActor` to the method.

---

**Q11.** Why must a SwiftUI view model that drives the UI be `@MainActor`-isolated?

- A) To make the app run on a background thread for performance.
- B) Because UIKit/AppKit/SwiftUI view state must be mutated on the main thread, and `@MainActor` makes the compiler enforce that every caller hops to the main actor first.
- C) Because `@Observable` requires it; there is no thread-safety reason.
- D) It does not need to be — UI state is safe to mutate from any thread.

---

**Q12.** When is `@unchecked Sendable` **legitimately** justified?

- A) Whenever the compiler raises a `Sendable` error you don't want to fix.
- B) Never — it is always a bug.
- C) When the type has a real synchronisation mechanism the compiler cannot see (a hand-held `Mutex`, or a documented thread-safe C type) — and you assert the safety the checker can't verify.
- D) Only on `struct` types.

---

**Q13.** You call `await stats.record(page:)` inside a loop of 10,000 iterations. What is the hop count, and what is the better design?

- A) 2 hops total; the loop is already optimal.
- B) 20,000 hops (2 per iteration); batch the loop into a single `record(pages: [String])` actor method to make it 2 hops.
- C) 10,000 hops; nothing can reduce it.
- D) 0 hops; loops inside `await` are free.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — An actor's serial executor *is* the synchronisation. Only one piece of isolated work runs against an actor instance at a time. No lock is written because the runtime owns it and the compiler knows it.
2. **C** — `id` is a `let` constant, which is nonisolated and readable synchronously (an immutable value cannot race). `get` is an isolated method (needs `await`); `storage` is private *and* isolated (inaccessible from outside even with `await`). Only `c.id` compiles bare.
3. **C** — Two hops: out of the main actor into the cache actor to run `get`, then back into the main actor to resume the caller. The "back" hop is the one engineers forget. (See Lecture 1 §4.)
4. **B** — Swift actors are reentrant by design: an `await` inside an actor method suspends it and lets another call in. This avoids non-reentrant deadlocks but means state can change across every `await` — the source of logic races that survive into Swift 6.
5. **C** — A `final class` with a `var` stored property is *not* implicitly `Sendable` (a mutable shared reference is exactly what races). Structs and enums of `Sendable` parts are implicitly `Sendable`; actors are always `Sendable`.
6. **B** — `Config` is genuinely immutable (`let` everywhere, `Sendable` parts), so declaring the conformance is honest and the compiler verifies it. `@unchecked` would be a lie (no synchronisation needed); a lock or an actor is overkill for an immutable value.
7. **B** — `@Sendable` requires every captured value to be `Sendable` and forbids capturing mutable `var` state by reference, because the closure may run in a different isolation domain. It says nothing about `async` calls, return values, or call count.
8. **B** — The cooperative thread pool may run the task body on any thread, so its captures cross an isolation boundary; `@Sendable` is the compiler's guarantee that the crossing is safe.
9. **B** — The toolchain is the compiler binary (`swift --version`). The language mode is per-target in the manifest. A Swift 6 toolchain can compile a target in v5 mode (checks are warnings) or v6 mode (checks are errors). This per-target control is what makes migration incremental.
10. **C** — Record the in-flight `Task` in the cache before the first `await`. A reentrant call then finds the entry and `await`s the existing task instead of starting a duplicate. (Holding a lock across the download, option B, would serialise all downloads — wrong.)
11. **B** — All view-state mutation must happen on the main thread. `@MainActor` moves that requirement from a runtime convention you enforced by hand (`DispatchQueue.main.async`) to a compile-time guarantee the type system holds you to.
12. **C** — `@unchecked Sendable` is honest exactly when a real synchronisation mechanism exists that the compiler can't see (a `Mutex`-guarded type, a documented thread-safe C API). It is a lie when written purely to silence an error with no synchronisation behind it.
13. **B** — Each iteration is 2 hops (in and back), so 20,000 hops. Moving the loop inside the actor via a `record(pages:)` batch method makes it 2 hops total for the same work. This is the "batch into the actor" move from Lecture 1 §5.

</details>

---

If you scored under 10, re-read the lectures for the questions you missed — especially the hop-counting (Q3, Q13) and reentrancy (Q4, Q10) items, which the mini-project leans on hardest. If you scored 12 or 13, you're ready for the [homework](./06-homework.md).
