# Week 1 — Exercises

Short, focused drills. Each one should take 25–45 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Install and prove value semantics](./exercise-01-install-and-prove-value-semantics.md)** — install the swift.org toolchain on Linux and macOS, run the REPL, and prove value-vs-reference semantics with a `struct` and a `class` side by side. (~40 min)
2. **[Exercise 2 — Optionals](./exercise-02-optionals.swift)** — write optional-handling code with `if let`, `guard let`, and `??`, then refactor a force-unwrap-heavy snippet to be crash-safe. (~35 min)
3. **[Exercise 3 — Collections](./exercise-03-collections.swift)** — transform a sample dataset with `String`, `Array`, `Dictionary`, `Set`, ranges, and tuples, with type-inference annotations explained in comments. (~40 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run it. See the output. Read the error if it crashed.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must end with `swift build` printing `Build complete!` with no warnings, and (where there are tests) `swift test` reporting all tests passed. A warning is a bug this week.

## Running a single `.swift` file without a package

Exercises 2 and 3 are single files. You can run them two ways:

```bash
# Quickest: interpret the file directly.
swift exercise-02-optionals.swift

# Or compile to a binary first, then run.
swiftc exercise-02-optionals.swift -o ex2 && ./ex2
```

Both work on Linux and macOS. The first is faster to iterate; the second is closer to what `swift build` does in a package.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-01` to compare.
