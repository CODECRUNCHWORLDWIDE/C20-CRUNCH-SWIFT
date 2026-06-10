// Exercise 2 — Hermetic networking tests with URLProtocol
//
// Goal: Write a reusable stub URLProtocol that can return canned responses OR
//       errors per request, route a URLSession through it, and test a networking
//       client with ZERO network: a 200 success, an HTTP 500, a decode failure,
//       and a simulated offline error. A networking suite that never touches a
//       real server is fast, deterministic, and runs offline in CI.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite plus the stub and a minimal client. Drop it into
// a test target (iOS 17+/macOS 14+). It needs no package and no server.
//
//   1. Add to a test target.
//   2. Run with Cmd-U.
//   3. Read the assertions: each maps a stubbed response to the client's
//      typed behaviour.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] A StubURLProtocol whose handler returns (HTTPURLResponse, Data) or throws.
//   [ ] Four tests: 200 success decodes; 500 throws .http(status:500); malformed
//       body throws .decoding; a URLError(.notConnectedToInternet) throws .offline.
//   [ ] No test makes a real network call.
//   [ ] You can explain why URLProtocol is the right testing seam.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// Minimal model + error + client (a trimmed version of exercise 1's).
// ----------------------------------------------------------------------------

struct Note: Codable, Sendable, Equatable {
    let id: UUID
    var title: String
}

enum NetworkError: Error, Equatable {
    case offline, cancelled, timedOut, transport, http(status: Int), decoding

    init(_ urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed: self = .offline
        case .cancelled:                               self = .cancelled
        case .timedOut:                                self = .timedOut
        default:                                       self = .transport
        }
    }
}

actor MiniClient {
    let session: URLSession
    let url = URL(string: "https://test.local/notes")!
    init(session: URLSession) { self.session = session }

    func fetchNotes() async throws -> [Note] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let e as URLError {
            throw NetworkError(e)
        }
        guard let http = response as? HTTPURLResponse else { throw NetworkError.transport }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode)
        }
        do { return try JSONDecoder().decode([Note].self, from: data) }
        catch { throw NetworkError.decoding }
    }
}

// ----------------------------------------------------------------------------
// The reusable stub. Per-request handler returns a response+body OR throws.
// ----------------------------------------------------------------------------

final class StubURLProtocol: URLProtocol {
    // Set by each test. Class-based URLProtocol API predates concurrency, so a
    // static is the pragmatic seam — acceptable in a TEST stub only.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }   // intercept all
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // Deliver the error to the URL loading system — this is how we
            // simulate offline/timeout/transport failures hermetically.
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

func makeStubbedClient() -> MiniClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]   // route every request through the stub
    return MiniClient(session: URLSession(configuration: config))
}

func ok(_ json: String, for request: URLRequest, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
    return (response, json.data(using: .utf8)!)
}

// ----------------------------------------------------------------------------
// The four hermetic tests.
// ----------------------------------------------------------------------------

struct URLProtocolStubTests {

    @Test("200 OK decodes into a typed [Note]")
    func success() async throws {
        let id = UUID()
        StubURLProtocol.handler = { request in
            ok(#"[{"id":"\#(id.uuidString)","title":"Hi"}]"#, for: request)
        }
        let notes = try await makeStubbedClient().fetchNotes()
        #expect(notes == [Note(id: id, title: "Hi")])
    }

    @Test("HTTP 500 throws .http(status: 500)")
    func serverError() async {
        StubURLProtocol.handler = { request in ok("server exploded", for: request, status: 500) }
        await #expect(throws: NetworkError.http(status: 500)) {
            _ = try await makeStubbedClient().fetchNotes()
        }
    }

    @Test("a malformed body throws .decoding")
    func decodeFailure() async {
        StubURLProtocol.handler = { request in ok(#"{"not":"an array"}"#, for: request) }
        await #expect(throws: NetworkError.decoding) {
            _ = try await makeStubbedClient().fetchNotes()
        }
    }

    @Test("a not-connected URLError throws .offline")
    func offlineError() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: NetworkError.offline) {
            _ = try await makeStubbedClient().fetchNotes()
        }
    }
}

// ----------------------------------------------------------------------------
// WHY URLProtocol is the right seam (write it before reading):
//
//   A networking client tested against a real server is tested against a
//   dependency that might be down, slow, or rate-limited when CI runs — flaky by
//   construction. URLProtocol intercepts requests BELOW the client, inside the
//   URL loading system, so the client code under test is exercised UNCHANGED
//   (real URLSession, real request building, real decode) but the bytes it
//   "receives" are whatever you canned. You can deterministically produce a 500,
//   a malformed body, or an offline error — cases a live server makes hard to
//   trigger on demand — with zero network and millisecond test times.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The stub is registered via `config.protocolClasses = [StubURLProtocol.self]`
//   on an EPHEMERAL config, then passed to the client's URLSession. Don't use
//   URLSession.shared — it ignores your protocolClasses.
//
// - To simulate a transport/offline error, THROW from the handler; the
//   `catch` calls `client?.urlProtocol(self, didFailWithError:)`, which surfaces
//   as the thrown URLError to the awaiting `session.data(from:)`.
//
// - `await #expect(throws:)` needs the error Equatable to match a specific case.
//   NetworkError is Equatable here. For non-Equatable errors, match the type:
//   `#expect(throws: NetworkError.self)` and inspect.
//
// - If a test "passes" suspiciously fast with no decode, confirm the handler is
//   set BEFORE the call and that `canInit` returns true so the stub intercepts.
//
// ----------------------------------------------------------------------------
