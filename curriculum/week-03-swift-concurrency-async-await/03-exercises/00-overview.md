# Week 3 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume the earlier ones.

## Index

1. **[Exercise 1 — `async let` vs `TaskGroup`](./exercise-01-async-let-vs-taskgroup.md)** — fan out the *same* workload two ways, compare the code and the timing, and learn when each is the right tool. (~45 min)
2. **[Exercise 2 — Cooperative cancellation through a tree](./exercise-02-cooperative-cancellation.swift)** — implement cancellation with `withTaskCancellationHandler` and prove it propagates from a parent through two levels of children. (~50 min)
3. **[Exercise 3 — Bounded concurrency and back-pressure](./exercise-03-bounded-concurrency.swift)** — cap a `TaskGroup` to a configurable maximum and *measure* how throughput and peak in-flight count change as you vary the window. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run it. See the output. Read the error if it crashed.
- If you get stuck for more than 10 minutes, peek at the hints at the bottom of each file.
- Every exercise must end with `swift build` printing **no warnings and no errors**, and the program must **drain cleanly on Ctrl-C** where applicable. A hung Ctrl-C is a failing test this week.

## Scaffolding any exercise

Exercises 2 and 3 are `.swift` files meant to be dropped into a fresh executable package:

```bash
mkdir Drill && cd Drill
swift package init --type executable --name Drill
# Replace Sources/Drill/Drill.swift (or main.swift) with the exercise file.
swift run
```

If your generated package uses the `@main`-struct layout (Swift 6 default), the exercise files already declare `@main`; just replace the generated source file's contents. If your template uses a top-level `main.swift`, rename the file to `main.swift` and delete the `@main` attribute (top-level code can't coexist with `@main`).

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-03` to compare.
