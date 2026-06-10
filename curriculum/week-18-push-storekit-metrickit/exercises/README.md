# Week 18 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Register for and receive a real push](exercise-01-register-and-receive-a-push.md)** — request authorization, get a device token, and send yourself a real APNs push from the command line with a JWT signed from your `.p8` auth key. The push pipeline, proven end to end on a device. (~45 min)
2. **[Exercise 2 — The StoreKit 2 purchase flow](exercise-02-storekit-purchase-flow.swift)** — fetch a product from a `.storekit` config, run `product.purchase()`, verify the `VerificationResult`, `finish()`, observe entitlements, and gate a feature — with tests that prove the gate flips and an unverified transaction is rejected. (~50 min)
3. **[Exercise 3 — A MetricKit collector](exercise-03-metrickit-collector.swift)** — build an `MXMetricManagerSubscriber`, receive metric and diagnostic payloads, serialize them, and ship them to a backend endpoint (mocked in the test). (~40 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills — and for pipeline code, the muscle memory of "check the VerificationResult, call finish(), match the push-type to the payload" is exactly what stops the bug.
- Run it. Exercise 1 needs a **physical device** and your **Apple Developer membership** (push registration doesn't fully work in the Simulator). Exercise 2 runs in the **Simulator** against a `.storekit` configuration file — the fast iteration path before a device sandbox purchase. Exercise 3's collector wiring builds anywhere; real payloads only arrive on a device on a ~24h cadence, so the test drives a synthetic payload.
- The `.swift` exercises are written as Swift Testing suites (`import Testing`, `@Test`, `#expect`) where they can be, with the device-only parts clearly marked.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — StoreKit's async API and the `@MainActor` `Store` are designed to satisfy the compiler if you isolate correctly.

## A pipeline-specific working rule

For every pipeline you touch this week, **prove the failure path, not just the success.** Exercise 1 isn't done when a push arrives — it's done when you've *also* sent to a stale token and seen nothing arrive. Exercise 2 isn't done when a purchase unlocks — it's done when you've *also* forced a refund in the transaction manager and watched the gate flip back. A pipeline you've only seen succeed is a pipeline you haven't tested. This is the README's "prove the pipeline, not the demo" promise, applied per exercise.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-18` to compare.
