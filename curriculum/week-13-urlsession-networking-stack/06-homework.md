# Week 13 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 13 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. URLSession ships with the SDK; the exercises run against a stubbed session, so no live server is needed except where stated. Every problem must build with **0 warnings**.

---

## Problem 1 — Map every `URLError` to the right typed case

**Problem statement.** Write a `NetworkError` enum and an `init(_ urlError: URLError)` that maps at least six `URLError.Code` values to the right cases: `.notConnectedToInternet`/`.dataNotAllowed` → `.offline`, `.cancelled` → `.cancelled`, `.timedOut` → `.timedOut`, `.cannotFindHost`/`.cannotConnectToHost` → `.transport`, and a default `.transport`. Write tests asserting each mapping.

**Acceptance criteria.**

- `NetworkError` with the cases above and the `URLError` initialiser.
- At least six tests, each constructing a `URLError(code:)` and asserting the mapped case.
- 0 warnings. Committed.

**Hint.** `URLError(.timedOut)` constructs a `URLError` with that code. Switch on `urlError.code` in the initialiser. Make `NetworkError: Equatable` so the test can assert the specific case.

**Estimated time.** 35 minutes.

---

## Problem 2 — Decode three failure modes into actionable errors

**Problem statement.** Given a model `struct User: Codable { let id: Int; let name: String; let email: String? }`, write a decode function that, on failure, returns a *specific* message for each `DecodingError` case: a missing required key (`keyNotFound`), a wrong type (`typeMismatch`), and a null-where-required (`valueNotFound`). Test each by feeding malformed JSON.

**Acceptance criteria.**

- A decode function that catches `DecodingError.keyNotFound`, `.typeMismatch`, and `.valueNotFound` and produces a distinct, actionable message for each.
- Three tests, each with JSON that triggers one case (e.g. `{}` for missing `id`; `{"id":"x",...}` for type mismatch; `{"id":null,...}` for value-not-found).
- 0 warnings. Committed.

**Hint.** `email` is optional, so omitting it must *not* error — that proves optionality tolerates drift. Make `id`/`name` non-optional so omitting them throws `keyNotFound`. Catch the specific `DecodingError` cases with pattern matching.

**Estimated time.** 45 minutes.

---

## Problem 3 — A `URLProtocol` stub that asserts the request

**Problem statement.** Extend the stub `URLProtocol` so its handler can *inspect* the outgoing request, and write a test proving your client sends the right method, path, and JSON body for a `POST /notes`. The stub records the request; the test asserts on it.

**Acceptance criteria.**

- A stub whose handler receives the `URLRequest` and a test that asserts `httpMethod == "POST"`, the path is `/notes`, and the decoded body matches the draft sent.
- 0 warnings. Committed.

**Hint.** The request's body may arrive via `httpBodyStream` rather than `httpBody` when set through URLSession — read it from the stream in the handler, or capture the body before the request is sent. Decode the captured body and assert its fields.

**Estimated time.** 45 minutes.

---

## Problem 4 — Honour `Retry-After`

**Problem statement.** Extend your retry loop so that on an HTTP 429 with a `Retry-After: <seconds>` header, it waits *that* duration instead of its computed backoff. Use a `URLProtocol` stub that returns 429 with `Retry-After: 2` once, then 200. Assert the loop waited ~2s (use an injected sleep that records the requested durations rather than really sleeping).

**Acceptance criteria.**

- The retry loop reads `Retry-After` from the 429 response and uses it as the delay.
- A test (with an injected, recording sleep) asserting the delay used after the 429 was the header's value, and the second attempt succeeded.
- 0 warnings. Committed.

**Hint.** Thread the response headers into the retry decision (the loop needs to see the `HTTPURLResponse`, so carry it on the error or restructure `send` to return it). Inject `sleep: { duration in recorded.append(duration) }` so you assert the requested delay without waiting.

**Estimated time.** 50 minutes.

---

## Problem 5 — A signing + logging middleware chain

**Problem statement.** Implement a `RequestMiddleware` protocol and two conformers — `AuthMiddleware` (attaches `Authorization: Bearer <token>`) and `LoggingMiddleware` (logs method/path/status to `OSLog`, **redacting** the auth header). Run them as a chain in your client and write a test proving the auth header is present on the sent request and that the logged output does **not** contain the token.

**Acceptance criteria.**

- A `RequestMiddleware` protocol with `prepare` and `didReceive`; the two conformers; the client runs them in order.
- A test asserting the sent request carries the bearer header (via a recording stub).
- A demonstration (test or note) that the logged output redacts the token (e.g. log the *header name* count, never the value).
- 0 warnings. Committed.

**Hint.** Capture the prepared request in the stub to assert the header. For redaction, the `LoggingMiddleware` simply never reads or prints `request.value(forHTTPHeaderField: "Authorization")` — log the path and status only. Assert the absence by checking your log sink string doesn't contain the token.

**Estimated time.** 45 minutes.

---

## Problem 6 — A minimal outbox that survives an app kill

**Problem statement.** Build a minimal `PendingMutation` `@Model` and a `drainOutbox()` that replays queued mutations in `createdAt` order against a stubbed client. Seed two mutations into a SwiftData store, "relaunch" (open a fresh `ModelContext` on the same store), and assert the outbox is still there and drains in order. This proves the outbox is durable across a process restart.

**Acceptance criteria.**

- A `PendingMutation` `@Model` with an idempotency `id`, `kind`, `createdAt`, and a `drainOutbox()` that replays sorted by `createdAt`.
- A test that seeds two mutations, reopens the store with a fresh context (simulating relaunch), and asserts both survive and replay in order against a recording stub.
- 0 warnings. Committed.

**Hint.** Use an on-disk SwiftData store at a temp URL (like Week 10 exercise 3) so "reopen with a fresh context" actually exercises persistence. An in-memory store wouldn't survive the reopen — that contrast is the lesson. The recording stub records the order of replayed requests.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/URLSession, and the networking decisions (error mapping, retry policy, redaction) are correct and defensible. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a discarded `URLResponse`, a slightly loose error mapping, an unnecessary `URLSession.shared`). |
| 3 | Works, but misses one criterion (e.g. retries a non-retryable error, logs a token, an outbox that doesn't preserve order). |
| 2 | Compiles and partially works; a core idea is wrong (no status check before decode, a `try!` decode, retries with no jitter or no cap). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)` outside a test stub) used to silence the compiler instead of restructuring; **−2** for logging a secret (token/password) or a `try!` decode that turns server drift into a crash; **−1** for a discarded response status or retrying a non-retryable error.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — typed errors branched-on with hermetic `URLProtocol` tests (problems 1, 2, 3) and resilient retries / offline durability (problems 4, 6) — so re-run exercises 02 and 03 before resubmitting.
