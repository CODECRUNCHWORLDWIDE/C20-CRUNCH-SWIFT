// Exercise 2 — Bearer-token authentication middleware
//
// Goal: Write a bearer-token authenticator the idiomatic Vapor way, and protect
//       the WRITE routes (POST, PATCH, DELETE) while leaving the READ routes
//       (GET-list, GET-by-id) public.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// 1. Continue in the `notes-api` project from Exercise 1 (you need the Note model,
//    the migration, configure.swift, and NotesController). Postgres must be running
//    (see Exercise 1, Setup).
//
// 2. Create a new file Sources/App/Auth/APIUser.swift and paste the
//    "Authenticatable + Authenticator" section below into it. Fill in the TODOs.
//
// 3. Replace your NotesController.boot(routes:) with the version at the bottom of
//    this file (the "WIRING" section), which splits public reads from protected
//    writes. Read the comments — the split is the whole point of the exercise.
//
// 4. Set the token in the environment and run:
//
//        export API_TOKEN=dev-token
//        swift run App serve --hostname 0.0.0.0 --port 8080
//
// 5. Verify the behaviour with the curl commands in the "EXPECTED BEHAVIOUR"
//    section. Reads work without a token; writes require the right token.
//
// ACCEPTANCE CRITERIA
//
//   [ ] `swift build`: 0 warnings, 0 errors under strict concurrency.
//   [ ] GET  /notes        works WITHOUT an Authorization header (public).
//   [ ] GET  /notes/:id    works WITHOUT an Authorization header (public).
//   [ ] POST /notes        returns 401 with no token, 401 with a wrong token,
//                          and 201 with `Authorization: Bearer dev-token`.
//   [ ] PATCH and DELETE   are protected the same way as POST.
//   [ ] The token is read from Environment.get("API_TOKEN"); a missing
//       API_TOKEN makes the service refuse to boot (fatalError), it does NOT
//       silently fall back to a guessable default in production.
//   [ ] You used `grouped(...)` to apply the middleware to a SUBSET of routes,
//       not `app.middleware.use(...)` which would protect everything.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Vapor

// ============================================================================
// AUTHENTICATABLE + AUTHENTICATOR   (Sources/App/Auth/APIUser.swift)
// ============================================================================

// The "user" this token authenticates. For a single shared service token this
// is trivial — there is one logical caller, "the API client". In a real system
// this would be a row in a `users` table looked up by an API key. We keep it
// minimal so the focus stays on the middleware mechanics.
struct APIUser: Authenticatable, Sendable {
    let id: String
}

// The configuration that holds the expected token. We read it ONCE at boot and
// hand it to the authenticator, rather than reading the environment on every
// request. Reading env vars per-request is both slower and harder to test.
struct APITokenConfig: Sendable {
    let expectedToken: String

    static func fromEnvironment() -> APITokenConfig {
        guard let token = Environment.get("API_TOKEN") else {
            fatalError("API_TOKEN is required. Set it before booting the service.")
        }
        return APITokenConfig(expectedToken: token)
    }
}

// The authenticator. `AsyncBearerAuthenticator` is Vapor's purpose-built
// middleware for "Authorization: Bearer <token>" — it parses the header for you
// and calls `authenticate(bearer:request:)` with the token. Your job is to
// decide whether the token is valid and, if so, log in a principal.
struct APITokenAuthenticator: AsyncBearerAuthenticator {
    let config: APITokenConfig

    func authenticate(bearer: BearerAuthorization, request: Request) async throws {
        // TODO:
        //   1. Compare bearer.token against config.expectedToken using a
        //      CONSTANT-TIME comparison (see hint — do NOT use `==` on the
        //      raw strings; that leaks length/timing information).
        //   2. If it matches, call request.auth.login(APIUser(id: "api-client")).
        //   3. If it does not match, do NOTHING. Returning without logging in
        //      means "not authenticated" — the guard middleware (below) turns
        //      that into a 401. Do NOT throw here; let the guard decide.
        fatalError("TODO: implement authenticate(bearer:request:)")
    }
}

// ============================================================================
// CONSTANT-TIME COMPARISON HELPER
// ============================================================================

// A naive `a == b` on Strings can short-circuit on the first differing byte,
// which leaks information about how many leading bytes were correct. For a
// secret comparison we want a comparison whose timing does not depend on WHERE
// the mismatch is. This is the standard pattern.
enum ConstantTime {
    static func equals(_ a: String, _ b: String) -> Bool {
        let lhs = Array(a.utf8)
        let rhs = Array(b.utf8)
        // Comparing lengths first is fine — length is not the secret here, the
        // bytes are. But we still fold length into the result so a length
        // mismatch doesn't early-return.
        var diff = lhs.count ^ rhs.count
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let x = i < lhs.count ? Int(lhs[i]) : 0
            let y = i < rhs.count ? Int(rhs[i]) : 0
            diff |= x ^ y
        }
        return diff == 0
    }
}

// ============================================================================
// WIRING   (replace NotesController.boot(routes:) with this version)
// ============================================================================
//
// The key move: build a `protected` group that carries the authenticator AND a
// guard, and register the write routes on it. The read routes stay on the open
// `notes` group. This is how you protect a SUBSET of routes — exactly what the
// syllabus asks for.

struct NotesAuthRouting {
    static func boot(routes: RoutesBuilder, config: APITokenConfig) throws {
        let notes = routes.grouped("notes")

        // PUBLIC reads — no middleware.
        notes.get(use: NotesController().index)
        notes.group(":noteID") { note in
            note.get(use: NotesController().show)
        }

        // PROTECTED writes — authenticator + guard.
        //
        // `APITokenAuthenticator(...)` tries to authenticate; on success it logs
        // in an APIUser, on failure it does nothing. `APIUser.guardMiddleware()`
        // then checks whether an APIUser was logged in and, if not, throws a 401.
        // The two-step (authenticate, then guard) is the idiomatic Vapor pattern:
        // the authenticator NEVER rejects, the guard does.
        let protected = notes.grouped(
            APITokenAuthenticator(config: config),
            APIUser.guardMiddleware()
        )
        protected.post(use: NotesController().create)
        protected.group(":noteID") { note in
            note.patch(use: NotesController().update)
            note.delete(use: NotesController().destroy)
        }
    }
}

// In configure(_:), after building the database, wire it up:
//
//     let apiConfig = APITokenConfig.fromEnvironment()
//     app.get("health") { _ async -> [String: String] in ["status": "ok"] }
//     try NotesAuthRouting.boot(routes: app, config: apiConfig)
//
// (Remove the old `try app.register(collection: NotesController())` line — the
//  routing is now done by NotesAuthRouting so reads and writes can diverge.)

// ============================================================================
// EXPECTED BEHAVIOUR
// ============================================================================
//
//   export API_TOKEN=dev-token
//   swift run App serve --hostname 0.0.0.0 --port 8080
//
//   # Reads are public:
//   curl -s -i localhost:8080/notes
//   # HTTP/1.1 200 OK   →   []  (or your existing notes)
//
//   # Write with NO token → 401:
//   curl -s -i -X POST localhost:8080/notes \
//     -H 'Content-Type: application/json' \
//     -d '{"title":"x","body":"y"}'
//   # HTTP/1.1 401 Unauthorized
//
//   # Write with WRONG token → 401:
//   curl -s -i -X POST localhost:8080/notes \
//     -H 'Authorization: Bearer nope' \
//     -H 'Content-Type: application/json' \
//     -d '{"title":"x","body":"y"}'
//   # HTTP/1.1 401 Unauthorized
//
//   # Write with RIGHT token → 201:
//   curl -s -i -X POST localhost:8080/notes \
//     -H 'Authorization: Bearer dev-token' \
//     -H 'Content-Type: application/json' \
//     -d '{"title":"x","body":"y"}'
//   # HTTP/1.1 201 Created   →   {"id": "...", ...}
//
// ============================================================================
// HINTS (read only if stuck > 15 min)
// ============================================================================
//
// authenticate(bearer:request:):
//   func authenticate(bearer: BearerAuthorization, request: Request) async throws {
//       if ConstantTime.equals(bearer.token, config.expectedToken) {
//           request.auth.login(APIUser(id: "api-client"))
//       }
//       // No else. No throw. Not logging in == not authenticated, and the
//       // guardMiddleware produces the 401.
//   }
//
// Why authenticator-then-guard instead of throwing in the authenticator?
//   Because Vapor composes authenticators: you might stack a bearer authenticator
//   AND a session authenticator AND a basic authenticator on the same group, and
//   a request authenticated by ANY of them should pass. If each authenticator
//   threw on failure, stacking would be impossible — the first one to fail would
//   reject a request the second would have accepted. So authenticators only ever
//   "log in on success", and a single guard at the end asks "did ANYONE log in?".
//
// Why constant-time comparison?
//   `bearer.token == config.expectedToken` on Strings can return early at the
//   first differing byte. An attacker measuring response time across many guesses
//   can learn the secret byte by byte. ConstantTime.equals folds every byte into
//   the result so timing is independent of where the mismatch is. For a low-value
//   dev token this is paranoia; for a production secret it is table stakes, and
//   building the habit now is free.
//
// Why read API_TOKEN once at boot, not per request?
//   Per-request env reads are slower, and — more importantly — make the
//   authenticator hard to test (tests would have to mutate process env). Reading
//   once into an immutable Sendable config makes the authenticator a pure function
//   of (token, config), trivially testable.
