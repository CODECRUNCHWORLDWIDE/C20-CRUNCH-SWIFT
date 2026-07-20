# Week 6 — Shared Types, swift-nio Basics, Phase I Integration

Welcome to the last week of **Phase I**. Five weeks ago you could read a typed OOP language; now you have written idiomatic Swift, designed protocol-backed generic APIs, run structured-concurrency workloads under strict-concurrency mode, and stood up a Dockerized Vapor `notes-api` backed by Postgres. This week we do the thing that separates a hobby backend from a system: we make a single source of truth for the wire format and consume it from two processes.

The move is small to describe and large in consequence. Take the `struct` types your `notes-api` serializes — the create request, the update patch, the response DTO — and lift them out of the Vapor target into their own SwiftPM package, `NotesCore`. Then build a second executable, `notes-cli`, that imports the *same* package, talks to the running server over `URLSession`, and decodes responses into the *same* `Note` type the server encoded. One `Codable` definition. Two consumers. Zero "the client's `dueDate` is a string but the server's is a date" bugs, ever, because the compiler will not let them drift.

That pattern — the shared `Models` module — is the spine of every multi-target Swift system you will build for the rest of this track. In Phase II your SwiftUI client imports `NotesCore`. In Phase III your `NotesClient` actor decodes `NotesCore` types off the wire. In Phase IV your capstone backend, watchOS companion, and visionOS window all import the same package. The discipline you build this week pays compounding interest for eighteen weeks.

Alongside the shared-types work we take a deliberate, honest tour of the runtime your Vapor service has been standing on the whole time — **swift-nio** and its event-loop model — so you stop treating "the server" as a black box. We look at **Hummingbird** as the lighter-weight alternative to Vapor and name the trade. We wire up **OpenTelemetry-Swift** so your service emits spans you can actually read. And we add **swift-collections** (`OrderedDictionary`, `Deque`, `Heap`) to your toolbox, because `Array` and `Dictionary` are not always the right shape and a senior engineer reaches for the correct data structure on purpose.

By Friday you demo a Vapor service, a CLI client, and a shared package — all running on Linux — with Swift Testing coverage above 70% on the shared package. That is the **Phase I gate**.

## Learning objectives

By the end of this week, you will be able to:

- **Extract** a set of `Codable, Sendable` request/response types from a Vapor target into a standalone `NotesCore` SwiftPM library package.
- **Consume** a local SwiftPM package from two targets — the Vapor server and a CLI client — via a `path:` dependency, and explain why a shared module beats hand-copied DTOs.
- **Decode** server responses in a `URLSession`-based CLI using the exact types the server encoded, and **diagnose** a decode failure down to the offending key.
- **Explain** the swift-nio event-loop model — `EventLoopGroup`, `EventLoop`, `EventLoopFuture`, `Channel`, `ChannelPipeline` — at a level where you can read a stack trace and a back-pressure bug.
- **Compare** Vapor and Hummingbird and **justify** a framework choice on concrete axes (dependency weight, async-first design, ecosystem).
- **Instrument** a server with OpenTelemetry-Swift so a request emits a readable trace, and **read** that trace.
- **Choose** between `Array`, `OrderedDictionary`, `Deque`, and `Heap` for a given access pattern and **defend** the choice on complexity and intent.
- **Raise** Swift Testing line coverage on a package above a stated threshold with round-trip and edge-case decoding tests.

## Prerequisites

This week assumes you have completed **Weeks 1–5 of C20**, or have equivalent fluency. Specifically:

- You have a working `notes-api` from Week 5: a Vapor 4 service with `POST/GET/PATCH/DELETE /notes`, Fluent + Postgres, a bearer-token middleware, and a `docker compose up` that boots it. Bring that repository; this week extends it.
- You can write Swift under **strict concurrency** (Week 4) and explain `Sendable` and actor isolation.
- You can write a structured-concurrency workload with `async`/`await` and cancellation (Week 3).
- You have the **open-source Swift 6 toolchain** installed on Linux, macOS, or Windows+WSL2, and `swift --version` reports a 6.x toolchain.
- You can write a Swift Testing target with `@Test` and `#expect` (Week 1).

You do **not** need a Mac this week. Everything runs on Linux. This is the last week before Phase II requires Xcode, so if you have been on Linux the whole time, enjoy the home stretch.

## Topics covered

- The shared `Models` module pattern: one `Codable, Sendable` type, two consumers, a `path:` SwiftPM dependency.
- SwiftPM workspace topology: a library package depended on by an executable package; `Package.swift` `dependencies` and `targets`.
- DTOs vs persistence models: why the `Note` you put on the wire is not the `Note` Fluent stores, and where the boundary belongs.
- `Codable` on the wire: `CodingKeys`, `JSONDecoder.keyDecodingStrategy`, `dateDecodingStrategy`, ISO-8601 dates, and the `try`/`catch` shape of a `DecodingError`.
- `Sendable` across a package boundary; why your wire types should be value types with no reference-type members.
- A `URLSession`-based HTTP client in async Swift: `URLSession.shared.data(for:)`, status-code handling, typed errors, bearer auth headers.
- swift-nio at a glance: `EventLoopGroup`, `EventLoop`, `EventLoopFuture`/`EventLoopPromise`, `Channel`, `ChannelPipeline`, `ChannelHandler`, and how Vapor sits on top.
- The `async`/`await` bridge over nio futures (`EventLoopFuture.get()`), and why Vapor route handlers can be `async`.
- Hummingbird 2 as the async-first alternative to Vapor; the decision axes.
- OpenTelemetry-Swift: `swift-distributed-tracing`, the `Tracer`, spans, and exporting to an OTLP collector.
- swift-collections: `OrderedDictionary`, `Deque`, `Heap` — what each is for, the complexity table, and how to pick.
- Swift Testing coverage: `swift test --enable-code-coverage`, `llvm-cov`, and how to read a coverage report.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target.

| Day       | Focus                                                  | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Shared codable types; SwiftPM workspace topology       |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Extract `NotesCore`; import from Vapor; DTO boundary    |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Wednesday | swift-nio event loops; Hummingbird; OpenTelemetry      |    2h    |    1.5h   |     1h     |    0.5h   |   1h     |     0h       |    0h      |     6h      |
| Thursday  | swift-collections; the `URLSession` CLI client          |    1h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | Phase I integration: server + CLI on Linux             |    0h    |    1h     |     0h     |    0.5h   |   0h     |     3h       |    0.5h    |     5h      |
| Saturday  | Mini-project deep work; coverage above 70%              |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, Phase I gate rehearsal                   |    0h    |    0h     |     0h     |    1h     |   0h     |     1.5h     |    0h      |     2.5h    |
| **Total** |                                                        | **6h**   | **7h**    | **2h**     | **3.5h**  | **5h**   | **12.5h**    | **2h**     | **35h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Curated, current (2026) docs, talks, and source links for SwiftPM, swift-nio, Hummingbird, OpenTelemetry-Swift, and swift-collections |
| [lecture-notes/01-shared-codable-types.md](./lecture-notes/01-shared-codable-types.md) | Shared codable types — the move that pays for the rest of the track |
| [lecture-notes/02-swift-nio-and-swift-collections.md](./lecture-notes/02-swift-nio-and-swift-collections.md) | swift-nio event loops and swift-collections at a glance |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-extract-notescore.md](./exercises/exercise-01-extract-notescore.md) | Extract the notes request/response models into `NotesCore` and import it from Vapor |
| [exercises/exercise-02-cli-client.swift](./exercises/exercise-02-cli-client.swift) | A `URLSession`-based CLI client that consumes the notes-api using the shared types |
| [exercises/exercise-03-swift-collections.swift](./exercises/exercise-03-swift-collections.swift) | Add `OrderedDictionary`/`Deque`/`Heap` to an in-memory task and justify the choice |
| [challenges/README.md](./challenges/README.md) | Index of the weekly challenge |
| [challenges/challenge-01-coverage-above-70.md](./challenges/challenge-01-coverage-above-70.md) | Raise Swift Testing coverage of `NotesCore` above 70% with round-trip and malformed-payload tests |
| [quiz.md](./quiz.md) | 13 questions with an answer key |
| [homework.md](./homework.md) | Six concrete problems with deliverables and a rubric |
| [mini-project/README.md](./mini-project/README.md) | Phase I integration project: `NotesCore` + `notes-cli` against the Week 5 `notes-api`, both on Linux |

## The "swift test passed" promise

C20 uses a recurring marker in every exercise that ends in working code:

```
Test Suite 'All tests' passed at 2026-06-09 14:02:11.
	 Executed 24 tests, with 0 failures (0 unexpected) in 0.214 seconds
```

If `swift test` does not print zero failures, you are not done. We treat a failing test and a compiler warning the same way we treat a `null`: as a defect to remove, not to suppress. The point of this week is to make that line ordinary across *two* packages at once.

## Stretch goals

If you finish the regular work early and want to push further:

- Read the swift-nio `README` and the `Channel` / `ChannelPipeline` docs end to end: <https://github.com/apple/swift-nio>.
- Port one route of your `notes-api` to **Hummingbird 2** in a throwaway branch and compare the `Package.resolved` dependency graphs. <https://github.com/hummingbird-project/hummingbird>.
- Run a local **OpenTelemetry Collector** in Docker and point your Vapor service's OTLP exporter at it. Watch a `POST /notes` produce a trace with a child span for the database write.
- Add a `Heap`-backed priority queue to a small scheduler and benchmark it against a sorted `Array` you re-sort on every insert. Write down the crossover point.
- Read the `Sendable` chapter of the Swift book and write a one-paragraph note on why your `NotesCore` types are `Sendable` "for free."

## Up next

When the Phase I gate passes — Vapor service, CLI client, shared package, all on Linux, coverage above 70% — you are done with Phase I. **Week 7 opens Phase II**: a Mac with Xcode 16+, the SwiftUI mental model, and your first app. The `NotesCore` package you build this week is the first thing your SwiftUI client will import.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
