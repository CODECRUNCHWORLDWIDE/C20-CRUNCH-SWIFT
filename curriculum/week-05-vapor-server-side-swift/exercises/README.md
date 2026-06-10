# Week 5 — Exercises

Three focused drills that build the pieces of the `notes-api` mini-project. Each one takes 45–75 minutes. Do them in order — exercise 2 protects the routes from exercise 1, and exercise 3 instruments the service from both.

## Index

1. **[Exercise 1 — Fluent model, migration, and CRUD routes](exercise-01-fluent-model-migration-crud.md)** — define a `Note` Fluent model and a Postgres migration, then wire up the five CRUD routes returning `Content`-conforming JSON. A guided, step-by-step walkthrough with starter and solution code. (~70 min)
2. **[Exercise 2 — Bearer-token authentication middleware](exercise-02-bearer-auth-middleware.swift)** — write a bearer-token middleware, the idiomatic `BearerAuthenticator` way, and protect the write routes (`POST`, `PATCH`, `DELETE`) while leaving the read routes public. A runnable Swift file with TODOs and a hints section. (~50 min)
3. **[Exercise 3 — Structured logging and environment config](exercise-03-structured-logging-and-config.swift)** — add `swift-log` structured logging with request-scoped metadata, and move the database credentials and API token to environment-driven configuration that fails loudly when a required secret is missing. A runnable Swift file with TODOs and a hints section. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run it against a real Postgres container (`docker run ... postgres:16`, the exact command is in Exercise 1). A server exercise you cannot `curl` is one you have not finished.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must end with `swift build` printing **no warnings and no errors** under Swift 6 strict concurrency. A `Sendable` warning is a bug this week, exactly as it was in Week 4.

There are no solutions checked in beyond what each file contains in its hints section. The course is open source — fuller solutions live in forks. After you finish, search GitHub for `c20-week-05` to compare.

## The recurring check

Every exercise here ends with a working endpoint you reach over HTTP:

```bash
curl -s -H "Authorization: Bearer dev-token" http://localhost:8080/notes | jq
```

If that returns JSON (even `[]`), the exercise's plumbing is correct. If it hangs, errors, or returns HTML, something upstream is wrong — re-read the step you just finished.
