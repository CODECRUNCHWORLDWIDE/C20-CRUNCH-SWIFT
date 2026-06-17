# Week 6 — Resources

Every resource on this page is **free**. swift.org docs, the Swift book, and Apple's developer docs are free without an account. The Swift Server Workgroup packages are open source on GitHub. No paywalled books are linked. Links are current as of June 2026; if one rots, open an issue.

## Required reading (work it into your week)

- **The Swift Programming Language — "Modules and Source Files" / package basics**, the canonical reference for how a module is a unit of distribution:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/>
- **Swift Package Manager — Package.swift manifest reference**, every field you touch when you add a `path:` dependency:
  <https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html>
- **Encoding and Decoding Custom Types (`Codable`)** — Apple's reference on `Encodable`/`Decodable`, `CodingKeys`, and custom strategies:
  <https://developer.apple.com/documentation/foundation/archives-and-serialization/encoding-and-decoding-custom-types>
- **`Sendable` and sendable closures** — the chapter that explains why your value-type wire models are `Sendable` for free:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types>
- **swift-nio README** — the project front page; read the "Basic architecture" and "Conceptual overview" sections:
  <https://github.com/apple/swift-nio>

## SwiftPM — the workspace topology

- **Organizing your code with local packages** — Apple's guide to splitting a codebase into local packages:
  <https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages>
- **`swift package` CLI reference** — `swift build`, `swift test`, `swift run`, `swift package resolve`, `swift package describe`:
  <https://docs.swift.org/package-manager/PackageDescription/index.html>
- **Swift Package Manager source** — read `Package.swift` of a real package to see idiomatic manifests:
  <https://github.com/swiftlang/swift-package-manager>

## swift-nio — the runtime under Vapor

- **swift-nio docs (DocC)** — `EventLoopGroup`, `EventLoop`, `EventLoopFuture`, `Channel`, `ChannelPipeline`:
  <https://swiftpackageindex.com/apple/swift-nio/documentation/niocore>
- **"SwiftNIO" — the original WWDC introduction** (still the clearest mental-model talk; concepts unchanged):
  <https://developer.apple.com/videos/play/wwdc2019/704/>
- **`EventLoopFuture` and `EventLoopPromise`** — the futures model nio is built on, and how `async`/`await` bridges it:
  <https://swiftpackageindex.com/apple/swift-nio/documentation/niocore/eventloopfuture>
- **Swift Server Workgroup** — the governance body for server-side Swift; read the incubation process and the package list:
  <https://www.swift.org/sswg/>

## Vapor and Hummingbird

- **Vapor docs** — the framework you already use; the "Async" and "Content" pages are relevant this week:
  <https://docs.vapor.codes/>
- **Hummingbird 2 docs** — the async-first, lighter-weight alternative; read "Getting Started" and "Router":
  <https://docs.hummingbird.codes/2.0/documentation/hummingbird/>
- **Hummingbird source** — small enough to read; see how a router sits directly on swift-nio:
  <https://github.com/hummingbird-project/hummingbird>
- **"Vapor vs Hummingbird" — Swift Server Workgroup ecosystem overview** (the SSWG package index is the neutral reference):
  <https://www.swift.org/packages/server.html>

## OpenTelemetry-Swift and distributed tracing

- **swift-distributed-tracing** — the Apple/SSWG tracing API that `Tracer`, spans, and instrumentation build on:
  <https://github.com/apple/swift-distributed-tracing>
- **OpenTelemetry Swift** — the OTLP-exporting implementation of the tracing API:
  <https://github.com/open-telemetry/opentelemetry-swift>
- **OpenTelemetry — traces concepts** — vendor-neutral definitions of span, trace, context propagation:
  <https://opentelemetry.io/docs/concepts/signals/traces/>
- **swift-log** — the logging API you already use; tracing complements it, it does not replace it:
  <https://github.com/apple/swift-log>

## swift-collections

- **swift-collections** — the package: `OrderedDictionary`, `OrderedSet`, `Deque`, `Heap`, `BitSet`, `TreeDictionary`:
  <https://github.com/apple/swift-collections>
- **swift-collections DocC** — the per-type docs with complexity notes:
  <https://swiftpackageindex.com/apple/swift-collections/documentation>
- **"Swift Collections" announcement** — the Swift blog post that introduced the package and the design rationale:
  <https://www.swift.org/blog/swift-collections/>
- **`Heap` documentation** — the min-max heap; read the complexity table before you reach for it:
  <https://swiftpackageindex.com/apple/swift-collections/documentation/heapmodule/heap>

## Testing and coverage

- **Swift Testing** — the `@Test`/`#expect` framework you have used since Week 1; the "Migrating from XCTest" and parameterized-test pages are relevant:
  <https://developer.apple.com/documentation/testing>
- **Code coverage with SwiftPM** — `swift test --enable-code-coverage` and reading the `.profdata` with `llvm-cov`:
  <https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Usage.md>
- **`llvm-cov` report** — the LLVM tool SwiftPM emits coverage for:
  <https://llvm.org/docs/CommandGuide/llvm-cov.html>

## Foundation networking

- **`URLSession`** — the async `data(for:)` API you build the CLI on:
  <https://developer.apple.com/documentation/foundation/urlsession>
- **`URLRequest`** — setting method, headers, and body for the bearer-authed calls:
  <https://developer.apple.com/documentation/foundation/urlrequest>
- **swift-corelibs-foundation** — the open-source Foundation that ships in the Linux toolchain; confirm an API exists on Linux before you rely on it:
  <https://github.com/swiftlang/swift-corelibs-foundation>

## Tools you'll use this week

- **The Swift 6 toolchain** — `swift build`, `swift test`, `swift run`. Verify with `swift --version`.
- **Docker** — to run the Week 5 Postgres and (stretch) an OpenTelemetry Collector. `docker --version` to confirm.
- **`curl`** — to sanity-check the API by hand before you point the CLI at it. Preinstalled on macOS and Linux.
- **`jq`** (optional) — to pretty-print JSON responses while debugging the wire format.

## Talks and posts (free, no signup)

- **"On the Road to Swift 6"** — the swift.org content covering strict concurrency and `Sendable`, which underpins why your shared types are safe to cross a process boundary by value:
  <https://www.swift.org/migration/documentation/migrationguide/>
- **Swift Server-Side Swift conference talks** (ServerSide.swift) — recorded sessions on nio, Vapor, Hummingbird, and tracing:
  <https://www.serversideswift.info/>
- **The Swift Server Workgroup forum** — where the ecosystem actually discusses design; search for "tracing" or "Hummingbird 2":
  <https://forums.swift.org/c/server/43>

## Open-source projects to read this week

You learn more from one hour reading a well-structured `Package.swift` than from three hours of tutorials. Pick one and scroll through:

- **`apple/swift-nio`** — the event-loop runtime; read `Sources/NIOCore/EventLoopFuture.swift`:
  <https://github.com/apple/swift-nio>
- **`hummingbird-project/hummingbird`** — a complete async-first server framework, small enough to read in an afternoon:
  <https://github.com/hummingbird-project/hummingbird>
- **`apple/swift-collections`** — read `Sources/DequeModule/Deque.swift` to see how a ring buffer is implemented in Swift:
  <https://github.com/apple/swift-collections>
- **`vapor/vapor`** — the framework you use; read how a `Request` decodes `Content` and where `async` handlers bridge nio:
  <https://github.com/vapor/vapor>

## Glossary cheat sheet

Keep this open in a tab.

| Term | Plain English |
|------|---------------|
| **SwiftPM** | Swift Package Manager. Builds, tests, and resolves dependencies for Swift packages. |
| **Module** | The unit of code distribution and the namespace boundary. A target compiles to one module. |
| **Target** | A buildable unit in a package — a library, an executable, or a test suite. |
| **Product** | What a package exposes to consumers — a `.library` or an `.executable`. |
| **`path:` dependency** | A local package dependency referenced by filesystem path, not a Git URL. |
| **DTO** | Data Transfer Object — the type you put on the wire, distinct from your persistence model. |
| **`Codable`** | `Encodable & Decodable`. The protocol that powers JSON encode/decode. |
| **`Sendable`** | A type safe to pass across concurrency domains. Value types of `Sendable` members are `Sendable`. |
| **swift-nio** | The non-blocking event-loop networking library Vapor and Hummingbird are built on. |
| **`EventLoop`** | A single thread running a run loop that processes I/O and scheduled work. |
| **`EventLoopFuture`** | nio's promise/future type; the value that may not exist yet. `async`/`await` bridges it. |
| **`Channel`** | A nio connection (a socket). Data flows through its `ChannelPipeline` of handlers. |
| **OTLP** | OpenTelemetry Protocol — the wire format for exporting traces/metrics to a collector. |
| **Span** | A single timed operation in a trace (e.g. "handle POST /notes", "INSERT into notes"). |
| **`Deque`** | Double-ended queue. O(1) push/pop at both ends. From swift-collections. |
| **`Heap`** | A min-max heap. O(log n) insert, O(1) peek-min/max. From swift-collections. |

---

*If a link 404s, please open an issue so we can replace it.*
