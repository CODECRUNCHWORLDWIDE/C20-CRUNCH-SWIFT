# Lecture 1 — From one line to a typed, testable client

> "Everyone can write `try await URLSession.shared.data(from: url)`. The senior skill is everything that goes wrong after that line returns — the wrong status, the wrong shape, the timeout, the offline — and building a client that handles each on purpose."

This lecture builds the *read* half of a production networking client: configuration, the modern async APIs, a typed `Endpoint` abstraction, `Codable` decoding done right, a typed error space, and hermetic `URLProtocol` tests. Lecture 2 builds the *resilience* half — retries, signing, logging, and offline-first write-replay. By the end of this one you can turn a server contract into a type-checked, testable Swift client. Bring the shared `NotesCore` `Codable` models from Week 6; they are the contract this client decodes.

---

## 1. The one-liner, and everything it hides

Here is the network call everyone knows:

```swift
let url = URL(string: "http://localhost:8080/notes")!
let (data, _) = try await URLSession.shared.data(from: url)
let notes = try JSONDecoder().decode([Note].self, from: data)
```

Three lines, and it works against your Vapor `notes-api` on the happy path. Now count what it hides, because every hidden thing is a production incident waiting to happen:

- **It ignores the response.** The `_` discards the `URLResponse`. A `200 OK` and a `404 Not Found` both return `data`; the second is an HTML error page, and `decode([Note].self)` throws a confusing error instead of "the resource was not found." You *must* inspect the status code.
- **It uses `URLSession.shared`.** A global singleton with default configuration — no timeout you chose, no auth headers, no way to inject a stub for testing, no `waitsForConnectivity`. Fine for a script; wrong for an app.
- **It has one error type: thrown `Error`.** A transport failure (offline), an HTTP 500 (server down), and a decode failure (server changed the shape) all surface as an opaque `Error`. The caller cannot tell "retry this" from "show the user an error" from "the contract drifted."
- **It does not retry, sign, log, or fall back.** A blip fails the whole call. There is no auth. There is no offline path.

The rest of this lecture replaces each hidden thing with a deliberate choice. We are not making networking complicated; we are making the complexity that *already exists* visible and handled.

---

## 2. `URLSessionConfiguration` — choosing the session on purpose

`URLSession.shared` is fine for a quick fetch, but a real client owns its session with a configuration it chose. Three configurations, three jobs:

```swift
// DEFAULT — persistent cache, cookies, credentials. The everyday app session.
let def = URLSessionConfiguration.default
def.timeoutIntervalForRequest = 15        // give up waiting for data after 15s
def.timeoutIntervalForResource = 60       // give up on the whole transfer after 60s
def.waitsForConnectivity = true           // queue the request until connectivity exists
def.httpAdditionalHeaders = ["Accept": "application/json"]
let session = URLSession(configuration: def)

// EPHEMERAL — nothing persisted to disk: no cache, no cookies, no credential store.
// For privacy-sensitive flows (an incognito mode, a one-shot auth) and for tests.
let ephemeral = URLSession(configuration: .ephemeral)

// BACKGROUND — the system runs the transfer even if your app is suspended/killed.
// For large uploads/downloads that must finish. Has a delegate-only completion model.
let bg = URLSessionConfiguration.background(withIdentifier: "com.crunch.notes.sync")
```

The decisions you must be able to defend:

- **`default`** is the right choice for almost every app request — it caches, persists cookies, and stores credentials, which is what you want for talking to your own API.
- **`ephemeral`** when you must *not* persist anything: a privacy mode, or — usefully — a **test session**, because it starts clean every time with no cached state to make a test non-deterministic.
- **`background`** only when a transfer must survive the app being suspended or terminated: a big photo upload, a podcast download. It is heavier (delegate-based, system-scheduled) and not what you reach for to `GET /notes`. We flag it; the mini-project uses `default`.
- **`waitsForConnectivity = true`** is the modern, often-correct setting: instead of failing immediately when offline, the request *waits* (up to `timeoutIntervalForResource`) for connectivity to appear, then runs. For a user-initiated action you often want this; for a background poll you might prefer to fail fast and rely on your own offline path (lecture 2). Choose it deliberately.
- **Timeouts are not optional.** `timeoutIntervalForRequest` (the per-stage wait, default 60s — usually too long for a responsive UI) and `timeoutIntervalForResource` (the whole-transfer cap). A 15s request timeout keeps the UI honest; the default 60s makes a flaky network feel like a hang.

---

## 3. The async URLSession APIs

The modern surface is small and built on `async`/`await`. Four methods cover everything:

```swift
// data — load a response body into memory. The everyday GET/POST.
let (data, response) = try await session.data(for: request)

// upload — send a body (Data or a file) as the request body. POST/PUT with a payload.
let (respData, respMeta) = try await session.upload(for: request, from: bodyData)

// download — stream a response to a temp file on disk (large bodies you don't want in RAM).
let (fileURL, dlResponse) = try await session.download(for: request)

// bytes — an AsyncSequence of the response body's bytes/lines (streaming, Week 12 bridge).
let (bytes, streamResponse) = try await session.bytes(for: request)
for try await line in bytes.lines { handle(line) }   // server-sent events / NDJSON, line by line
```

Two things to internalise about all of them:

**Always cast and check the response.** The `URLResponse` is the half of the tuple the one-liner discarded. Cast it to `HTTPURLResponse` and read the status code — this is the difference between a robust client and a confusing one:

```swift
guard let http = response as? HTTPURLResponse else {
    throw NetworkError.transport(URLError(.badServerResponse))
}
guard (200..<300).contains(http.statusCode) else {
    throw NetworkError.http(status: http.statusCode, data: data)  // 404, 500, 401 — branch on it
}
// only now is `data` trustworthy to decode
```

**Cancellation propagates into the request.** Because these are `async` calls inside a `Task`, cancelling the task cancels the in-flight network request — the `URLSession` task is torn down and the `await` throws a `CancellationError` (surfaced as a `URLError(.cancelled)`). This is the Week 3/Week 12 cancellation discipline reaching the network: a cancelled debounced search (Week 12) cancels its HTTP request, so a stale response never races a fresh one onto the screen. You get this *for free* with the async APIs; the old completion-handler `dataTask(with:)` required manual `cancel()` bookkeeping. Always run network requests inside a cancellable `Task` and let structured concurrency tear them down.

`bytes(for:)` is the bridge to last week: its `.lines` is an `AsyncSequence<String>`, so a streaming endpoint (server-sent events, an NDJSON feed of note changes) is consumed with `for try await line in bytes.lines` — the same `for await` loop you mastered in Week 12, now over the network.

---

## 4. The typed `Endpoint` — turning a server contract into Swift types

Scattering `URLRequest` construction through your call sites is how a networking layer rots. The fix is a single abstraction that describes *one endpoint* as a type, generic over what it returns. This is the spine of a maintainable client.

```swift
import Foundation

enum HTTPMethod: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

protocol Endpoint {
    associatedtype Response: Decodable      // what a successful call decodes to
    var path: String { get }                // "/notes", "/notes/\(id)"
    var method: HTTPMethod { get }
    var body: (any Encodable & Sendable)? { get }   // nil for GET/DELETE
    var queryItems: [URLQueryItem] { get }
}

extension Endpoint {
    var body: (any Encodable & Sendable)? { nil }
    var queryItems: [URLQueryItem] { [] }
}
```

Now describe the actual `notes-api` endpoints as concrete types — each one *is* the contract:

```swift
// GET /notes -> [Note]
struct ListNotes: Endpoint {
    typealias Response = [Note]
    let path = "/notes"
    let method = HTTPMethod.get
}

// GET /notes/:id -> Note
struct GetNote: Endpoint {
    typealias Response = Note
    let id: UUID
    var path: String { "/notes/\(id.uuidString)" }
    let method = HTTPMethod.get
}

// POST /notes (body: NoteDraft) -> Note
struct CreateNote: Endpoint {
    typealias Response = Note
    let path = "/notes"
    let method = HTTPMethod.post
    let draft: NoteDraft
    var body: (any Encodable & Sendable)? { draft }
}
```

The client turns any `Endpoint` into a `URLRequest`, sends it, checks the status, and decodes its `Response` — all generically, once:

```swift
actor NotesClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = URLSession(configuration: .default)) {
        self.baseURL = baseURL
        self.session = session
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase   // server sends created_at; we want createdAt
        d.dateDecodingStrategy = .iso8601               // server sends ISO-8601 timestamps
        self.decoder = d
    }

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let request = try buildRequest(for: endpoint)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw NetworkError(urlError)   // map transport/offline/cancelled (§6)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode, data: data)
        }
        do {
            return try decoder.decode(E.Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    private func buildRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                       resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty { components?.queryItems = endpoint.queryItems }
        guard let url = components?.url else { throw NetworkError.transport(URLError(.badURL)) }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
```

Now a call site is fully typed and impossible to misuse:

```swift
let client = NotesClient(baseURL: URL(string: "http://localhost:8080")!)
let notes: [Note] = try await client.send(ListNotes())          // returns [Note], type-checked
let one: Note = try await client.send(GetNote(id: someID))      // returns Note
let made: Note = try await client.send(CreateNote(draft: draft)) // returns the created Note
```

The compiler enforces that `send(ListNotes())` returns `[Note]` and `send(GetNote(id:))` returns `Note` — the `Response` associated type *is* the contract. Add an endpoint by adding a type; you cannot forget to set the method or mis-decode the response, because the type says it. **Why an `actor`?** The client holds the session and a token (lecture 2) as mutable state shared across concurrent callers; an actor serialises access and makes the whole thing `Sendable` under Swift 6 strict concurrency without locks. A debounced search and a manual refresh hitting the client at once are safe by construction.

---

## 5. `Codable` decoding — strategies and the failure modes

The decode is where the server contract meets your types, and it is where things break when the server changes. Get the strategies right and handle the failures.

### Strategies

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase   // created_at JSON -> createdAt Swift property
decoder.dateDecodingStrategy = .iso8601               // "2026-06-09T12:00:00Z" -> Date
```

- **`keyDecodingStrategy = .convertFromSnakeCase`** lets your Swift `createdAt` decode the server's `created_at` without hand-writing `CodingKeys`. Most servers (including a conventional Vapor/Fluent API) send snake_case JSON; this one line bridges the casing. (If your shared `NotesCore` model and the server agree on camelCase already — which is the cleaner choice when you control both sides — you don't need it. Know it exists for APIs you *don't* control.)
- **`dateDecodingStrategy`** must match how the server encodes dates. `.iso8601` is the modern default; some APIs send Unix timestamps (`.secondsSince1970`) or a custom format (`.custom { decoder in ... }`). A mismatch here is the single most common decode bug — the JSON has a date string and your decoder expects a number, so it throws.

### The failure modes, and turning them into actionable errors

A `DecodingError` is not one error; it is four cases, each pointing at exactly what is wrong:

```swift
do {
    return try decoder.decode(E.Response.self, from: data)
} catch let DecodingError.keyNotFound(key, context) {
    // The server omitted a key your type requires (non-optional).
    log.error("Missing key '\(key.stringValue)': \(context.debugDescription)")
    throw NetworkError.decoding(DecodingError.keyNotFound(key, context))
} catch let DecodingError.typeMismatch(type, context) {
    // The JSON had the wrong type (e.g. a String where you expected an Int).
    log.error("Type mismatch, expected \(type) at \(context.codingPath)")
    throw NetworkError.decoding(DecodingError.typeMismatch(type, context))
} catch let DecodingError.valueNotFound(type, context) {
    // A non-optional property was null in the JSON.
    log.error("Null where \(type) required at \(context.codingPath)")
    throw NetworkError.decoding(DecodingError.valueNotFound(type, context))
} catch {
    throw NetworkError.decoding(error)
}
```

The defensive habits that prevent most decode incidents:

- **Make optional what the server may omit.** If `body` can be absent, declare `var body: String?`, not `var body: String`. A non-optional property is a *contract that the key is always present*; if the server breaks that contract, you crash-on-decode instead of degrading. Optionality is how you tolerate server drift.
- **Decode the server's error envelope, not just the success shape.** A `400`/`500` often returns `{ "error": true, "reason": "..." }`. On a non-2xx status, try decoding *that* shape to get a real message for `NetworkError.server(message:)` (lecture 2 wires this), instead of showing "decoding failed."
- **Never `try!` a decode.** A force-decode turns server drift into a crash. The whole point of the typed error is to *report* the drift, not die from it.

The shared-types payoff (Week 6) is most visible here: because the client decodes the *same* `struct Note: Codable` the server encodes, drift is caught at *compile time* when you change the shared model — both sides update together, and the decode cannot mismatch a field that the shared type guarantees exists. That is the architectural reason we built shared models before SwiftUI: it eliminates a whole class of decode bugs by construction.

---

## 6. The typed error space — branch on *why* it failed

A bare thrown `Error` tells the caller *that* the request failed, not *why*, and "why" is exactly what the caller needs to decide between retry, report, and fall-back. Model the error space as a typed enum:

```swift
enum NetworkError: Error {
    case offline                          // no connectivity (URLError .notConnectedToInternet etc.)
    case cancelled                        // the task was cancelled (don't show an error for this)
    case timedOut                         // the request exceeded its timeout
    case transport(URLError)              // other transport failures (DNS, TLS, connection reset)
    case http(status: Int, data: Data)    // a non-2xx HTTP status
    case decoding(Error)                  // the body didn't match the expected shape
    case server(message: String)          // a decoded server error envelope

    /// Map a URLError into the right case so callers can branch.
    init(_ urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .cancelled:
            self = .cancelled
        case .timedOut:
            self = .timedOut
        default:
            self = .transport(urlError)
        }
    }
}
```

Now the caller can do the thing that distinguishes a product from a demo — *branch on the kind of failure*:

```swift
do {
    let notes = try await client.send(ListNotes())
    show(notes)
} catch NetworkError.offline {
    show(localCachedNotes())          // fall back to SwiftData (lecture 2)
    banner("You're offline — showing saved notes")
} catch NetworkError.cancelled {
    return                            // user moved on; not an error, show nothing
} catch let NetworkError.http(status, _) where status == 401 {
    await refreshTokenAndRetry()      // auth expired
} catch NetworkError.http(status: 500...599, _) {
    banner("The server is having trouble — try again")  // retryable (lecture 2)
} catch NetworkError.decoding {
    banner("Something's out of date — update the app")   // contract drift; not retryable
} catch {
    banner("Couldn't load notes")
}
```

`offline` triggers the cache; `cancelled` shows *nothing* (the user moved on); `401` refreshes auth; `5xx` is retryable; `decoding` means the contract drifted and retrying won't help. **A single `Error` type cannot express any of this** — every failure would look the same and you would either retry things you shouldn't or show errors you shouldn't. The typed error space is what makes the resilience in lecture 2 *possible*: retry logic decides what to retry by matching these cases.

---

## 7. `URLProtocol` — hermetic tests that never touch the network

A networking client you cannot test without a live server is a networking client you cannot trust. The seam is **`URLProtocol`**: a custom protocol you register on a `URLSessionConfiguration` that *intercepts every request* and returns whatever canned response you want — no socket, no server, no flakiness.

```swift
final class StubURLProtocol: URLProtocol {
    // The test sets this: given a request, return (response, body) or throw.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }   // intercept everything
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)   // simulate a transport failure
        }
    }

    override func stopLoading() {}
}

// Build a session that routes through the stub:
func makeStubbedClient() -> NotesClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]            // <- the interception
    let session = URLSession(configuration: config)
    return NotesClient(baseURL: URL(string: "https://test.local")!, session: session)
}
```

Now a test injects exactly the response it wants and asserts the client's behaviour, with zero network:

```swift
import Testing

@Test("send decodes a 200 OK into the typed response")
func decodesSuccess() async throws {
    StubURLProtocol.handler = { request in
        let json = #"[{"id":"\#(UUID().uuidString)","title":"Hi","body":"there"}]"#.data(using: .utf8)!
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        return (response, json)
    }
    let client = makeStubbedClient()
    let notes = try await client.send(ListNotes())
    #expect(notes.count == 1)
    #expect(notes.first?.title == "Hi")
}
```

This is the testing pattern the whole week's exercises lean on: a stub `URLProtocol` lets you assert "a 500 throws `.http(status: 500)`," "a malformed body throws `.decoding`," "a `URLError(.notConnectedToInternet)` throws `.offline`," and "the retry loop retried exactly three times" — all deterministically, fast, and offline. **A networking client without `URLProtocol` tests is a client tested against a server that might be down when CI runs.** Make the session injectable (we did — `NotesClient(session:)`), route it through a stub in tests, and your networking suite becomes as fast and reliable as your pure-logic suite.

---

## 8. Recap — the typed, testable read path

You now have the read half of a production client:

- The **one-liner hides** the response status, the session, the error kinds, and all resilience. A real client makes each a deliberate choice.
- **`URLSessionConfiguration`** is chosen on purpose — `default` for app requests, `ephemeral` for privacy and tests, `background` for must-finish transfers — with timeouts and `waitsForConnectivity` set deliberately.
- The **async APIs** (`data`/`upload`/`download`/`bytes`) always cast the response to `HTTPURLResponse` and check the status, and propagate cancellation into the in-flight request for free.
- The **typed `Endpoint`** turns a server contract into Swift types generic over `Response: Decodable`; the `actor` client sends any endpoint, checks the status, and decodes — once, generically, impossible to misuse.
- **`Codable` strategies** (`keyDecodingStrategy`, `dateDecodingStrategy`) must match the server; the four `DecodingError` cases become actionable errors; optionality tolerates server drift; shared types (Week 6) catch drift at compile time.
- The **typed `NetworkError` enum** lets the caller branch on *why* it failed — offline → cache, cancelled → nothing, 401 → refresh, 5xx → retry, decoding → "update the app" — which a bare `Error` cannot express.
- **`URLProtocol`** makes the client hermetically testable: intercept every request, return canned responses, assert behaviour with zero network.

Lecture 2 builds the resilience half on this foundation: retry with exponential backoff and **jitter** (and why jitter stops a thundering herd), request **signing** and **logging** middleware, **offline detection**, and the **offline-first write-replay outbox** that keeps the app fully usable with no connection and reconciles when it returns. The typed errors you built here are what the retry logic branches on; the injectable session is what makes the whole resilient client testable. Bring both forward.
