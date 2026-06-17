# Mini-Project — Phase I Integration: `NotesCore` + `notes-cli`

> Take the `notes-api` you shipped in Week 5, extract its request/response models into a standalone `NotesCore` SwiftPM package published as a local dependency, then write a `notes-cli` Swift client that consumes the API over `URLSession` using the shared types. Both server and CLI build and run on **Linux**. Drive `NotesCore` Swift Testing coverage **above 70%**. This is the Phase I gate, in one repository.

This is the capstone of Phase I. It is not a new feature — it is the *architecture move* that makes every later feature cheaper: a single source of truth for the wire format, consumed by two processes that the compiler keeps in lockstep. Every serious Swift shop that runs both a server and a client converges on this shape. You make the move now, while the surface is three structs and three routes, so it is a reflex by the time the surface is a forty-screen SwiftUI app talking to a dozen endpoints. **This mini-project compounds directly on the Week 5 `notes-api`.** Bring that codebase; you will refactor it, not rebuild it.

**Estimated time:** ~9.5 hours (split across Thursday, Friday, Saturday, Sunday in the suggested schedule).

---

## What you will build

A single workspace, `notes-workspace/`, containing **three SwiftPM packages**:

```
notes-workspace/
├── NotesCore/            # library package — the shared wire types (NEW this week)
│   ├── Package.swift
│   ├── Sources/NotesCore/
│   │   ├── Note.swift
│   │   ├── CreateNoteRequest.swift
│   │   ├── UpdateNoteRequest.swift
│   │   └── APIError.swift
│   ├── Tests/NotesCoreTests/
│   │   └── CodableTests.swift
│   └── coverage.md
│
├── notes-api/            # the Week 5 Vapor server, refactored to depend on NotesCore
│   ├── Package.swift     # adds .package(path: "../NotesCore")
│   ├── Sources/App/
│   │   ├── Models/NoteModel.swift     # Fluent persistence model (NOT the wire type)
│   │   ├── Controllers/NotesController.swift
│   │   ├── Middleware/BearerAuthMiddleware.swift
│   │   └── configure.swift
│   └── docker-compose.yml             # Postgres, from Week 5
│
└── notes-cli/            # the new CLI client (NEW this week)
    ├── Package.swift     # adds .package(path: "../NotesCore")
    └── Sources/notes-cli/
        ├── main.swift
        ├── NotesAPIClient.swift       # the URLSession client, an actor
        └── CLI.swift                  # argument parsing and command dispatch
```

`NotesCore` is a pure library with no dependency but Foundation. `notes-api` and `notes-cli` both depend on it by `path:`. The contract between server and client is the `NotesCore` module, and the compiler enforces it.

---

## Functional requirements

### The `NotesCore` package

1. Defines `Note`, `CreateNoteRequest`, `UpdateNoteRequest`, and `APIError` exactly as in Lecture 1 — `public`, `Codable`, `Sendable`, with hand-written `public init`s.
2. Has **zero** dependency on Vapor, Fluent, or any server package. Foundation only.
3. Compiles under the Swift 6 language mode (`.swiftLanguageMode(.v6)`) with strict concurrency on, with **0 warnings**.
4. Ships a `NotesCoreTests` target whose line coverage is **above 70%** (the Challenge work lands here).

### The `notes-api` server (refactor of Week 5)

5. Depends on `NotesCore` via `.package(path: "../NotesCore")` and imports it in the controller.
6. Keeps its Fluent persistence model **separate** from the wire type. The class Fluent stores is `NoteModel` (a reference type, not `Sendable`); the type on the wire is `NotesCore.Note` (a value type). A `toDTO()` method maps `NoteModel → NotesCore.Note` at the route boundary.
7. Adds `Content` conformance to the `NotesCore` types **in the server target**, in an extension, so `NotesCore` stays Vapor-free:
   ```swift
   import Vapor
   import NotesCore
   extension Note: @retroactive Content {}
   extension CreateNoteRequest: @retroactive Content {}
   extension UpdateNoteRequest: @retroactive Content {}
   ```
8. Serves the same five routes as Week 5 — `POST /notes`, `GET /notes`, `GET /notes/:id`, `PATCH /notes/:id`, `DELETE /notes/:id` — now encoding/decoding the shared types.
9. Encodes dates as **ISO-8601** (`ContentConfiguration` or a configured `JSONEncoder`), matching the CLI.
10. Still boots with `docker compose up` (Postgres) + `swift run`, on Linux.

### The `notes-cli` client (new)

11. A standalone executable package depending on `NotesCore` by `path:`.
12. Supports three commands:
    - `notes-cli create "<title>" "<body>" <tag1,tag2,...>` — `POST`s a `CreateNoteRequest`, prints the created note's id and title.
    - `notes-cli list` — `GET`s `/notes`, prints one line per note: id, title, tags.
    - `notes-cli get <uuid>` — `GET`s `/notes/:id`, prints the note, or a clean "not found" message on 404.
13. Decodes every response into **`NotesCore.Note`** (or `[NotesCore.Note]`). No client-local `Note` struct anywhere.
14. Uses `URLSession`'s async `data(for:)` API, on Linux.
15. Sends the bearer token from Week 5 (`Authorization: Bearer <token>`), read from `NOTES_API_TOKEN`, defaulting to a dev token.
16. On a non-2xx response, decodes the body into `NotesCore.APIError` and surfaces `reason` to the user — never a raw status-code dump.
17. The networking lives in a `NotesAPIClient` **actor** (you learned actors in Week 4) so the client is concurrency-clean under Swift 6 mode.

---

## Rules

- **You may** read swift.org docs, the Vapor and Hummingbird docs, the swift-nio README, the swift-collections docs, your Week 5 codebase, and this week's lectures and exercises.
- **You may NOT** copy-paste a `Note` struct into the CLI. If you find yourself re-declaring a wire type, you have missed the entire point — import it from `NotesCore`.
- **You may NOT** make `NotesCore` depend on Vapor. The `Content` conformance lives in the server target via a `@retroactive` extension, not in the shared package.
- Target the **Swift 6 toolchain**, Swift 6 language mode, on **Linux**. If it only builds on your Mac, it does not pass the gate.
- `0 warnings` across all three packages. A warning is a defect this week.
- Use only first-party / SSWG packages: Vapor, Fluent, swift-collections, swift-nio (transitively). No third-party "API client" or "JSON" libraries — Foundation's `URLSession` and `Codable` are the assignment.

---

## Acceptance criteria

The rubric below maps each box to a deliverable. This is also the Phase I gate checklist.

### Shared package (30%)

- [ ] `NotesCore` builds standalone (`cd NotesCore && swift build`) with 0 warnings under Swift 6 mode.
- [ ] `NotesCore` has no dependency but Foundation (check `Package.swift` and `swift package show-dependencies`).
- [ ] All four types are `public`, `Codable`, `Sendable`, with `public` initializers.
- [ ] `swift test` in `NotesCore` passes with 0 failures.
- [ ] `swift test --enable-code-coverage` shows `NotesCore` source files **above 70%** line coverage, pasted in `coverage.md`.

### Server refactor (30%)

- [ ] `notes-api` depends on `NotesCore` via `.package(path: "../NotesCore")`.
- [ ] The Fluent model (`NoteModel`) is distinct from the wire type (`NotesCore.Note`); a `toDTO()` maps between them.
- [ ] `Content` conformance is added in the *server* target via `@retroactive` extension, not in `NotesCore`.
- [ ] All five routes still work, encoding/decoding the shared types, with ISO-8601 dates.
- [ ] `docker compose up` + `swift run` boots the server on Linux and serves a `curl` request.

### CLI client (30%)

- [ ] `notes-cli` depends on `NotesCore` via `.package(path: "../NotesCore")`.
- [ ] `create`, `list`, and `get` all work against the running server.
- [ ] Every decode target is a `NotesCore` type; there is no client-local `Note`.
- [ ] Networking is in a `NotesAPIClient` actor using async `URLSession`.
- [ ] A 404 produces a clean message; a non-2xx body decodes into `APIError` and shows `reason`.
- [ ] `notes-cli` builds with 0 warnings under Swift 6 mode on Linux.

### The drift proof (10%)

- [ ] A short `DRIFT.md` documenting the following experiment: rename a field on `NotesCore.Note` (e.g. `body` → `content`), run `swift build` in **both** `notes-api` and `notes-cli`, and paste the compile errors from *both* targets. Then revert. This proves the shared type keeps the two sides in lockstep — the entire thesis of the week.

---

## Suggested implementation outline

The order matters. Extract the types first, refactor the server to use them, *then* build the client against a known-good server.

### Day 1 (Thursday — ~2 hours)

1. Create `notes-workspace/` and move your Week 5 `notes-api` into it.
2. Scaffold `NotesCore` with `swift package init --type library --name NotesCore`. Replace `Package.swift` per Lecture 1 §3.
3. Create `Note.swift`, `CreateNoteRequest.swift`, `UpdateNoteRequest.swift`, `APIError.swift` per Lecture 1 §4–6. Build `NotesCore` standalone; confirm 0 warnings.
4. Write the first three round-trip tests so `NotesCore` has a test target from the start. (You will grow this to >70% in the Challenge.)

### Day 2 (Friday — ~3.5 hours)

5. Add `.package(path: "../NotesCore")` to `notes-api/Package.swift` and the product to the `App` target (Lecture 1 §7).
6. Rename your Week 5 Fluent `Note` class to `NoteModel`; add `toDTO() -> NotesCore.Note` (Lecture 1 §8).
7. Add the `@retroactive Content` extensions in the server target (Exercise 1).
8. Rewrite the controller to decode `CreateNoteRequest`/`UpdateNoteRequest` and return `NotesCore.Note`. Configure ISO-8601 dates.
9. Boot with `docker compose up` + `swift run`. `curl` each route. Confirm the JSON shape matches what the CLI will expect.

### Day 3 (Saturday — ~3 hours)

10. Scaffold `notes-cli` with `swift package init --type executable`. Add the `NotesCore` `path:` dependency (Exercise 2).
11. Build `NotesAPIClient` as an actor: `create`, `list`, `get`, each using `URLSession.shared.data(for:)`, bearer header, status handling, and `APIError` decode on failure.
12. Wire up argument parsing in `CLI.swift` and dispatch in `main.swift`.
13. Run all three commands end-to-end against the live server. Fix the inevitable date-strategy mismatch (both ends must be `.iso8601`).
14. Do the **drift experiment** and write `DRIFT.md`.
15. Bring `NotesCore` coverage above 70% (the Challenge work).

### Day 4 (Sunday — ~1 hour)

16. Write the workspace `README.md`: how to boot the server, how to run each CLI command, the architecture (three packages, one shared type), and the coverage figure.
17. Fresh-clone test: `git clean -xdf`, then build all three packages from scratch on Linux. The most common gate-fail is "works on my machine, won't build clean."

---

## Hints

- **The `@retroactive` keyword is required** when you conform a type you do not own (`NotesCore.Note`) to a protocol you do not own (`Vapor.Content`) in a third module (the server target). Swift 6 warns without it; `@retroactive` is you telling the compiler "I know this is a retroactive conformance and I accept the risk." It is the correct, idiomatic way to keep `NotesCore` Vapor-free.
- **Date strategy is the #1 integration bug.** If the server encodes a `Date` with the default strategy (a `Double`) and the CLI decodes with `.iso8601` (a `String`), every fetch fails with a `typeMismatch`. Set `.iso8601` on *both* ends, explicitly. In Vapor, configure `ContentConfiguration.global` with a JSON encoder/decoder that use `.iso8601`.
- **`URLSession` works on Linux** in the 2026 toolchain — the async `data(for:)` API is available via swift-corelibs-foundation. If a specific `URLSession` API is missing, check it exists on Linux before depending on it (the resources page links the Linux Foundation repo).
- **Make `NotesAPIClient` an actor**, not a class with locks. The client holds a base URL and a token (both `Sendable`) and runs `async` requests; an actor is the clean Swift 6 expression of that.
- **Test the server with `curl` before pointing the CLI at it.** A bug you can reproduce with `curl` is a server bug; a bug only the CLI shows is a client bug. Isolate before you debug.

---

## Anti-goals

These are explicitly **not** part of this mini-project. Pursuing them distracts from the lesson.

- **A new feature.** No search, no pagination, no auth flows beyond the Week 5 bearer token. The five routes from Week 5 are the surface; the work is the *architecture*, not new functionality.
- **A SwiftUI client.** That is Phase II, Week 7. The client this week is a CLI precisely because it runs on Linux and keeps the focus on the shared-types pattern, not on UI.
- **Publishing `NotesCore` to a Git remote.** A `path:` dependency is the assignment. Publishing by URL+tag is a one-line change you will make in a real job; we use `path:` because all three packages live in one workspace.
- **Rewriting in Hummingbird.** Porting one route to Hummingbird is a *stretch* goal (and a good one), but the gate deliverable is the Vapor `notes-api` you already have, refactored.

---

## Submission

Push `notes-workspace/` to your Week 6 GitHub repository at `mini-project/notes-workspace/`. The instructor reviews by, on a Linux box:

1. Cloning the repo and running `git clean -xdf`.
2. `cd NotesCore && swift test --enable-code-coverage` — must pass and show >70% coverage.
3. `cd ../notes-api && docker compose up -d && swift run` — must boot and serve.
4. `cd ../notes-cli && swift run notes-cli create "demo" "body" a,b` then `list` then `get <id>` — must work end-to-end.
5. Reading `DRIFT.md` to confirm the rename broke *both* targets.

A submission where all three packages build clean on Linux, the CLI round-trips through the server, and `NotesCore` coverage is above 70% **passes the Phase I gate**.

---

## Stretch goals (no extra grade)

- **Port one route to Hummingbird 2** in a `notes-api-hb` package and confirm the *same* `NotesCore.Note` drops in unchanged. Diff the two `Package.resolved` files and write one paragraph on the dependency-graph difference.
- **Add OpenTelemetry-Swift to the server** (Lecture 2 §2.7): wrap the `POST /notes` handler and the database write in `withSpan`, stand up a local OTel Collector in Docker, and screenshot the trace showing the DB latency as a child span.
- **Add `patch` and `delete` to the CLI** so it covers all five routes, using `UpdateNoteRequest` for the patch.
- **Use `OrderedDictionary`** (Lecture 2 §2.8) in the CLI's `list` rendering to dedupe-by-id while preserving server order, and justify the choice in a comment.

The stretch goals are deliberately harder than the main project. Do not start them until every acceptance box is checked.

---

**References**

- SwiftPM `Package.swift` reference: <https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html>
- Vapor `Content` and `ContentConfiguration`: <https://docs.vapor.codes/basics/content/>
- `URLSession` async API: <https://developer.apple.com/documentation/foundation/urlsession>
- `@retroactive` conformances (SE-0364): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0364-retroactive-conformance-warning.md>
- swift-corelibs-foundation (Linux Foundation): <https://github.com/swiftlang/swift-corelibs-foundation>
- Code coverage with SwiftPM: <https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Usage.md>
