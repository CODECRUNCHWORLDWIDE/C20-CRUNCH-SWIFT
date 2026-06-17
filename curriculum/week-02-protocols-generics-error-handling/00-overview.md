# Week 2 — Protocols, Generics, and Error Handling

Welcome to Week 2 of **C20 · Crunch Swift**. Week 1 made you fluent in Swift the language — value types, optionals, exhaustive `switch`, a SwiftPM executable, a Swift Testing target. Week 2 is where Swift stops being "a typed language with optionals" and starts being "a type system with opinions."

The opinion is this: **you design with protocols and generics, not with class inheritance.** If you arrived from Java, Kotlin, C#, or TypeScript, your fingers are trained to type a base class and an `override`. That reflex fights Swift. The standard library — every one of `Int`, `Array`, `Dictionary`, `Optional`, `Result`, `Sequence`, `Comparable`, `Codable` — is built on protocols, generics, and value types, with not an inheritance hierarchy in sight. This week you learn to build the same way.

By Friday you will have designed a protocol with an `associatedtype`, written generic functions and types constrained by `where` clauses, chosen `some` (opaque) over `any` (existential) deliberately using the decision matrix from the Swift Evolution proposals, hand-reasoned about type erasure, and modeled a real error domain with `throws`, `try` / `try?` / `try!`, custom error enums, and `Result`. The capstone of the week is a generic `Cache<Key: Hashable, Value>` with TTL eviction and a pluggable, protocol-backed `CacheStore` — the data structure that reappears, with an eviction policy bolted on, in this week's challenge.

We move fast. The reference week assumes you can already read and write idiomatic Swift and run `swift test` from the terminal. Everything here runs on the open-source Swift 6 toolchain on **Linux, macOS, or Windows + WSL2** — no Mac, no Xcode required yet.

## Learning objectives

By the end of this week, you will be able to:

- **Explain** why a Swift protocol is not a Java interface, and why protocol-oriented programming replaces class inheritance for most designs.
- **Design** a protocol with method, property, and `associatedtype` requirements, and provide shared behaviour through protocol extensions with default implementations.
- **Distinguish** a protocol requirement (dynamic dispatch, overridable) from an extension-only method (static dispatch) — and avoid the dispatch gotcha that bites everyone exactly once.
- **Write** generic functions and generic types constrained with `<T: Protocol>` and `where` clauses, and reach into associated types like `C.Element`.
- **Add** conditional conformance (`extension Stack: Equatable where Element: Equatable`) to a generic type.
- **Choose** `some` (opaque) over `any` (existential) over a named generic deliberately, and state the run-time cost of each.
- **Hand-write** a three-layer type eraser, and recognise when a constrained existential (`any P<…>`) makes one unnecessary.
- **Model** an error domain as an `enum: Error`, use `throws` / typed throws, and handle failures with `do`/`catch`, `try?`, and `try!` — knowing when each is a smell.
- **Bridge** `throws` and `Result<Success, Failure>` in both directions and transform a `Result` with `map` / `mapError` / `flatMap`.
- **Conform** a type to `Sequence` via `IteratorProtocol` and inherit the entire functional toolbox.
- **Ship** a generic, protocol-backed cache with property tests.

## Prerequisites

This week assumes you completed **C20 Week 1** (Swift the language) or have equivalent Swift fluency. Specifically:

- You can scaffold a SwiftPM package (`swift package init`) and run `swift build` / `swift test` / `swift run` from the terminal.
- You understand value vs reference types, `let` vs `var`, optionals, `if let` / `guard let`, and exhaustive `switch`.
- You can write a Swift Testing target with `@Test` and `#expect`.
- You can read and write basic Git.

You do **not** need a Mac or Xcode. Install the Swift 6 toolchain from <https://www.swift.org/install/> (the official Docker image or the Ubuntu / Windows builds are all fine). Verify with `swift --version` — you should see `6.x`.

## Topics covered

- Protocol-oriented programming: protocols as requirements, not implementations; explicit conformance; `Self` requirements.
- Protocol extensions and default implementations; the static-vs-dynamic dispatch gotcha.
- Generic functions and generic types; type parameters, constraints, and `where` clauses.
- `associatedtype`: protocols with type holes the conformer fills; constraining algorithms on associated types.
- Why a protocol with an associated type (a PAT) cannot be used as a bare type.
- Generic types (`Stack<Element>`), and conditional conformance (`where Element: …`).
- `Sequence` and `IteratorProtocol` — building the abstraction behind every `for` loop.
- Opaque types (`some`) vs existential types (`any`): semantics, run-time cost, and the SwiftUI `some View` rule.
- The `some`/`any` decision matrix from SE-0244, SE-0335, SE-0341, SE-0309, SE-0346.
- Constrained existentials and primary associated types (`any Container<Int>`).
- Type erasure: the three-layer hand-built eraser; `AnySequence` / `AnyPublisher` in the wild.
- The `Error` protocol; custom error enums with associated values; `Equatable` errors for testing.
- `throws` / `try`; typed throws (Swift 6); `try?` and `try!` and when each is a code smell.
- `Result<Success, Failure>`: bridging to/from `throws`, and `map` / `mapError` / `flatMap`.
- `defer` for resource cleanup that survives a thrown error.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target.

| Day       | Focus                                                       | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|-------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | POP, protocols, extensions, `Sequence`/`IteratorProtocol`   |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Generics, `associatedtype`, constrained algorithms          |    2h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | `some` vs `any`, type erasure, the decision matrix          |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Error model: `Error`, `throws`, `try` variants, `Result`    |    1h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | Cache mini-project: generics + protocol store + errors      |    0h    |    0.5h   |     0h     |    0.5h   |   1h     |     3h       |    0.5h    |     5.5h    |
| Saturday  | Mini-project deep work + property tests                     |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, polish                                        |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                             | **6h**   | **7h**    | **3h**     | **4h**    | **6h**   | **11.5h**    | **2h**     | **35.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Curated Swift docs, Swift Evolution proposals, WWDC talks, and open-source reading |
| [lecture-notes/01-protocols-generics-not-java.md](./02-lecture-notes/01-protocols-generics-not-java.md) | Protocol-oriented programming, protocol extensions, generics, `associatedtype`, generic types, `Sequence`/`IteratorProtocol` |
| [lecture-notes/02-some-vs-any-and-the-error-model.md](./02-lecture-notes/02-some-vs-any-and-the-error-model.md) | `some` vs `any`, the decision matrix, type erasure, custom errors, `throws`/`try`/`try?`/`try!`, `Result` |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three coding exercises |
| [exercises/exercise-01-associatedtype-and-generics.md](./03-exercises/exercise-01-associatedtype-and-generics.md) | Define a protocol with an `associatedtype`, write two conformers, and a generic function constrained on it |
| [exercises/exercise-02-any-to-some.swift](./03-exercises/exercise-02-any-to-some.swift) | Refactor an `any`-typed API to `some` where appropriate and document each choice |
| [exercises/exercise-03-errors-and-result.swift](./03-exercises/exercise-03-errors-and-result.swift) | Model a custom error enum; exercise `throws`, `try`, `try?`, `try!`; map failures into `Result` |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the weekly challenge |
| [challenges/challenge-01-pluggable-eviction-policy.md](./04-challenges/challenge-01-pluggable-eviction-policy.md) | Add a pluggable LRU/TTL eviction policy to the cache behind a protocol, proven with property tests |
| [quiz.md](./05-quiz.md) | 13 multiple-choice questions with an answer key |
| [homework.md](./06-homework.md) | Six practice problems for the week with a rubric |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for the generic `Cache<Key, Value>` mini-project |

## The "0 failures" promise

C20 uses a recurring marker in every exercise that ends in working code:

```
Test Suite 'All tests' passed at 2026-06-09 ... 
     Executed 18 tests, with 0 failures (0 unexpected) in 0.041 (0.043) seconds
```

If `swift test` does not print zero failures, you are not done. We also build with warnings treated as errors (`swift build -Xswiftc -warnings-as-errors`); a warning is a bug this week, exactly as a nullable warning was in C9. The point of Week 2 is to make zero-failure, zero-warning output ordinary.

## Stretch goals

If you finish the regular work early and want to push further:

- Read **SE-0335 (existential `any`)** end to end. It is the clearest single document on *why* the keyword exists: <https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md>.
- Watch **"Embrace Swift generics" (WWDC 2022)** and **"Design protocol interfaces in Swift" (WWDC 2022)** back to back: <https://developer.apple.com/videos/play/wwdc2022/110352/>.
- Open `swift-collections` on GitHub and read `OrderedDictionary` — you will use it for LRU in the challenge: <https://github.com/apple/swift-collections>.
- Skim the standard library's `Sequence` and `Collection` source in `swiftlang/swift` under `stdlib/public/core/` — see how many free methods one requirement buys.
- Write a one-page note for your future self comparing how Java's exceptions, Rust's `Result`, and Swift's `throws` + `Result` each model failure.

## Up next

Continue to **Week 3 — Swift Concurrency I (async/await, structured concurrency)** once you have pushed the cache mini-project to your GitHub. The generic, protocol-backed `Cache` you build this week becomes a concurrency exercise next week: you will make its store `async` and protect it against data races.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
