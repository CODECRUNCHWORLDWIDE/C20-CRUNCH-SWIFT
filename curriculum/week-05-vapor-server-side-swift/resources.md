# Week 5 — Resources

Every resource on this page is **free**. The Vapor documentation, the Vapor and Fluent source repositories, and every Apple `swift-*` package are open source (MIT or Apache-2.0). The Swift on Server working-group material is free. The comparison-framework docs (Hummingbird, FastAPI, Express, Rails) are all freely available. No paywalled books are linked; the one book mentioned — *Server-Side Swift with Vapor* by raywenderlich.com / Kodeco — has a freely readable web edition that the link points at.

These were current as of the **2026** Swift on Server ecosystem: Swift 6.x, Vapor 4.x, Fluent 4.x, SwiftNIO 2.x, swift-log 1.x. Where Vapor 5 (in development through 2025–2026) changes an API, the docs note it; we teach Vapor 4 because that is what ships in production today.

## Required reading (work it into your week)

- **Vapor — official documentation home**:
  <https://docs.vapor.codes/>
- **Vapor — "Getting Started → Hello, world"** (scaffold and run your first service):
  <https://docs.vapor.codes/getting-started/hello-world/>
- **Vapor — "Basics → Routing"** (path components, parameters, route groups):
  <https://docs.vapor.codes/basics/routing/>
- **Vapor — "Basics → Content"** (the `Content` protocol, encoding/decoding, content configuration):
  <https://docs.vapor.codes/basics/content/>
- **Vapor — "Basics → Middleware"** (the middleware chain, ordering, `AsyncMiddleware`):
  <https://docs.vapor.codes/basics/middleware/>
- **Vapor — "Basics → Errors"** (`Abort`, `AbortError`, `ErrorMiddleware`):
  <https://docs.vapor.codes/basics/errors/>
- **Vapor — "Fluent → Overview"** (the ORM model, drivers, the `Model` protocol):
  <https://docs.vapor.codes/fluent/overview/>
- **Vapor — "Fluent → Model"** (`@ID`, `@Field`, `@Timestamp`, `@Parent`/`@Children`):
  <https://docs.vapor.codes/fluent/model/>
- **Vapor — "Fluent → Migration"** (the `Migration` protocol, `prepare`/`revert`, schema builder):
  <https://docs.vapor.codes/fluent/migration/>
- **Vapor — "Fluent → Query"** (filtering, sorting, `find`, `all`, `first`):
  <https://docs.vapor.codes/fluent/query/>
- **Vapor — "Security → Authentication"** (`Authenticator`, `BearerAuthenticator`, `req.auth`, `guardMiddleware`):
  <https://docs.vapor.codes/security/authentication/>
- **Vapor — "Advanced → Logging"** (`swift-log` integration, `req.logger`, metadata):
  <https://docs.vapor.codes/advanced/logging/>
- **Vapor — "Deploy → Docker"** (the official Dockerfile and `docker-compose.yml`):
  <https://docs.vapor.codes/deploy/docker/>

## Authoritative deep dives

- **Apple `swift-log` — README and design rationale** — why Apple shipped a logging *API* (not a backend), how `LogHandler` is pluggable, and what `Logger.Metadata` is for:
  <https://github.com/apple/swift-log>
- **Apple `swift-metrics`** — the companion metrics API; you will want it for the capstone:
  <https://github.com/apple/swift-metrics>
- **Apple SwiftNIO — README** — the event-loop, non-blocking I/O foundation Vapor is built on. Read the "Basic concepts" and "Channel pipeline" sections to understand what is under Vapor:
  <https://github.com/apple/swift-nio>
- **Swift on Server — the Swift.org "Server" landing page** — the working group's overview of the server ecosystem, including the SSWG (Server-Side Swift Work Group) incubated packages:
  <https://www.swift.org/server/>
- **Swift Server Work Group — package incubation process and graduated packages** — how `swift-log`, `swift-metrics`, AsyncHTTPClient, and others reached production maturity:
  <https://github.com/swift-server/sswg>
- **PostgresNIO — README** — the non-blocking Postgres client that `fluent-postgres-driver` sits on top of; read it when you need to drop below Fluent to raw SQL:
  <https://github.com/vapor/postgres-nio>
- **Tim Condon — "Server-Side Swift" talks and blog** — Tim is a Vapor core contributor and the clearest current voice on production Vapor; his talks cover testing, auth, and deployment:
  <https://www.timc.dev/>

## Official Swift/Vapor API references

- **Vapor API documentation (DocC, generated from source)**:
  <https://api.vapor.codes/>
- **Fluent API documentation**:
  <https://api.vapor.codes/fluentkit/documentation/fluentkit/>
- **swift-log API documentation**:
  <https://swiftpackageindex.com/apple/swift-log/documentation/logging>
- **SwiftNIO API documentation**:
  <https://swiftpackageindex.com/apple/swift-nio/documentation/nio>
- **`Codable` (the foundation of `Content`)**:
  <https://developer.apple.com/documentation/swift/codable>

## Source repos worth skimming

- **`vapor/vapor`** — the framework itself. Look at `Sources/Vapor/Middleware/` for the middleware protocol, `Sources/Vapor/Content/` for the `Content` machinery, and `Sources/Vapor/Routing/` for how routes register:
  <https://github.com/vapor/vapor>
- **`vapor/fluent` and `vapor/fluent-kit`** — the ORM. `FluentKit` holds the `Model`, `Migration`, and query builder; `Fluent` is the Vapor integration layer:
  <https://github.com/vapor/fluent-kit>
- **`vapor/fluent-postgres-driver`** — the Postgres driver that turns Fluent queries into Postgres wire protocol via PostgresNIO:
  <https://github.com/vapor/fluent-postgres-driver>
- **`vapor/template`** — the official `vapor new` project template. Reading it top to bottom is the fastest way to learn the canonical layout:
  <https://github.com/vapor/template>

## The comparison frameworks (Lecture 2 reading)

Lecture 2 compares Vapor to four other ways to build an HTTP service. Skim each one's "getting started" so the comparison is grounded in code you have actually seen:

- **Hummingbird — the lighter-weight Swift server framework** (the SSWG-incubated alternative to Vapor; v2 is fully `async`/`await` and structured-concurrency native):
  <https://github.com/hummingbird-project/hummingbird>
  Docs: <https://docs.hummingbird.codes/>
- **FastAPI — Python's typed, async web framework** (the closest philosophical cousin to Vapor in another language; both lean on type annotations for serialisation and validation):
  <https://fastapi.tiangolo.com/>
- **Express — the Node.js minimalist framework** (the canonical "unopinionated middleware chain" the rest of the industry compares against):
  <https://expressjs.com/>
- **Ruby on Rails — the opinionated full-stack framework** (the high-convention end of the spectrum; ActiveRecord is the ORM Fluent is most often compared to):
  <https://guides.rubyonrails.org/>

## Books and longer-form

- **Tim Condon et al. — *Server-Side Swift with Vapor* (Kodeco / raywenderlich.com)** — the standard book-length Vapor introduction. The web edition is free to read; it tracks Vapor 4 and covers Fluent, auth, and deployment in more depth than the docs:
  <https://www.kodeco.com/books/server-side-swift-with-vapor>
- **RFC 9457 — "Problem Details for HTTP APIs"** — the standard you implement in this week's challenge. It supersedes RFC 7807. Short, readable, and worth reading in full:
  <https://www.rfc-editor.org/rfc/rfc9457.html>
- **RFC 9110 — "HTTP Semantics"** — the authoritative reference for what each status code *means*. You will reach for it when deciding between `400`, `404`, `409`, and `422`:
  <https://www.rfc-editor.org/rfc/rfc9110.html>
- **The Twelve-Factor App** — the configuration discipline this week's environment-config lecture is built on; "III. Config" is the section that matters:
  <https://12factor.net/config>

## Talks worth watching (all free, no account)

- **"Server-Side Swift" track at ServerSide.swift conference** — the annual conference for the ecosystem; talks are posted to YouTube. Search for the most recent year's "ServerSide.swift" playlist:
  <https://www.serversideswift.info/>
- **Tim Condon — Vapor and server-side Swift talks** (various conferences, on YouTube): search YouTube for "Tim Condon Vapor".
- **WWDC — "Use async/await with URLSession"** — not Vapor, but the clearest Apple explanation of the `async` request model your handlers live in: search the Apple Developer videos site for "async await URLSession".

## How to use this resource list

The lectures cite specific URLs from this page at decision points. When a lecture says "see the Vapor Routing docs," the URL is above. You do not need to read every link this week — even senior server engineers re-read the Fluent migration docs every time they touch a schema. The links to read end-to-end this week are:

1. **Vapor — "Getting Started → Hello, world"** and **"Basics → Routing"**. Foundational; do not skip.
2. **Vapor — "Basics → Content"**. The protocol your entire JSON API rests on.
3. **Vapor — "Fluent → Migration"**. The one people most often get wrong; read it twice.
4. **Apple `swift-log` README**. ~20 minutes, decisive for the logging exercise and homework.
5. **RFC 9457**. ~25 minutes, the spec the challenge implements.

The rest are reference material — bookmark and return when a specific question arises.

---

*Bookmarks decay. If a link rots, search the title — the Vapor docs and the Apple `swift-*` repos are canonical and reappear at the same homes.*
