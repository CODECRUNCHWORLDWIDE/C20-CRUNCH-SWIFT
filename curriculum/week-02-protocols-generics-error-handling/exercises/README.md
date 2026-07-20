# Week 2 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A protocol with an `associatedtype`, and a generic function over it](exercise-01-associatedtype-and-generics.md)** — define `Repository` with an `associatedtype`, write two conforming types, and a generic function constrained on the protocol. (~45 min)
2. **[Exercise 2 — Refactor `any` to `some`](exercise-02-any-to-some.swift)** — take an API written entirely in `any` and move each declaration to `some` (or a named generic) where appropriate, documenting why each choice was made. (~40 min)
3. **[Exercise 3 — Custom errors and `Result`](exercise-03-errors-and-result.swift)** — model a custom error enum, exercise `throws`, `try`, `try?`, and `try!` against it, and map the throwing outcome into a `Result`. (~40 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- The two `.swift` files are runnable as scripts: `swift exercises/exercise-02-any-to-some.swift`. They contain a `// TODO` section, a driver, and the expected output at the bottom. Fill in the TODOs until `swift <file>` prints the expected output.
- Exercise 1 is a guided, multi-step build inside a SwiftPM package with Swift Testing — follow the steps in the markdown.
- If you get stuck for more than 15 minutes, peek at the hints at the bottom of each file.
- Every exercise must end with a clean build. We treat warnings as errors: `swift build -Xswiftc -warnings-as-errors`. A warning is a bug this week.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-02` to compare.
