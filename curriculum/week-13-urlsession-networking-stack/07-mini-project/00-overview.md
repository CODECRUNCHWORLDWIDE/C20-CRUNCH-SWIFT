# Mini-Project — Wire "Notes v1" to the Vapor backend with a resilient `NotesClient`

This week the two halves of the entire track meet. The Vapor `notes-api` you built on Linux in **Phase I** (Weeks 5–6) becomes the server your iOS client talks to. The SwiftUI app you grew across **Phase II** becomes the client. The shared `Codable` models from **Week 6** become the contract between them. You build a `NotesClient` **actor** — typed errors, retries with backoff and jitter, request signing, logging, offline detection — and wire it into "Notes v1" so the app is backed by a real server, *and* stays fully usable when that server is unreachable by falling back to SwiftData and replaying writes when it returns.

This is the week the architecture closes the loop. If you ever wondered why we built a Vapor service and shared models *before* SwiftUI, this is the payoff: the client decodes exactly what the server encodes, type-checked, with no drift, and the offline-first layer makes the app feel native-grade regardless of connectivity. This is the second of your three portfolio apps' foundations and the named Phase III skill: **architect a networking layer with offline-first write-replay.**

---

## Where you're starting from

- **The server:** your Phase I `notes-api` Vapor service — `POST /notes`, `GET /notes`, `GET /notes/:id`, `PATCH /notes/:id`, `DELETE /notes/:id`, bearer-token authenticated, persisting to Postgres via Fluent. Bring it up locally: `docker compose up` (or `swift run`) from your Phase I repo. It listens on `http://localhost:8080`.
- **The shared types:** the `NotesCore` SwiftPM package (Week 6) with `struct Note: Codable, Sendable`. The client imports it; the server imports it; they cannot drift.
- **The client:** "Notes v1" from Week 12 — SwiftData-backed, navigable, architected, with reactive debounced search. Right now its data is *only* local. This week the server becomes the source of truth and SwiftData becomes the offline cache.

If your Phase I service isn't running, the resources page has the `docker compose up` refresher. If you don't have the shared package, you can redefine the `Note` model in a small local module — but the *point* of the exercise is reusing the Week 6 shared types, so reconstruct them if you can.

## What you're building toward

- A `NotesClient` **actor** speaking typed `Endpoint`s over the async URLSession APIs, returning decoded `Note`s or a typed `NetworkError`.
- **Retries** with exponential backoff and full jitter on transient failures, bounded and cancellation-aware.
- **Auth + logging middleware**: a bearer token attached to every request through one seam; redacted request/response logging.
- **Offline detection** via `NWPathMonitor`, surfaced as an "offline" banner in the UI.
- **Offline-first behaviour**: reads fall back to the SwiftData cache; writes apply locally and queue in an outbox; the outbox replays in order and idempotently on reconnect.
- **A passing reconnect test**: create notes offline, restore the network, and they reconcile to the server — proven hermetically and demonstrated live with the Network Link Conditioner.

---

## Milestone 1 — The typed client and endpoints (≈ 2 h)

Build the `NotesClient` actor (lecture 1) over your real endpoints, using the shared `Note` type:

```swift
import Foundation
import NotesCore   // the Week 6 shared package: struct Note: Codable, Sendable

actor NotesClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()
    private let middleware: [RequestMiddleware]

    init(baseURL: URL = URL(string: "http://localhost:8080")!,
         session: URLSession = URLSession(configuration: .default),
         middleware: [RequestMiddleware] = []) {
        self.baseURL = baseURL
        self.session = session
        self.middleware = middleware
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        var request = try buildRequest(for: endpoint)
        for m in middleware { request = try await m.prepare(request) }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch let e as URLError { throw NetworkError(e) }
        guard let http = response as? HTTPURLResponse else { throw NetworkError.transport(URLError(.badServerResponse)) }
        for m in middleware { await m.didReceive(http, data: data, for: request) }
        guard (200..<300).contains(http.statusCode) else { throw NetworkError.http(status: http.statusCode, data: data) }
        do { return try decoder.decode(E.Response.self, from: data) }
        catch { throw NetworkError.decoding(error) }
    }
    // buildRequest as in lecture 1
}
```

Describe `ListNotes`, `GetNote`, `CreateNote`, `UpdateNote`, `DeleteNote` as `Endpoint` types matching your Vapor routes:

```swift
struct ListNotes: Endpoint {
    typealias Response = [Note]
    let path = "/notes"
    let method = HTTPMethod.get
}

struct CreateNote: Endpoint {
    typealias Response = Note
    let path = "/notes"
    let method = HTTPMethod.post
    let draft: NoteDraft
    var body: (any Encodable & Sendable)? { draft }
}

struct UpdateNote: Endpoint {
    typealias Response = Note
    let id: UUID
    let draft: NoteDraft
    var path: String { "/notes/\(id.uuidString)" }
    let method = HTTPMethod.patch
    var body: (any Encodable & Sendable)? { draft }
}

struct DeleteNote: Endpoint {
    typealias Response = EmptyResponse   // a 204 No Content decodes to an empty marker
    let id: UUID
    var path: String { "/notes/\(id.uuidString)" }
    let method = HTTPMethod.delete
}

/// A stand-in for endpoints that return no body (DELETE → 204). Decodes from
/// empty data so the generic `send` doesn't choke on a zero-byte success.
struct EmptyResponse: Decodable, Sendable {
    init() {}
    init(from decoder: Decoder) throws {}   // accepts empty/absent body
}
```

One real-world wrinkle worth handling now: a `DELETE` that returns `204 No Content` has an **empty body**, and `JSONDecoder().decode(EmptyResponse.self, from: Data())` would throw because there is nothing to decode. The `EmptyResponse` above with a no-op `init(from:)` handles it; alternatively, special-case 204 in `send` to skip the decode for `EmptyResponse`-typed endpoints. Either way, "success with no body" is a case the naive client forgets and then crashes on the first delete — handle it deliberately.

Verify each endpoint against the live server with `curl` first (`curl -H "Authorization: Bearer <token>" http://localhost:8080/notes`), then with the client. Seeing a real `[Note]` come back from your own server, decoded into your own shared type, is the moment Phase I and Phase II connect.

## Milestone 2 — Retries, signing, and logging middleware (≈ 1.5 h)

Add the resilience layer (lecture 2):

- `sendWithRetry` wrapping `send` with a `RetryPolicy` (exponential backoff + full jitter, attempt cap, cancellation-aware), retrying only `isRetryable` errors.
- An `AuthMiddleware` that attaches `Authorization: Bearer <token>` from a token provider — every request, one place.
- A `LoggingMiddleware` over `OSLog` that logs `→ METHOD /path` and `← status /path (bytes)`, **redacting** the auth header (never log the token).

Confirm in the logs (Console.app or Xcode's console, filtered to your subsystem) that every request is signed and logged and no token appears in the output. Trigger a 500 on the server (or stub one) and watch the retry log fire with growing, jittered delays.

## Milestone 3 — Offline detection and the banner (≈ 1 h)

Wire `NWPathMonitor` (lecture 2, §4) into an `@Observable` reachability model, consume its `AsyncStream<Bool>` in a `.task`, and show a non-intrusive "You're offline" banner when the path is unsatisfied. Remember the caveat: reachability is a *hint* (the device has a path), not proof your server is up — so the request's actual error still drives the fallback. The banner is UX; the error is truth.

## Milestone 4 — Offline-first reads and the write outbox (≈ 2.5 h)

This is the named skill. Restructure the data flow so the app works offline:

- **Reads:** the UI reads from SwiftData (the cache). A background sync calls `client.send(ListNotes())`; on success it upserts the results into SwiftData (which `@Query` picks up automatically — Week 10); on `.offline`/`.timedOut`/`.transport` it leaves the cache in place and shows the banner.
- **Writes:** create/update/delete apply to SwiftData **immediately** (the UI updates with no spinner), then attempt the server. On success, mark the note `synced`. On offline/transient failure, enqueue a `PendingMutation` (the outbox, challenge 1).
- **Reconnect:** when reachability flips online (or the next request succeeds), `drainOutbox()` replays the queued mutations **in order** and **idempotently** (idempotency key as a header), removing each on success.

```swift
@Observable @MainActor
final class NotesStore {
    private(set) var syncState: SyncBanner = .idle
    private let repository: NotesRepository   // owns the client + context + outbox

    func refresh() async {
        do { try await repository.syncFromServer(); syncState = .synced }
        catch NetworkError.offline { syncState = .offline }   // keep the cache, show banner
        catch { syncState = .error }
    }
    func create(title: String) async { await repository.create(title: title) }   // local-first
    func onReconnect() async { await repository.drainOutbox() }
}
```

## Milestone 4b — The server-to-cache merge (the upsert that avoids duplicates)

The read sync has a subtlety worth its own milestone, because getting it wrong is how you end up with two copies of every note. When `client.send(ListNotes())` returns `[Note]` from the server, you must **merge** it into the SwiftData cache, not blindly insert it — the cache already holds the local copies (some `pending`, some `synced`). The merge rule:

```swift
func mergeFromServer(_ remote: [Note]) throws {
    // Index existing local notes by their stable id for an O(1) lookup.
    let locals = try context.fetch(FetchDescriptor<LocalNote>())
    var byID = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    for serverNote in remote {
        if let local = byID[serverNote.id] {
            // Already cached. Update it — UNLESS we have a pending local edit that
            // hasn't reached the server yet (don't clobber the user's offline work).
            if local.syncState == "synced" {
                local.title = serverNote.title
                local.body  = serverNote.body ?? ""
                local.updatedAt = serverNote.updatedAt
            }
            // else: local is "pending" — keep the local version; the outbox will
            // push it and the next sync will agree. (Real conflict resolution is Week 14.)
        } else {
            // New to us — insert it as synced.
            context.insert(LocalNote(from: serverNote, syncState: "synced"))
        }
    }
    // Optionally: delete local synced notes that the server no longer returns
    // (a remote delete). Be careful not to delete pending local creates.
    try context.save()
}
```

The three cases the merge must handle, and why each matters:

- **Note exists locally as `synced`** → update from the server. The server is authoritative for already-synced notes.
- **Note exists locally as `pending`** → *keep the local version.* The user made an offline edit the server hasn't seen; clobbering it with the stale server copy would lose their work. The outbox will push the pending change, and the *next* sync will reconcile. (This is a deliberately simple last-writer policy; real multi-device conflict resolution — where two devices both have valid newer edits — is Week 14's CloudKit topic.)
- **Note is new from the server** → insert it as `synced`.

This upsert-by-id is exactly why your `LocalNote` carries the server's stable `id`, not just SwiftData's `persistentModelID`: the `id` is the join key between the server's truth and your cache. Blindly inserting the server's `[Note]` every sync — the naive bug — duplicates every note on every refresh. The merge is the unglamorous code that makes "the same note, everywhere" actually hold.

## Milestone 5 — The reconnect test, hermetic and live (≈ 1 h)

Prove it two ways:

- **Hermetic (`URLProtocol`, exercise 2 / challenge 1):** a test that stubs the network offline, makes two writes, asserts they're queued, flips the stub online, drains the outbox, and asserts both reconciled in order with no duplicates. This is the test that runs in CI.
- **Live (Network Link Conditioner):** with the real server running, enable the **100% Loss** profile (or airplane mode), create a couple of notes — see them appear instantly with a "pending" indicator — then disable the conditioner and watch them reconcile to the server (verify with `curl` against the live API that the notes arrived). Record a short clip.

---

## Acceptance criteria

- [ ] A `NotesClient` **actor** speaking typed `Endpoint`s over async URLSession, returning the shared `Note` type or a typed `NetworkError`, with the **status checked** every time.
- [ ] **Retries** with exponential backoff + **full jitter**, bounded by an attempt cap, retrying only `isRetryable` errors, cancellation-aware.
- [ ] **Auth + logging middleware** through one seam; the token is attached to every request and **never logged**.
- [ ] **Offline detection** via `NWPathMonitor`, surfaced as a banner; the request error (not just reachability) drives the fallback.
- [ ] **Offline-first reads** (SwiftData cache fallback) and **local-first writes** (apply locally, queue in an outbox on failure).
- [ ] **Outbox replay** on reconnect — **in order**, **idempotent**, surviving an app kill (the outbox is in SwiftData).
- [ ] A **hermetic reconnect test** (zero network) and a **live** demonstration with the Network Link Conditioner (recorded).
- [ ] Uses the **Week 6 shared `Codable` types** (or a faithful reconstruction) so the client/server contract is type-checked.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict concurrency.

## Stretch goals

- **`bytes` streaming sync.** If your Vapor service exposes an NDJSON or SSE change feed, consume it with `session.bytes(for:).lines` (Week 12 bridge) for live updates instead of polling. Note in the README which you used and why.
- **`Retry-After` on 429.** Add server-side rate limiting to one endpoint and have the client honour the `Retry-After` header instead of its computed backoff.
- **Token refresh.** When a request returns 401, have the `AuthMiddleware` refresh the token once and retry the request transparently — the auth-refresh concern living in the same middleware seam.
- **Conflict surfacing.** When the server's `updatedAt` is newer than the local note's at sync time, surface a "this note changed on the server" indicator (a teaser for Week 14's real conflict resolution).

## What this milestone earns you

You connected the server you built in Phase I to the client you built in Phase II, through the shared types you designed in Week 6, with a networking layer that is typed, resilient, signed, logged, tested, and — the senior move — **offline-first with write-replay**. That is the literal Phase III "skill earned": architect a networking layer with offline-first write-replay. "Notes v1" is now a real client-server app that survives the network failing, the second of your three portfolio apps. Every remaining Production iOS week builds on this exact networking layer: Week 14 secures the token in the Keychain and adds multi-device CloudKit sync, Week 17 adds certificate pinning and Secure-Enclave request signing to the middleware seam you built, and Week 18 lets an APNs push trigger a sync. You did not wire up a fetch this week; you built the resilient networking foundation the rest of the phase stands on.

## How this rolls into Phase III

The bearer token you attach this week lives in `UserDefaults` or a constant right now — Week 14 moves it to the **Keychain** with the right accessibility class, because a token in `UserDefaults` is a token in plaintext on disk. The single-client outbox you built becomes Week 14's **multi-device conflict resolution** over CloudKit, where two devices editing the same note offline must reconcile deterministically — a real step up from one client replaying against one server. And the middleware seam you built is where Week 17 plugs in **certificate pinning** (at the delegate) and **Secure-Enclave request signing**. Keep the client clean and the seam composable — it's about to get a lot more responsibility.
