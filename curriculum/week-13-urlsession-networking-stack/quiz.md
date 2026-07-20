# Week 13 — Quiz

Fourteen questions. Take it with your lecture notes closed. Aim for 11/14 before moving to Week 14. Answer key with explanations at the bottom — don't peek.

---

**Q1.** What does `let (data, _) = try await URLSession.shared.data(from: url)` dangerously hide?

- A) Nothing; it's complete.
- B) The response status (a 404 returns `data` too), the chosen session/config, the distinction between error kinds, and all resilience.
- C) Only the timeout.
- D) The URL.

---

**Q2.** Which `URLSessionConfiguration` persists nothing to disk and is ideal for tests and privacy-sensitive flows?

- A) `.default`
- B) `.ephemeral`
- C) `.background(withIdentifier:)`
- D) `.shared`

---

**Q3.** After `let (data, response) = try await session.data(for: request)`, what must you do before decoding `data`?

- A) Nothing; `data` is always valid.
- B) Cast `response` to `HTTPURLResponse` and verify the status code is 2xx — a 404/500 returns a body too, and decoding it as your type throws a confusing error.
- C) Sleep 1 second.
- D) Re-send the request.

---

**Q4.** Why is the networking client built as an `actor`?

- A) Actors are faster.
- B) It holds mutable state (session, token) shared across concurrent callers; an actor serialises access and makes it `Sendable` under Swift 6 without locks.
- C) Only actors can do networking.
- D) `URLSession` requires it.

---

**Q5.** In the typed `Endpoint` protocol, what does `associatedtype Response: Decodable` buy you?

- A) Nothing.
- B) The compiler enforces that `send(ListNotes())` returns `[Note]` and `send(GetNote())` returns `Note` — the response type *is* the contract, impossible to mis-decode.
- C) Faster decoding.
- D) Automatic retries.

---

**Q6.** Your server sends dates as `"2026-06-09T12:00:00Z"`. What `JSONDecoder` setting decodes them?

- A) `dateDecodingStrategy = .secondsSince1970`
- B) `dateDecodingStrategy = .iso8601`
- C) `keyDecodingStrategy = .convertFromSnakeCase`
- D) No setting needed.

---

**Q7.** Why model networking failures as a typed `enum` (offline/cancelled/http/decoding/...) instead of a bare `Error`?

- A) It's prettier.
- B) So the caller can branch on *why* it failed — offline → cache, cancelled → show nothing, 5xx → retry, decoding → "update the app" — which a single `Error` can't express.
- C) Bare `Error` doesn't compile.
- D) It's required by URLSession.

---

**Q8.** Which of these should you **NOT** retry?

- A) A timeout.
- B) An HTTP 503.
- C) An HTTP 400 (bad request) — retrying the same request fails identically; it's a deterministic client error.
- D) A connection reset.

---

**Q9.** Why does retry backoff need *jitter*, not just exponential growth?

- A) Jitter makes retries faster.
- B) Without jitter, many clients that failed at the same instant retry in lockstep — a synchronized wave (thundering herd) that re-overwhelms a recovering server. Jitter spreads retries randomly so the server sees a trickle.
- C) Jitter is decorative.
- D) Exponential backoff alone is illegal.

---

**Q10.** What makes `try await Task.sleep(for: delay)` the right delay primitive in a retry loop?

- A) It's faster than other sleeps.
- B) It's cancellation-aware — if the task is cancelled mid-retry, the sleep throws `CancellationError` and the loop exits instead of firing a stale request.
- C) It never throws.
- D) It blocks the thread.

---

**Q11.** Where should request signing (attaching a bearer token) live?

- A) At every call site, manually.
- B) In a middleware that runs on every outgoing request, in one place, so you can't forget it on a new endpoint and secrets are handled consistently.
- C) In the view.
- D) In the decoder.

---

**Q12.** What is `URLProtocol` used for in this week's tests?

- A) Defining a new URL scheme.
- B) Intercepting requests below the client to return canned responses or errors, so the client is tested unchanged with zero network — deterministic, fast, offline.
- C) Encrypting traffic.
- D) Parsing URLs.

---

**Q13.** In offline-first write-replay, what happens when the user creates a note while offline?

- A) A spinner shows until the network returns.
- B) The write fails and is lost.
- C) The note is applied to SwiftData immediately (UI updates now) and a `PendingMutation` is queued in an outbox for replay on reconnect.
- D) The app crashes.

---

**Q14.** Why must outbox replay be idempotent, and how is that achieved?

- A) It needn't be.
- B) Because the network is unreliable in both directions — a write may be applied by the server but its response lost, so a replay could duplicate it; an **idempotency key** (sent as a header) lets the server dedupe so a re-apply is a no-op.
- C) For speed.
- D) To preserve order.

---

## Answer key

**Q1 — B.** The one-liner hides the response status, the session/config, the error kinds, and all resilience. A real client makes each a deliberate choice. (Lecture 1, §1.)

**Q2 — B.** `.ephemeral` persists nothing — no cache, cookies, or credentials — making it ideal for privacy flows and for deterministic tests that start clean. (Lecture 1, §2.)

**Q3 — B.** Cast to `HTTPURLResponse` and check for a 2xx status before trusting `data`. A 404/500 returns a body that decoding-as-your-type turns into a confusing error. (Lecture 1, §3.)

**Q4 — B.** The client holds mutable shared state (session, token); an actor serialises concurrent access and is `Sendable` under Swift 6 without locks. (Lecture 1, §4.)

**Q5 — B.** The `Response` associated type makes each endpoint's return type a compile-time contract — `send` returns exactly what the endpoint declares, impossible to mis-decode. (Lecture 1, §4.)

**Q6 — B.** `.iso8601` matches the ISO-8601 string. A mismatch here (e.g. expecting a number) is the most common decode bug. (Lecture 1, §5.)

**Q7 — B.** A typed error lets the caller branch on the *kind* of failure (cache / nothing / retry / report) — the thing a bare `Error` cannot express and the thing resilience depends on. (Lecture 1, §6.)

**Q8 — C.** A 400 is a deterministic client error; retrying the identical request fails identically. Timeouts, 503, and connection resets are transient and retryable. (Lecture 2, §1.)

**Q9 — B.** Without jitter, synchronized retries form a thundering herd that re-overwhelms a recovering server. Full jitter randomises the delay so retries trickle in. (Lecture 2, §2.)

**Q10 — B.** `Task.sleep` is cancellation-aware — it throws `CancellationError` when the task is cancelled, so a cancelled retry loop stops cleanly instead of firing a stale request. (Lecture 2, §2.)

**Q11 — B.** Signing lives in middleware, once, on every request — you can't forget it on a new endpoint, and secrets are handled (and redacted) consistently. (Lecture 2, §3.)

**Q12 — B.** `URLProtocol` intercepts requests below the client and returns canned responses/errors, so the client is tested unchanged with zero network — deterministic and fast. (Lecture 1, §7.)

**Q13 — C.** Offline-first: the write applies to SwiftData immediately (instant UI) and queues a `PendingMutation` for replay on reconnect. No spinner, no lost draft. (Lecture 2, §5.)

**Q14 — B.** A response can be lost after the server applies a write, so a replay could duplicate it; an idempotency key sent as a header lets the server dedupe, making a re-apply a no-op. (Lecture 2, §5.)

---

*Score 11+? On to Week 14. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — hermetic `URLProtocol` testing (so you can prove the client's behaviour) and retry-with-jitter (so retries don't form a herd) are the two ideas this week is graded on, and the offline-first write-replay in the challenge is the named skill.*
