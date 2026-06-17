# Challenge 1 — RFC 9457 Problem-JSON Errors Across Every Notes Endpoint

> **Estimated time:** 120–150 minutes. This is the challenge that turns an API a client engineer tolerates into one they enjoy. The error contract is half the public surface of an API, and almost nobody designs it deliberately. You will.

Vapor's default error body is `{"error": true, "reason": "..."}`. It is fine for a demo and inadequate for a service a real client decodes. This challenge replaces it with a consistent, machine-readable error contract following **RFC 9457 — Problem Details for HTTP APIs** (the successor to RFC 7807), adds request validation, and proves with tests that *every failure path* returns the right status code **and** the right body. The result is the error layer the mini-project's grading rubric rewards and the SwiftUI client in Phase III decodes into typed Swift errors.

## What RFC 9457 specifies

A problem-details response has media type `application/problem+json` and a body with these members (all optional, but conventionally present):

```json
{
  "type": "https://api.notes.example/problems/validation-error",
  "title": "Validation failed",
  "status": 422,
  "detail": "title must be 1–200 characters",
  "instance": "/notes",
  "errors": [
    { "field": "title", "message": "must be 1–200 characters" }
  ]
}
```

- **`type`** — a URI identifying the problem class. Stable; a client can switch on it.
- **`title`** — a short human-readable summary of the problem class. Does not change per occurrence.
- **`status`** — the HTTP status code, duplicated in the body for convenience.
- **`detail`** — human-readable explanation specific to *this* occurrence.
- **`instance`** — a URI for the specific occurrence (here, the request path).
- **`errors`** — a non-standard but widely-used extension member: a list of per-field validation failures. RFC 9457 explicitly allows extension members.

The contract you ship: **every** error response from the notes service — not just validation, but `400` malformed id, `401` missing token, `404` not found, `405` wrong method, `415` wrong content type, `422` validation, and `500` unexpected — is `application/problem+json` with this shape. No endpoint ever returns the default Vapor error body. No endpoint ever returns an HTML error page.

## Starting point

Build on the `notes-api` from Exercises 1–3 (model, migration, CRUD, bearer auth, logging, env config). You are adding an error layer on top.

## Your task, in four parts

### Part 1 — The problem-details type and a custom error middleware

Define a `Content`-conforming `ProblemDetails` struct and an `AsyncMiddleware` that *replaces* `ErrorMiddleware`. It catches any thrown `Error`, maps it to a `ProblemDetails`, and writes it with the right status and the `application/problem+json` content type.

```swift
import Vapor

struct ProblemDetails: Content {
    let type: String
    let title: String
    let status: Int
    let detail: String
    let instance: String
    let errors: [FieldError]?

    static let defaultContentType = HTTPMediaType(type: "application", subType: "problem+json")

    struct FieldError: Content {
        let field: String
        let message: String
    }
}
```

The middleware must map at least these error sources to the right `(status, type, title)`:

| Thrown error | status | `type` slug | `title` |
|---|---|---|---|
| `ValidationError` (yours, Part 3) | 422 | `validation-error` | Validation failed |
| `AbortError` with `.badRequest` (malformed UUID) | 400 | `bad-request` | Bad request |
| `AbortError` with `.unauthorized` (auth guard) | 401 | `unauthorized` | Authentication required |
| `AbortError` with `.notFound` | 404 | `not-found` | Resource not found |
| `AbortError` with `.unsupportedMediaType` | 415 | `unsupported-media-type` | Unsupported media type |
| Any other `Error` | 500 | `internal-error` | Internal server error |

Crucial detail: for the `500` case, the `detail` must be a generic string (`"An unexpected error occurred."`) in `production`, and may include the underlying error in `development`. **Never leak an internal error message to a production client** — it can disclose stack internals, SQL fragments, or secrets. Branch on `app.environment`.

### Part 2 — Validation at the decode boundary

Make `CreateNoteRequest` and `UpdateNoteRequest` validate their fields. Vapor ships `Validatable`:

```swift
extension CreateNoteRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty && .count(...200))
        validations.add("body", as: String.self, is: .count(...10_000))
    }
}
```

In the handler, call `try CreateNoteRequest.validate(content: req)` **before** decoding, and convert any `ValidationsError` into your own `ValidationError` carrying the per-field messages, so the middleware can render it as `422` with the `errors` array populated.

### Part 3 — A typed `ValidationError`

Define a `ValidationError: Error` that holds `[ProblemDetails.FieldError]`. Map Vapor's `ValidationsError` into it (Vapor's `ValidationsError.failures` gives you the per-field results). The middleware in Part 1 special-cases this to a `422` with the `errors` array.

### Part 4 — Tests proving every failure path

Using `VaporTesting`, write a test per failure path that asserts **both** the status code and the body. This is the part that earns the grade — anyone can write the happy path; you are proving the *sad* paths.

```swift
import VaporTesting
import Testing
@testable import App

@Suite("Notes error contract")
struct NotesErrorTests {
    @Test("malformed id returns 400 problem+json")
    func malformedID() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "/notes/not-a-uuid") { res async throws in
                #expect(res.status == .badRequest)
                #expect(res.headers.contentType == HTTPMediaType(type: "application", subType: "problem+json"))
                let problem = try res.content.decode(ProblemDetails.self)
                #expect(problem.status == 400)
                #expect(problem.type.hasSuffix("bad-request"))
                #expect(problem.instance == "/notes/not-a-uuid")
            }
        }
    }

    // ... one @Test per row of the table below.
}
```

You must cover, at minimum, these eight paths:

1. `GET /notes/not-a-uuid` → **400**, `type` ends `bad-request`.
2. `POST /notes` with **no** `Authorization` header → **401**, `type` ends `unauthorized`.
3. `POST /notes` with **wrong** token → **401**, `type` ends `unauthorized`.
4. `GET /notes/<random-but-absent-uuid>` → **404**, `type` ends `not-found`.
5. `POST /notes` (authed) with `{"title":"","body":"x"}` → **422**, `errors` contains a `title` entry.
6. `POST /notes` (authed) with a 201-char title → **422**, `errors` contains a `title` entry.
7. `POST /notes` (authed) with `Content-Type: text/plain` → **415**, `type` ends `unsupported-media-type`.
8. A forced internal error (inject a route that throws a non-`AbortError`) → **500**, `detail` is the *generic* string in `.production`.

Each test asserts the **status** AND decodes the body into `ProblemDetails` and asserts at least one body field. A test that only checks the status code does not pass this challenge — the whole point is the body contract.

## Acceptance criteria

- [ ] `ProblemDetails` conforms to `Content` with `defaultContentType` = `application/problem+json`.
- [ ] A custom error middleware replaces `ErrorMiddleware` and maps every error source in the Part 1 table to the correct `(status, type, title)`.
- [ ] The `500` path returns a **generic** `detail` in `.production` and may include the error in `.development`. You can prove this by running the relevant test under both environments.
- [ ] `CreateNoteRequest` and `UpdateNoteRequest` validate via `Validatable`; an invalid body produces a `422` with a populated `errors` array.
- [ ] All eight failure-path tests exist and pass: `swift test` reports them green.
- [ ] Each failure-path test asserts the **status code** and decodes the **body** into `ProblemDetails`, asserting at least one body field.
- [ ] `swift build` and `swift test`: 0 warnings, 0 errors under strict concurrency.
- [ ] A `curl` against a malformed id returns `application/problem+json`, not the default Vapor error body and not HTML.

## Hints

<details>
<summary>Registering the middleware so it actually catches everything</summary>

Your custom middleware must be added **before** (outer to) anything that can throw, and you must **not** also add the default `ErrorMiddleware` (two error middlewares double-wrap and the inner one wins). In `configure`:

```swift
app.middleware = .init()   // start from empty — drop Vapor's default ErrorMiddleware
app.middleware.use(ProblemDetailsMiddleware(environment: app.environment))
app.middleware.use(StructuredLoggingMiddleware())
```

Resetting `app.middleware` to empty is the cleanest way to guarantee yours is the only error middleware. If you only `use(...)` yours, Vapor's default may still be present depending on how you scaffolded.

</details>

<details>
<summary>Mapping an AbortError to status/type</summary>

`AbortError` exposes `.status` (an `HTTPStatus`). Switch on `error`:

```swift
func problem(for error: Error, instance: String) -> ProblemDetails {
    if let validation = error as? ValidationError {
        return ProblemDetails(type: slug("validation-error"), title: "Validation failed",
                              status: 422, detail: "One or more fields are invalid.",
                              instance: instance, errors: validation.fieldErrors)
    }
    if let abort = error as? AbortError {
        let (slugName, title) = mapping(for: abort.status)
        return ProblemDetails(type: slug(slugName), title: title,
                              status: Int(abort.status.code), detail: abort.reason,
                              instance: instance, errors: nil)
    }
    let detail = environment.isRelease ? "An unexpected error occurred." : String(describing: error)
    return ProblemDetails(type: slug("internal-error"), title: "Internal server error",
                          status: 500, detail: detail, instance: instance, errors: nil)
}
```

`environment.isRelease` is your production check; `slug(_:)` prefixes the `type` URI base.

</details>

<details>
<summary>Turning a thrown problem into a Response with the right content type</summary>

```swift
func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    do {
        return try await next.respond(to: request)
    } catch {
        let problem = problem(for: error, instance: request.url.path)
        let response = Response(status: HTTPStatus(statusCode: problem.status))
        try response.content.encode(problem, as: problem.contentType)
        return response
    }
}
```

`response.content.encode(_:as:)` sets the body and the `Content-Type` header to `application/problem+json` in one call.

</details>

<details>
<summary>Forcing a 500 for test #8 without breaking production</summary>

Add a route guarded by `app.environment == .testing`:

```swift
if app.environment == .testing {
    app.get("__boom") { _ async throws -> Response in
        struct Boom: Error {}
        throw Boom()
    }
}
```

`Boom` is not an `AbortError`, so it falls through to the `500` branch — exactly the path you want to test.

</details>

## Submission

Commit to your Week 5 GitHub repository at `challenges/challenge-01-problem-json/` containing the added source files (`ProblemDetails.swift`, the middleware, the `Validatable` extensions, the typed `ValidationError`) and the `AppTests/NotesErrorTests.swift` test suite. The instructor reviews by running `swift test` and by `curl`-ing a malformed request to confirm the wire body is `application/problem+json`. The most common review-fail is "the tests assert the status code but never decode the body" — the body contract is the entire point, so assert it.

---

**References**

- RFC 9457 — Problem Details for HTTP APIs: <https://www.rfc-editor.org/rfc/rfc9457.html>
- Vapor — "Errors": <https://docs.vapor.codes/basics/errors/>
- Vapor — "Validation": <https://docs.vapor.codes/basics/validation/>
- Vapor — "Testing" (`VaporTesting`): <https://docs.vapor.codes/advanced/testing/>
- Swift Testing — `@Test` / `#expect`: <https://developer.apple.com/documentation/testing>
