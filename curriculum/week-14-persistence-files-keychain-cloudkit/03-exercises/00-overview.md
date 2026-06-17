# Week 14 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — The sandbox and atomic writes](./exercise-01-sandbox-and-atomic-writes.md)** — map the four sandbox directories, write a document **atomically** to the right one, exclude a cache from backup, and prove the placement with the file inspector. The "right place for each byte" tree, made concrete. (~40 min)
2. **[Exercise 2 — A typed `KeychainStore`](./exercise-02-keychain-store.swift)** — wrap the `SecItem*` C API in a typed Swift `KeychainStore` with an upserting `set`, store a token with the correct accessibility class, and test the full round-trip. The wrapper every shop has, written by you. (~50 min)
3. **[Exercise 3 — Deterministic CloudKit conflict resolution](./exercise-03-cloudkit-conflict-resolution.swift)** — model a CloudKit-safe `@Model`, write the conflict-resolution policy as a **pure function** over two snapshots, and test that it is deterministic (order-independent) and keeps the later edit. Conflict resolution you can unit-test without a paid account. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run it on the **iOS Simulator** (or a macOS target — the file and Keychain APIs run on both). See the output. Read the error if it crashed.
- The `.swift` exercises are written to drop into a SwiftUI app target *or* run as a Swift Testing / XCTest suite. Each file's header says which.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — the conflict policy is a pure function over `Sendable` snapshots precisely so it crosses actor boundaries cleanly.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-14` to compare.
