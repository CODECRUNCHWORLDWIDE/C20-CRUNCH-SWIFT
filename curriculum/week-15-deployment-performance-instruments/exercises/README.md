# Week 15 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones. **Exercises 1 and the profiling parts of 2/3 require a physical device and a paid Apple Developer account** — the Simulator cannot give you honest performance numbers, which is the whole point of the week.

## Index

1. **[Exercise 1 — Deploy and read the profile](exercise-01-deploy-and-read-the-profile.md)** — sign and deploy a Release build to your device, run the Time Profiler while you exercise the app, and read a flame graph to find the heaviest stack. The "device tells the truth, Instruments reads it" loop, in one exercise. (~40 min)
2. **[Exercise 2 — Find and fix a hang](exercise-02-find-and-fix-a-hang.swift)** — plant a deliberate synchronous main-thread hang, find it in the Hangs instrument (and Time Profiler's main-thread track), move the work off-main with structured concurrency, and prove the hang is gone. (~50 min)
3. **[Exercise 3 — Signposts and MetricKit](exercise-03-signposts-and-metrickit.swift)** — wrap an operation in an `OSSignposter` interval so it appears as a named region in the trace, then wire an `MXMetricManagerSubscriber` that logs the daily metric and diagnostic payloads. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- **Profile on a physical device, in a Release build.** Set the scheme's Run configuration to Release (Product ▸ Scheme ▸ Edit Scheme) before measuring. The Simulator and Debug builds lie about performance — a measurement taken there is worse than none, because it's confidently wrong.
- The `.swift` exercises are written to drop into a SwiftUI app target. Each file's header says how to run it.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, the hang fix uses real structured concurrency — a `@MainActor` violation suppressed with `nonisolated(unsafe)` is a bug, not a fix.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-15` to compare.
