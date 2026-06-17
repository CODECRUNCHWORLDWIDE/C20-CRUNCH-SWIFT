# Week 5 — Challenges

The exercises drill the individual pieces — a model, a middleware, a logger. **Challenges stretch you across the whole surface.** This one takes 90–150 minutes and produces something you will be proud to point a reviewer at: a service that fails the way a *real* API fails, with a consistent, machine-readable error contract and tests that prove every failure path.

## Index

1. **[Challenge 1 — RFC 9457 problem-JSON errors across every notes endpoint](./challenge-01-problem-json-error-handling.md)** — replace Vapor's default `{"error": true, "reason": "..."}` error shape with a consistent `application/problem+json` body (RFC 9457), add request validation, and write `VaporTesting` tests that prove each failure path returns the right status code *and* the right body. (~120 min)

Challenges are optional for passing the week. If you skip this one you can still ship the mini-project. But the error contract you build here is exactly what the mini-project's grading rubric rewards, and it is the difference between an API a client engineer enjoys consuming and one they curse. The SwiftUI client you build in Phase III will decode these problem bodies into typed Swift errors — so the cleaner the contract is now, the less the client fights it later.

If you do the challenge before the mini-project, you can fold the result straight in. That is the intended path.
