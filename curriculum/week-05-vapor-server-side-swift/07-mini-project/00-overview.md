# Mini-Project — `notes-api`: a Dockerized REST service backed by Postgres

> Build a production-shaped Vapor 4 service exposing the five notes endpoints — `POST /notes`, `GET /notes`, `GET /notes/:id`, `PATCH /notes/:id`, `DELETE /notes/:id` — persisting to Postgres through Fluent, authenticated with a bearer-token middleware, configured entirely from the environment, instrumented with structured logging, and shipping a Dockerfile plus a `docker compose up` integration test. By Sunday night, a reviewer should be able to clone your repo, run one command, and watch the service come up next to its database and pass its own integration test. That is the bar: not "it runs on my machine," but "it runs anywhere Docker runs, and proves it."

This is the keystone of Phase I. The `notes-api` you build here is not a throwaway — it is the backend the SwiftUI client talks to in Phase III (Week 13 wires offline-first write-replay against exactly these endpoints), and the `Note` model you ship becomes the shared `NotesCore` package in Week 6. Build it like you will have to live with it, because you will.

**Estimated time:** ~10.5 hours (split across Friday, Saturday, and Sunday in the suggested schedule).

**Compounds on / into:** This mini-project consumes the four pieces you drilled this week — the Fluent model + CRUD (Exercise 1), the bearer-token middleware (Exercise 2), the structured logging + env config (Exercise 3), and, if you did it, the RFC 9457 error contract (Challenge 1). The mini-project is where they become one coherent service. **Week 6** extracts this service's request/response models into a shared SwiftPM package; **Week 13** points the iOS client at it. Design the wire contract like it is permanent — because for the rest of the track, it is.

---

## What you will build

A single SwiftPM executable package named `notes-api`, built around the `App` module, with:

1. **Five CRUD endpoints** over a `Note` resource, persisting to Postgres via Fluent.
2. **A bearer-token middleware** that protects the write endpoints (`POST`, `PATCH`, `DELETE`) while leaving the reads (`GET`-list, `GET`-by-id) public.
3. **Environment-driven configuration** — every credential and secret read from the environment at boot, failing loud when a required one is missing.
4. **Structured logging** with `swift-log` — a per-request access log plus business-event logs with structured metadata.
5. **A health endpoint** (`GET /health`) and a readiness endpoint (`GET /health/db`) that actually pings the database.
6. **A multi-stage Dockerfile** building on the official Swift images.
7. **A `docker-compose.yml`** that brings the service up next to a Postgres 16 container, runs the migration, and serves.
8. **An integration test** runnable with `docker compose up` (or a small wrapper script) that exercises the full CRUD cycle against the containerized service and asserts the results.

### The endpoint contract

| Method | Path | Auth | Success | Body in | Body out |
|---|---|---|---|---|---|
| `GET` | `/health` | none | 200 | — | `{"status":"ok"}` |
| `GET` | `/health/db` | none | 200 / 503 | — | `{"status":"ok"}` or `503` |
| `GET` | `/notes` | none | 200 | — | `[Note]`, newest first |
| `GET` | `/notes/:id` | none | 200 / 404 | — | `Note` |
| `POST` | `/notes` | **bearer** | 201 | `{title, body}` | `Note` |
| `PATCH` | `/notes/:id` | **bearer** | 200 / 404 | `{title?, body?}` | `Note` |
| `DELETE` | `/notes/:id` | **bearer** | 204 / 404 | — | — |

`PATCH` is a partial update: a field absent from the body is left untouched; a field present overwrites. A malformed `:id` (not a UUID) returns `400`. A missing or wrong bearer token on a write returns `401`. The wire format is JSON with ISO-8601 dates.

---

## Project structure

```
notes-api/
├── Package.swift
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .gitignore
├── .env.example
├── README.md                         ← project README (you write this)
├── scripts/
│   └── integration-test.sh           ← the docker compose integration test
├── Sources/
│   └── App/
│       ├── entrypoint.swift
│       ├── configure.swift
│       ├── routes.swift
│       ├── AppConfig.swift            ← typed env config (Exercise 3)
│       ├── Controllers/
│       │   └── NotesController.swift
│       ├── Models/
│       │   └── Note.swift
│       ├── Migrations/
│       │   └── CreateNote.swift
│       ├── Auth/
│       │   ├── APIUser.swift
│       │   └── APITokenAuthenticator.swift
│       └── Middleware/
│           └── StructuredLoggingMiddleware.swift
└── Tests/
    └── AppTests/
        └── NotesTests.swift           ← VaporTesting unit/integration tests
```

If you completed Challenge 1, fold its files in (`ProblemDetails.swift`, the problem-details middleware, the `Validatable` extensions). The rubric rewards the error contract.

---

## Rules

- **You may** read the Vapor and Fluent docs, the Vapor/Fluent/swift-log source, your Week 5 exercises and challenge, and the Swift on Server material.
- **You may NOT** use a different ORM (no raw `PostgresNIO` for the CRUD — use Fluent; a raw SQLKit escape for `/health/db` is fine), a different web framework, or a managed cloud database for the deliverable (the reviewer runs it locally in Docker).
- Dependencies are limited to: `vapor`, `fluent`, `fluent-postgres-driver`, and (test only) `VaporTesting`. No third-party auth, logging-backend, or config libraries — the point is to learn the primitives.
- Target Swift 6, **strict concurrency on**. A `Sendable` warning is a build failure.
- Every credential and secret comes from the environment. **No secret literals in source.** The reviewer greps for `password`, `token`, and `secret` string literals; finding one is a fail.
- `.env` is gitignored; `.env.example` is committed.

---

## Acceptance criteria

The grading rubric is below; each box maps to a deliverable.

### Functionality (35%)

- [ ] All five CRUD endpoints behave per the contract table, including status codes (`201` on create, `204` on delete, `404` on absent, `400` on malformed id).
- [ ] `PATCH` is a true partial update — a body of `{"title":"x"}` does not blank out `body`.
- [ ] `GET /notes` returns notes newest-first.
- [ ] `GET /health` returns `{"status":"ok"}`; `GET /health/db` returns `200` only when the database round-trip succeeds and `503` otherwise.
- [ ] Dates serialise as ISO-8601 strings.

### Security & config (20%)

- [ ] Write endpoints require `Authorization: Bearer <token>`; missing or wrong token → `401`; reads are public.
- [ ] The token comparison is constant-time (Exercise 2).
- [ ] Every credential is read from the environment via a typed `AppConfig`; a missing required secret makes the service refuse to boot with a message naming the variable.
- [ ] No secret literals in source. `.env` is gitignored; `.env.example` lists the keys.

### Persistence (15%)

- [ ] The `Note` model and `CreateNote` migration are correct; `swift run App migrate` prepares the schema.
- [ ] CRUD persists across a service restart (a created note survives a container restart, because it lives in Postgres, not memory).

### Logging (10%)

- [ ] A per-request access log line carries `method`, `path`, `status`, `duration_ms`, and a `request_id`, all as structured metadata.
- [ ] At least one business event (note created) is logged at `info` with structured `note_id`.
- [ ] `LOG_LEVEL` controls the floor.

### Docker & integration test (20%)

- [ ] The `Dockerfile` is multi-stage (build on `swift:6.0`, run on `swift:6.0-slim`), produces a small final image, and runs as a non-root user.
- [ ] `docker compose up` brings up Postgres and the service, runs the migration, and serves on a published port.
- [ ] `scripts/integration-test.sh` (or an equivalent compose service) exercises the full CRUD cycle against the running container and exits non-zero on any failure.
- [ ] The README documents the one command a reviewer runs to see it all work.

---

## Reference Dockerfile

A multi-stage build. The build stage has the full toolchain; the runtime stage is the slim image plus your binary and the Swift runtime libraries it links.

```dockerfile
# ---- Build stage ----
FROM swift:6.0-jammy AS build
WORKDIR /build

# Resolve dependencies first so this layer caches across source changes.
COPY ./Package.* ./
RUN swift package resolve

# Build the release binary.
COPY . .
RUN swift build -c release --static-swift-stdlib

# Stage the binary and resources into a clean directory.
RUN mkdir -p /staging \
    && cp "$(swift build -c release --show-bin-path)/App" /staging/ \
    && find -L "$(swift build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} /staging/ \; || true

# ---- Runtime stage ----
FROM swift:6.0-jammy-slim AS run

# Run as a non-root user.
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
```

`--static-swift-stdlib` links the Swift runtime statically so the slim image does not need the full Swift runtime package. The `find ... .resources` line copies any bundled resources (Fluent and Vapor ship some); the `|| true` keeps the build from failing when there are none.

---

## Reference docker-compose.yml

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: notes
      POSTGRES_PASSWORD: notes
      POSTGRES_DB: notes
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U notes"]
      interval: 2s
      timeout: 3s
      retries: 15

  migrate:
    build: .
    environment:
      DATABASE_HOST: db
      DATABASE_USERNAME: notes
      DATABASE_PASSWORD: notes
      DATABASE_NAME: notes
      API_TOKEN: dev-token
      LOG_LEVEL: info
    depends_on:
      db:
        condition: service_healthy
    command: ["migrate", "--yes"]

  api:
    build: .
    environment:
      DATABASE_HOST: db
      DATABASE_USERNAME: notes
      DATABASE_PASSWORD: notes
      DATABASE_NAME: notes
      API_TOKEN: dev-token
      LOG_LEVEL: info
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
    command: ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
```

The `migrate` service runs the migration once and exits; the `api` service waits for it to complete successfully before booting. The `db` healthcheck means the migration never races the database coming up. This three-service shape — database, one-shot migrate, long-running api — is the standard production deploy choreography in miniature.

---

## Reference integration test

`scripts/integration-test.sh` — a bash script that brings the stack up, waits for health, runs the CRUD cycle, and tears down. It must exit non-zero on any failed assertion.

```bash
#!/usr/bin/env bash
set -euo pipefail

TOKEN="dev-token"
BASE="http://localhost:8080"

cleanup() { docker compose down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "==> Bringing up the stack"
docker compose up --build -d

echo "==> Waiting for /health"
for i in $(seq 1 30); do
  if curl -fs "$BASE/health" >/dev/null 2>&1; then break; fi
  sleep 1
  if [ "$i" -eq 30 ]; then echo "FAIL: service never became healthy"; exit 1; fi
done

assert_status() {  # $1 expected  $2 actual  $3 message
  if [ "$1" != "$2" ]; then echo "FAIL: $3 (expected $1, got $2)"; exit 1; fi
  echo "ok: $3 ($2)"
}

echo "==> Reads are public"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/notes")
assert_status 200 "$code" "GET /notes is public"

echo "==> Writes require auth"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/notes" \
  -H 'Content-Type: application/json' -d '{"title":"x","body":"y"}')
assert_status 401 "$code" "POST /notes without token is rejected"

echo "==> Create"
created=$(curl -s -X POST "$BASE/notes" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Integration","body":"from the test"}')
id=$(printf '%s' "$created" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
[ -n "$id" ] || { echo "FAIL: create returned no id"; exit 1; }
echo "ok: created $id"

echo "==> Read back"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/notes/$id")
assert_status 200 "$code" "GET /notes/:id returns the created note"

echo "==> Partial update preserves body"
updated=$(curl -s -X PATCH "$BASE/notes/$id" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Renamed"}')
body=$(printf '%s' "$updated" | python3 -c 'import sys,json;print(json.load(sys.stdin)["body"])')
[ "$body" = "from the test" ] || { echo "FAIL: PATCH blanked the body"; exit 1; }
echo "ok: PATCH preserved body"

echo "==> Delete"
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/notes/$id" \
  -H "Authorization: Bearer $TOKEN")
assert_status 204 "$code" "DELETE /notes/:id returns 204"

echo "==> Confirm gone"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/notes/$id")
assert_status 404 "$code" "GET deleted note returns 404"

echo "==> ALL INTEGRATION CHECKS PASSED"
```

Make it executable (`chmod +x scripts/integration-test.sh`) and run it with `./scripts/integration-test.sh`. A passing run prints `ALL INTEGRATION CHECKS PASSED` and exits 0.

---

## Suggested implementation order

### Friday (~4 hours)

1. Assemble the service from your three exercises: copy in the `Note` model, `CreateNote` migration, `NotesController` with all five handlers, the bearer authenticator, the `AppConfig`, and the logging middleware. Get `swift build` clean and `swift run App serve` working against a local Postgres container (as in Exercise 1).
2. Add `/health` and `/health/db`. The latter runs a trivial query (`Note.query(on: req.db).count()` or a raw `SELECT 1` via SQLKit) and returns `503` if it throws.
3. Wire the auth split (public reads, protected writes) from Exercise 2 and confirm with `curl`.

### Saturday (~3 hours)

4. Write the `Dockerfile`, `.dockerignore`, and `docker-compose.yml`. Get `docker compose up --build` to bring all three services up and serve. Debug the inevitable "service can't reach `db`" (the host inside compose is the service name `db`, not `localhost`) and "binary not found" (the staging copy path) issues.
5. Write `scripts/integration-test.sh`. Run it until it passes end-to-end.

### Sunday (~3.5 hours)

6. Write the `VaporTesting` unit tests in `Tests/AppTests/NotesTests.swift`: at least one test per endpoint, covering the happy path and the key failure (404, 401, 400). Use an in-process app with `app.testing()`. Get `swift test` green.
7. Write the project `README.md`: what it is, the one-command quickstart (`./scripts/integration-test.sh`), the endpoint table, the env-var reference, and a note on the auth model.
8. Final clean pass: confirm no secret literals, `.env` gitignored, strict concurrency clean, push.

---

## Hints

- **Inside compose, the database host is `db`, not `localhost`.** The service container reaches Postgres at the compose *service name*. Set `DATABASE_HOST=db` for the api service. `localhost` inside a container is the container itself.
- **`depends_on: condition: service_healthy`** is what stops the migration racing the database. Without the healthcheck + condition, the migrate service starts before Postgres accepts connections and crashes.
- **`--static-swift-stdlib`** in the build keeps the slim runtime image from needing the full Swift runtime. If your final image is 1.5 GB, you forgot it.
- **Run as non-root in the container.** The reference Dockerfile creates a `vapor` user. A service running as root in a container is a finding in any real security review.
- **`app.testing()` boots an in-process app with no socket** — fast, no Docker needed for unit tests. Reserve the compose integration test for the full-stack assertion. Unit tests and the integration test are complementary, not redundant.
- **Tear down with `docker compose down -v`** between integration runs. The `-v` drops the Postgres volume so each run starts from a clean database; otherwise a leftover note from the last run fails a count assertion.

---

## Anti-goals

Explicitly **not** part of this mini-project — do not pursue them here:

- **User accounts and per-user notes.** One shared service token is the auth model. Multi-tenant auth (a `users` table, JWT, sessions) is a later concern.
- **Pagination, search, full-text.** `GET /notes` returns all notes newest-first. Pagination is a real feature; it is not this week's lesson.
- **Deploying to a cloud.** The deliverable runs locally in Docker. Phase IV's capstone deploys the descendant of this service to Fly.io / a VPS; not now.
- **WebSockets, server-sent events.** REST only. The real-time surface arrives with Live Activities in Phase IV.

---

## Submission

Push the solution to your Week 5 GitHub repository at `mini-project/notes-api/`. The instructor reviews by:

1. Cloning the repo.
2. Running `swift test` — must pass.
3. Running `./scripts/integration-test.sh` (or `docker compose up --build` then the test) — must print `ALL INTEGRATION CHECKS PASSED` and exit 0.
4. Grepping the source for secret literals — must find none.
5. Reading the `README.md`.

A submission whose `swift test` passes and whose integration test goes green against the containerized service is a pass. The most common review-fail is "it works with `swift run` locally but the compose stack can't reach the database" — almost always the `DATABASE_HOST=db` vs `localhost` issue. Run the full compose path before you submit.

---

**References**

- Vapor — "Deploy → Docker": <https://docs.vapor.codes/deploy/docker/>
- Vapor — official Dockerfile template (in `vapor new` output): <https://github.com/vapor/template>
- Fluent — "Migrations": <https://docs.vapor.codes/fluent/migration/>
- Vapor — "Testing": <https://docs.vapor.codes/advanced/testing/>
- Docker — Compose `depends_on` conditions: <https://docs.docker.com/compose/how-tos/startup-order/>
- Swift on Server — Docker images: <https://www.swift.org/documentation/server/guides/deploying/docker.html>
