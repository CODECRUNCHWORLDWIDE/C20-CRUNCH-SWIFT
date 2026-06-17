# Week 5 — Quiz

Twelve multiple-choice questions. Take it with your lecture notes closed. Aim for 9/12 before moving to Week 6. Answer key at the bottom — don't peek.

---

**Q1.** In a Vapor 4 service scaffolded the conventional way, you run `swift run App migrate`. What does the `App` refer to?

- A) The package name in `Package.swift`.
- B) The executable target / module named `App` that contains your code. The convention is one module called `App` built into an executable also addressed as `App`.
- C) A built-in Vapor command-line tool installed alongside the toolchain.
- D) The `Application` instance, referenced by name from the shell.

---

**Q2.** Your `configure(_:)` registers middleware in this order:

```swift
app.middleware.use(MyAuthMiddleware())
app.middleware.use(ErrorMiddleware.default(environment: app.environment))
```

A request hits a protected route with no token, and `MyAuthMiddleware` throws `Abort(.unauthorized)`. What does the client receive?

- A) A clean `401 Unauthorized` JSON body — `ErrorMiddleware` catches the throw.
- B) A dropped connection or unhandled error, because `ErrorMiddleware` is registered *after* (inner to) `MyAuthMiddleware`, so it never sees the throw from the auth layer. The fix is to register `ErrorMiddleware` first so it is outermost.
- C) A `500 Internal Server Error`, because auth errors always map to 500.
- D) The request succeeds; middleware order does not affect error handling.

---

**Q3.** You make a type sendable over HTTP by conforming it to `Content`. What does `Content` refine?

- A) Only `Encodable` — `Content` is for responses only.
- B) `Codable` (`Encodable` + `Decodable`) plus the request/response coding protocols, with a default media type of `.json`. That is why a one-word `: Content` conformance is usually enough.
- C) `Sendable` and nothing else.
- D) A Vapor-specific serialization protocol unrelated to `Codable`.

---

**Q4.** A Fluent model property is declared `@Timestamp(key: "created_at", on: .create) var createdAt: Date?`. In a `POST` handler that creates the row, what should you do with `createdAt`?

- A) Set it to `Date()` yourself before calling `create(on:)`.
- B) Nothing — Fluent sets it automatically on insert. Setting it by hand fights the framework, and `@Timestamp(on: .create)` exists precisely so you don't.
- C) Pass it in the request body so the client controls it.
- D) Set it in the migration's `prepare` method.

---

**Q5.** Why does Fluent require you to write explicit `Migration`s with `prepare`/`revert` instead of generating the schema from the model automatically?

- A) Because Swift cannot reflect over property wrappers at runtime.
- B) Because a production schema and the model diverge for periods of time during a zero-downtime deploy — you ship the migration that adds a column, deploy it, *then* deploy the code that uses the column. Auto-schema cannot express that two-step; explicit, ordered, reversible migrations can.
- C) Because Postgres does not support `CREATE TABLE` from an ORM.
- D) It is a historical accident; Fluent 5 removes migrations entirely.

---

**Q6.** In the idiomatic Vapor bearer-auth pattern, your `AsyncBearerAuthenticator.authenticate(bearer:request:)` finds the token is wrong. What should it do?

- A) `throw Abort(.unauthorized)` immediately to reject the request.
- B) Nothing — return without calling `request.auth.login(...)`. "Not logging in" means "not authenticated," and a separate `guardMiddleware` turns the absence of a logged-in principal into the `401`. Authenticators never reject so they can be stacked; a single guard rejects.
- C) Return `false` from the function.
- D) Log the failure and call `next.respond(to:)` anyway.

---

**Q7.** You compare an incoming bearer token to the expected secret with `incoming == expected` on two `String`s. Why does the lecture insist on a constant-time comparison instead?

- A) `==` on `String` does not compile for secrets.
- B) `==` can short-circuit at the first differing byte, so an attacker who measures response timing across many guesses can learn the secret byte by byte. A constant-time comparison folds every byte into the result, making timing independent of where the mismatch is.
- C) Constant-time comparison is faster.
- D) `String` equality is locale-dependent and unreliable for tokens.

---

**Q8.** Your `AppConfig.load()` reads configuration at boot. `DATABASE_HOST` is missing but `DATABASE_PASSWORD` is also missing. Which is correct?

- A) Both should fall back to defaults (`localhost` and `""`) so the service always boots.
- B) `DATABASE_HOST` should fall back to `localhost` (a safe development default), but `DATABASE_PASSWORD` should make the service refuse to boot with a clear error naming the variable. A secret has no safe default; failing loud at startup beats serving with a guessable credential.
- C) Both should throw — every missing variable is fatal.
- D) Neither should throw; configuration errors should surface on the first query.

---

**Q9.** `swift-log` ships a logging *API* package separate from any logging *backend*. Why is that separation valuable?

- A) It lets each library pick its own output format.
- B) It lets a *library* log without knowing or choosing where the logs go; the *application* bootstraps exactly one backend (`LoggingSystem.bootstrap`, once, before anything logs) and every logger in the process routes there — including Vapor's and Fluent's.
- C) It reduces binary size.
- D) It is required for `async` logging.

---

**Q10.** You log `req.logger.info("created note", metadata: ["note_id": .string(id), "title_length": .stringConvertible(n)])` instead of `req.logger.info("created note \(id) len \(n)")`. What does the structured form buy you?

- A) Nothing — they produce identical output.
- B) The structured fields are emitted as discrete key-value pairs a log aggregator can filter and aggregate on (`note_id == X`, `title_length > 200`), rather than being mashed into a single string you can only grep.
- C) The structured form is faster because it skips string interpolation.
- D) It automatically redacts sensitive values.

---

**Q11.** In `configure`, the Postgres connection is built with `tls: .disable` for local development. What is the production-correct change, and why does it matter?

- A) Leave it `.disable`; TLS is handled by the load balancer.
- B) Use `tls: .require(...)` (or `.prefer`) so the connection to the database is encrypted. Database credentials and row data crossing an unencrypted link — even inside a VPC — are an avoidable disclosure risk; encrypt in transit.
- C) Change it to `tls: .none`; there is no functional difference.
- D) TLS only applies to the HTTP listener, not the database connection.

---

**Q12.** Your `PATCH /notes/:id` handler decodes the body into `struct UpdateNoteRequest: Content { let title: String?; let body: String? }` and applies `if let title = input.title { note.title = title }`. A client sends `{"title":"Renamed"}` (no `body` key). What happens to the stored `body`, and why is that correct PATCH semantics?

- A) `body` is set to `nil`, blanking the column — a bug.
- B) `body` is left unchanged, because `input.body` decodes to `nil` (absent key) and the `if let` skips it. A field absent from a PATCH body must be left untouched; that is exactly what partial-update semantics require.
- C) The request is rejected with a `400` because `body` is required.
- D) `body` is set to the empty string `""`.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — Vapor's convention is a single module named `App`, built into an executable also addressed as `App`. `swift run App migrate` runs the `migrate` subcommand of *your* service. It is not the package name (which can differ), not a separate tool, and not the `Application` instance.

2. **B** — `ErrorMiddleware` catches throws only from middleware *inner* to it (registered after it). Here it is registered after the auth middleware, so it is inner, and a throw from the auth layer escapes it. The fix is to register `ErrorMiddleware` first so it is outermost and wraps everything. This ordering bug is the single most common Vapor middleware mistake.

3. **B** — `Content` refines `Codable` plus `RequestDecodable`/`ResponseEncodable`, with `defaultContentType` of `.json`. Because it is `Codable`-based, adding `: Content` to an already-`Codable` type is usually all it takes. It is not encode-only, not `Sendable`-only, and very much built on `Codable`.

4. **B** — `@Timestamp(on: .create)` is Fluent-managed: it is set automatically on insert. You never set it by hand, never accept it from the client, and never set it in the migration (the migration only declares the *column*). Letting Fluent own it is the entire reason the wrapper exists.

5. **B** — Explicit migrations exist so the schema can lead the code during a zero-downtime deploy: add the column (migration), deploy, then deploy the code that reads it. Auto-schema ("the model is the schema") cannot express that decoupling. Ordered, reversible migrations are the discipline that makes safe deploys possible.

6. **B** — Authenticators only ever *log in on success* and do nothing on failure, so that multiple authenticators can be stacked on one route group (bearer OR session OR basic). A single `guardMiddleware` at the end asks "did anyone log in?" and produces the `401`. An authenticator that threw on failure would make stacking impossible.

7. **B** — `==` can return early at the first mismatched byte, leaking, through response timing, how many leading bytes were correct. An attacker can walk the secret byte by byte. A constant-time comparison folds every byte into the result so timing does not depend on the mismatch position. For a production secret this is table stakes.

8. **B** — A value with a safe development default (`DATABASE_HOST` → `localhost`) uses `?? default`; a secret with no safe default (`DATABASE_PASSWORD`) must make the service refuse to boot, with a message naming the missing variable. Fail loud, fail at startup — serving traffic with a missing or guessable secret is the worse outcome.

9. **B** — The API/backend split lets a *library* emit logs without choosing a destination; the *application* bootstraps a single backend exactly once (before anything logs) and every `Logger` in the process — yours, Vapor's, Fluent's — routes there. That is why `LoggingSystem.bootstrap` must run once, at the very top of `main`.

10. **B** — Structured metadata is emitted as discrete, typed key-value fields that a log aggregator can filter and aggregate on. The string-interpolated form collapses everything into one opaque message you can only grep. Structured logging is what makes `note_id == X` or `title_length > 200` a query instead of a regex.

11. **B** — `.require(...)` (or `.prefer`) encrypts the connection between the service and Postgres. Credentials and row data on an unencrypted link are an avoidable disclosure risk even inside a private network; encrypt in transit. The database TLS setting is independent of the HTTP listener's TLS.

12. **B** — An absent key decodes the optional to `nil`, the `if let` skips it, and the stored value is left untouched. That is correct PATCH semantics: present fields overwrite, absent fields are preserved. Setting absent fields to `nil`/`""` (options A and D) would be the classic partial-update bug.

</details>

---

If you scored under 9, re-read the lecture sections for the questions you missed (Q2/Q5 → Lecture 1 §1.6 and §1.9; Q6/Q7 → Lecture 2 and Exercise 2; Q9/Q10 → Lecture 1 §1.11 and Exercise 3). If you scored 11 or 12, you're ready for the [homework](./06-homework.md).
