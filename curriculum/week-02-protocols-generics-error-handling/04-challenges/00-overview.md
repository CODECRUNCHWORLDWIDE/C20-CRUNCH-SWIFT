# Week 2 — Challenges

The exercises drill basics. **Challenges stretch you.** Each one takes 90–150 minutes and produces something you can commit to your portfolio.

## Index

1. **[Challenge 1 — Pluggable eviction policy via a protocol](./challenge-01-pluggable-eviction-policy.md)** — extend the cache with a swappable `EvictionPolicy` (LRU vs TTL) behind a protocol, so the policy changes without touching the cache's public generic API. Prove the behaviour with property tests. (~120 min)

This challenge compounds directly on the [mini-project](../07-mini-project/00-overview.md): you build the `Cache<Key, Value>` there first, then graft a pluggable eviction policy onto it here. Do the mini-project first, or at least the in-memory store, before you start.

Challenges are optional. If you skip them, you can still pass the week. If you do them, you will be measurably ahead — and the "policy behind a protocol so the host doesn't change" pattern reappears throughout the track: the networking retry policy (Week 13), the conflict-resolution policy (Week 14), and the dependency-injection design (Week 11).
