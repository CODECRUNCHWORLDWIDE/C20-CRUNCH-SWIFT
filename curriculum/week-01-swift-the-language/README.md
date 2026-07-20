# Week 1 — Swift the Language

Welcome to **C20 · Crunch Swift**. This is the language week. By Friday you should be able to install the open-source Swift toolchain on Linux or macOS, scaffold a Swift Package Manager executable from a blank folder, drop into the REPL to test an idea, write a Swift Testing target, and ship a small command-line tool — all from the terminal, with no Xcode and no Mac required.

We assume you already know one typed OOP language well. The target reader has shipped production code in Java, Kotlin, C#, TypeScript, Go, or Rust. If that's you, this week is not "learn to program." It is "learn the Swift dialect and the SwiftPM toolchain, and unlearn three habits that will hurt you." We move fast, and we spend our time on the parts of Swift that do **not** map cleanly from the language you already know.

The first thing to internalize is that **Swift is not an Apple-only language and it has no `null`**. Swift the language is open-source, Apache-2.0 licensed, developed in the open at `github.com/swiftlang/swift`, and runs on Linux, macOS, Windows, and WebAssembly. The absence of `null` — replaced by the `Optional` enum and forced unwrapping at the point of use — is the single biggest conceptual shift for an engineer coming from a `null`-bearing language. We spend a whole lecture and a whole exercise on it. In 2026 the default assumption is **Swift 6.1 on the open-source toolchain**, and that's what every example this week uses.

## Learning objectives

By the end of this week, you will be able to:

- **Install** the open-source Swift 6.1 toolchain on both Linux (via Swiftly or the `swift.org` tarball) and macOS, and verify it with `swift --version`.
- **Scaffold** a SwiftPM executable from a blank folder with `swift package init --type executable`, build it with `swift build`, run it with `swift run`, and test it with `swift test`.
- **Navigate** the standard SwiftPM layout: `Package.swift`, `Sources/`, `Tests/`, and where `.build/` artifacts land.
- **Use** the Swift REPL (`swift` with no arguments) to explore a value, a type, and a standard-library API without writing a file.
- **Distinguish** value types (`struct`, `enum`) from reference types (`class`) and predict copy-vs-share behaviour in code review.
- **Model** "no value" with `Optional`, and handle it with `if let`, `guard let`, optional chaining, and the nil-coalescing operator `??` — without reaching for force-unwrap `!`.
- **Read and write** Swift's core collection types — `String`, `Array`, `Dictionary`, `Set`, ranges, and tuples — and reason about their value semantics and copy-on-write behaviour.
- **Explain** which parts of Swift map cleanly from your previous language (generics, closures, exhaustive switching) and which do not (optionals, value types, no `null`, `let` vs `var` immutability).
- **Write** a Swift Testing target with `@Test` and `#expect`, run it with `swift test`, and read its output.
- **Ship** a small typed CLI that reads a file, processes it, and prints formatted output, cross-compiled and tested on Linux and macOS.

## Prerequisites

This week assumes you have completed **C1 · Code Crunch Convos**, or have equivalent fluency in a typed OOP language. Specifically:

- Comfortable in a terminal — you can `cd`, run a build tool, install a package.
- You've written and tested a small project end-to-end at least once.
- You understand functions, classes, generics-or-equivalent, and exceptions.
- You can read and write basic Git (`clone`, `add`, `commit`, `push`).

You do **not** need any prior Swift exposure, and you do **not** need a Mac. Weeks 1–6 run on Linux, macOS, or Windows + WSL2 using the open-source toolchain. If you have only ever seen Swift in an Xcode tutorial, you will be pleasantly surprised how much you can do from a Linux box and a terminal.

## Topics covered

- The open-source Swift toolchain: `swift.org`, Swiftly (the toolchain installer), the Docker image, and what ships inside a toolchain (the compiler, SwiftPM, the REPL, LLDB, the standard library, Foundation, Swift Testing, and XCTest).
- Installing on Linux (Ubuntu 22.04 / 24.04) and macOS, and verifying with `swift --version`.
- The Swift REPL: `swift`, `:type`, `:help`, multi-line entry, importing modules.
- Swift Package Manager: `swift package init`, `Package.swift` (the manifest), `Sources/`, `Tests/`, `.build/`, executable vs library targets.
- `let` vs `var` — immutability by default and why it matters.
- Type inference and when to write the type anyway.
- Value types (`struct`, `enum`) vs reference types (`class`); copy semantics; copy-on-write for the standard-library collections.
- Optionals: the `Optional<Wrapped>` enum, `?`, `!`, `if let`, `guard let`, optional chaining `?.`, nil-coalescing `??`, and why there is no `null`.
- Control flow: `if`, `guard`, `for`-`in`, `while`, `switch` with exhaustiveness and pattern matching.
- The core collection types: `String` (and `Character`, grapheme clusters), `Array`, `Dictionary`, `Set`, `Range`/`ClosedRange`, and tuples.
- Swift Testing: `@Test`, `#expect`, `#require`, parameterized tests with `arguments:`, and the `swift test` runner.
- The map: what carries over from Java/Kotlin/C#/TypeScript, and what breaks.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target.

| Day       | Focus                                                | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Toolchain install, SwiftPM, the REPL                 |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Value vs reference types, `let`/`var`, type inference |    2h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Optionals, `if let`/`guard let`, no `null`           |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Collections, ranges, tuples, Swift Testing           |    1h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | Cross-platform build; mini-project work              |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0.5h    |     6h      |
| Saturday  | Mini-project deep work                               |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, polish                                 |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                      | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **6h**   | **8.5h**     | **2h**     | **35.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Curated swift.org, language-guide, and open-source links, current to 2026 |
| [lecture-notes/01-swift-for-the-typed-oop-engineer.md](./lecture-notes/01-swift-for-the-typed-oop-engineer.md) | What maps cleanly from Java/Kotlin/C#/TypeScript, and what breaks — optionals, value types, no `null`, exhaustive switching |
| [lecture-notes/02-swiftpm-the-repl-and-swift-testing.md](./lecture-notes/02-swiftpm-the-repl-and-swift-testing.md) | The toolchain, SwiftPM executables, `Package.swift`, the REPL, and the Swift Testing target |
| [exercises/README.md](./exercises/README.md) | Index of short coding exercises |
| [exercises/exercise-01-install-and-prove-value-semantics.md](./exercises/exercise-01-install-and-prove-value-semantics.md) | Install the toolchain, run the REPL, prove value-vs-reference with a `struct` and a `class` side by side |
| [exercises/exercise-02-optionals.swift](./exercises/exercise-02-optionals.swift) | Optional-handling drill: `if let`, `guard let`, `??`, then refactor a force-unwrap-heavy snippet to be crash-safe |
| [exercises/exercise-03-collections.swift](./exercises/exercise-03-collections.swift) | Transform a sample dataset with `String`, `Array`, `Dictionary`, `Set`, ranges, and tuples, with type-inference annotations explained in comments |
| [challenges/README.md](./challenges/README.md) | Index of weekly challenges |
| [challenges/challenge-01-wordfreq-multi-file.md](./challenges/challenge-01-wordfreq-multi-file.md) | Extend the `wordfreq` CLI: multiple files, merged counts, a `--min-count` flag, tests green on Linux and macOS |
| [quiz.md](./quiz.md) | 12 multiple-choice questions with an answer key |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for the `wordfreq` CLI mini-project |

## The "build complete" promise

C20 uses a small recurring marker in every exercise that ends in working code:

```
Build complete! (1.42s)
```

That is the literal last line `swift build` prints on success. If you do not see `Build complete!`, you are not done. We also treat warnings as defects: a clean build prints no diagnostics above that line. The point of Week 1 is to make `Build complete!` ordinary, and to make `swift test` reporting `Test run with N tests passed` the thing you check before every commit.

## Stretch goals

If you finish the regular work early and want to push further:

- Read **The Swift Programming Language** book chapters "The Basics" and "Optional Chaining": <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/>.
- Skim the **Swift Package Manager** documentation, especially the `Package.swift` manifest reference: <https://www.swift.org/documentation/package-manager/>.
- Browse **swiftlang/swift** on GitHub. Open the standard library's `Optional.swift` and read how `Optional` is just an `enum`: <https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Optional.swift>.
- Read the **Swift Testing** documentation and compare `@Test`/`#expect` to the XCTest you may have seen before: <https://developer.apple.com/documentation/testing>.
- Write a short note for your future self comparing how your previous language and Swift each handle "no value" — `null` / `nil` / `None` / `Optional<T>` / `?`.

## Up next

Continue to **Week 2 — Protocols, Generics, Error Handling** once you have pushed the `wordfreq` mini-project to your GitHub and confirmed it builds and tests green on both Linux and macOS.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
