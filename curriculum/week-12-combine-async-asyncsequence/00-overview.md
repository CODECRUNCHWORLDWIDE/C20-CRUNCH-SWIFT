# Week 12 — Combine, async/await, and AsyncSequence

Welcome to Week 12 of **C20 · Crunch Swift**, the last week of Phase II. You have spent five weeks on SwiftUI's *structure*: views, state, navigation, persistence, architecture. This week is about its *time* — the values that arrive over a span rather than all at once. A user typing into a search field, a stream of notifications, a timer ticking, a download reporting progress, a WebSocket pushing events: none of these is a single value you `await` once. They are sequences-over-time, and Swift gives you two-and-a-half ways to model them — **Combine**, **`async`/`await` with `AsyncSequence`/`AsyncStream`**, and the SwiftUI glue that bridges them. This week you learn all three, learn *which* to reach for, and stop treating "reactive" as a vibe.

The honest framing for 2026: **`async`/`await` won, and Combine is in maintenance.** Apple has not meaningfully evolved Combine since 2021; the entire concurrency story Apple now invests in is structured concurrency (`async`/`await`, actors, `AsyncSequence`) — the stuff you learned in Weeks 3–4. But Combine is *everywhere* in shipping code, in framework APIs (`NotificationCenter.publisher`, `Timer.publish`, `@Published`, the URLSession `dataTaskPublisher`), and in your future codebase's git history. You cannot avoid reading it, and there are still a handful of jobs it does more ergonomically than the async equivalents. So we teach Combine honestly — enough to read it, maintain it, and bridge it — and we teach `AsyncSequence`/`AsyncStream` as the tool you reach for in new code. The deliverable is the *decision matrix*: given a streaming problem, you can say which tool fits and defend it.

The worked example that ties the week together is the one you already built twice in Week 11: **search-as-you-type with a debounce.** In Week 11 you wired it with a hand-rolled `Task` and with a TCA `.cancellable` effect. This week you implement it *both* with Combine (`.debounce(for:scheduler:)` — the operator Combine was practically designed for) and with `AsyncStream` (a continuation you feed keystrokes into, debounced by hand). Side by side, the debounce reveals everything: where Combine's operator vocabulary is genuinely elegant, where `AsyncStream` is more explicit and Swift-6-native, and how back-pressure differs between them. By Friday you can debounce user input two ways and explain the trade in one sentence.

You close the week — and Phase II — with the **Phase II integration project: "Notes v1."** Everything from Weeks 7–12 converges into one polished, persistent, reactive SwiftUI app: full CRUD, SwiftData persistence, value-typed navigation with deep links, dark mode and Dynamic Type, an architecture you can defend, and search-as-you-type debounced via `AsyncStream`. It runs on iPhone, iPad, and Mac, survives a cold-launch state restoration, and is tested with XCUITest. This is the Phase II gate: a real app you can demo on three simulators and walk through in a code review. The reactive search you build this week is the feature that makes it feel alive.

## Learning objectives

By the end of this week, you will be able to:

- **Read and reason about Combine** — `Publisher`, `Subscriber`, `Subscription`, `AnyCancellable`, the demand/back-pressure model, and the core operators (`map`, `filter`, `debounce`, `removeDuplicates`, `combineLatest`, `flatMap`, `sink`, `assign`) — well enough to maintain a Combine codebase and bridge it.
- **Model streams with `AsyncSequence`** — consume one with `for await`, build one with `AsyncStream`/`AsyncThrowingStream` and a `Continuation`, control termination with `onTermination`, and explain its buffering/back-pressure policy.
- **Implement search-as-you-type debouncing two ways** — with Combine's `.debounce` operator and with a hand-rolled `AsyncStream` debounce — and articulate the trade between them.
- **Bridge Combine and `async`/`await`** in both directions: consume a `Publisher` with `for await publisher.values`, and adapt async work back into a publisher when a Combine API demands one.
- **Wire reactivity into SwiftUI** correctly — `.onReceive` for a publisher, `.task`/`.task(id:)` for an `AsyncSequence`, and the Observation framework for plain state — and explain why `.task` is cancelled-and-restarted automatically while `.onReceive` is not.
- **Choose the right tool** with a decision matrix: when Combine's operator chain wins, when `async`/`await` is simpler, when `AsyncStream` is the bridge, and why new code defaults to the async side in 2026.
- **Ship "Notes v1"** — a multi-platform SwiftUI app integrating persistence, navigation, architecture, and reactive search, state-restoring across cold launch, UI-tested with XCUITest.

## Prerequisites

This week assumes you have completed **C20 weeks 1–11**, or have equivalent fluency. Specifically:

- You are fluent in `async`/`await`, `Task`, `TaskGroup`, cancellation, and structured concurrency — Week 3. `AsyncSequence`/`AsyncStream` are structured concurrency applied to *streams*; if `Task.sleep` and cancellation are not second nature, re-read Week 3 first.
- You understand actors, `@MainActor`, `Sendable`, and Swift 6 strict concurrency — Week 4. An `AsyncStream`'s continuation and a Combine publisher both cross concurrency boundaries; `Sendable` is load-bearing all week.
- You know the Observation framework (`@Observable`, `@Bindable`) and SwiftUI state ownership — Week 8. The `@Published`/`ObservableObject` pair is Combine's SwiftUI bridge and the *predecessor* to `@Observable`; understanding both is half the "when Combine" answer.
- You can pick an architecture (plain SwiftUI / MVVM / TCA) and defend it — Week 11. This week's reactive work lives *inside* a view model or reducer; the integration project asks you to commit to one.
- You have the Hello, Notes app, SwiftData-backed (Week 10) with an architecture (Week 11). The integration project polishes it into "Notes v1."

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. Combine ships with the SDK (no package). XCUITest is built in. Everything this week runs in the Simulator — no device, no Apple Developer membership.

## Topics covered

- **Combine fundamentals.** `Publisher`/`Subscriber`/`Subscription`, the request-demand back-pressure model, `AnyCancellable` and the cancellation/retain rules, `PassthroughSubject`/`CurrentValueSubject`, `@Published` and `ObservableObject`.
- **Combine operators.** Transforming (`map`, `tryMap`, `scan`), filtering (`filter`, `removeDuplicates`, `compactMap`), combining (`combineLatest`, `merge`, `zip`), time (`debounce`, `throttle`, `delay`), flattening (`flatMap`, `switchToLatest`), and the terminal operators (`sink`, `assign(to:)`).
- **Combine in SwiftUI.** `.onReceive(_:perform:)`, `@Published` driving an `ObservableObject`, and why this whole bridge is the *legacy* path now that `@Observable` exists.
- **`AsyncSequence`.** The protocol, `for await` / `for try await`, the standard library's `AsyncMapSequence` & friends, `.first(where:)`, `.reduce`, and why `for await` is just a loop the compiler desugars over the async iterator.
- **`AsyncStream` and `AsyncThrowingStream`.** Building a stream from a callback/delegate world with a `Continuation`, `yield`/`finish`, `onTermination`, buffering policies (`.unbounded`, `.bufferingNewest(_:)`, `.bufferingOldest(_:)`), and the back-pressure consequences of each.
- **Debouncing user input, two ways.** Combine `.debounce(for:scheduler:)` vs a hand-rolled `AsyncStream` debounce; the back-pressure and cancellation comparison; which the search feature should use.
- **Bridging Combine ⇄ async.** `publisher.values` (a publisher *is* an `AsyncSequence`), `Future`/`Deferred` to wrap async work, and the rules for not leaking subscriptions across the bridge.
- **SwiftUI reactivity placement.** `.task` (auto-cancelled on disappear, restarted on `id` change) vs `.onReceive` (manual lifecycle) vs `@Observable` (plain state); the re-render implications of each.
- **The decision matrix.** A worked table mapping streaming problems → the right tool, with the 2026 default (async-first for new code, Combine for reading legacy and a few framework APIs).
- **The Phase II integration: "Notes v1."** Persistence + navigation + architecture + reactive debounced search + multi-platform + state restoration + XCUITest, as one cohesive deliverable.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                                | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Combine fundamentals; publishers, subscribers, operators; `.onReceive` |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `AsyncSequence`, `AsyncStream`, continuations, buffering; `.task`      |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Debounce two ways; bridging Combine⇄async; the matrix; challenge      |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Back-pressure deep dive; "Notes v1" kickoff; XCUITest intro           |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Integration project — reactive search wired into Notes v1            |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Notes v1 deep work; multi-platform; state restoration; XCUITest      |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, record the demo, push                         |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                      | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's Combine and Swift Concurrency docs, the WWDC AsyncSequence sessions, the canonical community writing, and the XCUITest references |
| [lecture-notes/01-combine-fundamentals-and-operators.md](./02-lecture-notes/01-combine-fundamentals-and-operators.md) | Combine end to end: publishers/subscribers/subscriptions, back-pressure, the operator catalogue, `@Published`/`ObservableObject`, `.onReceive`, and where Combine still earns its keep |
| [lecture-notes/02-asyncsequence-bridging-and-the-matrix.md](./02-lecture-notes/02-asyncsequence-bridging-and-the-matrix.md) | `AsyncSequence`/`AsyncStream`, continuations and buffering, the two-way Combine⇄async bridge, debounce two ways, SwiftUI reactivity placement, and the decision matrix |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-combine-pipeline.md](./03-exercises/exercise-01-combine-pipeline.md) | Build a small Combine pipeline (`debounce` → `removeDuplicates` → `map`), drive it from a subject, and observe demand/cancellation |
| [exercises/exercise-02-asyncstream-debounce.swift](./03-exercises/exercise-02-asyncstream-debounce.swift) | Build an `AsyncStream` from a callback source, debounce it by hand, and test it with a clock |
| [exercises/exercise-03-bridge-and-task.swift](./03-exercises/exercise-03-bridge-and-task.swift) | Bridge a Combine publisher into `for await publisher.values`, consume it in a `.task`, and prove cancellation works |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-debounce-two-ways-measured.md](./04-challenges/challenge-01-debounce-two-ways-measured.md) | Implement search-as-you-type debounce in Combine and in `AsyncStream`, measure keystroke→search latency and dropped intermediate searches, and write the decision note |
| [quiz.md](./05-quiz.md) | 14 questions on Combine, `AsyncSequence`/`AsyncStream`, bridging, SwiftUI placement, back-pressure, and the matrix |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for the **Phase II integration project — "Notes v1"**: the polished multi-platform app with reactive debounced search, persistence, navigation, state restoration, and XCUITest |

## The "right tool, defended" promise

Phase II has accreted one reviewer-checked promise per week. Week 12 adds the last one:

> **You reach for the right reactive tool and can defend the choice in one sentence.** When a reviewer asks "why Combine here and `AsyncStream` there?", you answer with the trade — operator ergonomics, back-pressure, cancellation lifecycle, framework-API fit, and the 2026 async-first default — not "it's what I knew." And your search-as-you-type drops the intermediate keystrokes it should and never fires a search per character.

"I used Combine because the tutorial did" is not an engineering answer. The skill this week earns is having the matrix in your head and the latency numbers to back it.

## A note on what's not here

Week 12 is the *reactive streams* week. It deliberately does **not** cover:

- **Networking proper.** The URLSession async APIs, `dataTaskPublisher`, retries, and a real client are Week 13. This week's streams are local (keystrokes, timers, notifications) so the focus stays on the *stream model*, not the network. We use `dataTaskPublisher` only as an example of a *framework Combine API* you must be able to read.
- **The full TCA effect system.** TCA's `Effect` (Week 11) is built on the async machinery you learn here; we reference how a `.cancellable` debounce maps to this week's concepts but do not re-teach TCA.
- **RxSwift / ReactiveSwift.** Third-party reactive frameworks predate Combine and still appear in older codebases. We name them, note that Combine is Apple's first-party answer and `async`/`await` is the future, and do not teach them.

The point of Week 12 is narrow and deep: the three reactive tools, the debounce that distinguishes them, the bridge between them, and the matrix that chooses — then the integration project that proves you can ship a real app.

## Up next

Continue to **Week 13 — URLSession and the networking stack** once you have shipped "Notes v1" and cleared the Phase II gate. Phase III opens by taking the reactive and async machinery you mastered this week and pointing it at the *network*: a typed, retryable, cancellable, instrumented `URLSession` client built on `async`/`await`, with `AsyncSequence` for streaming responses and the bridge for the legacy `dataTaskPublisher` you'll still meet. The debounced search you built this week becomes search-against-a-server; the offline-first write-replay you'll build in Week 13 leans on exactly the cancellation discipline you drilled here. Earn the reactive fluency this week — the whole production-iOS phase assumes it.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
