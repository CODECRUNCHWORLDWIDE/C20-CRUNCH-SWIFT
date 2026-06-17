# Week 23 — Exercises

Short, focused drills that feed directly into the capstone build and the Friday architecture review. Each one should take 30–60 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Trace one write end to end](./exercise-01-trace-one-write-end-to-end.md)** — follow a single note edit through every hop of the capstone (local edit → SwiftData → outbox → CloudKit/Vapor → conflict resolution → push → Live Activity → Widget), naming the failure mode and the data-loss window at each. The trace-an-event walk from Lecture 1, written down so you can deliver it live. (~50 min)
2. **[Exercise 2 — The conflict-resolution policy](./exercise-02-conflict-resolution-policy.swift)** — implement the capstone's deterministic three-way merge (`local`, `remote`, `ancestor`) as a pure function and prove with Swift Testing that two devices converge to the same note regardless of merge order. The ADR-0003 decision, in code. (~50 min)
3. **[Exercise 3 — The feature-flag killswitch](./exercise-03-killswitch-feature-flag.swift)** — build the remote killswitch the runbook depends on: a flag store that fetches from the Vapor backend, caches the last-known value, and falls back to a safe default offline, so you can disable a broken feature without an App Store resubmission. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- The `.swift` exercises are written as **Swift Testing** suites (the `import Testing` / `@Test` / `#expect` style shipped with Xcode 16). Drop each into a test target of your capstone (or a fresh SwiftPM package's test target) and run with Cmd-U (or `swift test`). Each file's header says exactly how.
- Exercise 1 is a written deliverable — a markdown trace you commit to your capstone repo and rehearse for the review.
- If you get stuck for more than 15 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with 0 warnings** under Swift 6 strict concurrency. A `Sendable` warning is a bug this week — the conflict resolver and the flag store both cross actor boundaries, and the compiler is right to hold you to it.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-23` to compare.
