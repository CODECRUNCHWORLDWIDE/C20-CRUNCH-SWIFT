# Week 12 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A Combine pipeline you can read in your sleep](exercise-01-combine-pipeline.md)** — build the canonical search pipeline (`debounce` → `removeDuplicates` → `map` → `sink`), drive it from a `PassthroughSubject`, store the `AnyCancellable` correctly, and observe what happens when you *don't*. (~45 min)
2. **[Exercise 2 — A hand-rolled `AsyncStream` debounce](exercise-02-asyncstream-debounce.swift)** — build an `AsyncStream` from a callback source with a `Continuation`, debounce it by cancelling per-keystroke tasks, and test it deterministically with a clock. The async twin of exercise 1. (~50 min)
3. **[Exercise 3 — Bridge a publisher and consume it in a `.task`](exercise-03-bridge-and-task.swift)** — take a framework-style Combine publisher, consume it via `for await publisher.values`, run that loop inside a `.task`, and prove the loop is cancelled structurally when the task is. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Combine and the concurrency runtime ship with the SDK — **no package needed** for the core exercises. The stretch in exercise 2 optionally uses `swift-async-algorithms` (**File ▸ Add Package Dependencies ▸ `https://github.com/apple/swift-async-algorithms`**).
- The `.swift` exercises are written to drop into a Swift Testing target. Each file's header says exactly how. Run with **Cmd-U**.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — continuations and publishers cross concurrency boundaries and the compiler is right.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-12` to compare.
