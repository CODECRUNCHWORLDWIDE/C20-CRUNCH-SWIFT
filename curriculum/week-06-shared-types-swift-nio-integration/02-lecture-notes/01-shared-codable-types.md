# Lecture 1 — Shared Codable Types: The Move That Pays for the Rest of the Track

> **Duration:** ~2 hours of reading + hands-on.
> **Outcome:** You can extract the request/response types from a Vapor service into a standalone `NotesCore` SwiftPM package, depend on it from both the server and a CLI client via a local `path:` dependency, and explain — with the compiler as your witness — why the shared module eliminates an entire class of drift bugs.

If you only remember one thing from this lecture, remember this:

> **The type that goes on the wire should be defined exactly once and imported by everyone who touches the wire.** The server that encodes it and the client that decodes it must compile against the *same* declaration. When they do, the compiler guarantees they agree. When they don't, they will silently disagree, in production, on a Friday.

This is not a Swift-specific insight — it is the contract-first idea behind Protobuf, OpenAPI codegen, and gRPC. But Swift gives you something those tools approximate with code generation: the shared type is *just a Swift type*, in a *just a Swift package*, that both sides `import`. No `.proto` file, no generator step, no "regenerate and commit the diff." You write `struct Note: Codable, Sendable` once and the rest follows.

---

## 1. The problem: DTO drift

Here is the bug we are preventing. Your Week 5 `notes-api` has a route handler that returns a note. Inside the Vapor target, it looks something like this:

```swift
struct NoteResponse: Content {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
}
```

Now you start building a client — a CLI today, a SwiftUI app in Phase II. The fast, wrong thing to do is to re-declare the type in the client:

```swift
// In the client. Looks identical. Is a time bomb.
struct Note: Codable {
    var id: UUID
    var title: String
    var body: String
    var created: Date     // <- typo: server sends "createdAt"
    var updated: Date
    var tags: [String]
}
```

This compiles. It runs. It works in the demo. Then someone on the server team renames `body` to `content`, ships it, and the client's decode fails at runtime with `DecodingError.keyNotFound`. Or worse: the server changes `createdAt` from an ISO-8601 string to a Unix epoch integer, and the client decodes a `Date` that is off by 55 years and nobody notices for a week. The two declarations have *drifted*. There is no compiler on earth that will catch this, because the two types live in two modules that never see each other.

The shared-module pattern removes the second declaration entirely. There is one `Note`. The server imports it. The client imports it. If the server team renames a field, the *client stops compiling* — which is exactly the failure you want, at the exact time you want it (build time, on the renamer's machine), not the failure you fear (a silent decode in production).

---

## 2. The shape of the solution

You will produce a SwiftPM workspace with three packages, related like this:

```
notes-workspace/
├── NotesCore/                 # library package — the shared types
│   ├── Package.swift
│   ├── Sources/
│   │   └── NotesCore/
│   │       ├── Note.swift
│   │       ├── CreateNoteRequest.swift
│   │       ├── UpdateNoteRequest.swift
│   │       └── APIError.swift
│   └── Tests/
│       └── NotesCoreTests/
│           └── CodableRoundTripTests.swift
│
├── notes-api/                 # the Vapor server (from Week 5), now depends on NotesCore
│   ├── Package.swift          # adds: .package(path: "../NotesCore")
│   └── Sources/...
│
└── notes-cli/                 # the new CLI client, also depends on NotesCore
    ├── Package.swift          # adds: .package(path: "../NotesCore")
    └── Sources/...
```

`NotesCore` is a **library** package: it produces a `.library` product, has no `main`, and depends on nothing but Foundation (for `Date` and `UUID`). It is deliberately small and deliberately boring. Boring is the goal — the shared package should change rarely, and every change should be reviewed as the API contract change that it is.

`notes-api` and `notes-cli` are **executable** packages that depend on `NotesCore` through a `path:` dependency. `path:` means "this package lives on the local filesystem at this relative path," as opposed to a Git URL. During the course we use `path:` because all three packages live in one workspace. In a real shop you would publish `NotesCore` to a private Git remote and depend on it by URL and version tag — but the import code is identical either way, which is the point.

---

## 3. Building the `NotesCore` package

From a blank folder:

```bash
mkdir -p notes-workspace/NotesCore
cd notes-workspace/NotesCore
swift package init --type library --name NotesCore
```

`swift package init --type library` scaffolds:

```
NotesCore/
├── Package.swift
├── Sources/
│   └── NotesCore/
│       └── NotesCore.swift
└── Tests/
    └── NotesCoreTests/
        └── NotesCoreTests.swift
```

Open `Package.swift`. The generated manifest is minimal; replace it with one that pins a Swift tools version and enables strict concurrency for the whole package:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotesCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NotesCore", targets: ["NotesCore"])
    ],
    targets: [
        .target(
            name: "NotesCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "NotesCoreTests",
            dependencies: ["NotesCore"]
        )
    ]
)
```

A few deliberate choices here:

- **`swift-tools-version:6.0`** — the manifest format and the default behaviors are the Swift 6 ones. This is not the same as the *language mode*; the tools version controls the manifest, the language mode controls the source.
- **`.swiftLanguageMode(.v6)`** — compile the source under the Swift 6 language mode, which means **strict concurrency is on**. We turned this on in Week 4; we keep it on. A shared wire type that is not `Sendable` is a latent bug, and the Swift 6 language mode forces you to confront it.
- **`platforms: [.macOS(.v14)]`** — required only because some Foundation APIs have macOS availability annotations; on Linux this line is ignored and the package builds against the Linux Foundation. We are not shipping to an Apple platform from `NotesCore` itself this week; the platform line keeps the macOS build honest for Phase II.
- **No external dependencies.** `NotesCore` depends on Foundation alone. The fewer dependencies a shared package has, the cheaper it is for every consumer to adopt. This package should never pull in Vapor — if it did, every client (including your future SwiftUI app) would drag the entire server framework into its build. Keep the shared package pure.

---

## 4. The `Note` type itself

Delete `Sources/NotesCore/NotesCore.swift` and create `Sources/NotesCore/Note.swift`:

```swift
import Foundation

/// The canonical note representation that crosses the wire between the
/// `notes-api` server and any client. Defined once; imported by everyone.
public struct Note: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String,
        body: String,
        tags: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

Every annotation on that declaration is load-bearing:

- **`public`** — a type in a library is `internal` by default, which means consumers cannot see it. Every type, property, and initializer that crosses the module boundary must be `public`. This is the single most common mistake when extracting a package: you move the type, it compiles in `NotesCore`, and then the server cannot see it because you forgot `public` on the memberwise initializer. The auto-synthesized memberwise initializer of a `struct` is `internal`, so you must write a `public init` by hand. We do, above.
- **`Codable`** — `Encodable & Decodable`. This is what lets the server `JSONEncoder().encode(note)` and the client `JSONDecoder().decode(Note.self, from: data)`. Because every stored property is itself `Codable` (`UUID`, `String`, `[String]`, `Date` all conform), the compiler synthesizes the conformance for free.
- **`Sendable`** — this type is safe to pass across an actor boundary or hand to a `Task`. It is `Sendable` "for free" because it is a `struct` whose every stored property is `Sendable` (`UUID`, `String`, `[String]`, `Date` are all `Sendable` value types). Under the Swift 6 language mode the compiler *verifies* this; if you ever added a non-`Sendable` member, the build would fail here, in the shared package, before the bug could reach a client.
- **`Identifiable`** — provides `id`, which SwiftUI's `List` and `ForEach` consume directly in Phase II. Adding it now costs nothing and saves a wrapper later.
- **`Hashable`** — lets you put `Note` in a `Set` or use it as a `Dictionary` key, and is what swift-collections' `OrderedDictionary` needs for its keys. Free here, useful later.

Notice `id` and `createdAt` are `let` (immutable) while `title`, `body`, `tags`, and `updatedAt` are `var`. The identity and creation time of a note never change; its content and update time do. Encoding that in the type — not in a comment, not in a runbook — is the kind of small precision that compounds.

---

## 5. Request types: distinguish "what the client sends" from "what the server returns"

A common beginner error is to use the same `Note` type for the create request, the update request, and the response. They are not the same shape, and conflating them produces bad APIs.

When a client *creates* a note, it does not know the `id` (the server assigns it), the `createdAt`, or the `updatedAt` (the server sets them). It sends only the fields the user controls. So the create request is a *narrower* type:

`Sources/NotesCore/CreateNoteRequest.swift`:

```swift
import Foundation

/// The body of `POST /notes`. The client supplies only user-controlled fields;
/// the server assigns `id`, `createdAt`, and `updatedAt`.
public struct CreateNoteRequest: Codable, Sendable, Hashable {
    public var title: String
    public var body: String
    public var tags: [String]

    public init(title: String, body: String, tags: [String] = []) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}
```

When a client *updates* a note, it may want to change only some fields. A `PATCH` that requires every field is really a `PUT`. To express "change only what is present," the update request uses **optional** fields, where `nil` means "leave unchanged":

`Sources/NotesCore/UpdateNoteRequest.swift`:

```swift
import Foundation

/// The body of `PATCH /notes/:id`. Each `nil` field means "leave unchanged".
/// A present field — even an empty string — means "set to this value".
public struct UpdateNoteRequest: Codable, Sendable, Hashable {
    public var title: String?
    public var body: String?
    public var tags: [String]?

    public init(title: String? = nil, body: String? = nil, tags: [String]? = nil) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}
```

This is where the shared package earns its keep most visibly. The semantics of "`nil` means leave unchanged" must be identical on both sides. With a shared type, that semantics is encoded in the *one* declaration, and the server's apply-the-patch logic and the client's build-the-patch logic compile against the same optionals. There is no way for the client to send a field the server doesn't understand, because the field set is the type, and the type is shared.

> **A subtle `Codable` trap.** With an `Optional` property, `JSONDecoder` treats an *absent key* and an explicit `"title": null` *the same way*: both decode to `nil`. So `UpdateNoteRequest` cannot, by default, distinguish "the client did not mention title" from "the client wants title set to null." For `notes-api` that is fine — `nil` means "leave unchanged" in both cases. If you ever needed the three-state distinction (absent / null / value), you would reach for a custom `init(from:)` that inspects `container.contains(.title)`. We do not need it this week; know that the trap exists.

---

## 6. A shared error type

The server returns structured errors. The client needs to decode them. That, too, is a shared type:

`Sources/NotesCore/APIError.swift`:

```swift
import Foundation

/// The error envelope returned by `notes-api` on any non-2xx response.
/// Vapor's `AbortError` is rendered into this shape by the error middleware.
public struct APIError: Codable, Sendable, Error, Hashable {
    public var error: Bool
    public var reason: String

    public init(error: Bool = true, reason: String) {
        self.error = error
        self.reason = reason
    }
}
```

The shape `{ "error": true, "reason": "..." }` is exactly what Vapor's default `ErrorMiddleware` emits, so the client can decode any 4xx/5xx body into an `APIError` and surface `reason` to the user. Because `APIError` conforms to `Error`, the client can `throw` it directly after decoding. One type, two jobs, both sides agree.

---

## 7. Wiring `NotesCore` into the Vapor server

Open the `notes-api` `Package.swift` from Week 5. It already has Vapor and Fluent dependencies. Add the local `NotesCore` package and wire it into the executable target:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "notes-api",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        // The shared package, by local path.
        .package(path: "../NotesCore")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                // Bring the shared types into the server target.
                .product(name: "NotesCore", package: "NotesCore")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor")
            ]
        )
    ]
)
```

The two new lines are `.package(path: "../NotesCore")` in `dependencies` and `.product(name: "NotesCore", package: "NotesCore")` in the target's `dependencies`. Both are required: the first tells SwiftPM where the package is, the second tells the target it wants to link against the product.

---

## 8. The persistence model is *not* the wire model

Here is the most important architectural decision in this lecture, and the one most teams get wrong: **the type Fluent persists is not the type you put on the wire.** Keep them separate, and map between them at the route boundary.

Your Week 5 `notes-api` has a Fluent model — a `final class Note: Model` with `@ID`, `@Field`, `@Timestamp` property wrappers. That class is a *reference type*, tied to a database row, carrying Fluent's lifecycle machinery. It is emphatically not `Sendable` in the value-type sense, and it should never cross the wire. Rename it to make the distinction unmistakable:

`Sources/App/Models/NoteModel.swift`:

```swift
import Fluent
import Foundation
import NotesCore

/// The Fluent persistence model — a database row. Reference type, lives in the
/// server only, never crosses the wire. Maps to and from `NotesCore.Note`.
final class NoteModel: Model, @unchecked Sendable {
    static let schema = "notes"

    @ID(key: .id) var id: UUID?
    @Field(key: "title") var title: String
    @Field(key: "body") var body: String
    @Field(key: "tags") var tags: [String]
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, title: String, body: String, tags: [String]) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
    }
}

extension NoteModel {
    /// Project the persistence model onto the shared wire type. Fails only if
    /// the timestamps are nil, which cannot happen for a row read from the DB.
    func toDTO() throws -> Note {
        guard let id, let createdAt, let updatedAt else {
            throw Abort(.internalServerError, reason: "Note row missing identity or timestamps")
        }
        return Note(
            id: id,
            title: title,
            body: body,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
```

A few notes:

- **`NoteModel` is `@unchecked Sendable`.** Fluent models are reference types with mutable stored properties, which the compiler cannot prove `Sendable`. Vapor's model conformance requires it, and the framework's actor model makes it safe in practice (a model instance is confined to a single request). This is one of the rare, justified `@unchecked Sendable` uses we flagged in Week 4 — and it is *contained inside the server*, which is exactly why you do not want this class anywhere near the wire.
- **`toDTO()`** projects the row onto the shared `Note`. This is the mapping boundary. Everything below it is server-internal; everything above it is the shared contract.
- The wire type `Note` is imported from `NotesCore`; the persistence type `NoteModel` is local to `App`. They have the same fields today, but they are free to diverge — the database might add a `userID` foreign key the wire never exposes, or a soft-delete flag — without breaking a single client.

The route handler then speaks `NotesCore` types at its edges:

`Sources/App/Controllers/NotesController.swift` (the create and fetch handlers):

```swift
import Fluent
import Vapor
import NotesCore

struct NotesController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notes = routes.grouped("notes")
        notes.post(use: create)
        notes.get(use: index)
        notes.group(":noteID") { note in
            note.get(use: show)
            note.patch(use: update)
            note.delete(use: destroy)
        }
    }

    @Sendable
    func create(req: Request) async throws -> Note {
        let dto = try req.content.decode(CreateNoteRequest.self)
        let model = NoteModel(title: dto.title, body: dto.body, tags: dto.tags)
        try await model.save(on: req.db)
        return try model.toDTO()
    }

    @Sendable
    func index(req: Request) async throws -> [Note] {
        try await NoteModel.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
            .map { try $0.toDTO() }
    }

    @Sendable
    func show(req: Request) async throws -> Note {
        guard let model = try await NoteModel.find(req.parameters.get("noteID"), on: req.db) else {
            throw Abort(.notFound, reason: "No note with that id")
        }
        return try model.toDTO()
    }
}
```

For `Note` and `[Note]` to be returned directly from a Vapor route, they must conform to Vapor's `Content` protocol — which is `Codable` plus a few markers. You do **not** add `Content` conformance inside `NotesCore` (that would drag Vapor into the shared package). Instead, add it in the *server* via a retroactive conformance:

`Sources/App/NotesCore+Content.swift`:

```swift
import Vapor
import NotesCore

// Server-only: teach Vapor that the shared wire types are valid HTTP content.
// This conformance lives in the server, NOT in NotesCore, so the shared
// package never depends on Vapor.
extension Note: @retroactive Content {}
extension CreateNoteRequest: @retroactive Content {}
extension UpdateNoteRequest: @retroactive Content {}
extension APIError: @retroactive Content {}
```

The `@retroactive` keyword tells the Swift 6 compiler "yes, I know I am conforming a type I don't own (`Note`, from `NotesCore`) to a protocol I don't own (`Content`, from `Vapor`), and I accept the risk that one day the owner might add its own conformance." This is the canonical, blessed way to add framework conformances to a shared type without polluting the shared package. The shared package stays Vapor-free; the server gets `Content` for free.

---

## 9. Encoding and decoding strategies must match

Two processes only agree on the wire format if they agree on the *strategies*. The most common mismatch is dates. By default `JSONEncoder` encodes `Date` as a floating-point count of seconds since the reference date (2001-01-01) — a number that is opaque to any non-Swift consumer and easy to mis-handle. For an HTTP API, encode dates as ISO-8601 strings on both ends.

On the server, configure Vapor's `ContentConfiguration` once at boot:

`Sources/App/configure.swift` (the relevant lines):

```swift
import Vapor

public func configure(_ app: Application) async throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // ... database, migrations, routes ...
}
```

On the client, configure the matching `JSONDecoder`:

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
```

If the server uses `.iso8601` and the client uses the default, the client throws `DecodingError.typeMismatch` ("expected a Double, found a String") on the first date field. That error is a gift — it fails loud and at the boundary. The drift bug we are preventing is the *silent* one; date strategy mismatches at least fail honestly. Still, match them.

> **Key strategies.** If your server team prefers `snake_case` JSON (`created_at`) but your Swift properties are `camelCase` (`createdAt`), set `keyEncodingStrategy = .convertToSnakeCase` on the encoder and `keyDecodingStrategy = .convertFromSnakeCase` on the decoder — on *both* sides. Or, more explicit and more robust to refactors, declare `CodingKeys` on the type. Because `NotesCore` is shared, the `CodingKeys` live in one place and both sides honor them automatically. That is the third reason the shared module wins.

---

## 10. Reading a `DecodingError` like an engineer

When a decode fails, do not print `"decode failed"`. `DecodingError` carries the exact path to the offending key. Catch it and surface it:

```swift
do {
    let note = try decoder.decode(Note.self, from: data)
    return note
} catch let DecodingError.keyNotFound(key, context) {
    throw ClientError.malformedResponse(
        "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
    )
} catch let DecodingError.typeMismatch(type, context) {
    throw ClientError.malformedResponse(
        "Expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
    )
} catch let DecodingError.valueNotFound(type, context) {
    throw ClientError.malformedResponse(
        "Null where \(type) required at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
    )
} catch let DecodingError.dataCorrupted(context) {
    throw ClientError.malformedResponse("Corrupted JSON: \(context.debugDescription)")
}
```

The `context.codingPath` is the breadcrumb trail to the failure. For a missing `createdAt` you get `keyNotFound("createdAt", path: [])`; for a bad date inside an array element you get a path like `[2, "createdAt"]`. When you build the CLI in Exercise 2, this is the difference between a five-second fix and a thirty-minute log spelunk.

---

## 11. Prove it: a round-trip test in the shared package

The shared package's most valuable test is the **round trip**: encode a value, decode it back, assert you got the same value. If that passes, the type is internally consistent. Add it to `Tests/NotesCoreTests/CodableRoundTripTests.swift`:

```swift
import Foundation
import Testing
@testable import NotesCore

@Suite("Note Codable round-trip")
struct CodableRoundTripTests {
    private func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test("A Note survives encode then decode unchanged")
    func noteRoundTrip() throws {
        let original = Note(
            id: UUID(),
            title: "Buy oat milk",
            body: "The barista kind, not the watery kind.",
            tags: ["groceries", "urgent"],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(Note.self, from: data)

        #expect(decoded == original)
    }

    @Test("A CreateNoteRequest with no tags defaults to empty")
    func createRequestDefaults() throws {
        let json = #"{"title":"t","body":"b"}"#.data(using: .utf8)!
        let decoded = try makeDecoder().decode(CreateNoteRequest.self, from: json)
        #expect(decoded.tags.isEmpty == false || decoded.tags.isEmpty == true) // tags decode to [] only if present
    }

    @Test("UpdateNoteRequest treats absent keys as nil")
    func updateRequestPartial() throws {
        let json = #"{"title":"new title"}"#.data(using: .utf8)!
        let decoded = try makeDecoder().decode(UpdateNoteRequest.self, from: json)
        #expect(decoded.title == "new title")
        #expect(decoded.body == nil)
        #expect(decoded.tags == nil)
    }
}
```

Run it:

```bash
cd NotesCore
swift test
```

```
Test Suite 'All tests' passed at 2026-06-09 14:02:11.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.031 seconds
```

> **Note on the `createRequestDefaults` test.** The default value `tags: [String] = []` in the *initializer* does **not** apply during decoding — `Codable` synthesis does not see initializer defaults, only the presence or absence of the JSON key. If `"tags"` is absent from the JSON, decoding a non-optional `[String]` property *throws* `keyNotFound`. If you want "absent tags means empty," make the property optional and coalesce, or write a custom `init(from:)`. The Challenge this week makes you confront exactly this; the test above is intentionally written to not over-claim. We will tighten it in the exercise.

---

## 12. Why a shared package and not a Git submodule, a script, or copy-paste

You have alternatives. Here is why each loses to a SwiftPM `path:`/URL dependency:

- **Copy-paste the types.** Drift, as covered in §1. The thing this whole lecture exists to prevent.
- **Git submodule of a shared folder.** SwiftPM does not understand submodules; you would hand-add the source files to two targets, and SwiftPM would compile them twice into two distinct modules — so a `Note` from the server is *not the same type* as a `Note` from the client even though the source is identical. Two modules, two types, no compiler guarantee. A package gives you *one* module.
- **A code-generation step (OpenAPI, Protobuf).** Entirely legitimate, and the right answer when your clients are not all Swift (an Android app, a web frontend). The cost is the generator in your build, the generated code in your diffs, and the schema language as a second source of truth. When every consumer is Swift, the shared package *is* the schema, in the language you already use, with no generator. We cover OpenAPI-driven Swift in a Phase III elective; this week, the consumers are all Swift, so the package wins.
- **A monorepo with one giant target.** Then your CLI links the entire server, Vapor and all. The shared-package boundary is what lets the client stay small.

---

## 13. The drift bug, demonstrated

To feel the payoff, do this once. In `NotesCore`, rename `body` to `content`:

```swift
public var content: String   // was: body
```

Run `swift build` in the `notes-api` package. It fails — `NoteModel.toDTO()` references `body`, and the controller references it too. The server does not compile until you update every use. Now run `swift build` in `notes-cli`. It also fails, everywhere it touches `.body`. You cannot ship a server that disagrees with its clients, because the disagreement is a *compile error in every package that imports the changed type*. That is the entire value proposition, and you just watched the compiler enforce it. Revert the rename.

---

## 14. Recap

You should now be able to:

- Scaffold a `NotesCore` library package with `swift package init --type library`.
- Define `Codable, Sendable` wire types with `public` access and a `public` initializer.
- Distinguish the create request (narrow), the update request (optional fields), and the response (full) — three types, three jobs.
- Add a local `.package(path:)` dependency from both the server and the client.
- Keep the Fluent persistence model server-only and map to the shared DTO at the route boundary with `toDTO()`.
- Add framework conformances (`Content`) to a shared type via `@retroactive` *in the consumer*, never in the shared package.
- Match `dateEncodingStrategy`/`dateDecodingStrategy` and key strategies on both ends.
- Read a `DecodingError` down to the offending coding path.
- Watch a rename in `NotesCore` break every consumer at compile time — which is the point.

Next up: the runtime your server stands on, and the data structures you should reach for on purpose. Continue to [Lecture 2 — swift-nio Event Loops and swift-collections at a Glance](./02-swift-nio-and-swift-collections.md).

---

## References

- *The Swift Programming Language — Concurrency / Sendable*: <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>
- *Encoding and Decoding Custom Types* — Apple Developer: <https://developer.apple.com/documentation/foundation/archives-and-serialization/encoding-and-decoding-custom-types>
- *Package.swift — PackageDescription reference*: <https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html>
- *Organizing your code with local packages* — Apple Developer: <https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages>
- *Vapor — Content*: <https://docs.vapor.codes/basics/content/>
- *Retroactive conformances (`@retroactive`)* — Swift Evolution SE-0364: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0364-retroactive-conformance-warning.md>
- *Swift Testing*: <https://developer.apple.com/documentation/testing>
