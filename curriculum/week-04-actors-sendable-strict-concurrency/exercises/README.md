# Week 4 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones. Every exercise must end with `swift build` finishing under **Swift 6 language mode** with **zero warnings** and **zero `@unchecked Sendable`**. A concurrency warning is a bug this week — it is the compiler pointing at a data race.

## Index

1. **[Exercise 1 — From class to actor](exercise-01-class-to-actor.md)** — convert a shared mutable `class` into an `actor`, then map every actor hop in the call graph and state what each one costs. (~45 min)
2. **[Exercise 2 — Satisfying the Sendable checker](exercise-02-sendable-diagnostics.swift)** — a file full of strict-concurrency diagnostics. Annotate types and closures with `Sendable` / `@Sendable` until it compiles, naming each diagnostic you fixed. (~40 min)
3. **[Exercise 3 — Reentrancy and @MainActor](exercise-03-reentrancy-and-mainactor.swift)** — reproduce an actor reentrancy bug, fix it, then mark a UI-touching method `@MainActor` and justify it. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorise.
- **Type the code yourself.** Do not copy-paste. Reading the diagnostic and reacting to it is the entire skill being trained.
- Build with `swift build`. Read the error. The Swift concurrency diagnostics are unusually good — they usually tell you the fix.
- For the `.swift` files: each is a self-contained SwiftPM executable target's `main.swift` unless noted. The header of each file tells you how to scaffold and run it.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise ends with the marker:
  ```
  Build complete! (Swift 6 language mode, 0 warnings)
  ```
  If you don't see zero warnings under `.v6`, you're not done — and if you got there with `@unchecked Sendable`, you're not done either. Remove it and fix the real problem.

## Scaffolding any `.swift` exercise

```bash
mkdir Ex && cd Ex
swift package init --type executable --name Ex
# replace Sources/Ex/main.swift with the exercise file
# set the language mode in Package.swift (see each file's header)
swift build
swift run Ex
```

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-04` to compare.
