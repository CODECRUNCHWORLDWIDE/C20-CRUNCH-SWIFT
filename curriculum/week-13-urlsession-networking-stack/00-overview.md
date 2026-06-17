# Week 13 — URLSession and the networking stack

Welcome to Week 13 of **C20 · Crunch Swift**, the opening week of Phase III — Production iOS. For twelve weeks you built an app that ran entirely on the device: SwiftUI, state, navigation, SwiftData, architecture, reactive search. This week the app reaches the network, and everything gets harder, because the network is the most hostile dependency in any client. It is slow, it fails, it times out, it returns the wrong shape, it succeeds-but-empty, it works on Wi-Fi and dies on cellular, and it is *unavailable the moment the user walks into an elevator.* A networking layer that only handles the happy path is not a networking layer; it is a demo. This week you build the grown-up version.

The arc is "from one line to a real client." You start at `let (data, _) = try await URLSession.shared.data(from: url)` — the one-liner everyone knows — and by Friday you have a **typed, retryable, cancellable, instrumented `NotesClient` actor**: it speaks `Codable` over a typed endpoint description, surfaces structured errors instead of a bare `Error`, retries transient failures with exponential backoff and jitter, signs and logs every request through middleware, detects offline conditions, and falls back to the SwiftData store you built in Week 10 — replaying queued writes when the network returns. That last part, **offline-first write-replay**, is the senior move and the week's named skill: the app stays fully usable with no connection, and when connectivity returns it reconciles automatically.

This is also where the whole track's two halves meet. The Vapor `notes-api` you built on Linux in Phase I — `POST /notes`, `GET /notes`, `PATCH /notes/:id` — becomes the server your iOS client talks to, using the *shared `Codable` types* from Week 6. The move you made in Week 6 ("a single `struct Note: Codable, Sendable` lives in a shared package imported by both the server and the client") pays off this week: the client decodes exactly what the server encodes, type-checked, with no drift. If you ever doubted why we built a Vapor service and shared models before touching SwiftUI, this is the week the architecture closes the loop.

The networking surface is deep, and we cover the parts a production client actually needs: `URLSession` configuration (default vs ephemeral vs background), the modern `async` URLSession APIs (and the `URLSession.bytes` streaming API that connects to last week's `AsyncSequence`), `Codable` decoding strategies and their failure modes, `URLProtocol` for hermetic tests that never touch the network, retry policy with backoff *and jitter* (and why jitter matters when ten thousand clients retry at once), request signing, and request/response logging middleware. By the end you can architect a networking layer the senior engineer in the room defers to — typed, resilient, testable, and offline-first.

## Learning objectives

By the end of this week, you will be able to:

- **Configure** a `URLSession` deliberately — `default`, `ephemeral`, and `background` configurations, timeouts, `waitsForConnectivity`, cache policy, and per-host concurrency — and explain which configuration fits which job.
- **Build** a typed networking client over the modern `async` URLSession APIs — `data(for:)`, `upload(for:from:)`, `download(for:)`, and `bytes(for:)` — that takes a typed `Endpoint` description and returns a decoded `Codable` value or a structured error.
- **Model** a networking error space as a typed `enum` (transport vs HTTP-status vs decoding vs offline) instead of a bare `Error`, so callers can branch on *why* a request failed.
- **Decode** robustly with `JSONDecoder` strategies (`keyDecodingStrategy`, `dateDecodingStrategy`), handle the failure modes (missing keys, wrong types, null), and produce actionable decode errors.
- **Retry** transient failures with **exponential backoff and full jitter**, bounded by an attempt cap and respecting cancellation, and explain why jitter prevents the thundering-herd retry storm.
- **Test** the client hermetically with a `URLProtocol` stub that returns canned responses, so the test suite never hits a real server and is fast, deterministic, and offline.
- **Instrument** the client with request/response logging middleware and `OSLog`, and **sign** outbound requests (a bearer token or an HMAC header) through the same middleware seam.
- **Architect** offline-first write-replay: detect unreachability, fall back to SwiftData, queue mutations in an outbox, and replay them in order when connectivity returns — so the app is fully usable offline and reconciles on reconnect.

## Prerequisites

This week assumes you have completed **C20 weeks 1–12**, or have equivalent fluency. Specifically:

- You are fluent in `async`/`await`, `Task`, structured concurrency, **cancellation**, and actors — Weeks 3–4. The client is an `actor`; retries are `async` loops with `Task.sleep`; a cancelled request must not race a stale response onto the screen. If cancellation isn't second nature, re-read Week 3.
- You understand `AsyncSequence` and the reactive matrix — Week 12. `URLSession.bytes(for:)` returns an `AsyncSequence` of bytes/lines; the streaming-download and server-sent-events paths build directly on last week.
- You can model with `Codable`, generics, protocols, and typed `Result`/error enums — Weeks 1–2. The `Endpoint` abstraction is generic over its `Response: Decodable`; the error space is a typed enum.
- You have the Vapor `notes-api` and the shared `NotesCore` `Codable` models from Phase I (Weeks 5–6). This week's client talks to *that* server using *those* types. If your Phase I service isn't running, the resources page has a `docker compose up` refresher.
- You have "Notes v1" from Week 12 — the SwiftData-backed, navigable, architected app. This week wires it to the network and adds the offline-first layer.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. The Vapor backend runs locally (Linux container or macOS). Everything client-side runs in the Simulator — no device, no Apple Developer membership yet (that arrives in Week 15). `mitmproxy` is recommended (free) for inspecting traffic; Charles is not required.

## Topics covered

- **`URLSession` configuration.** `URLSessionConfiguration.default` / `.ephemeral` / `.background(withIdentifier:)`, `timeoutIntervalForRequest`/`ForResource`, `waitsForConnectivity`, `allowsCellularAccess`, `httpAdditionalHeaders`, cache policy, and per-host connection limits.
- **The async URLSession APIs.** `data(for:)`, `upload(for:from:)`, `download(for:)`, `bytes(for:)`, the `(Data, URLResponse)` tuple, casting to `HTTPURLResponse` and reading the status code, and how cancellation propagates into an in-flight request.
- **`URLSession.bytes` and streaming.** The `AsyncBytes`/`.lines` sequence (Week 12 bridge), streaming a large download, and reading a server-sent-events / NDJSON stream line by line.
- **A typed `Endpoint` abstraction.** A generic request description (`path`, `method`, `body`, `Response: Decodable`), building a `URLRequest` from it, and a `send<E: Endpoint>(_:) async throws -> E.Response` client method.
- **Typed errors.** A `NetworkError` enum (`.transport`, `.http(status:)`, `.decoding`, `.offline`, `.cancelled`, `.server(message:)`), mapping `URLError` codes into it, and why callers need to branch on the *kind* of failure.
- **`Codable` decoding strategies.** `keyDecodingStrategy` (`.convertFromSnakeCase`), `dateDecodingStrategy` (`.iso8601`, custom), handling optionals/nulls/missing keys, and turning a `DecodingError` into an actionable message.
- **Retry with backoff and jitter.** Which errors are retryable (transient transport, 5xx, 429-with-Retry-After) and which are not (4xx client errors), exponential backoff (`base * 2^attempt`), **full jitter**, the attempt cap, and the thundering-herd problem jitter solves.
- **Request signing.** Attaching a bearer token or an HMAC signature header, where signing belongs in the pipeline (middleware, once), and why you don't scatter `request.setValue` calls through call sites.
- **Middleware / logging.** A request/response logging interceptor over `OSLog`, redacting secrets, and a composable middleware seam that signing, logging, and auth-refresh all plug into.
- **`URLProtocol` for hermetic tests.** Registering a stub `URLProtocol` that intercepts requests and returns canned `(Data, HTTPURLResponse)` or errors, so tests are fast, deterministic, and never touch the network.
- **Offline-first write-replay.** Reachability/offline detection, SwiftData fallback for reads, an outbox queue for writes, ordered replay on reconnect, and idempotency so a replayed write isn't applied twice.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                                  | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | `URLSession` config; async APIs; the typed `Endpoint`; `Codable` decode |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Typed errors; decoding strategies/failures; `URLProtocol` testing       |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Retry with backoff + jitter; signing; logging middleware; challenge     |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Offline-first write-replay; reachability; the outbox; mini-project kick |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — wire Notes v1 to the Vapor api; NotesClient actor        |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; offline fallback + write-replay; reconnect test |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                            |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                        | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's URLSession and Codable docs, the WWDC networking sessions, the Vapor refresher, and the canonical community writing on retries, errors, and offline-first |
| [lecture-notes/01-from-one-line-to-a-typed-client.md](./02-lecture-notes/01-from-one-line-to-a-typed-client.md) | From `URLSession.shared.data` to a typed `Endpoint`-driven actor client: configuration, async APIs, `Codable` decoding strategies, typed errors, and `URLProtocol` hermetic testing |
| [lecture-notes/02-resilience-retries-signing-and-offline-first.md](./02-lecture-notes/02-resilience-retries-signing-and-offline-first.md) | The resilient client: retry with exponential backoff and jitter, request signing and logging middleware, offline detection, and the offline-first write-replay/outbox pattern against SwiftData |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-typed-endpoint-client.md](./03-exercises/exercise-01-typed-endpoint-client.md) | Build a generic `Endpoint` and a `send` method, decode a real `Codable` response, and map failures into a typed `NetworkError` |
| [exercises/exercise-02-urlprotocol-stub-tests.swift](./03-exercises/exercise-02-urlprotocol-stub-tests.swift) | Write a stub `URLProtocol` and test the client hermetically — success, an HTTP 500, a decode failure, and an offline error — with zero network |
| [exercises/exercise-03-retry-backoff-jitter.swift](./03-exercises/exercise-03-retry-backoff-jitter.swift) | Implement retry-with-exponential-backoff-and-jitter, prove it retries the right errors, stops at the cap, respects cancellation, and that jitter spreads the delays |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-offline-write-replay.md](./04-challenges/challenge-01-offline-write-replay.md) | Build an offline-first write-replay outbox: queue mutations while offline, replay them in order on reconnect, make replay idempotent, and prove it with a simulated network drop |
| [quiz.md](./05-quiz.md) | 14 questions on configuration, async APIs, typed errors, decoding, retries/jitter, signing, `URLProtocol`, and offline-first |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for wiring "Notes v1" to the Vapor `notes-api` with a `NotesClient` actor — structured errors, retries, offline detection, and SwiftData write-replay |

## The "survives the network failing" promise

Each Phase has its reviewer-checked promise. Phase III opens with the one that separates a demo from a product:

> **The app stays usable when the network fails, and reconciles when it returns.** Pull the network out from under the app mid-use — airplane mode, a killed server, a dropped connection — and it does not hang, does not crash, does not lose the user's write. It reads from the local SwiftData cache, queues the write in an outbox, tells the user honestly, and when connectivity returns it replays the queued writes in order, exactly once. A networking layer that can't survive the network failing is not done.

"It works on my Wi-Fi" is not the test. Turn the network off. Kill the server. The app must degrade gracefully and recover automatically, and the skill this week earns is building exactly that.

## A note on what's not here

Week 13 is the *networking layer* week. It deliberately does **not** cover:

- **Security depth.** ATS configuration, certificate pinning (the URLSession delegate path), and request signing with Secure Enclave keys are Week 17. This week we attach a bearer token / HMAC header through the middleware seam and flag that *pinning* plugs into the same delegate point — but the cryptography is Phase III's security week.
- **CloudKit sync.** SwiftData + CloudKit, conflict resolution, and multi-device sync are Week 14. This week's "sync" is a single-client outbox replaying against one Vapor backend — deliberately simpler than CloudKit's multi-device conflict story.
- **Performance profiling.** Instruments, hangs, and hitches are Week 15. We *log* timings with `OSLog` this week; profiling a slow request with the Network instrument is next phase.
- **Push.** APNs and silent pushes that trigger a sync are Week 18.

The point of Week 13 is narrow and deep: one typed, resilient, testable client, and the offline-first write-replay that keeps the app alive when the network isn't.

## Up next

Continue to **Week 14 — Persistence II: Files, Keychain, SwiftData + CloudKit** once you have shipped this week's mini-project and proven the offline write-replay. Week 14 takes the networking client you built and asks the harder persistence questions around it: where does the auth token live (Keychain, not `UserDefaults`), how do you sync across *multiple devices* (CloudKit, with real conflict resolution — a step up from this week's single-client outbox), and how do you store each byte safely. The bearer token you attach this week becomes a Keychain-stored credential next week; the single-client write-replay becomes multi-device conflict resolution. Earn the resilient single-client networking layer this week — Week 14 makes it multi-device and secure.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
