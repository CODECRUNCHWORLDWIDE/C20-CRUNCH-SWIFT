# Exercise 1 — Fluent Model, Migration, and CRUD Routes

**Goal:** Define a `Note` Fluent model and a Postgres migration, then wire up the five CRUD routes (`POST`, `GET`-list, `GET`-by-id, `PATCH`, `DELETE`) returning `Content`-conforming JSON. By the end you can create a note with `curl`, read it back, update it, list all of them, and delete one — against a real Postgres database in a container.

**Estimated time:** 70 minutes.

This is the spine of the whole week. Exercise 2 protects these routes with auth; Exercise 3 instruments them with logging; the mini-project hardens them into `notes-api`. Build this carefully.

---

## Setup

You need the Swift 6 toolchain and Docker. Verify:

```bash
swift --version    # expect 6.0 or newer
docker --version   # expect a real version
```

Start a Postgres 16 container the service will talk to:

```bash
docker run -d --name notes-pg \
  -e POSTGRES_USER=notes \
  -e POSTGRES_PASSWORD=notes \
  -e POSTGRES_DB=notes \
  -p 5432:5432 \
  postgres:16
```

Confirm it is up:

```bash
docker exec notes-pg pg_isready -U notes
# /var/run/postgresql:5432 - accepting connections
```

Leave it running for the whole exercise. When you are done: `docker rm -f notes-pg`.

---

## Step 1 — Scaffold the project

Create the package by hand so you see every file:

```bash
mkdir notes-api && cd notes-api
swift package init --type executable --name App
```

That gives you a bare executable. Replace `Package.swift` with the Vapor + Fluent + Postgres manifest:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "notes-api",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
```

Delete the generated `Sources/App/App.swift` (or `main.swift`) — we will create the proper files. Make the directory structure:

```bash
mkdir -p Sources/App/Controllers Sources/App/Models Sources/App/Migrations
```

Fetch dependencies (this takes a minute the first time):

```bash
swift package resolve
```

---

## Step 2 — The entrypoint

Create `Sources/App/entrypoint.swift`:

```swift
import Vapor
import Logging
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.execute()
        try await app.asyncShutdown()
    }
}
```

---

## Step 3 — The model

Create `Sources/App/Models/Note.swift`:

```swift
import Fluent
import Vapor

final class Note: Model, Content, @unchecked Sendable {
    static let schema = "notes"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "body")
    var body: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}
```

Because `Note: Content`, it serialises to JSON for free. The `@Timestamp` fields are managed by Fluent — you never set them yourself.

---

## Step 4 — The migration

Create `Sources/App/Migrations/CreateNote.swift`:

```swift
import Fluent

struct CreateNote: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("notes")
            .id()
            .field("title", .string, .required)
            .field("body", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("notes").delete()
    }
}
```

---

## Step 5 — configure(_:)

Create `Sources/App/configure.swift`:

```swift
import Vapor
import Fluent
import FluentPostgresDriver

func configure(_ app: Application) async throws {
    app.databases.use(
        .postgres(
            configuration: SQLPostgresConfiguration(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init)
                    ?? SQLPostgresConfiguration.ianaPortNumber,
                username: Environment.get("DATABASE_USERNAME") ?? "notes",
                password: Environment.get("DATABASE_PASSWORD") ?? "notes",
                database: Environment.get("DATABASE_NAME") ?? "notes",
                tls: .disable
            )
        ),
        as: .psql
    )

    app.migrations.add(CreateNote())

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    try routes(app)
}
```

We use `tls: .disable` because the local container speaks plaintext on `localhost`. In production you set `tls: .require(...)`. The ISO-8601 encoder/decoder settings make `created_at` and `updated_at` come out as `2026-06-09T12:00:00Z` instead of a bare epoch double.

---

## Step 6 — routes(_:)

Create `Sources/App/routes.swift`:

```swift
import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async -> [String: String] in
        ["status": "ok"]
    }
    try app.register(collection: NotesController())
}
```

---

## Step 7 — The controller (your turn)

Create `Sources/App/Controllers/NotesController.swift`. The `boot`, `index`, `show`, and `destroy` handlers are given. **You write `create` and `update`.**

```swift
import Fluent
import Vapor

struct CreateNoteRequest: Content {
    let title: String
    let body: String
}

struct UpdateNoteRequest: Content {
    let title: String?
    let body: String?
}

struct NotesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let notes = routes.grouped("notes")
        notes.get(use: index)
        notes.post(use: create)
        notes.group(":noteID") { note in
            note.get(use: show)
            note.patch(use: update)
            note.delete(use: destroy)
        }
    }

    // GET /notes
    func index(req: Request) async throws -> [Note] {
        try await Note.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    // GET /notes/:noteID
    func show(req: Request) async throws -> Note {
        try await find(req)
    }

    // POST /notes
    func create(req: Request) async throws -> Response {
        // TODO: decode a CreateNoteRequest, build a Note, save it, and
        // return it with status .created (201). Hint: build a Response
        // with `try await note.encodeResponse(status: .created, for: req)`.
        throw Abort(.notImplemented)
    }

    // PATCH /notes/:noteID
    func update(req: Request) async throws -> Note {
        // TODO: find the note (use `find(req)`), decode an UpdateNoteRequest,
        // apply only the fields that are non-nil, save, and return the note.
        throw Abort(.notImplemented)
    }

    // DELETE /notes/:noteID
    func destroy(req: Request) async throws -> HTTPStatus {
        let note = try await find(req)
        try await note.delete(on: req.db)
        return .noContent
    }

    // Shared lookup: 400 if the id is malformed, 404 if no such note.
    private func find(_ req: Request) async throws -> Note {
        let id = try req.parameters.require("noteID", as: UUID.self)
        guard let note = try await Note.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "No note with id \(id)")
        }
        return note
    }
}
```

Implement the two TODOs. The acceptance criteria below tell you exactly what the routes must do.

---

## Step 8 — Build, migrate, run

```bash
swift build
```

Expect `Build complete!` with no warnings. Then run the migration:

```bash
swift run App migrate --yes
```

Expect:

```
[ INFO ] [migration] Prepared CreateNote
```

Boot the server:

```bash
swift run App serve --hostname 0.0.0.0 --port 8080
```

Expect:

```
[ NOTICE ] Server started on http://0.0.0.0:8080
```

Leave it running. Open a second terminal for the `curl` commands below.

---

## Step 9 — Exercise the API

```bash
# Health check.
curl -s localhost:8080/health
# {"status":"ok"}

# Create a note (201).
curl -s -i -X POST localhost:8080/notes \
  -H 'Content-Type: application/json' \
  -d '{"title":"First","body":"Hello, Vapor"}'
```

Expected (the id and timestamps will differ):

```
HTTP/1.1 201 Created
content-type: application/json; charset=utf-8

{"id":"E6A0...","title":"First","body":"Hello, Vapor","created_at":"2026-06-09T12:00:00Z","updated_at":"2026-06-09T12:00:00Z"}
```

Grab the id from that response into a shell variable and continue:

```bash
ID=$(curl -s -X POST localhost:8080/notes \
  -H 'Content-Type: application/json' \
  -d '{"title":"Second","body":"Patch me"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')

# Read it back (200).
curl -s localhost:8080/notes/$ID | python3 -m json.tool

# Update only the title (200).
curl -s -X PATCH localhost:8080/notes/$ID \
  -H 'Content-Type: application/json' \
  -d '{"title":"Renamed"}' | python3 -m json.tool

# List all, newest first (200).
curl -s localhost:8080/notes | python3 -m json.tool

# Delete it (204, no body).
curl -s -i -X DELETE localhost:8080/notes/$ID

# Confirm it is gone (404).
curl -s -i localhost:8080/notes/$ID
```

The PATCH must change `title` to `"Renamed"`, leave `body` as `"Patch me"`, and bump `updated_at`. The DELETE must return `204 No Content`. The final GET must return `404 Not Found`.

A malformed id must return `400`, not crash:

```bash
curl -s -i localhost:8080/notes/not-a-uuid
# HTTP/1.1 400 Bad Request
```

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `swift build` completes with **0 warnings, 0 errors** under strict concurrency.
- [ ] `swift run App migrate --yes` prints `Prepared CreateNote`.
- [ ] `POST /notes` with a valid body returns **201** and the created note as JSON, with a generated `id` and both timestamps populated.
- [ ] `GET /notes` returns a JSON array of all notes, newest first.
- [ ] `GET /notes/:id` returns **200** with the note for a valid id, **404** for a valid-but-absent id, and **400** for a malformed id.
- [ ] `PATCH /notes/:id` applies **only the non-nil fields** from the body (a body of `{"title":"x"}` must not blank out `body`) and returns the updated note with a bumped `updated_at`.
- [ ] `DELETE /notes/:id` returns **204** and the note is gone afterward.
- [ ] Dates serialise as ISO-8601 strings, not epoch doubles.

---

## Stretch

- Add a `GET /health/db` route that runs `try await req.db.execute(...)` (or a trivial `Note.query(on:).count()`) and returns `200` only if the database round-trip succeeds. This is the readiness probe a real deploy needs.
- Add `.field("title", .string, .required)` a `CHECK` via a raw SQL escape (`SQLKit`) so the database rejects an empty title even if the app forgets to.
- Reject a `title` longer than 200 characters at the decode boundary with a `400`. (Exercise from the Validatable angle; the Challenge does this properly.)

---

## Hints

<details>
<summary>create — return a 201 with the body</summary>

```swift
func create(req: Request) async throws -> Response {
    let input = try req.content.decode(CreateNoteRequest.self)
    let note = Note(title: input.title, body: input.body)
    try await note.create(on: req.db)
    return try await note.encodeResponse(status: .created, for: req)
}
```

`encodeResponse(status:for:)` lets you set a non-default status (`201`) while still serialising the model to the body. Returning the `Note` directly would give a `200`; the convention for a successful create is `201 Created`.

</details>

<details>
<summary>update — apply only non-nil fields</summary>

```swift
func update(req: Request) async throws -> Note {
    let note = try await find(req)
    let input = try req.content.decode(UpdateNoteRequest.self)
    if let title = input.title { note.title = title }
    if let body = input.body { note.body = body }
    try await note.update(on: req.db)
    return note
}
```

The `if let` guards are the whole point of PATCH semantics: a field absent from the request body must be left untouched. Decoding into an `UpdateNoteRequest` with optional fields, then applying only the ones present, is the idiomatic Fluent way to do a partial update.

</details>

<details>
<summary>If the server cannot connect to Postgres</summary>

Check the container is up (`docker ps`), the port matches (`-p 5432:5432`), and your `DATABASE_*` env vars (or the defaults in `configure.swift`) match the container's `POSTGRES_*`. The error Vapor prints — `connection refused` vs `password authentication failed` — tells you which.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — Bearer-token authentication middleware](exercise-02-bearer-auth-middleware.swift).
