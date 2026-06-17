# Week 4 — Actors, Sendable, and Strict Concurrency

Welcome to Week 4 of **C20 · Crunch Swift**. Last week you learned structured concurrency — `async`/`await`, `Task`, `TaskGroup`, cancellation. You learned to *spawn* concurrent work. This week you learn to make it *safe*. By Friday you should be able to take a shared mutable class riddled with data races, convert it into an actor, compile the whole module under **Swift 6 strict concurrency** with zero `@unchecked Sendable` escape hatches, and explain — in a code review, out loud — where every actor hop happens and what it costs.

This is the week the compiler stops trusting you. In Swift 5 the data-race rules were advice. In Swift 6, with the language mode set to `6`, they are enforced at compile time. A whole category of bug — two threads touching the same mutable memory without synchronisation — becomes a *build error*, not a 2 a.m. pager incident. That is a genuinely new thing in mainstream programming languages, and learning to work *with* the checker instead of fighting it is the single highest-leverage skill in modern Swift.

We assume you finished Week 3. You can write an `async` function, `await` a result, fan out with a `TaskGroup`, and cancel cleanly. If `Task { }` versus `Task.detached { }` is fuzzy, re-skim the Week 3 notes before Monday — we build directly on top of them.

The first thing to internalise is the mental model: **isolation domains**. A piece of mutable state belongs to exactly one isolation domain — a specific actor, the main actor, or "nonisolated and therefore must be `Sendable`." Crossing a domain boundary requires an `await` (an actor hop) and requires that whatever crosses is `Sendable` (safe to hand to another domain). Everything this week is a consequence of those two rules. Once they click, strict concurrency stops feeling like the compiler being difficult and starts feeling like the compiler doing your concurrency review for free.

## Learning objectives

By the end of this week, you will be able to:

- **Explain** what an actor is, what "actor isolation" means, and why an actor serialises access to its mutable state without a single explicit lock.
- **Convert** a shared mutable `class` into an `actor`, and identify every call site that now requires an `await`.
- **Locate** each actor hop in a call graph and articulate its concrete cost — suspension, possible thread switch, and loss of atomicity across the `await`.
- **Apply** `@MainActor`, `nonisolated`, and `nonisolated(unsafe)` deliberately, and justify each in code review.
- **Reason** about `Sendable` and `@Sendable` closures — which types are implicitly `Sendable`, which must be declared, and what the compiler checks at a boundary crossing.
- **Diagnose and fix** an actor reentrancy bug — the class of bug where state you read before an `await` is stale after it.
- **Enable** Swift 6 language mode on a real SwiftPM target and migrate the code until it compiles clean.
- **Remove** an `@unchecked Sendable` escape hatch by reworking the data model rather than lying to the compiler.

## Prerequisites

This week assumes you have completed **C20 Weeks 1–3**, specifically:

- You can read and write idiomatic Swift — `struct` vs `class`, value vs reference semantics, optionals, protocols, generics.
- You can write an `async` function, `await` it, and reason about suspension points (Week 3).
- You can fan out work with `TaskGroup` and `async let`, and you understand structured cancellation (Week 3).
- You have a working Swift 6 toolchain. On Linux: the `swift.org` toolchain (6.0 or newer) or the official Docker image. On macOS: Xcode 16 or newer. Verify with `swift --version` — you need **Swift 6.0+**.
- You can scaffold a SwiftPM package (`swift package init`), add a target, and run `swift build` and `swift test` (Week 1).

You do **not** need a Mac for this week. Everything compiles and runs on Linux with the open-source toolchain. The actor model, `Sendable`, and strict concurrency are language features, not Apple-platform features — `@MainActor` exists on Linux too (the "main actor" is just the main thread's serial executor).

## Topics covered

- The actor isolation model: isolation domains, the implicit per-actor serial executor, and why actor state is safe without locks.
- Declaring an `actor`; the rule that cross-actor access to mutable state must be `async` and `await`ed.
- Actor hops: what a hop is, when one happens, and the three costs — suspension, executor switch, and the reentrancy window.
- `@MainActor` — on a type, a method, a property, a closure, and a protocol. Why UI-touching code must be main-actor-isolated.
- `nonisolated` — opting a member *out* of isolation, the constraints it imposes, and `nonisolated(unsafe)` as the rare, deliberate escape.
- Global-actor isolation in general; why `@MainActor` is just the built-in global actor and how you could define your own.
- `Sendable`: the marker protocol for "safe to cross an isolation boundary." Implicit conformance for value types, explicit conformance for `final class`, and what the compiler verifies.
- `@Sendable` closures: what the annotation promises, what captures it forbids, and where the compiler inserts the requirement (`Task { }`, `TaskGroup.addTask`, actor-crossing callbacks).
- Actor **reentrancy**: why actors are reentrant by design, the "check-then-act across an `await`" bug, and the standard fixes (re-validate after `await`, generation tokens, in-flight task coalescing).
- `@unchecked Sendable`: what it actually disables, when it is genuinely justified (legacy bridging, hand-synchronised types), and why it is almost always a smell.
- Swift 6 **strict-concurrency** language mode: `swiftLanguageModes`, the `StrictConcurrency` upcoming feature in Swift 5 mode, and the incremental migration path.
- Reading and resolving the real diagnostics: "Non-sendable type … crossing actor boundary", "Capture of … with non-sendable type", "Main actor-isolated property can not be referenced from a nonisolated context".

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract.

| Day       | Focus                                                      | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Actors, isolation domains, actor hops                      |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Tuesday   | Sendable, @Sendable closures, @MainActor, nonisolated      |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     5.5h    |
| Wednesday | Reentrancy bugs; the strict-concurrency mental model       |    1h    |    1.5h   |     1.5h   |    0.5h   |   1h     |     0h       |    0.5h    |     6.5h    |
| Thursday  | Enabling Swift 6 mode; a worked migration                  |    1h    |    1h     |     0.5h   |    0.5h   |   1h     |     2h       |    0h      |     6h      |
| Friday    | Studio: migrate the mini-project starter                   |    0h    |    0h     |     0h     |    0.5h   |   0h     |     3.5h     |    0.5h    |     4.5h    |
| Saturday  | Mini-project deep work                                     |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, polish                                       |    0h    |    0h     |     0h     |    1h     |   0h     |     1h       |    0h      |     2h      |
| **Total** |                                                            | **6h**   | **6.5h**  | **2h**     | **3.5h**  | **5h**   | **12.5h**    | **1.5h**   | **34.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Swift Evolution proposals, the migration guide, WWDC talks, books |
| [lecture-notes/01-actors-isolation-and-hops.md](./02-lecture-notes/01-actors-isolation-and-hops.md) | Actors, isolation domains, hops, `@MainActor`, `nonisolated`, `Sendable`, reentrancy |
| [lecture-notes/02-strict-concurrency-and-a-worked-migration.md](./02-lecture-notes/02-strict-concurrency-and-a-worked-migration.md) | What Swift 6 mode enforces and why; a worked migration removing a real data race |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-class-to-actor.md](./03-exercises/exercise-01-class-to-actor.md) | Convert a shared mutable class to an actor; map every hop and its cost |
| [exercises/exercise-02-sendable-diagnostics.swift](./03-exercises/exercise-02-sendable-diagnostics.swift) | Annotate types and closures to satisfy strict concurrency; name each diagnostic |
| [exercises/exercise-03-reentrancy-and-mainactor.swift](./03-exercises/exercise-03-reentrancy-and-mainactor.swift) | Reproduce a reentrancy bug, fix it, then justify a `@MainActor` method |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the weekly challenge |
| [challenges/challenge-01-remove-the-escape-hatch.md](./04-challenges/challenge-01-remove-the-escape-hatch.md) | Rework a data model so an `@unchecked Sendable` can be deleted |
| [quiz.md](./05-quiz.md) | 13 questions with an answer key |
| [homework.md](./06-homework.md) | Six practice problems with a rubric |
| [mini-project/README.md](./07-mini-project/00-overview.md) | The "ActorKV" mini-project: a callback KV store, migrated to an actor |

## The "clean under strict concurrency" promise

C20 uses a recurring marker in every exercise that ends in working code:

```
Build complete! (Swift 6 language mode, 0 warnings)
```

If `swift build` does not finish with zero warnings under Swift 6 language mode, you are not done. We treat concurrency warnings as bugs — they are the compiler telling you exactly where a data race would have been. The point of Week 4 is to make that line ordinary, and to make it ordinary *without* `@unchecked Sendable`.

## Stretch goals

If you finish the regular work early and want to push further:

- Read **SE-0306 (Actors)** and **SE-0337 (Incremental migration to concurrency checking)** end to end: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md> and <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md>.
- Build a tiny benchmark that measures the cost of an actor hop versus an in-domain call (the homework walks you through one). See how much the hop actually costs in nanoseconds on your machine.
- Define your own global actor with `@globalActor` and isolate a subsystem to it. Ask yourself when this is ever a better idea than a plain `actor`.
- Skim the Swift compiler's `swift-frontend -enable-actor-data-race-checks` runtime diagnostics and read what they do at run time versus compile time.

## Up next

Continue to **Week 5 — Vapor: server-side Swift fundamentals** once you have pushed the mini-project to your GitHub. The `Sendable` shared-model discipline you build this week is exactly what makes a single `struct Note: Codable, Sendable` safe to share between a Vapor route handler and a future SwiftUI client — that payoff lands in Week 6.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
