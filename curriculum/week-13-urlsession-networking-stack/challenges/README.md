# Week 13 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 90–150 minutes and produces something you can commit to your portfolio and point at in an interview: an offline-first write-replay outbox that survives a network drop, proven with a deterministic test.

## Index

1. **[Challenge 1 — Offline-first write-replay](challenge-01-offline-write-replay.md)** — build the outbox pattern: apply writes locally to SwiftData (instant UI), queue them as `PendingMutation`s while offline, and replay them **in order** and **idempotently** when connectivity returns. Prove it with a `URLProtocol` stub that simulates going offline, accumulating writes, then coming back — and assert nothing is lost, nothing is duplicated, and the order is preserved. (~120 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — and "I built an offline-first write-replay queue with idempotency and proved it survives a network drop" is exactly the concrete, senior-level artifact that lands in a production-iOS interview where "how do you handle offline?" is the real question. The offline-first instinct you build here is the week's named skill, and it is the foundation Week 14's multi-device CloudKit conflict resolution builds on.
