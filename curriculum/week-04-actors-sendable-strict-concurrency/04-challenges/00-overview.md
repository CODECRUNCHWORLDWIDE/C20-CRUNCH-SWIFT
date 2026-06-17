# Week 4 — Challenges

The exercises drill the mechanics. **Challenges stretch you.** This one takes 90–150 minutes and produces something you can commit to your portfolio.

## Index

1. **[Challenge 1 — Remove the escape hatch](./challenge-01-remove-the-escape-hatch.md)** — take a module that compiles under Swift 6 *only* because of a single `@unchecked Sendable`, and rework the data model so the escape hatch can be deleted while strict concurrency stays on. (~120 min)

Challenges are optional. If you skip them, you can still pass the week. If you do them, you'll be measurably ahead — and "I removed an `@unchecked Sendable` by changing the data model instead of the annotation" is the exact sentence that lands a senior iOS offer in 2026. The pattern reappears in Week 13 (the `NotesClient` actor) and Week 14 (Keychain + CloudKit sync state), where every shared piece of state must cross an isolation boundary cleanly.
