# Week 10 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 60–120 minutes and produces something you can commit to your portfolio and point at in an interview: a measured before/after performance fix.

## Index

1. **[Challenge 1 — Plant a footgun, then refactor it](./challenge-01-footgun-then-refactor.md)** — deliberately write the "fetch everything, filter in memory" footgun in your notes app, measure it with `OSSignposter` and `ContinuousClock` on a large seeded store, refactor it into a `#Predicate`-driven (and optionally `#Index`-backed) query, and document the before/after timing with an Instruments trace. (~90 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — and "I made a SwiftData fetch 80× faster and here's the flame graph" is the kind of concrete, quantified win that lands in code reviews and interviews. The performance instinct you build here reappears in Phase III's Instruments-tuning week.
