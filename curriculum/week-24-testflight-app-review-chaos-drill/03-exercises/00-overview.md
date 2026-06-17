# Week 24 — Exercises

Short, focused drills that feed the final week's ship-and-survive work. Each one should take 30–60 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — The App Review readiness audit](./exercise-01-app-review-readiness-audit.md)** — audit the capstone against the actually-enforced App Review guidelines before you submit, and write the demo-account-laden review notes that land you on the first try. The five-minute checks that prevent a multi-day rejection. (~45 min)
2. **[Exercise 2 — The offline-conflict chaos drill](./exercise-02-offline-conflict-chaos-drill.swift)** — model the offline-edit-conflict drill as a Swift Testing suite: two devices edit the same note offline, reconnect, and the test asserts convergence and zero loss for non-overlapping edits. The repeatable proof behind the live drill. (~50 min)
3. **[Exercise 3 — The subscription edge cases](./exercise-03-subscription-edge-cases.swift)** — model the StoreKit subscription transitions (refund, downgrade, billing retry) and assert that the *server's* entitlement is authoritative and the client follows it within the five-minute bar. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Exercise 1 is a written audit you commit to your capstone repo and use to gate your submission.
- The `.swift` exercises are **Swift Testing** suites (the `import Testing` / `@Test` / `#expect` style shipped with Xcode 16). Drop each into a test target. They model the drill's *logic* deterministically so the live drill against real devices/backends is a confirmation, not a discovery. Each file's header says exactly how.
- If you get stuck for more than 15 minutes, peek at the inline hints at the bottom of each file.
- Every `.swift` exercise must **build with 0 warnings** under Swift 6 strict concurrency.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-24` to compare.

## A note on "drill in a test" vs "drill live"

Exercises 2 and 3 model the chaos drills as deterministic tests. That is deliberate: a test pins the *logic* (the conflict resolver converges; the entitlement follows the server) so you can prove it repeatably, in CI, without flakiness. The *live* drill — the one your capstone postmortem documents — runs the same scenario against real simulators, a real CloudKit account, and your live Vapor backend, where you measure real timings under real latency. Run both. The test proves the logic is correct; the live drill proves the *system* behaves, with the messy real-world timings the postmortem reports. The capstone requires the live drill (and its postmortem); these exercises are how you make sure the logic is right before you drive the live version.
