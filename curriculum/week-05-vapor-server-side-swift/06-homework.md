# Week 5 Homework

Six practice problems that revisit the week's topics and harden the `notes-api`. The full set should take about **6 hours**. Work in your Week 5 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Deliverables** so you know exactly what to commit.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

A grading **rubric** is at the bottom.

---

## Problem 1 — Add a `GET /notes/:id/raw` endpoint with a custom encoder

**Problem statement.** Add a route `GET /notes/:id/raw` that returns the same note but with the wire format overridden *for this route only*: dates as Unix epoch seconds (a `Double`) and keys verbatim (no `snake_case` conversion), regardless of the global `ContentConfiguration`. This proves you understand that content encoding can be controlled per-response, not only globally.

**Deliverables.** The new route in `NotesController`, plus a `notes/encoder-override.md` (150 words) explaining how a per-route encoder differs from the global `ContentConfiguration`.

**Acceptance criteria.**

- `GET /notes/:id/raw` returns `200` with the note, dates as epoch `Double`s, keys unconverted.
- `GET /notes/:id` (the normal route) still returns ISO-8601 dates — the override does not leak.
- `swift build`: 0 warnings, 0 errors.

**Hint.** Build a `JSONEncoder` with `dateEncodingStrategy = .secondsSince1970` and pass it to `note.encodeResponse(for:)` via a `ContentEncoder` you set on the response, or encode into a `Response` and call `response.content.encode(note, using: customEncoder)`. The per-response encoder shadows the global one.

**Estimated time.** 45 minutes.

---

## Problem 2 — Read the Vapor `AsyncMiddleware` and `BearerAuthenticator` source

**Problem statement.** Open the Vapor source on GitHub (`vapor/vapor`). Find (a) the protocol declaration of `AsyncMiddleware` and (b) the `AsyncBearerAuthenticator` protocol and the `BearerAuthorization` type it parses. Read how `request.auth.login(_:)` stores the authenticated principal and how `guardMiddleware()` retrieves it.

**Deliverables.** A `notes/vapor-auth-internals.md` (200 words) covering:

1. The file path within the repo for `AsyncMiddleware`.
2. The file path for the bearer authenticator.
3. In your own words, the mechanism by which `request.auth.login(...)` and `guardMiddleware()` communicate (hint: `request.auth` is backed by a typed container keyed by the `Authenticatable` type).

**Acceptance criteria.**

- The note cites at least two specific filenames/paths from the Vapor repo.
- It correctly describes the `login` → container → `guard` flow.
- File is committed.

**Hint.** Search the repo for `protocol AsyncBearerAuthenticator` and `func login`. The auth container lives under `Sources/Vapor/Authentication/`.

**Estimated time.** 45 minutes.

---

## Problem 3 — Add an `@Parent` relationship: notes belong to a notebook

**Problem statement.** Add a `Notebook` model (a `name` and an id) and give `Note` a `@Parent` relationship to it (`notebook_id` foreign key). Write the migration for `Notebook` and a second migration that adds the `notebook_id` column to `notes` with a foreign-key constraint. Update `POST /notes` to accept a `notebook_id` and reject (`422`) a note that references a non-existent notebook.

**Deliverables.** `Notebook.swift`, `CreateNotebook.swift`, `AddNotebookToNote.swift` migrations, the updated `Note` model and `create` handler, and a `notes/relationships.md` (100 words) on what `@Parent`/`@Children` generate in SQL.

**Acceptance criteria.**

- Two new migrations exist and run cleanly with `swift run App migrate`.
- The second migration adds the column to the existing table (it does *not* recreate `notes`).
- `POST /notes` with a valid `notebook_id` creates the note; with an unknown `notebook_id` returns `422` (or `404`) — not a `500` from a foreign-key violation.
- `swift build`: 0 warnings, 0 errors.

**Hint.** `@Parent(key: "notebook_id") var notebook: Notebook`. In the migration, `.field("notebook_id", .uuid, .required, .references("notebooks", "id"))`. Validate the parent exists with `Notebook.find(id, on: req.db)` and throw a clean `422` before creating the note, so the FK violation never reaches Postgres.

**Estimated time.** 75 minutes.

---

## Problem 4 — Make `/health/db` a real readiness probe and document the difference

**Problem statement.** A liveness probe (`/health`) answers "is the process up?"; a readiness probe (`/health/db`) answers "can it serve traffic?" Implement `/health/db` so it runs a real database round-trip and returns `503 Service Unavailable` (not `500`) when the database is unreachable. Then write up why an orchestrator routes traffic differently based on each.

**Deliverables.** The `/health/db` route, and `notes/health-probes.md` (150 words) distinguishing liveness from readiness and explaining why a failing readiness probe should *not* restart the container (a database outage is not the container's fault).

**Acceptance criteria.**

- `/health/db` returns `200` when Postgres is up.
- `/health/db` returns `503` (verified by stopping the Postgres container and hitting the endpoint) — not a `500`, not a hang.
- The writeup correctly distinguishes liveness from readiness.

**Hint.** Wrap the query in `do { _ = try await Note.query(on: req.db).count(); return Response(status: .ok) } catch { return Response(status: .serviceUnavailable) }`. Stop the container with `docker stop notes-pg` to test the failure path, then `docker start notes-pg` to recover.

**Estimated time.** 45 minutes.

---

## Problem 5 — Write `VaporTesting` tests for the full CRUD cycle

**Problem statement.** Using `VaporTesting` and Swift Testing, write an in-process test suite that exercises all five endpoints: create a note (asserting `201` and a generated id), read it back, list it, partial-update it (asserting the untouched field survives), and delete it (asserting `204` then `404`). Cover the `401` path for an unauthenticated write.

**Deliverables.** `Tests/AppTests/NotesTests.swift` with at least six `@Test` functions, and a green `swift test` run.

**Acceptance criteria.**

- At least six `@Test` functions covering create, read, list, update (partial-update preservation), delete, and an auth-failure case.
- Tests run in-process (`app.testing()`), against a test database (Postgres test instance or SQLite in-memory via `fluent-sqlite-driver`).
- `swift test`: all green, 0 warnings, 0 errors.

**Hint.** A reusable `withApp` helper that builds an `Application(.testing)`, runs `configure`, runs migrations with `app.autoMigrate()`, runs the test closure, then `app.autoRevert()` and `asyncShutdown()`. For the auth header in a test request, pass `headers:` to `app.testing().test(...)`. Using SQLite in-memory for tests keeps them fast and hermetic and proves the model code is driver-agnostic.

**Estimated time.** 75 minutes.

---

## Problem 6 — Read one Swift on Server case study and write a deployment note

**Problem statement.** Browse the Swift on Server guides and the Vapor community (the Swift Forums "Server" category, the Vapor Discord announcements, or a published case study such as a company's "we run Vapor in production" writeup). Pick one real deployment story from the last ~18 months and extract what it says about the operational shape of a Vapor service — image size, memory footprint, boot time, connection pooling, or observability.

**Deliverables.** `notes/production-vapor.md` (250 words) covering:

1. The source (title and URL).
2. The deployment shape it describes (where it runs, image size / memory if stated).
3. One operational lesson you would apply to your own `notes-api` if you deployed it.
4. One claim from the source you would want to verify yourself before trusting it.

**Acceptance criteria.**

- `notes/production-vapor.md` exists, is 220–280 words, and cites a real source URL.
- It names a concrete operational detail (not just "Vapor is fast").
- It identifies one lesson and one claim-to-verify.
- File is committed.

**Hint.** Good starting points: the Swift on Server "Deploying" guides (<https://www.swift.org/documentation/server/>), the Swift Forums Server category (<https://forums.swift.org/c/server/>), and the Vapor docs' deploy section. Prefer a source with *numbers* (MB, ms, RPS) over one with adjectives.

**Estimated time.** 45 minutes.

---

## Submission

Push the entire `notes/` directory and all code changes to your Week 5 Git repository. The instructor reviews by:

1. Reading each note in `notes/`.
2. Running `swift build` and `swift test` — both must pass.
3. Hitting the new endpoints (`/notes/:id/raw`, `/health/db`) with `curl` to confirm the documented behaviour.
4. Cross-checking the cited URLs are real and the claims in the notes are consistent with the source.

A submission whose code builds, whose tests pass, and whose notes are present and accurate is a pass. The most common review-fail is "the note claims X but the linked source says Y" — double-check before submitting.

---

## Rubric

| Criterion | Weight | What full marks looks like |
|---|---|---|
| **Problem 1 — per-route encoder** | 15% | The raw route overrides the wire format without leaking into the normal route; the writeup is correct. |
| **Problem 2 — Vapor source reading** | 10% | Two real file paths cited; the `login`/`guard` flow described accurately. |
| **Problem 3 — `@Parent` relationship** | 20% | Two clean migrations (the second alters, not recreates); unknown notebook → `422`, not `500`. |
| **Problem 4 — readiness probe** | 15% | `/health/db` returns `503` (not `500`/hang) with the DB down; liveness-vs-readiness explained. |
| **Problem 5 — `VaporTesting` suite** | 25% | Six+ green tests, in-process, partial-update preservation and `401` both covered. |
| **Problem 6 — production case study** | 10% | A real source with concrete numbers; one lesson and one claim-to-verify. |
| **Build hygiene** | 5% | Everything builds and tests clean under strict concurrency — no warnings. |

Pass mark for the homework: **70%**. Anything that does not build is an automatic fail on that problem regardless of the prose — a server you cannot run is a server you have not written.

---

**References**

- Vapor — "Content" (custom encoders): <https://docs.vapor.codes/basics/content/>
- Fluent — "Relations" (`@Parent`/`@Children`): <https://docs.vapor.codes/fluent/relations/>
- Vapor — "Testing": <https://docs.vapor.codes/advanced/testing/>
- Swift on Server — guides: <https://www.swift.org/documentation/server/>
- `vapor/vapor` — source: <https://github.com/vapor/vapor>
