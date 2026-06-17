# Week 5 — Vapor: Server-Side Swift Fundamentals

Welcome to Week 5 of **C20 · Crunch Swift**. This is the week Swift stops being a language you write CLIs in and becomes a language you ship a *service* in. By Friday you will have stood up a Vapor 4 HTTP API on Linux, backed by a real Postgres database, authenticated with a bearer-token middleware, instrumented with structured logging, configured entirely from the environment, and shipped inside a Docker container that `docker compose up` brings to life with one command.

We are still on Linux. No Mac is required this week — and that is the point. Server-side Swift is the part of the Swift story that runs everywhere the cloud runs, and you are going to treat it the way you would treat any production service: typed at the edges, logged in the middle, configured from outside, and tested against a real database in a container, not a mock.

The mental shift this week is from "I call functions" to "I receive requests." A Vapor route handler is a function with a strange calling convention: the caller is the open internet, the argument is an untrusted `Request`, and the return value has to be something the framework knows how to turn into bytes on a socket. Swift's type system — `Codable`, `async/await`, `Sendable`, the actor model you spent weeks 3 and 4 internalising — is exactly the toolkit you want for that job. Vapor is the framework that wires it to a real HTTP server (SwiftNIO) and a real ORM (Fluent). This week you learn the shape of that wiring well enough to defend it in a code review.

We move fast. By the end you have built `notes-api` — the service that the SwiftUI client in Phase III will eventually talk to. Everything you write here is load-bearing for the rest of the track.

## Learning objectives

By the end of this week, you will be able to:

- **Scaffold** a Vapor 4 project from the official template, understand its layout (`configure.swift`, `routes.swift`, `entrypoint.swift`, the `App` module vs the executable target), and run it on Linux.
- **Route** HTTP requests with Vapor's `RoutesBuilder` — path components, route parameters, grouped routes, and the `RouteCollection` pattern for organising handlers.
- **Encode and decode** request and response bodies using the `Content` protocol on top of `Codable`, and explain how `Content` differs from raw `Codable`.
- **Model** a database table with a Fluent `Model`, write a forward-and-reverse `Migration`, and run migrations against Postgres with `swift run App migrate`.
- **Implement** full CRUD over a Fluent model — `create`, `all`, `find`, `update` (PATCH semantics), and `delete` — returning `Content`-conforming JSON.
- **Write** a `Middleware` that authenticates requests with a bearer token and rejects unauthenticated requests with the correct status, then protect a subset of routes with it.
- **Configure** the service entirely from the environment — database credentials, the API token, the log level — using Vapor's `Environment` and never committing a secret.
- **Emit** structured, level-controlled logs with `swift-log` and Vapor's `Logger`, with request-scoped metadata you can actually grep in production.
- **Containerise** the service with the official Vapor Dockerfile and stand up the full app-plus-database stack with `docker compose up`.

## Prerequisites

This week assumes you have completed **C20 weeks 1–4**, or have equivalent Swift fluency. Specifically:

- You can scaffold and run a Swift Package Manager executable (`swift package init`, `swift run`) — Week 1.
- You are comfortable with `Codable`, custom `Error` enums, and `Result` — Week 2.
- You understand `async`/`await`, `Task`, and structured concurrency — Week 3.
- You know what `Sendable` means and why the Swift 6 compiler enforces it — Week 4. Vapor 4 builds clean under strict concurrency, and you will see the compiler hold you to it.
- You can read and write basic Git, and you have run a `docker` command at least once.

You do **not** need any prior web-framework experience. If you have shipped Express, FastAPI, Rails, or ASP.NET Core, the routing and middleware concepts will transfer; we call out the analogies as we go. If you have never built a web service, this week teaches the concepts from the request up.

**Toolchain.** Swift 6.0+ from `swift.org`, Vapor 4 (via the `vapor` toolbox or by hand-editing `Package.swift`), Docker (Docker Desktop on macOS/Windows, or `docker` + `docker compose` on Linux), and Postgres 16 (you will run it in a container — no local install needed). Everything runs on Ubuntu 24.04, macOS, or Windows + WSL2.

## Topics covered

- What Vapor *is*: a web framework built on SwiftNIO, with Fluent (ORM), the `Content` protocol (serialisation), and an `async/await`-native request lifecycle.
- The Vapor 4 project layout: `Package.swift`, `Sources/App/`, `configure.swift`, `routes.swift`, `entrypoint.swift`, and the relationship between the `App` library target and the executable.
- The request lifecycle: socket → SwiftNIO `Channel` → `Application` → middleware chain → route handler → `Response`.
- Routing: `app.get`, `app.post`, path components, `:parameter` route parameters, `req.parameters.require`, route groups, and `RouteCollection`.
- The `Content` protocol: how `Codable` + `Content` lets you `req.content.decode(_:)` and `return someContent` with automatic `Content-Type` negotiation.
- JSON encoding/decoding: the default `JSONEncoder`/`JSONDecoder`, date strategies, snake_case ↔ camelCase, and per-route content configuration.
- Fluent fundamentals: the `Model` protocol, `@ID`, `@Field`, `@Timestamp`, the `Migration` protocol, and `Database` operations (`save`, `find`, `query`, `delete`).
- Postgres specifically: the `fluent-postgres-driver`, connection configuration, and connection pooling.
- Migrations: forward (`prepare`) and reverse (`revert`), the migration log table, and running them via the `migrate` command.
- Middleware: the `Middleware`/`AsyncMiddleware` protocol, the `responder.respond(to:)` chain, ordering, and where authentication lives.
- Bearer-token authentication: `BearerAuthenticator`, `req.auth`, `Authenticatable`, and the difference between *authenticating* and *guarding* a route.
- Environment configuration: `Environment.get(_:)`, `.env` files in development, and the rule that secrets come from the environment, never from source.
- Structured logging with `swift-log`: log levels, `Logger.Metadata`, request-scoped logging via `req.logger`, and choosing a log handler.
- Containerisation: the official Vapor Dockerfile (multi-stage build, `swift:6.0` builder, slim runtime image), `.dockerignore`, and `docker compose` for app + Postgres.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                               | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|-----------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Why Vapor; project layout; routing; the lifecycle   |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Content protocol; Fluent models; migrations; CRUD   |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Vapor vs the field; middleware; bearer-token auth   |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Environment config; structured logging; swift-log   |    1h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | Docker; compose; integration test; mini-project     |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0.5h    |     6h      |
| Saturday  | Mini-project deep work (`notes-api`)                |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, polish, push                          |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                     | **6h**   | **7.5h**  | **1h**     | **3.5h**  | **6h**   | **8.5h**     | **2h**     | **35.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Curated Vapor docs, Fluent docs, swift-log, SwiftNIO, and the comparison-framework reading |
| [lecture-notes/01-why-vapor-the-shape-of-a-production-swift-http-service.md](./02-lecture-notes/01-why-vapor-the-shape-of-a-production-swift-http-service.md) | What Vapor is, the request lifecycle, routing, Content, Fluent, migrations, environment, logging |
| [lecture-notes/02-vapor-vs-hummingbird-fastapi-express-rails.md](./02-lecture-notes/02-vapor-vs-hummingbird-fastapi-express-rails.md) | An honest comparison: when to reach for Vapor, Hummingbird, FastAPI, Express, or Rails |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-fluent-model-migration-crud.md](./03-exercises/exercise-01-fluent-model-migration-crud.md) | Define a Fluent model + migration for Postgres and wire up CRUD routes returning Content JSON |
| [exercises/exercise-02-bearer-auth-middleware.swift](./03-exercises/exercise-02-bearer-auth-middleware.swift) | Write a bearer-token authentication middleware and protect a subset of routes |
| [exercises/exercise-03-structured-logging-and-config.swift](./03-exercises/exercise-03-structured-logging-and-config.swift) | Add `swift-log` structured logging and environment-driven database configuration |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the weekly challenge |
| [challenges/challenge-01-problem-json-error-handling.md](./04-challenges/challenge-01-problem-json-error-handling.md) | RFC 9457 problem-JSON error responses across every notes endpoint, with tests for each failure path |
| [quiz.md](./05-quiz.md) | 12 multiple-choice questions with an answer key |
| [homework.md](./06-homework.md) | Six practice problems with deliverables and a rubric |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for the `notes-api` Vapor service mini-project |

## The "compose up and curl" promise

C20 uses a recurring marker for every server exercise that ends in a running service. After `docker compose up`, you should be able to run:

```bash
curl -s -H "Authorization: Bearer dev-token" http://localhost:8080/notes | jq
```

and get back a JSON array — even if it is empty (`[]`). If that command hangs, errors, or returns HTML, you are not done. A server you cannot `curl` is a server you cannot ship. The point of this week is to make that round-trip ordinary.

## A note on Swift 6 strict concurrency

Vapor 4's later releases compile clean under Swift 6 strict concurrency, and the template you scaffold this week enables it. That means the request lifecycle is `Sendable` end to end: a `Request` you hold across an `await` is checked, a closure you pass to `app.grouped(...)` is checked, and a value you stash in `req.storage` must conform to `Sendable`. This is the payoff of Week 4. You will occasionally fight the compiler over an actor boundary or a non-`Sendable` type, and every one of those fights is the compiler stopping a data race you would otherwise have shipped. Treat the warnings as bugs, exactly as you did in Week 4.

## Stretch goals

If you finish the regular work early and want to push further:

- Read the Vapor 4 docs end-to-end, starting from the "Getting Started → Hello, world" page: <https://docs.vapor.codes/>.
- Skim the SwiftNIO `README` to understand the event-loop model under Vapor: <https://github.com/apple/swift-nio>.
- Read the `swift-log` `README` and the rationale in its proposal — understand why Apple shipped a logging *API* package separate from any backend: <https://github.com/apple/swift-log>.
- Add a `GET /health` endpoint that pings the database with `req.db` and returns `200` only if the query succeeds. Most production services have exactly this.
- Wire `swift-metrics` and expose a `/metrics` endpoint in Prometheus format. (Phase IV's capstone wants this; getting ahead never hurts.)

## Up next

Continue to **Week 6 — Shared types, SwiftNIO basics, Phase I integration** once you have pushed `notes-api` to your GitHub. Week 6 extracts the request/response models from this week's service into a shared `NotesCore` SwiftPM package and writes a Swift CLI client against it — so the cleaner your `Content` types are this week, the easier next week will be. Build them well.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
