# Lecture 2 — Resilience: retries, signing, logging, and offline-first

Lecture 1 built the typed, testable *read* path — `Endpoint`, the actor client, `Codable` strategies, typed errors, `URLProtocol` tests. This lecture makes the client *resilient*: it retries transient failures with backoff and jitter, signs and logs every request through a middleware seam, detects when it is offline, and — the week's named skill — falls back to SwiftData and **replays queued writes when the network returns.** This is the difference between a client that works on your Wi-Fi and one that survives an elevator, a flaky cell tower, and a server restart. Bring the typed `NetworkError` from lecture 1; the retry logic branches on it.

---

## 1. Which failures to retry — and which never to

Retrying is not "try again on any error." Retrying the wrong error is at best wasted work and at worst a correctness bug (re-POSTing a payment). The rule comes straight from the typed error space (lecture 1, §6):

| Failure | Retry? | Why |
|---------|--------|-----|
| `.offline` | **No** (queue instead) | The network is gone; immediate retry fails too. Queue it (§5) and replay on reconnect. |
| `.cancelled` | **No** | The user moved on. Retrying is wrong. |
| `.timedOut` | **Yes** | Often transient (a slow hop); a retry may succeed. |
| `.transport` (connection reset, DNS blip) | **Yes** | Transient network failures resolve on retry. |
| `.http(5xx)` | **Yes** | Server-side transient error; retry, ideally after a delay. |
| `.http(429)` | **Yes, after `Retry-After`** | Rate-limited; respect the server's requested delay. |
| `.http(4xx)` except 429 | **No** | A client error (bad request, unauthorized, not found). Retrying the *same* request fails identically. |
| `.decoding` | **No** | The contract drifted; the response will be the same shape next time. Report it. |

The principle: **retry only failures that might succeed on a second identical attempt.** A `5xx` or a connection reset might; a `400 Bad Request` or a decode mismatch will not — they are deterministic given the request. A retry policy that blindly retries everything turns a permanent `400` into a slow `400` and hammers the server for nothing. Encode the "is this retryable?" decision once:

```swift
extension NetworkError {
    var isRetryable: Bool {
        switch self {
        case .timedOut, .transport:           return true
        case .http(let status, _):            return status == 429 || (500...599).contains(status)
        case .offline, .cancelled, .decoding, .server: return false
        }
    }
}
```

---

## 2. Exponential backoff and full jitter

When you do retry, *how long do you wait*? Not "immediately" (you'll hammer a struggling server) and not "a fixed second" (ten thousand clients retrying in lockstep is a self-inflicted DDoS). The answer is **exponential backoff with full jitter.**

- **Exponential backoff:** the delay grows with each attempt — `base * 2^attempt`. Attempt 0 waits ~0.5s, attempt 1 ~1s, attempt 2 ~2s, attempt 3 ~4s. This gives a struggling server progressively more breathing room instead of a constant barrage.
- **Jitter:** randomise the delay so retries *spread out* instead of synchronising. This is the part people skip and the part that matters most at scale.

Why jitter is not optional — the **thundering herd**: imagine a server hiccups and ten thousand clients all get a `503` at the same instant. With pure exponential backoff, *all ten thousand* wait exactly 1 second, then retry *at the same instant*, re-overwhelming the just-recovering server, get another `503`, all wait exactly 2 seconds, retry in lockstep again... The synchronised retries are a wave that keeps knocking the server back down. **Full jitter** breaks the synchronisation: each client waits a *random* duration between 0 and the backoff ceiling, so the ten thousand retries smear across the window instead of landing together. The server sees a manageable trickle, recovers, and the herd disperses. This is the canonical AWS result (resources): *full jitter dramatically reduces total work and time-to-recovery versus no jitter.*

```swift
import Foundation

struct RetryPolicy {
    var maxAttempts = 4
    var baseDelay: Duration = .milliseconds(500)
    var maxDelay: Duration = .seconds(8)

    /// Full jitter: a random delay in [0, min(maxDelay, base * 2^attempt)].
    func delay(forAttempt attempt: Int) -> Duration {
        let exponential = baseDelay * (1 << attempt)          // base * 2^attempt
        let capped = min(exponential, maxDelay)
        // Random point between zero and the capped ceiling.
        let cappedSeconds = Double(capped.components.seconds)
            + Double(capped.components.attoseconds) / 1e18
        let jittered = Double.random(in: 0...cappedSeconds)
        return .seconds(jittered)
    }
}
```

The retry loop wraps the `send` from lecture 1, respects cancellation, and honours `Retry-After` for 429s:

```swift
extension NotesClient {
    func sendWithRetry<E: Endpoint>(_ endpoint: E, policy: RetryPolicy = RetryPolicy()) async throws -> E.Response {
        var attempt = 0
        while true {
            do {
                return try await send(endpoint)
            } catch let error as NetworkError {
                attempt += 1
                // Stop if not retryable or we've hit the cap.
                guard error.isRetryable, attempt < policy.maxAttempts else { throw error }
                let delay = retryAfterDelay(for: error) ?? policy.delay(forAttempt: attempt - 1)
                log.info("retry \(attempt)/\(policy.maxAttempts) after \(delay) for \(E.self)")
                try await Task.sleep(for: delay)   // throws CancellationError if the task is cancelled
            }
        }
    }

    /// Honour a server's Retry-After header on a 429.
    private func retryAfterDelay(for error: NetworkError) -> Duration? {
        // In a fuller implementation you'd thread the response headers through;
        // here we model the hook. For a 429 with `Retry-After: 3`, return .seconds(3).
        nil
    }
}
```

Three correctness details:

- **`try await Task.sleep(for:)` is cancellation-aware.** If the user navigates away mid-retry, the sleep throws `CancellationError`, the loop exits, and you don't fire a stale request. This is the Week 3 cancellation discipline making the retry loop well-behaved.
- **The attempt cap is mandatory.** Without `maxAttempts`, a permanently-down server gives you an infinite retry loop. Four attempts over ~8 seconds is a reasonable default; tune per endpoint.
- **`Retry-After` overrides your backoff.** When the server *tells* you when to retry (429), obey it — your computed jitter is a guess; the server's header is the answer.

---

## 3. Middleware — signing and logging through one seam

A client that sets auth headers and logs at every call site rots: someone forgets the header on one request, secrets leak into logs, and there's no single place to add a new concern. The fix is a **middleware seam** — a small pipeline every request passes through before it goes out and every response passes through on the way back.

```swift
protocol RequestMiddleware: Sendable {
    /// Transform an outgoing request (sign it, add headers).
    func prepare(_ request: URLRequest) async throws -> URLRequest
    /// Observe a completed response (log it, scrub secrets).
    func didReceive(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async
}
```

### Signing — attach auth once

```swift
struct AuthMiddleware: RequestMiddleware {
    let tokenProvider: @Sendable () async -> String?

    func prepare(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    func didReceive(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async {}
}
```

Auth is attached in *one place*, to *every* request, automatically. You cannot forget it on a new endpoint because the endpoint doesn't set headers — the middleware does. (An HMAC-signing variant computes a signature over the method + path + body + timestamp and sets an `X-Signature` header here instead of a bearer token. The *seam* is the same; Week 17 puts a Secure Enclave key behind it. Certificate **pinning** plugs in at the `URLSessionDelegate` level — a related but distinct seam — also Week 17.)

### Logging — observe everything, redact secrets

```swift
import OSLog

struct LoggingMiddleware: RequestMiddleware {
    let log = Logger(subsystem: "com.crunch.notes", category: "network")

    func prepare(_ request: URLRequest) async throws -> URLRequest {
        log.debug("→ \(request.httpMethod ?? "?") \(request.url?.path ?? "?")")
        return request   // does not modify the request
    }
    func didReceive(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async {
        log.debug("← \(response.statusCode) \(request.url?.path ?? "?") (\(data.count) bytes)")
    }
}
```

**Redaction is a security requirement, not a nicety.** Never log the `Authorization` header value, a token, a password, or PII. Log the *path* and *status*, not the full headers and body. A logged bearer token is a credential leak in your crash reports and your log aggregator. Scrub at the middleware so no call site can leak by accident. (Week 17 goes deep on sensitive-log scrubbing; the habit starts here.)

The client runs the middleware chain around `send`:

```swift
actor NotesClient {
    private let middleware: [RequestMiddleware]
    // ...session, baseURL, decoder from lecture 1...

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        var request = try buildRequest(for: endpoint)
        for m in middleware { request = try await m.prepare(request) }   // sign, log-out
        let (data, response) = try await dataChecked(for: request)        // lecture 1's status check
        if let http = response as? HTTPURLResponse {
            for m in middleware { await m.didReceive(http, data: data, for: request) }  // log-in
        }
        return try decode(E.Response.self, from: data)
    }
}
```

Signing, logging, auth-refresh, metrics — every cross-cutting concern plugs into this one seam, in order, once. That is what keeps a networking layer maintainable as it grows.

---

## 4. Detecting offline — `NWPathMonitor`

To fall back to the cache and queue writes, the client must know it is offline. The modern API is `NWPathMonitor` from `Network.framework`, which streams path changes — and, satisfyingly, it bridges to an `AsyncStream` (Week 12) cleanly:

```swift
import Network

actor Reachability {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    func start() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            monitor.pathUpdateHandler = { path in
                let online = path.status == .satisfied
                continuation.yield(online)
            }
            continuation.onTermination = { _ in self.monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "reachability"))
        }
    }
}
```

`path.status == .satisfied` means "a usable path to the network exists." Consume the stream in a `.task` and update an observable flag the UI can show ("You're offline"). Two cautions: reachability tells you the *device* has a path, **not** that *your server* is reachable — a captive portal or a down backend is "online" by this measure. So treat reachability as a *hint* that lets you fail fast, but still rely on the request's actual `.offline`/`.timedOut`/`.transport` error as the source of truth. Reachability optimises the UX (show the offline banner promptly); the request result is what actually decides the fallback.

---

## 5. Offline-first write-replay — the outbox

Here is the week's named skill, and the senior move. The app must be **fully usable offline**: reads come from the SwiftData cache, and writes — create, update, delete a note — *succeed locally and queue* for the server, replaying in order when connectivity returns. This is the **outbox pattern**.

### The shape

```text
   User edits a note (offline)
        │
        ▼
   1. Apply the change to SwiftData LOCALLY (the UI updates immediately)
   2. Append a PendingMutation to the outbox (also in SwiftData)
        │
        ▼
   ... time passes, app is offline, user keeps working ...
        │
   Reachability flips to online (or a request succeeds)
        ▼
   3. Drain the outbox IN ORDER: replay each PendingMutation against the server
   4. On success, remove it from the outbox; on a permanent failure, mark/park it
```

The pending mutation, persisted so it survives an app kill:

```swift
import SwiftData

@Model
final class PendingMutation {
    var id: UUID                 // idempotency key (see below)
    var kind: String             // "create" | "update" | "delete"
    var noteID: UUID
    var payload: Data?           // encoded NoteDraft for create/update
    var createdAt: Date          // preserves order

    init(id: UUID = UUID(), kind: String, noteID: UUID, payload: Data?, createdAt: Date = .now) {
        self.id = id; self.kind = kind; self.noteID = noteID
        self.payload = payload; self.createdAt = createdAt
    }
}
```

### Writing while offline

```swift
func createNote(_ draft: NoteDraft) async {
    // 1. Apply locally — the UI updates NOW, no spinner, no waiting on the network.
    let local = Note(from: draft)
    context.insert(local)

    // 2. Try the server. If it works, great. If offline, queue it.
    do {
        let created = try await client.send(CreateNote(draft: draft))
        local.serverID = created.id          // reconcile the server's id
    } catch NetworkError.offline, NetworkError.timedOut, NetworkError.transport {
        let mutation = PendingMutation(kind: "create", noteID: local.id,
                                       payload: try? JSONEncoder().encode(draft))
        context.insert(mutation)             // queue for replay
    } catch {
        // a non-retryable failure (4xx, decoding) — surface it; don't queue a doomed write
    }
    try? context.save()
}
```

The user sees the note appear *instantly*, online or off. There is no spinner on a write, no "couldn't save," no lost draft. That is what "offline-first" *means* — the local store is the source of truth for the UI, and the network is a background reconciliation.

### Replaying on reconnect — in order, idempotently

```swift
func drainOutbox() async {
    let pending = (try? context.fetch(
        FetchDescriptor<PendingMutation>(sortBy: [SortDescriptor(\.createdAt)])  // ORDER matters
    )) ?? []

    for mutation in pending {
        do {
            try await replay(mutation)        // re-send to the server
            context.delete(mutation)          // success: remove from the outbox
        } catch let error as NetworkError where error.isRetryable {
            break                             // still offline/server down — stop; retry the whole queue later
        } catch {
            mutation.markFailed()             // permanent failure: park it, alert, don't block the queue forever
        }
    }
    try? context.save()
}
```

Two non-negotiable correctness properties:

- **Order.** Replay mutations in the order they were made (`sortBy createdAt`). A "create then update then delete" must not replay as "delete then create" — that leaves a ghost note on the server. The outbox is a *queue*, not a set.
- **Idempotency.** A replayed write must not be applied *twice*. The network is unreliable in both directions — you might send a create, the server applies it, but the response is lost, so on reconnect you replay it and create a duplicate. The fix is an **idempotency key**: each `PendingMutation` carries a stable `id`, you send it as an `Idempotency-Key` header, and the server (your Vapor backend) dedupes — a second create with the same key returns the *existing* resource instead of making a duplicate. Without idempotency, every dropped response becomes a duplicated note on reconnect. (Your Vapor service needs a small dedup table keyed on the idempotency key; the contract is "same key = same effect, applied once.")

This is the offline-first write-replay the week's promise demands and the mini-project builds: pull the network out, keep working, restore it, and watch the queued writes reconcile in order, exactly once.

---

## 6. The production checklist

Before you call a networking layer "done," walk this list — the code-review checklist a senior reviewer applies:

- **Typed errors, branched on.** `NetworkError` distinguishes offline / cancelled / timeout / transport / http-status / decoding / server, and callers branch on them (cache, refresh, retry, report).
- **Status checked every time.** Every response is cast to `HTTPURLResponse` and the status verified before decoding. No `_`-discarded responses.
- **Retries are bounded, backed-off, and jittered.** Only retryable errors retry; there's an attempt cap; the delay is exponential with **full jitter**; `Retry-After` is honoured; the loop respects cancellation.
- **Auth and logging go through middleware**, once, not scattered. Secrets are redacted from logs.
- **Cancellation is respected.** Requests run in cancellable tasks; a cancelled request doesn't race a stale response onto the screen, and a cancelled retry loop stops.
- **The client is hermetically tested** via `URLProtocol` — success, each error kind, the retry count, the offline fallback — with zero network.
- **Offline-first:** reads fall back to SwiftData; writes apply locally and queue; the outbox replays **in order** and **idempotently** on reconnect.
- **No `try!` decode**, no force-unwrapped `URL`, no `URLSession.shared` for app requests (a chosen, injectable session instead).

---

## 7. Recap

You now have the resilient half of a production client:

1. **Retry only what might succeed.** Transient transport, timeouts, and 5xx/429 retry; 4xx (except 429), cancelled, offline, and decoding do not. The decision is encoded once as `isRetryable`.
2. **Backoff with full jitter.** Exponential delay gives a struggling server room; jitter desynchronises the herd so retries trickle in instead of arriving as a wave — the difference between a server that recovers and one that keeps getting knocked down.
3. **Middleware is the seam.** Signing (bearer/HMAC) and logging (redacted) plug in once and apply to every request; pinning and Secure-Enclave signing extend the same seam in Week 17.
4. **Offline detection is a hint.** `NWPathMonitor` tells you the device has a path; the request's actual error is the source of truth for the fallback.
5. **Offline-first write-replay** is the named skill: apply writes locally (instant UI), queue them in a SwiftData outbox, and replay **in order** and **idempotently** when connectivity returns — so the app is fully usable offline and reconciles exactly once on reconnect.

The exercises build the typed `Endpoint` client, the `URLProtocol` hermetic tests, and the retry-backoff-jitter loop. The challenge builds the offline write-replay outbox and proves it survives a simulated network drop. The mini-project wires "Notes v1" to your Phase I Vapor `notes-api` with the full `NotesClient` actor — typed errors, retries, offline detection, and SwiftData write-replay — closing the loop between the server you built in Phase I and the client you've built across Phase II. Go make the app survive the network failing.
