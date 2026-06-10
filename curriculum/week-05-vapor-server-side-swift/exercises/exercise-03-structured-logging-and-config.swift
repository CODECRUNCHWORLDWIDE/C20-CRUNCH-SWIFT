// Exercise 3 — Structured logging and environment-driven configuration
//
// Goal: Add swift-log structured logging with request-scoped metadata, and move
//       ALL database credentials and the API token into environment-driven
//       configuration that FAILS LOUDLY at boot when a required secret is missing.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// 1. Continue in the `notes-api` project from Exercises 1 and 2.
//
// 2. Create Sources/App/AppConfig.swift and paste the "TYPED CONFIG" section.
//    Fill in the TODOs. This is the single struct that reads the environment.
//
// 3. Create Sources/App/Middleware/StructuredLoggingMiddleware.swift and paste
//    the "LOGGING MIDDLEWARE" section. Fill in the TODOs.
//
// 4. Rewrite configure(_:) along the lines of the "CONFIGURE" section so it (a)
//    bootstraps the log level from LOG_LEVEL, (b) loads AppConfig from the
//    environment, and (c) installs the logging middleware.
//
// 5. Add structured metadata to the create handler as shown in "HANDLER LOGGING".
//
// 6. Run with explicit env and watch the structured output:
//
//        export DATABASE_HOST=localhost DATABASE_USERNAME=notes \
//               DATABASE_PASSWORD=notes DATABASE_NAME=notes \
//               API_TOKEN=dev-token LOG_LEVEL=info
//        swift run App serve --hostname 0.0.0.0 --port 8080
//
//    Then in another terminal create a note and read the log line it produces.
//
// ACCEPTANCE CRITERIA
//
//   [ ] `swift build`: 0 warnings, 0 errors under strict concurrency.
//   [ ] ALL database credentials come from AppConfig (no literals in configure).
//   [ ] A missing REQUIRED secret (DATABASE_PASSWORD or API_TOKEN) makes the
//       service refuse to boot, with a clear message naming the missing var.
//   [ ] LOG_LEVEL controls the floor: with LOG_LEVEL=info, .debug lines vanish;
//       with LOG_LEVEL=debug they appear.
//   [ ] Each request's logs carry a `request_id` in their metadata, and a
//       `method` + `path` on the access line.
//   [ ] The create handler logs an `info` event with `note_id` and
//       `title_length` as STRUCTURED metadata (not string-interpolated).
//   [ ] `.env` is in `.gitignore`; you committed a `.env.example` instead.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Vapor
import Logging

// ============================================================================
// TYPED CONFIG   (Sources/App/AppConfig.swift)
// ============================================================================
//
// One struct, loaded once at boot, that reads every environment variable the
// service needs. Required secrets have NO default — a missing one throws. Values
// with a safe development default use `?? default`. The distinction is the whole
// lesson: "host=localhost" is a fine default for your laptop; "password=" is
// never a safe default and must fail.

struct AppConfig: Sendable {
    struct DatabaseConfig: Sendable {
        let host: String
        let port: Int
        let username: String
        let password: String
        let database: String
    }

    let database: DatabaseConfig
    let apiToken: String

    enum ConfigError: Error, CustomStringConvertible {
        case missing(String)
        var description: String {
            switch self {
            case .missing(let key):
                return "Required environment variable \(key) is not set. The service refuses to boot."
            }
        }
    }

    // Reads from the environment. Throws ConfigError.missing(...) naming the
    // first missing required variable.
    static func load() throws -> AppConfig {
        // A small helper so the required reads read cleanly below.
        func require(_ key: String) throws -> String {
            guard let value = Environment.get(key), !value.isEmpty else {
                throw ConfigError.missing(key)
            }
            return value
        }

        // TODO:
        //   - host:     Environment.get("DATABASE_HOST") ?? "localhost"   (safe default)
        //   - port:     Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432
        //   - username: Environment.get("DATABASE_USERNAME") ?? "notes"   (safe default)
        //   - password: try require("DATABASE_PASSWORD")                  (REQUIRED, no default)
        //   - database: Environment.get("DATABASE_NAME") ?? "notes"
        //   - apiToken: try require("API_TOKEN")                          (REQUIRED, no default)
        // Build and return the AppConfig.
        fatalError("TODO: implement AppConfig.load()")
    }
}

// ============================================================================
// LOGGING MIDDLEWARE   (Sources/App/Middleware/StructuredLoggingMiddleware.swift)
// ============================================================================
//
// Vapor already stamps a request UUID into req.logger's metadata. This middleware
// adds an access-log line per request — method, path, status, and duration —
// all as structured metadata so a log aggregator can filter on any field.

struct StructuredLoggingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let start = ContinuousClock.now

        // TODO:
        //   1. Call `let response = try await next.respond(to: request)`.
        //      Wrap it so that even if it THROWS you still log the failure
        //      (use do/catch; rethrow after logging).
        //   2. Compute the elapsed time: `let elapsed = ContinuousClock.now - start`.
        //   3. Log an `info` line through request.logger with metadata:
        //        "method": .string(request.method.rawValue)
        //        "path":   .string(request.url.path)
        //        "status": .stringConvertible(response.status.code)
        //        "duration_ms": .stringConvertible(elapsed milliseconds)
        //      (request_id is already in req.logger's metadata — don't re-add it.)
        //   4. Return the response.
        fatalError("TODO: implement respond(to:chainingTo:)")
    }
}

// ============================================================================
// CONFIGURE   (rewrite configure.swift along these lines)
// ============================================================================
//
//   import Vapor
//   import Fluent
//   import FluentPostgresDriver
//   import Logging
//
//   func configure(_ app: Application) async throws {
//       // 1. Load typed config from the environment (fails loud if a secret is missing).
//       let config = try AppConfig.load()
//
//       // 2. Database — credentials come from `config`, not literals.
//       app.databases.use(
//           .postgres(
//               configuration: SQLPostgresConfiguration(
//                   hostname: config.database.host,
//                   port: config.database.port,
//                   username: config.database.username,
//                   password: config.database.password,
//                   database: config.database.database,
//                   tls: .disable
//               )
//           ),
//           as: .psql
//       )
//
//       app.migrations.add(CreateNote())
//
//       // 3. JSON wire format (from Exercise 1).
//       let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
//       let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
//       ContentConfiguration.global.use(encoder: encoder, for: .json)
//       ContentConfiguration.global.use(decoder: decoder, for: .json)
//
//       // 4. Middleware — error handling, then our access log.
//       app.middleware.use(ErrorMiddleware.default(environment: app.environment))
//       app.middleware.use(StructuredLoggingMiddleware())
//
//       // 5. Routes (auth wiring from Exercise 2).
//       app.get("health") { _ async -> [String: String] in ["status": "ok"] }
//       let apiConfig = APITokenConfig(expectedToken: config.apiToken)
//       try NotesAuthRouting.boot(routes: app, config: apiConfig)
//   }
//
// NOTE ON THE LOG LEVEL:
//   The log level floor is set by LoggingSystem.bootstrap(from:&env) in
//   entrypoint.swift, which reads the `--log` flag and the LOG_LEVEL env var.
//   You do NOT set it in configure. To verify: run with LOG_LEVEL=debug and add
//   a `app.logger.debug("boot config loaded")` in configure — it appears. Run
//   with LOG_LEVEL=info — it vanishes.

// ============================================================================
// HANDLER LOGGING   (add to NotesController.create)
// ============================================================================
//
//   func create(req: Request) async throws -> Response {
//       let input = try req.content.decode(CreateNoteRequest.self)
//       let note = Note(title: input.title, body: input.body)
//       try await note.create(on: req.db)
//       req.logger.info("created note", metadata: [
//           "note_id": .string(note.id?.uuidString ?? "nil"),
//           "title_length": .stringConvertible(input.title.count),
//       ])
//       return try await note.encodeResponse(status: .created, for: req)
//   }

// ============================================================================
// .env.example   (commit this; .gitignore the real .env)
// ============================================================================
//
//   # Copy to .env and fill in real values. .env is gitignored.
//   DATABASE_HOST=localhost
//   DATABASE_PORT=5432
//   DATABASE_USERNAME=notes
//   DATABASE_PASSWORD=change-me
//   DATABASE_NAME=notes
//   API_TOKEN=dev-token
//   LOG_LEVEL=info

// ============================================================================
// EXPECTED OUTPUT
// ============================================================================
//
//   $ unset API_TOKEN
//   $ swift run App serve
//   Fatal error: Required environment variable API_TOKEN is not set. The service refuses to boot.
//
//   $ export API_TOKEN=dev-token DATABASE_PASSWORD=notes LOG_LEVEL=info
//   $ swift run App serve --hostname 0.0.0.0 --port 8080
//   [ NOTICE ] Server started on http://0.0.0.0:8080
//
//   # In another terminal:
//   $ curl -s -X POST localhost:8080/notes -H 'Authorization: Bearer dev-token' \
//       -H 'Content-Type: application/json' -d '{"title":"hi","body":"there"}'
//
//   # The server prints two structured lines (format depends on the backend):
//   [ INFO ] created note [note_id: 7C9A..., title_length: 2] [request_id: 0F2B...]
//   [ INFO ] request [method: POST, path: /notes, status: 201, duration_ms: 14] [request_id: 0F2B...]
//
// ============================================================================
// HINTS (read only if stuck > 15 min)
// ============================================================================
//
// AppConfig.load():
//   static func load() throws -> AppConfig {
//       func require(_ key: String) throws -> String {
//           guard let v = Environment.get(key), !v.isEmpty else { throw ConfigError.missing(key) }
//           return v
//       }
//       let db = DatabaseConfig(
//           host: Environment.get("DATABASE_HOST") ?? "localhost",
//           port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
//           username: Environment.get("DATABASE_USERNAME") ?? "notes",
//           password: try require("DATABASE_PASSWORD"),
//           database: Environment.get("DATABASE_NAME") ?? "notes"
//       )
//       return AppConfig(database: db, apiToken: try require("API_TOKEN"))
//   }
//
// StructuredLoggingMiddleware.respond:
//   func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
//       let start = ContinuousClock.now
//       do {
//           let response = try await next.respond(to: request)
//           let ms = (ContinuousClock.now - start).components.attoseconds / 1_000_000_000_000_000
//           request.logger.info("request", metadata: [
//               "method": .string(request.method.rawValue),
//               "path": .string(request.url.path),
//               "status": .stringConvertible(response.status.code),
//               "duration_ms": .stringConvertible(ms),
//           ])
//           return response
//       } catch {
//           let ms = (ContinuousClock.now - start).components.attoseconds / 1_000_000_000_000_000
//           request.logger.error("request failed", metadata: [
//               "method": .string(request.method.rawValue),
//               "path": .string(request.url.path),
//               "duration_ms": .stringConvertible(ms),
//               "error": .string(String(describing: error)),
//           ])
//           throw error
//       }
//   }
//
// Why a typed AppConfig instead of scattering Environment.get everywhere?
//   Because configuration is a CONTRACT. A single struct that reads the env at
//   boot, in one place, lets you (a) see the whole contract at a glance, (b) fail
//   fast and loud when a secret is missing — with a message that NAMES the
//   variable — instead of failing mysteriously on the first query, and (c) pass
//   an immutable Sendable value around instead of reaching into process state from
//   deep in a handler. This is the same discipline you'd apply to any config in a
//   real service; Swift's type system just makes it cheap.
//
// Why does swift-log separate the API from the backend?
//   So a LIBRARY can log without choosing where the logs go. Fluent logs through
//   swift-log; so does your code; so does Vapor. The APPLICATION bootstraps ONE
//   backend (console in dev, JSON-to-stdout in prod, shipped to your aggregator)
//   and every logger in the process routes there. That is why
//   LoggingSystem.bootstrap must run exactly once, before anything logs.
