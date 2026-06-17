# Lecture 2 — Vapor vs Hummingbird, FastAPI, Express, and Rails

> **Reading time:** ~70 minutes. **Hands-on time:** ~45 minutes (you write a bearer-token middleware and read the equivalent code in three other frameworks).

Lecture 1 built a working Vapor service without asking *why Vapor*. This lecture answers that — and the inverse question, *when would a senior engineer pick something else?* You do not get to be the person whose framework choice the room defers to by knowing one framework. You get there by knowing where your framework sits on the axes that matter — convention vs configuration, typed vs dynamic, batteries-included vs assemble-it-yourself — and being able to say, concretely, what you give up by choosing it.

We will anchor the comparison in code. The running example is **a bearer-token authentication middleware** — the exact thing Exercise 2 asks you to build in Vapor — implemented (or sketched) in each framework, so the comparison is grounded in something you have actually written rather than in marketing copy. Along the way we cover the middleware concept properly, because middleware is where every framework's design philosophy shows itself most clearly.

## 2.1 — The axes that actually matter

Frameworks differ on a dozen surface features, but five axes decide which one a team should use. Hold these in your head; they are the lens for the whole lecture.

1. **Typed vs dynamic.** Does the framework lean on a static type system to validate requests, serialise responses, and catch mistakes at compile time — or does it validate at runtime and trust you? Vapor, Hummingbird, and FastAPI are typed (Swift, Swift, Python type hints). Express and Rails are dynamic (JavaScript, Ruby).
2. **Convention vs configuration.** Does the framework make decisions for you (file layout, ORM, routing conventions) so you write less, or does it stay out of your way so you assemble exactly what you want? Rails is maximally convention; Express is maximally configuration; Vapor and FastAPI sit in the middle; Hummingbird leans toward configuration.
3. **Batteries included vs assemble-it-yourself.** Does the framework ship an ORM, auth, templating, jobs, mail, and migrations in the box — or do you pull each from the ecosystem? Rails ships everything. Express ships almost nothing. Vapor and FastAPI ship a curated core (Vapor: Fluent, sessions, auth; FastAPI: validation, OpenAPI, dependency injection) and lean on the ecosystem for the rest.
4. **Concurrency model.** Thread-per-request, event-loop, async/await, or coroutine? This determines how the framework scales and what footguns you face. Vapor and Hummingbird are event-loop + `async/await` (SwiftNIO). FastAPI is `async`/`await` on an ASGI event loop. Express is single-threaded event-loop (Node). Rails is traditionally thread-per-request (though modern Rails has async support).
5. **Deployment shape.** What does the artifact look like, how big is it, how fast does it boot, and how much memory does it idle at? A compiled Swift binary in a slim container is a different operational story from a Ruby app needing a full interpreter and gem set, or a Python app needing the interpreter and a wheel cache.

Every framework choice is a position on these five axes. There is no universally best position — there is a best position *for a given team, product, and constraint set*. The rest of this lecture places each framework.

## 2.2 — Middleware, properly

Before the comparison, nail down middleware, because it is the concept the comparison turns on. A *middleware* is a function that sits between the framework and your handler, with the power to inspect or modify the request on the way in, inspect or modify the response on the way out, or short-circuit the chain entirely (returning a response without ever calling the handler). Authentication, logging, CORS, rate limiting, compression — all middleware.

In Vapor, middleware conforms to `AsyncMiddleware`:

```swift
import Vapor

struct APITokenMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        // Inspect the request on the way IN.
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }
        let expected = Environment.get("API_TOKEN") ?? "dev-token"
        guard token == expected else {
            throw Abort(.unauthorized, reason: "Invalid bearer token")
        }

        // Call the next responder (the rest of the chain, ending in your handler).
        let response = try await next.respond(to: request)

        // Inspect or modify the response on the way OUT.
        response.headers.add(name: "X-Authenticated", value: "true")
        return response
    }
}
```

The shape — `respond(to:chainingTo:)`, call `next.respond(to:)`, do work before and after — is the universal middleware shape. Every framework in this lecture has the same structure under different names. Read this once and you can read all of them.

A subtle but important point: this middleware throws `Abort(.unauthorized)` *before* calling `next`, which short-circuits the chain — the handler never runs for an unauthenticated request. The error middleware (registered ahead of this one) catches the throw and produces the `401` response. That ordering — error middleware outermost, then auth, then the handler — is the load-bearing arrangement we flagged in Lecture 1. Register the middleware on a route group so it protects exactly the routes you intend:

```swift
let protected = app.grouped(APITokenMiddleware())
protected.post("notes", use: NotesController().create)
protected.delete("notes", ":noteID", use: NotesController().delete)
// GET routes stay public, outside the group.
```

Vapor also offers a higher-level **authentication** abstraction (`Authenticator` + `Authenticatable` + `guardMiddleware`) that separates *identifying* the caller from *requiring* that they be identified. Exercise 2 uses the `BearerAuthenticator` form, which is the idiomatic production pattern; the raw `AsyncMiddleware` above is the from-scratch version that teaches the concept. Both appear this week on purpose.

## 2.3 — Vapor: the mature, typed, batteries-curated choice

**Position on the axes:** typed (Swift), middle on convention, batteries-curated, event-loop + `async/await`, compiled-binary deployment.

Vapor's case rests on three things:

1. **It is the most mature server-side Swift framework.** It has the largest ecosystem (Fluent drivers for Postgres/MySQL/SQLite/Mongo, Leaf templating, JWT, Redis, Queues), the most documentation, the most Stack Overflow answers, and the most production deployments. When you hit a problem, someone has hit it before. For a team betting a product on server-side Swift, "the boring, well-trodden choice" is a feature.
2. **It carries the full weight of the Swift type system into the web layer.** `Content` makes request/response bodies typed. Fluent makes queries typed. `async/await` makes the request lifecycle typed and structured. Under Swift 6 strict concurrency, the compiler catches data races in your handlers before they ship. This is the same argument that sells Swift on the client: the type system is your first test suite.
3. **The deployment shape is excellent.** A Vapor app compiles to a single binary. The official Dockerfile produces a slim runtime image (Swift slim base + your binary + a handful of shared libraries), boots in well under a second, and idles at tens of megabytes of RAM. Compared to a JVM or a Ruby/Python interpreter footprint, this is cheap to run at scale.

**What you give up:** Swift's server ecosystem, while mature *for Swift*, is small next to Node's npm or Python's PyPI. If you need an SDK for an obscure third-party service, it may not exist in Swift and you will write the HTTP client yourself. Hiring is also narrower — fewer engineers know server-side Swift than know Express or Rails. And compile times, while improved, are longer than an interpreted language's edit-run loop.

**When Vapor is the right call:** you are an Apple-platform shop that already writes Swift on the client and wants to share types and skills across client and server (exactly the C20 thesis — Week 6 extracts shared `Content` types into a package both halves import). Or you want a typed, fast-booting, low-memory service and your team is comfortable with Swift.

## 2.4 — Hummingbird: the lighter, concurrency-native Swift alternative

**Position on the axes:** typed (Swift), leans toward configuration, minimal batteries, event-loop + `async/await` (and structured-concurrency-native in v2), compiled-binary deployment.

Hummingbird is the other serious server-side Swift framework, an SSWG-incubated project. Its v2 was rebuilt to be fully `async`/`await` and structured-concurrency-native from the ground up, without the historical `EventLoopFuture`-based API surface Vapor still carries for compatibility. The same middleware in Hummingbird:

```swift
import Hummingbird

struct APITokenMiddleware<Context: RequestContext>: RouterMiddleware {
    let expectedToken: String

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let header = request.headers[.authorization],
              header == "Bearer \(expectedToken)" else {
            throw HTTPError(.unauthorized, message: "Invalid bearer token")
        }
        return try await next(request, context)
    }
}
```

Notice the family resemblance to the Vapor version — `handle(_:context:next:)`, inspect, call `next`, return — but two differences stand out. First, Hummingbird threads a generic `Context` through the request, which is how it does request-scoped state without Vapor's `req.storage` dictionary; the context is a typed struct you define. Second, the API has no `EventLoopFuture` anywhere — it is `async`/`await` all the way down, which makes it feel more like the Swift you write on the client.

**The honest comparison:** Hummingbird is lighter and arguably cleaner-by-construction under strict concurrency, but it has a smaller ecosystem and fewer batteries — you assemble more yourself. The Swift Server Work Group lists both as production-grade. For this course we teach Vapor because it is the more common production choice and has Fluent (Hummingbird users typically pair it with Fluent or with a lower-level Postgres client anyway). But you should know Hummingbird exists, know it is a credible choice, and be able to say *why* you would pick it: a service where you want minimal surface area, full structured-concurrency idioms, and you are happy to assemble persistence and auth from the ecosystem.

## 2.5 — FastAPI: the typed Python cousin

**Position on the axes:** typed (Python type hints), middle on convention, batteries-curated (validation, OpenAPI, DI in the box), `async`/`await` on ASGI, interpreter deployment.

FastAPI is the framework Vapor most resembles in *philosophy*, in a different language. Both lean on the type system to do work: where Vapor uses `Content` (Codable) for serialisation and validation, FastAPI uses Pydantic models and Python type hints. The same create-note endpoint with a token check:

```python
from fastapi import FastAPI, Header, HTTPException, Depends
from pydantic import BaseModel
import os

app = FastAPI()

class CreateNote(BaseModel):
    title: str
    body: str

def require_token(authorization: str = Header(default="")):
    expected = os.environ.get("API_TOKEN", "dev-token")
    if authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Invalid bearer token")

@app.post("/notes", dependencies=[Depends(require_token)])
async def create_note(note: CreateNote):
    return {"title": note.title, "body": note.body}
```

The parallels are striking and worth naming because they will help you reason about both:

- **Pydantic `BaseModel` ≈ Vapor `Content`.** Both declare a typed request/response shape and validate the incoming body against it, producing a clean error when it does not match.
- **FastAPI's `Depends` (dependency injection) ≈ Vapor's middleware + `req.auth`.** FastAPI expresses "this route requires a valid token" as a dependency; Vapor expresses it as middleware on a route group. Different mechanisms, same outcome: the auth check is declarative and reusable.
- **Automatic OpenAPI generation** is FastAPI's headline feature — it derives an OpenAPI/Swagger schema from your type hints. Vapor does not do this out of the box (you reach for a package, or for the newer Swift OpenAPI Generator). If interactive API docs generated from types are a hard requirement, FastAPI has the edge today.

**The honest comparison:** FastAPI is faster to prototype in (no compile step, the richest data-science and ML ecosystem in the world one `pip install` away) and produces OpenAPI docs for free. Vapor is faster at runtime, lower on memory, catches more at compile time, and lets an Apple shop share code across client and server. If your backend is ML-adjacent or your team is Python-native, FastAPI is the obvious pick. If your team is Swift-native and runtime cost matters, Vapor is.

## 2.6 — Express: the unopinionated middleware chain

**Position on the axes:** dynamic (JavaScript), maximally configuration, almost no batteries, single-threaded event-loop (Node), interpreter deployment.

Express is the framework everyone else's middleware design is implicitly compared against, because Express *is* a middleware chain and almost nothing else. The same token check:

```javascript
import express from "express";

const app = express();
app.use(express.json());

function requireToken(req, res, next) {
  const expected = process.env.API_TOKEN || "dev-token";
  if (req.headers.authorization !== `Bearer ${expected}`) {
    return res.status(401).json({ error: "Invalid bearer token" });
  }
  next();
}

app.post("/notes", requireToken, (req, res) => {
  res.json({ title: req.body.title, body: req.body.body });
});
```

The `(req, res, next)` signature is the canonical middleware shape the whole industry borrowed — including, philosophically, Vapor's `respond(to:chainingTo:)`. Call `next()` to continue the chain; send a response without calling `next()` to short-circuit. It is elegant and minimal.

**The honest comparison:** Express ships nothing — no ORM, no validation, no typed request bodies (note `req.body.title` is `any`; nothing checked that the body has a `title`), no auth. You assemble everything from npm, which is both Express's greatest strength (the largest package ecosystem on earth) and its greatest liability (dependency sprawl, supply-chain risk, "left-pad" fragility). Without TypeScript layered on, you get no compile-time safety at all — the `req.body` is untyped and a typo is a runtime 500. Express is the right call when you want minimal opinion, the npm ecosystem, and a team that already lives in JavaScript. It is the *wrong* call when you want the framework to catch your mistakes for you — which is precisely what Vapor and FastAPI are selling.

## 2.7 — Rails: maximal convention, batteries fully included

**Position on the axes:** dynamic (Ruby), maximally convention, every battery included, traditionally thread-per-request, interpreter deployment.

Rails is the opposite end of the spectrum from Express. Where Express gives you a middleware chain and nothing else, Rails gives you an ORM (ActiveRecord), migrations, routing conventions, mailers, background jobs, asset pipelines, and a code generator that scaffolds a CRUD resource from one command. The token check, as a `before_action` controller filter:

```ruby
class NotesController < ApplicationController
  before_action :require_token, only: [:create, :destroy]

  def create
    note = Note.create!(title: params[:title], body: params[:body])
    render json: note, status: :created
  end

  private

  def require_token
    expected = ENV.fetch("API_TOKEN", "dev-token")
    unless request.headers["Authorization"] == "Bearer #{expected}"
      render json: { error: "Invalid bearer token" }, status: :unauthorized
    end
  end
end
```

`before_action` is Rails' middleware-equivalent at the controller layer — a filter that runs before specified actions and can short-circuit by rendering a response. `Note.create!` is ActiveRecord, the ORM Fluent is most often compared to. The comparison between Fluent and ActiveRecord is instructive: ActiveRecord is dynamic (columns become methods at runtime via metaprogramming, `note.title` is not checked until the query runs), while Fluent is static (`note.$title` is a typed property wrapper checked at compile time). ActiveRecord is more magical and faster to write; Fluent is more explicit and catches schema mismatches at compile time.

**The honest comparison:** Rails is unmatched for going from idea to deployed CRUD app fastest — the conventions mean you write very little, and "the Rails way" answers most architecture questions for you. The cost is that the magic (metaprogramming, convention-over-configuration) is opaque until you learn it, the runtime is heavier (interpreter + full framework + thread-per-request memory), and you get no compile-time type safety. Rails is the right call for a content- or CRUD-heavy product where developer velocity dominates and the team knows Ruby. It is the wrong call when you want a small, fast, typed, low-memory service — which is, again, Vapor's pitch.

## 2.8 — The decision, as a table

Here is the whole comparison condensed. Read each row as "if *this* is your binding constraint, lean *here*."

| If your binding constraint is… | Lean toward |
|---|---|
| You already write Swift on the client and want shared types/skills | **Vapor** (or Hummingbird) |
| You want the smallest, most concurrency-native Swift surface | **Hummingbird** |
| Your backend is ML/data-adjacent or your team is Python-native | **FastAPI** |
| You want auto-generated OpenAPI docs from types, today, for free | **FastAPI** |
| You want maximal flexibility and the npm ecosystem | **Express** |
| You want fastest idea-to-CRUD and your team knows Ruby | **Rails** |
| You want compile-time safety on request/response and queries | **Vapor**, Hummingbird, or FastAPI (typed) |
| You want lowest memory and fastest boot in a slim container | **Vapor** or Hummingbird (compiled binary) |
| You need the broadest hiring pool | **Express** or **Rails** (dynamic, huge communities) |

Notice that no framework wins every row. The skill is matching the binding constraint to the framework, and being able to say out loud what you traded away. "We chose Vapor because we are a Swift shop and shared client/server types cut our integration bugs, accepting a narrower hiring pool and longer compiles" is a senior answer. "We chose Vapor because it is the best framework" is not.

## 2.9 — Why this course teaches Vapor

Given all that, the C20 reasons for Vapor are specific, not tribal:

1. **Shared types across client and server.** The entire track builds toward a SwiftUI client that talks to this Vapor backend. Week 6 extracts the `Content` request/response structs into a `NotesCore` SwiftPM package that *both* the server and the client import. That single shared `struct Note: Codable, Sendable` is the move that eliminates a whole class of integration bug — the client and server cannot disagree about the shape of a note, because they compile against the same type. No other framework in this lecture can share its request/response types with an iOS client; only Swift on both ends makes that possible.
2. **The type system is one continuous story.** `Codable`, `Sendable`, actors, `async/await` — the same concepts you spent weeks 1–4 learning, and the same ones you will use in SwiftUI in Phase II — are exactly the tools Vapor uses. There is no context switch to a second language's mental model.
3. **It runs on Linux, today, with no Mac.** Phase I's whole premise is that you can do real Swift engineering before you adopt the Apple-only toolchain. Vapor delivers that — everything this week runs in a Linux container.

That is the case. You should be able to make it, and make the counter-case, in an interview.

## 2.10 — The performance picture, honestly

Framework benchmarks are the most-abused numbers in our industry — they measure a "hello world" round-trip that has nothing to do with your real workload, where the database query dominates the wall-clock time and the framework overhead is noise. So treat the following as *order-of-magnitude intuition*, not a leaderboard.

The thing that genuinely separates the compiled-Swift frameworks (Vapor, Hummingbird) from the interpreted ones (FastAPI, Express, Rails) is not raw requests-per-second on a contrived benchmark — it is **the cost profile under sustained load**:

- **Boot time.** A Vapor binary in a slim container is serving traffic well under a second after the process starts. A Rails app loading its full framework and gem set, or a Python app importing a large dependency tree, takes noticeably longer. This matters more than it sounds: it is the difference between a scale-from-zero deployment (Cloud Run, Lambda-style) feeling instant and feeling sluggish, and it is the difference between a rolling deploy that finishes in seconds and one that crawls.
- **Idle memory.** A Vapor service idles at tens of megabytes. A JVM service idles at hundreds. A Ruby or Python service sits in between, plus the per-worker multiplier — because thread-per-request and the Python GIL push you toward running *multiple processes* to use multiple cores, and each process re-pays the interpreter and framework memory cost. A Swift binary uses every core from one process, on the NIO event-loop group, with one copy of everything in memory.
- **Tail latency under concurrency.** This is where the event-loop + `async/await` model earns its keep. Because no request blocks a thread while waiting on the database, a Swift service degrades gracefully as concurrency climbs — the event loops stay busy doing useful work rather than parked. A thread-per-request model hits a wall when the thread pool saturates; past that point, latency climbs sharply.

None of this means "always pick the fast one." A Rails app that a team ships in a third of the time, on hardware that costs the company nothing relative to engineer salaries, is the correct engineering decision for a great many products. The point of knowing the cost profile is so that you can say *when it matters*: a high-fan-out service running thousands of concurrent connections per box, a scale-to-zero deployment where boot time is user-visible, a memory-constrained edge environment. There, the compiled-binary, event-loop story is a real, measurable advantage — and it is Vapor's and Hummingbird's to claim.

## 2.11 — The `EventLoopFuture` history (so old code doesn't confuse you)

You will, this week, hit a blog post or Stack Overflow answer that writes Vapor handlers like this:

```swift
// PRE-2022 STYLE — you will see this in old tutorials. Do not write it.
func index(_ req: Request) -> EventLoopFuture<[Note]> {
    return Note.query(on: req.db).all()
}

func create(_ req: Request) throws -> EventLoopFuture<Note> {
    let note = try req.content.decode(Note.self)
    return note.save(on: req.db).map { note }
}
```

That is the `EventLoopFuture` API — Vapor's original async model, predating Swift's `async`/`await`. An `EventLoopFuture<T>` is a promise of a future `T`, composed with `.map`, `.flatMap`, and `.flatMapThrowing`. It works, and Vapor still supports it for backward compatibility, but it is **not** how you write Vapor in 2026. The modern equivalent is the straight-line `async` code you saw in Lecture 1:

```swift
// 2026 STYLE — write this.
@Sendable func index(_ req: Request) async throws -> [Note] {
    try await Note.query(on: req.db).all()
}

@Sendable func create(_ req: Request) async throws -> Note {
    let note = try req.content.decode(Note.self)
    try await note.save(on: req.db)
    return note
}
```

The rule of thumb: **if you see `EventLoopFuture`, `.flatMap`, or `.map` on a database call in a tutorial, it predates 2022.** Mentally translate `EventLoopFuture<T>` to `async throws -> T`, `.flatMap { }` to `let x = try await`, and read on. This is the single biggest source of "the tutorial doesn't compile" confusion for newcomers, and now it will not catch you. (The same caution applies to `Migration` vs `AsyncMigration` and `Middleware` vs `AsyncMiddleware`, flagged in `resources.md` — always reach for the `Async` variant.)

Hummingbird, by contrast, was rebuilt in v2 with *no* `EventLoopFuture` surface at all — there is nothing to translate, because the whole API is `async`/`await` from the ground up. That is the cleanliness-by-construction advantage we noted in §2.4, and it is the single most-cited reason teams starting fresh in 2026 evaluate Hummingbird seriously.

## 2.12 — Reading the four frameworks side by side

You have now seen the same bearer-token-protected create-note endpoint in five frameworks. Step back and read the *shape* of each, because the shape is the philosophy:

- **Vapor** separated concerns into a `Content` type (the body), a `RouteCollection` (the routes), and an `AsyncMiddleware` (the auth) — three typed pieces the compiler checks fit together. Verbose, explicit, safe.
- **Hummingbird** did the same with a generic `Context` threaded through, trading a little ceremony for full structured-concurrency idioms and a smaller framework footprint.
- **FastAPI** collapsed the body type into a Pydantic model and the auth into a `Depends`, with the type hints doing double duty as validation *and* OpenAPI schema. Concise, typed-at-runtime, docs-for-free.
- **Express** gave you a bare `(req, res, next)` chain with nothing typed — the most flexible and the least safe; `req.body.title` is `any` and a typo is a production 500.
- **Rails** gave you a `before_action` filter and an ActiveRecord `create!`, with conventions filling in everything you did not write — the fastest to type and the most magical to debug.

Five solutions to one problem. The senior move is to look at a team, a product, and a constraint set and say which shape fits — and to be unsurprised by any of them in code review, because you can read all five.

## 2.13 — Fluent vs ActiveRecord vs EF Core, concretely

Because the ORM is where you will spend the most code this week, it is worth a closer side-by-side of the three ORMs you are most likely to meet. The same operation — "find a note by id, update its title, save" — in each:

```swift
// Fluent (Swift). Static, property-wrapper-based, async.
guard let note = try await Note.find(id, on: req.db) else { throw Abort(.notFound) }
note.title = "updated"
try await note.save(on: req.db)
```

```ruby
# ActiveRecord (Ruby). Dynamic, metaprogrammed, synchronous.
note = Note.find(id)          # raises RecordNotFound if missing
note.title = "updated"
note.save!
```

```csharp
// EF Core (C#). Static, change-tracked, async.
var note = await db.Notes.FindAsync(id) ?? throw new KeyNotFoundException();
note.Title = "updated";
await db.SaveChangesAsync();
```

The shapes rhyme, but the philosophies differ in ways that bite:

- **Schema-to-code binding.** In ActiveRecord, `note.title` is resolved at *runtime* — ActiveRecord reads the table schema and synthesises accessor methods via metaprogramming. Misspell a column and you find out when the query runs, in production, on the unlucky code path. In Fluent and EF Core, `note.title` (Fluent) or `note.Title` (EF) is a compile-time property; misspell it and the build fails. This is the single biggest practical difference: Fluent moves a class of error from runtime to compile time, which is the whole Swift-on-the-server thesis applied to persistence.
- **Change tracking.** EF Core tracks which properties changed and emits a minimal `UPDATE`. Fluent and ActiveRecord are more explicit about what gets written. None is "better" — but knowing which model you are in tells you whether `save` writes the whole row or a diff, which matters the first time you debug a surprising `UPDATE` in the query log.
- **Migrations.** All three version the schema. Fluent's `AsyncMigration` with explicit `prepare`/`revert` (Lecture 1) is closest to EF Core's migration files; ActiveRecord's are more conventional and generated. The discipline is identical across all three: never edit a table by hand in production; always go through a reviewed, reversible migration.

The takeaway for code review: when someone says "the ORM is leaky" or "we should drop to raw SQL here," you should be able to say *why* — usually it is a query the ORM expresses awkwardly (a window function, a recursive CTE, a bulk upsert), and the right move is to drop to raw SQL *for that one query* through Fluent's `SQLDatabase` escape hatch, not to abandon the ORM wholesale. Knowing where the abstraction is thin is what lets you use it confidently everywhere it is not.

## 2.14 — The shared-types payoff, previewed

The single most important architectural reason this course teaches Vapor deserves one more concrete look, because it is the move that pays for the rest of the track. Today, your `notes-api` defines a response shape:

```swift
struct NoteDTO: Content {
    let id: UUID
    let title: String
    let body: String
    let createdAt: Date
}
```

Next week (Week 6) you will lift exactly that struct into a standalone SwiftPM package, `NotesCore`, and have *both* the Vapor server and a Swift CLI client depend on it. In Phase III, the SwiftUI iOS app depends on it too. The consequence is profound and worth stating plainly: **the client and the server cannot disagree about the shape of a note, because they compile against the same type.** If you add a field to `NoteDTO`, every consumer either compiles against the new shape or fails to build — there is no "the iOS app and the server drifted out of sync" bug, because there is no second definition to drift.

No other framework in this lecture can do this with an iOS client. FastAPI's Pydantic model lives in Python; your Swift client cannot import it. Express's untyped body lives nowhere in particular. Rails' ActiveRecord model is Ruby. Only Swift-on-both-ends collapses the client's and server's type definitions into one shared, compiler-enforced source of truth. That is the C20 thesis in one sentence, and it is why the whole Phase I arc — Swift language, then Vapor, then shared package — is sequenced the way it is. You are not learning a backend framework as a detour from iOS; you are learning the half of the stack that, in Swift, shares its types with the other half.

## 2.15 — An interview drill

You will be asked some version of "why did you choose your backend framework?" in every backend or full-stack interview. Here is the structure of a strong answer, using Vapor as the worked example — adapt the nouns to whatever you actually shipped:

> "We were an Apple-platform shop already writing Swift on the client, so we chose Vapor for the backend. The decisive factor was that we could extract our request and response types into a Swift package and import it on *both* the server and the iOS client — which eliminated an entire class of integration bug, because the two halves literally compile against the same `Codable` struct. We also got low idle memory and sub-second boot, which mattered for our scale-to-zero deployment. The trade we accepted was a narrower hiring pool than if we'd picked Express or Rails, and longer compile times than an interpreted language — we judged those acceptable because the team already knew Swift and the shared-types win was large for us."

Notice the structure: **constraint → choice → the decisive reason → the secondary benefit → the explicit trade.** That last clause — naming what you gave up — is what separates a senior answer from a junior one. A junior says "Vapor is great." A senior says "Vapor, accepting a narrower hiring pool, because shared types eliminated our integration bugs." Practice giving that answer about a real decision you have made; it is worth more in an interview than any single technical fact.

## 2.16 — The reflexes to internalise

- **Place any framework on the five axes** (typed/dynamic, convention/configuration, batteries, concurrency, deployment) before you have an opinion about it.
- **Recognise the universal middleware shape** — inspect in, call next, inspect out, optionally short-circuit — under every framework's local naming.
- **State the trade, not the verdict.** "We chose X, accepting Y" beats "X is best" in every code review and every interview.
- **Know that Hummingbird exists** and is a credible server-side Swift alternative; do not present Vapor as the only option.
- **Map the analogies:** `Content` ≈ Pydantic `BaseModel`; Fluent ≈ ActiveRecord ≈ EF Core; Vapor middleware ≈ Express `(req,res,next)` ≈ Rails `before_action` ≈ FastAPI `Depends`. The concepts transfer; only the syntax changes.

---

## Lecture 2 — checklist before moving on

- [ ] I can name the five axes and place Vapor, Hummingbird, FastAPI, Express, and Rails on each.
- [ ] I can write a Vapor `AsyncMiddleware` that checks a bearer token and short-circuits with a `401`.
- [ ] I can explain why error middleware must be outermost and auth middleware must run before the handler.
- [ ] I can map Vapor's `Content` / Fluent / middleware to the equivalent concept in FastAPI, Express, and Rails.
- [ ] I can state, in one sentence each, when I would pick Hummingbird, FastAPI, Express, or Rails *over* Vapor.
- [ ] I can give the three specific C20 reasons Vapor is the course's server framework.

If any box is unchecked, return to that section. Exercise 2 builds the bearer-token middleware you sketched here, the idiomatic way.

---

**References cited in this lecture**

- Vapor — "Basics → Middleware": <https://docs.vapor.codes/basics/middleware/>
- Vapor — "Security → Authentication": <https://docs.vapor.codes/security/authentication/>
- Hummingbird — project and docs: <https://github.com/hummingbird-project/hummingbird> and <https://docs.hummingbird.codes/>
- Swift Server Work Group — incubated packages: <https://github.com/swift-server/sswg>
- FastAPI — documentation: <https://fastapi.tiangolo.com/>
- Express — documentation: <https://expressjs.com/>
- Ruby on Rails — guides: <https://guides.rubyonrails.org/>
- Swift.org — "Server": <https://www.swift.org/server/>
