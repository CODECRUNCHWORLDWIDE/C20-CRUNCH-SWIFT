# Week 4 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 4 Git repository so each problem produces at least one commit you can point to later.

Every problem must build under **Swift 6 language mode** (`swiftLanguageModes: [.v6]`) with **zero warnings** and **zero `@unchecked Sendable`**, unless the problem explicitly says otherwise. That is the recurring bar for the week.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

---

## Problem 1 — Audit a module for isolation domains

**Problem statement.** Take the `ArticleService` / `ArticleListModel` subsystem from Lecture 1 §11 (copy it into `homework/p1-audit/Sources/`). Without changing the code, write `homework/p1-audit/AUDIT.md` that, for every type and every method, states its isolation domain — one of: a specific actor, `@MainActor`, or `nonisolated`/`Sendable`. For each boundary crossing (`await`) in `ArticleListModel.load(from:)`, name the two domains it crosses between and whether the value crossing it is `Sendable`.

**Acceptance criteria.**

- `homework/p1-audit/` contains the copied subsystem and it builds under `.v6` with zero warnings.
- `AUDIT.md` lists every type/method with its domain.
- `AUDIT.md` traces each `await` in `load(from:)`: the two domains and the `Sendable` value(s) crossing.
- Committed.

**Hint.** `Article` is a `Sendable` value type; `ArticleService` is an actor (so `Sendable`); `ArticleListModel` is `@MainActor`. The `await service.articles(from:)` crosses main → service and service → main. The `[Article]` returned is `Sendable` because `Article` is.

**Estimated time.** 30 minutes.

---

## Problem 2 — Convert a callback bank account to an actor

**Problem statement.** In `homework/p2-account/`, you are given (write it yourself from this spec) a `final class BankAccount` with a callback API:

```swift
final class BankAccount {
    private var balanceCents: Int = 0
    func deposit(_ cents: Int, completion: (Int) -> Void) { /* updates, calls back with new balance */ }
    func withdraw(_ cents: Int, completion: (Result<Int, Error>) -> Void) { /* error if insufficient */ }
    func balance(completion: (Int) -> Void) { /* calls back with current balance */ }
}
```

Convert it to an `actor BankAccount` with an `async` API (`deposit(_:) -> Int`, `withdraw(_:) async throws -> Int`, `balance() -> Int`). Define a `SendableError` enum for the insufficient-funds case. Write a Swift Testing test that fires 100 concurrent `deposit(1_00)` calls in a `TaskGroup` and asserts the final balance is exactly `100_00` cents — deterministically, every run.

**Acceptance criteria.**

- `BankAccount` is an `actor`; the API is `async`. No callbacks remain.
- The error type conforms to `Error` and is `Sendable`.
- `swift build` and `swift test` pass under `.v6`, zero warnings.
- The concurrent-deposit test passes on at least 5 consecutive runs (the actor makes it deterministic).
- Committed.

**Hint.** The `withdraw` error path: `guard balanceCents >= cents else { throw SendableError.insufficientFunds }`. A simple `enum SendableError: Error { case insufficientFunds }` is `Sendable` for free. In the test, `await withTaskGroup(of: Void.self) { group in for _ in 0..<100 { group.addTask { _ = await account.deposit(1_00) } } }`.

**Estimated time.** 50 minutes.

---

## Problem 3 — Measure an actor hop

**Problem statement.** In `homework/p3-hopcost/`, write a small executable that measures the cost of an actor hop on your machine. Define `actor Counter { private(set) var n = 0; func bump() { n += 1 }; func bumpMany(_ times: Int) { for _ in 0..<times { n += 1 } } }`. Time two workloads with `ContinuousClock`:

1. **Hop-per-call:** `for _ in 0..<1_000_000 { await counter.bump() }` — one hop in, one back, per iteration.
2. **Batched:** `await counter.bumpMany(1_000_000)` — one hop in, one back, total.

Print both durations and the per-hop cost (workload 1 time divided by 1,000,000). Write a one-paragraph `RESULT.md` with the numbers from *your* machine and the ratio between the two workloads.

**Acceptance criteria.**

- Executable builds under `.v6`, zero warnings.
- It prints both durations and a per-call hop cost in nanoseconds.
- `RESULT.md` reports your machine's numbers and the speedup of the batched form.
- Both workloads end with `n == 1_000_000` (assert it).
- Committed.

**Hint.** `let clock = ContinuousClock(); let elapsed = await clock.measure { for _ in 0..<1_000_000 { await counter.bump() } }`. Per-hop nanoseconds: `elapsed / 1_000_000` then read `.components`. Expect the batched form to be hundreds to thousands of times faster — that gap *is* the hop cost.

**Estimated time.** 50 minutes.

---

## Problem 4 — Fix a `@Sendable` capture without `@unchecked`

**Problem statement.** In `homework/p4-capture/`, start from this code, which does **not** compile under `.v6`:

```swift
final class Telemetry {
    var events: [String] = []
    func record(_ e: String) { events.append(e) }
}

func instrument(_ t: Telemetry) {
    for i in 0..<10 {
        Task { t.record("event \(i)") }   // error: capture of non-Sendable 't'
    }
}
```

Make it compile and run correctly under `.v6` **without** `@unchecked Sendable` and without `nonisolated(unsafe)`. Then write a driver that calls `instrument`, waits, and prints the recorded event count (must be 10).

**Acceptance criteria.**

- Builds under `.v6`, zero warnings, zero escape hatches.
- The 10 events are all recorded (order may vary; count must be 10).
- A short comment in the file names the diagnostic you fixed and the fix.
- Committed.

**Hint.** Make `Telemetry` an `actor`. Then `record` becomes a cross-actor call, so `Task { await t.record("event \(i)") }`. To read the final count, `await t.events.count` (or add a `count()` method). To wait for all 10 fire-and-forget tasks deterministically, collect them: `await withTaskGroup(of: Void.self) { group in for i in 0..<10 { group.addTask { await t.record("event \(i)") } } }`.

**Estimated time.** 40 minutes.

---

## Problem 5 — Re-validate across an `await`

**Problem statement.** In `homework/p5-revalidate/`, you are given an actor with a check-then-act reentrancy bug on a *value* (not a duplicate-task bug — a stale-guard bug):

```swift
actor Reservation {
    private var seatsLeft: Int
    init(seats: Int) { self.seatsLeft = seats }

    func reserve() async -> Bool {
        guard seatsLeft > 0 else { return false }     // check
        await confirmWithPaymentGateway()              // suspends — reentrancy window
        seatsLeft -= 1                                 // act on a possibly-stale guard
        return true
    }

    private func confirmWithPaymentGateway() async {
        try? await Task.sleep(for: .milliseconds(10))
    }
}
```

With a single seat and many concurrent `reserve()` calls, this oversells: several callers pass the guard before any of them decrements. Fix it by **re-validating the invariant after the `await`** (and decrementing only if still valid). Write a test that starts with `seats: 1`, fires 20 concurrent `reserve()` calls, and asserts that exactly **one** returns `true` and `seatsLeft == 0`.

**Acceptance criteria.**

- Builds under `.v6`, zero warnings.
- After the fix, the 20-caller / 1-seat test shows exactly one `true` and `seatsLeft == 0`, deterministically.
- The fix is a re-check after the `await`, not a lock and not removing the suspension.
- A comment explains why the second `guard` is required.
- Committed.

**Hint.** Add `guard seatsLeft > 0 else { return false }` *again* immediately after `await confirmWithPaymentGateway()`. The world changed across the suspension; the pre-`await` guard is stale. (For a real payment flow you would also need to *reserve* the seat before confirming and release it on failure — but for this exercise, the re-check is the lesson.)

**Estimated time.** 45 minutes.

---

## Problem 6 — Mini reflection essay

**Problem statement.** Write a 300–400 word reflection at `homework/week-04-reflection.md` answering:

1. Before this week, how did you (or your team, or a language you know) prevent data races? How does Swift's compiler-enforced model compare?
2. Which clicked harder: `Sendable` (what may cross a boundary) or actor reentrancy (what can change across an `await`)? Why?
3. You removed (or will remove, in the challenge) an `@unchecked Sendable`. In one paragraph, explain to a teammate why reaching for that annotation to clear a build error is a bug, not a fix.
4. What is one place in a codebase you have worked on that you now suspect has a data race the Swift 6 checker would catch?

**Acceptance criteria.**

- File exists, 300–400 words.
- Each numbered question is addressed in its own paragraph.
- File is committed.

**Hint.** This is for *you*, not for a grade. Be honest. Future-you migrating a real 100-target app to Swift 6 will be grateful for the notes.

**Estimated time.** 30 minutes.

---

## Time budget recap

| Problem | Estimated time |
|--------:|--------------:|
| 1 | 30 min |
| 2 | 50 min |
| 3 | 50 min |
| 4 | 40 min |
| 5 | 45 min |
| 6 | 30 min |
| **Total** | **~4 h 5 min** |

## Rubric

Homework is graded out of 12 points, 2 per problem:

| Criterion | Points (per applicable problem) |
|-----------|--------------------------------|
| Builds under `.v6` with zero warnings | 1 |
| Correctness (tests pass / output matches / analysis is accurate) | 0.5 |
| No `@unchecked Sendable` or `nonisolated(unsafe)` (except where the problem permits) | 0.5 |

A submission that builds clean, passes its tests, and reaches for no escape hatch scores full marks. The most common deduction is "made it compile with `@unchecked Sendable`" — that is a zero on the no-escape-hatch criterion, every time.

When you've finished all six, push your repo and open the [mini-project](./mini-project/README.md).
