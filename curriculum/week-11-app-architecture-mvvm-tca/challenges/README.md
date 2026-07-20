# Week 11 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 90–150 minutes and produces something you can commit to your portfolio and point at in an interview: the same feature built three ways, measured, with the ADR that picks one.

## Index

1. **[Challenge 1 — The same feature, three ways](challenge-01-same-feature-three-ways.md)** — implement one feature (a filterable, loadable list) as plain SwiftUI + `@Observable`, as MVVM with an injected dependency, and as a TCA reducer with a `TestStore`. Measure the line count, the test coverage, and the cost of one realistic change in each. Then write the ADR that decides which you would ship for two different contexts (a throwaway prototype and a six-engineer, money-touching app) — and explain why the answer differs. (~120 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — and "here are the same feature in three architectures with the numbers and the ADR" is exactly the kind of concrete, defensible artifact that lands in senior interviews where "what architecture do you like?" is the real question. The judgment you build here is what Week 12's integration project and the entire rest of the track assume.
