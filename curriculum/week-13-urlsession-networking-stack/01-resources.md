# Week 13 — Resources

Every primary resource on this page is **free**. Apple's developer documentation and WWDC sessions are free without a paid membership. Vapor and the open-source repos are public. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **`URLSession` — framework landing page.** The configuration, task, and async-API index:
  <https://developer.apple.com/documentation/foundation/urlsession>
- **"Fetching website data into memory."** Apple's canonical async-data article — read before you write `send`:
  <https://developer.apple.com/documentation/foundation/url-loading-system/fetching-website-data-into-memory>
- **`URLSessionConfiguration`.** Default vs ephemeral vs background, timeouts, `waitsForConnectivity`:
  <https://developer.apple.com/documentation/foundation/urlsessionconfiguration>
- **"Encoding and decoding custom types" / `Codable`.** Decoding strategies and failure modes:
  <https://developer.apple.com/documentation/foundation/archives-and-serialization/encoding-and-decoding-custom-types>
- **`URLProtocol`.** The interception point you use for hermetic tests:
  <https://developer.apple.com/documentation/foundation/urlprotocol>

## The types and APIs (reference, skim don't memorize)

- **`URLSession.data(for:)` / `.upload(for:from:)` / `.download(for:)`:** under <https://developer.apple.com/documentation/foundation/urlsession>
- **`URLSession.bytes(for:)` and `URLSession.AsyncBytes`** (the streaming `AsyncSequence`): <https://developer.apple.com/documentation/foundation/urlsession/asyncbytes>
- **`URLRequest`** (method, headers, body, cache policy, timeout): <https://developer.apple.com/documentation/foundation/urlrequest>
- **`HTTPURLResponse`** (status code, headers): <https://developer.apple.com/documentation/foundation/httpurlresponse>
- **`URLError`** (the transport error codes you map into your typed error): <https://developer.apple.com/documentation/foundation/urlerror>
- **`JSONDecoder` strategies** (`keyDecodingStrategy`, `dateDecodingStrategy`): <https://developer.apple.com/documentation/foundation/jsondecoder>
- **`DecodingError`** (the cases you turn into actionable messages): <https://developer.apple.com/documentation/swift/decodingerror>
- **`Network.framework` / `NWPathMonitor`** (the modern reachability API): <https://developer.apple.com/documentation/network/nwpathmonitor>

## WWDC sessions (free, watch in this order)

- **"Use async/await with URLSession"** (WWDC21) — the modern async networking APIs end to end:
  <https://developer.apple.com/videos/play/wwdc2021/10095/>
- **"Meet async/await in Swift"** (WWDC21) — the concurrency foundation the client is built on:
  <https://developer.apple.com/videos/play/wwdc2021/10132/>
- **"Reduce networking delays for a more responsive app"** (WWDC23) — connectivity, latency, and `waitsForConnectivity`:
  <https://developer.apple.com/videos/play/wwdc2023/10004/>
- **"Ready, set, relay"** / the URLSession and connectivity sessions — caching, background sessions, and connection behaviour (browse the Networking topic):
  <https://developer.apple.com/videos/networking-and-internet/>
- **"Eliminate data races using Swift Concurrency"** (WWDC22) — why the client is an actor and how `Sendable` crosses the request boundary:
  <https://developer.apple.com/videos/play/wwdc2022/110351/>

## The Vapor backend refresher (Phase I, the server this client talks to)

This week the iOS client talks to the `notes-api` Vapor service you built in Weeks 5–6, using the shared `NotesCore` `Codable` models from Week 6.

- **Vapor docs** — routing, `Content`, Fluent (in case your service needs a tune-up): <https://docs.vapor.codes/>
- **The Phase I `notes-api`** — your own repo. Bring it up locally with `docker compose up` (the Dockerfile and compose file you wrote in Week 5). The client expects `POST /notes`, `GET /notes`, `GET /notes/:id`, `PATCH /notes/:id`, `DELETE /notes/:id`, bearer-token-authenticated.
- **The shared `NotesCore` package** (Week 6) — the `struct Note: Codable, Sendable` imported by both server and client. This is the contract that makes the client's decode type-checked against the server's encode.

## Community writing (current, opinionated, correct)

- **Donny Wals — "Networking in Swift" and the async URLSession series.** The most production-focused writing on building a real client, retries, and error modelling:
  <https://www.donnywals.com/category/swift/>
- **Swift by Sundell — networking and Codable articles.** Clean treatments of the typed-endpoint pattern and decoding strategies:
  <https://www.swiftbysundell.com/>
- **Hacking with Swift — URLSession and Codable guides.** Paul Hudson's free, current references:
  <https://www.hackingwithswift.com/quick-start/concurrency>
- **AWS Architecture Blog — "Exponential Backoff And Jitter."** The canonical writeup on *why* jitter matters (it's an AWS post but the math is universal):
  <https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/>
- **Point-Free — dependencies and `URLSession` testing.** How to make networking a swappable dependency and test it without the network (some free episodes):
  <https://www.pointfree.co/collections/dependencies>

## Tools you'll use this week

- **Xcode 16+** — URLSession and the concurrency runtime ship with the SDK.
- **The Vapor `notes-api`** — running locally (`docker compose up` or `swift run` from your Phase I repo). The client points at `http://localhost:8080` by default.
- **`mitmproxy`** (free, recommended over Charles) — inspect the actual HTTP traffic your client sends: `mitmproxy` or `mitmweb`, then point the Simulator at the proxy. Seeing the real request headers and JSON body makes the typed `Endpoint` concrete: <https://mitmproxy.org/>
- **`curl` / `httpie`** — sanity-check the server independently of the client. `curl -H "Authorization: Bearer <token>" http://localhost:8080/notes`.
- **The Network Link Conditioner** (in Xcode's Additional Tools, free) — simulate slow/lossy/offline networks on the Simulator to test retries and offline-first behaviour without unplugging anything.
- **`URLProtocol`** — not a tool but the testing seam; the exercises use it to make the suite hermetic.

## Free reading (chapter-level, not whole books)

- **Apple's "URL Loading System" article group** (linked above) is effectively a free networking primer — the "Fetching website data," "Uploading data," and "Downloading files" articles cover the async surface end to end.
- **The Swift Programming Language — "Concurrency" chapter** for the `async`/`await`/cancellation foundation the retry loop relies on.

## Paid books (optional, clearly marked)

- **"Practical Server-Side Swift" / Vapor books** (paid) — if you want to deepen the *server* side of the contract; not required, your Phase I service is enough.
- **"Swift Networking" deep-dive titles** (various, paid) — most are dated against the async APIs; prefer the free Apple async URLSession session and Donny Wals' current articles over any pre-2021 book.

---

*If a link 404s, please open an issue so we can replace it.*
