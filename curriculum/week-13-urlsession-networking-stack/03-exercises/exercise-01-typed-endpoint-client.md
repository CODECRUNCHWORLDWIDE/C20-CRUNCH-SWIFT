# Exercise 1 — A typed `Endpoint` client

**Goal.** Build the spine of a production networking client: a generic `Endpoint` protocol, an `actor` client with a single `send<E: Endpoint>(_:) async throws -> E.Response` method, two concrete endpoints describing a real API, correct `Codable` decoding strategies, and a typed `NetworkError`. If you can do this, you can turn any server contract into a type-checked Swift client — the read path of the whole week.

**Estimated time.** 50 minutes.

**Prerequisites.** Xcode 16+. URLSession ships with the SDK — no package, no live server (we stub the session). This drops into an app or test target.

---

## Step 1 — The model and the error space

Define the response model (in a real project this is your shared `NotesCore.Note` from Week 6) and the typed error:

```swift
import Foundation

struct Note: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var body: String?          // optional — the server may omit it; optionality tolerates drift
    var createdAt: Date
}

struct NoteDraft: Codable, Sendable {
    var title: String
    var body: String?
}

enum NetworkError: Error, Equatable {
    case offline
    case cancelled
    case timedOut
    case transport(URLError)
    case http(status: Int)
    case decoding
    case badURL

    init(_ urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed: self = .offline
        case .cancelled:                               self = .cancelled
        case .timedOut:                                self = .timedOut
        default:                                       self = .transport(urlError)
        }
    }
}
```

## Step 2 — The `Endpoint` protocol

A generic description of one endpoint, with a default for the optional bits:

```swift
enum HTTPMethod: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

protocol Endpoint {
    associatedtype Response: Decodable & Sendable
    var path: String { get }
    var method: HTTPMethod { get }
    var body: (any Encodable & Sendable)? { get }
}

extension Endpoint {
    var body: (any Encodable & Sendable)? { nil }   // default: no body
}
```

## Step 3 — Two concrete endpoints

Describe `GET /notes` and `POST /notes` as types. The `Response` associated type *is* the contract:

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
```

## Step 4 — The actor client

The generic `send` builds the request, checks the status, and decodes — once, for every endpoint:

```swift
actor NotesClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()

    init(baseURL: URL, session: URLSession = URLSession(configuration: .default)) {
        self.baseURL = baseURL
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601           // match the server's date format
        // d.keyDecodingStrategy = .convertFromSnakeCase  // enable if the server sends snake_case
        self.decoder = d
    }

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let request = try buildRequest(for: endpoint)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw NetworkError(urlError)            // transport/offline/cancelled/timeout
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode)   // branch on this later
        }
        do {
            return try decoder.decode(E.Response.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    private func buildRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
```

## Step 5 — Prove it with a stubbed session

You'll write the full `URLProtocol` stub in exercise 2; for now, a tiny inline stub proves the decode path end to end without a server:

```swift
import Testing

final class QuickStub: URLProtocol {
    nonisolated(unsafe) static var data: Data = Data()
    nonisolated(unsafe) static var status = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func makeClient() -> NotesClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [QuickStub.self]
    return NotesClient(baseURL: URL(string: "https://test.local")!,
                       session: URLSession(configuration: config))
}

@Test("ListNotes decodes a typed [Note]")
func listDecodes() async throws {
    let id = UUID()
    QuickStub.status = 200
    QuickStub.data = """
    [{"id":"\(id.uuidString)","title":"Hello","body":"world","createdAt":"2026-06-09T12:00:00Z"}]
    """.data(using: .utf8)!

    let notes = try await makeClient().send(ListNotes())   // returns [Note], type-checked
    #expect(notes.count == 1)
    #expect(notes.first?.title == "Hello")
}

@Test("a 500 throws .http(status: 500)")
func serverErrorThrows() async {
    QuickStub.status = 500
    QuickStub.data = Data()
    await #expect(throws: NetworkError.http(status: 500)) {
        _ = try await makeClient().send(ListNotes())
    }
}
```

---

## Acceptance criteria

- [ ] A generic `Endpoint` protocol with an `associatedtype Response: Decodable & Sendable` and a default no-body extension.
- [ ] Two concrete endpoints (`ListNotes`, `CreateNote`) whose `Response` types are the contract.
- [ ] An `actor NotesClient` with one generic `send<E: Endpoint>` that builds the request, casts to `HTTPURLResponse`, checks the status, and decodes — with `dateDecodingStrategy` set.
- [ ] A typed `NetworkError` with a `URLError` initialiser mapping offline/cancelled/timeout/transport.
- [ ] Tests proving a 200 decodes a typed `[Note]` and a 500 throws `.http(status: 500)`, via a stubbed session.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict concurrency.

## What you just proved

You turned a server contract into Swift *types* — `send(ListNotes())` returns `[Note]` because the compiler says so — checked the HTTP status before trusting the body, decoded with the right strategy, and mapped failures into a typed error you can branch on. And you made the session *injectable*, which is the seam that made the test possible without a server. This is the read path of every production client you will ever build; the rest of the week adds resilience on top of it.

---

## Hints (read only if stuck > 10 min)

- **`URL(string:relativeTo:)` returns nil.** The `path` must be a valid relative path; if `baseURL` lacks a trailing slash and `path` lacks a leading one, the join can misbehave. Use a leading slash (`"/notes"`) and a `baseURL` like `https://test.local`.
- **The decode throws on the date.** Your `dateDecodingStrategy` must match the JSON. The test JSON uses ISO-8601 (`"2026-06-09T12:00:00Z"`), so `.iso8601` is correct. If the server sent a Unix timestamp, you'd use `.secondsSince1970`.
- **`nonisolated(unsafe) static var` warning.** For the *test stub* `URLProtocol`, the static mutable state is a pragmatic, test-only exception (the protocol's API is class-based and pre-concurrency). It's acceptable in a `URLProtocol` stub; do not use the same pattern in production code.
- **`#expect(throws:)` won't match.** Make `NetworkError: Equatable` (it is, above) so the specific case can be matched. If you can't make it `Equatable`, use the closure form `#expect(throws: NetworkError.self)` and inspect the caught error.
