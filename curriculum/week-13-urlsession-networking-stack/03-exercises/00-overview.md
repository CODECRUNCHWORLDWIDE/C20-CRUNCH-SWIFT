# Week 13 — Exercises

Short, focused drills. Each one should take 30–55 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A typed `Endpoint` client](./exercise-01-typed-endpoint-client.md)** — build the generic `Endpoint` protocol and a `send<E: Endpoint>` method on an actor client, describe two real endpoints, decode a `Codable` response with the right strategies, and map failures into a typed `NetworkError`. The read path in one exercise. (~50 min)
2. **[Exercise 2 — Hermetic tests with `URLProtocol`](./exercise-02-urlprotocol-stub-tests.swift)** — write a stub `URLProtocol`, route a session through it, and test the client with zero network: a 200 success, an HTTP 500, a decode failure, and an offline error. (~50 min)
3. **[Exercise 3 — Retry with backoff and jitter](./exercise-03-retry-backoff-jitter.swift)** — implement a retry loop with exponential backoff and full jitter, prove it retries the right errors, stops at the cap, respects cancellation, and that jitter actually spreads the delays. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- URLSession and the concurrency runtime ship with the SDK — **no package needed**. The exercises run against a *stubbed* session (`URLProtocol`), so you need no live server for them — the live Vapor backend is for the mini-project.
- The `.swift` exercises are written to drop into a Swift Testing target. Each file's header says exactly how. Run with **Cmd-U**.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, the client is an `actor` and the response types are `Sendable`; a `Sendable` warning is a bug this week and the compiler is right.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-13` to compare.
