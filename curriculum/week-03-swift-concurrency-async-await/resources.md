# Week 3 — Resources

Every resource on this page is **free**. The Swift documentation, the Swift Evolution proposals, and the WWDC session videos are all published openly by Apple and the Swift project. No paywalled books are required; the one book linked has free online chapters. No account is needed for anything here.

Everything is current to the **Swift 6.1 toolchain (2026)**. Where an API changed between Swift 5.5 (when concurrency shipped) and Swift 6, we flag it — a lot of stale blog posts on the open web still show the 5.5 spelling.

## Required reading (work it into your week)

- **The Swift Programming Language — Concurrency chapter.** The canonical reference, kept current per release. Read it once, all the way through, before the lectures click into place:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>
- **`Task` API reference** — the type at the centre of everything this week:
  <https://developer.apple.com/documentation/swift/task>
- **`TaskGroup` / `ThrowingTaskGroup`** — the fan-out primitive your mini-project is built on:
  <https://developer.apple.com/documentation/swift/taskgroup>
- **`withTaskCancellationHandler(operation:onCancel:)`** — how you respond to cancellation cooperatively:
  <https://developer.apple.com/documentation/swift/withtaskcancellationhandler(operation:oncancel:)>
- **`TaskLocal`** — task-local storage for request IDs, deadlines, trace context:
  <https://developer.apple.com/documentation/swift/tasklocal>

## The Evolution proposals (skim, don't memorize)

Swift Concurrency was designed in the open across a series of Swift Evolution proposals. You will not read all of them, but the first time a senior writes "that's structured per SE-0304" in review, you should know what they mean. These three are the spine of this week:

- **SE-0296 — `async`/`await`**: the language feature itself.
  <https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md>
- **SE-0304 — Structured concurrency**: `Task`, `TaskGroup`, cancellation, priority. The single most important proposal for this week.
  <https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md>
- **SE-0317 — `async let` bindings**: the lightweight child-task syntax.
  <https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md>

Bonus, if you finish early:

- **SE-0306 — Actors** (a preview of Week 4): <https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md>
- **SE-0461 — Run nonisolated async functions on the caller's actor** (a Swift 6.2-era refinement worth knowing the name of): <https://github.com/apple/swift-evolution/blob/main/proposals/0461-async-function-isolation.md>

## Official Swift docs and downloads

- **Swift.org — install the toolchain** (Linux, macOS, Windows): <https://www.swift.org/install/>
- **Swift Package Manager documentation**: <https://www.swift.org/documentation/package-manager/>
- **Swift migration guide — "Migrating to Swift 6"** (the data-race story; mostly Week 4, but the "Common problems" section is gold): <https://www.swift.org/migration/documentation/migrationguide/>
- **Swift 6.1 release notes**: <https://www.swift.org/blog/> (look for the "Swift 6.1 released" post)

## WWDC sessions (free, no signup, captions + transcripts)

Watch these in order. They are the best single explanation of the model, straight from the team that built it.

- **"Meet async/await in Swift"** (WWDC21, session 10132) — the gentle intro: <https://developer.apple.com/videos/play/wwdc2021/10132/>
- **"Explore structured concurrency in Swift"** (WWDC21, session 10134) — `async let`, task groups, cancellation. This is *the* session for this week: <https://developer.apple.com/videos/play/wwdc2021/10134/>
- **"Swift concurrency: Behind the scenes"** (WWDC21, session 10254) — the cooperative thread pool, why you must never block it, continuations. Watch this one twice: <https://developer.apple.com/videos/play/wwdc2021/10254/>
- **"Beyond the basics of structured concurrency"** (WWDC23, session 10170) — task-local values, cancellation drilled deeper, the discarding task group: <https://developer.apple.com/videos/play/wwdc2023/10170/>

## Libraries we touch (or name-drop) this week

- **`swift-async-algorithms`** — Apple's package of `AsyncSequence` operators (`merge`, `zip`, `debounce`, `chunked`). We mention it; we use it for real in Week 12:
  <https://github.com/apple/swift-async-algorithms>
- **`swift-argument-parser`** — the CLI parser used by the mini-project (and by the Swift toolchain itself). This is the `--timeout` / `--concurrency` flag layer:
  <https://github.com/apple/swift-argument-parser>
- **Foundation `URLSession`** — the HTTP client; we use its async API (`data(for:)`) and configure HEAD requests by hand:
  <https://developer.apple.com/documentation/foundation/urlsession>

## Free book chapters

- **"Modern Concurrency in Swift" (Kodeco)** — the free sample chapters cover `async`/`await` and task groups well; the book is paid but the samples are enough for this week:
  <https://www.kodeco.com/books/modern-concurrency-in-swift>
- **Donny Wals — "Practical Swift Concurrency" blog series** (free, frequently updated, 2026-current — one of the few sources that gets cancellation right):
  <https://www.donnywals.com/category/swift-concurrency/>

## Talks worth your time (free)

- **Swift Server / ServerSide.swift conference talks** — concurrency on the server (Vapor, Hummingbird) is where back-pressure bites hardest; many talks are on YouTube:
  <https://www.youtube.com/@ServerSideSwift>
- **"A Swift Concurrency Glossary"** by Matt Massicotte — the clearest mental-model writing on the open web in 2026; his whole site is worth a read:
  <https://www.massicotte.org/>

## Open-source projects to read this week

You learn more from one hour reading well-written concurrent Swift than from three hours of tutorials. Pick one and scroll:

- **`apple/swift-async-algorithms`** — see how the team writes `AsyncSequence`, cancellation, and back-pressure correctly:
  <https://github.com/apple/swift-async-algorithms>
- **`vapor/vapor`** — a production server-side framework, fully `async`/`await`, fully `Sendable`-audited:
  <https://github.com/vapor/vapor>
- **`pointfreeco/swift-dependencies`** — uses `@TaskLocal` extensively to thread dependencies through a task tree (the same trick we teach this week, applied at scale):
  <https://github.com/pointfreeco/swift-dependencies>
- **`apple/swift-nio`** — the event-loop engine under Vapor; advanced, but the `EventLoopFuture` → `async` bridge is instructive:
  <https://github.com/apple/swift-nio>

## Tools you'll use this week

- **`swift` toolchain** — `swift build`, `swift run`, `swift test`. Verify with `swift --version` (want 6.0+).
- **`curl`** — preinstalled on macOS and Linux. Useful for sanity-checking the URLs your link-checker will hit.
- **A local sitemap** — the mini-project ships one under `samples/`; you do not need to be online to develop, only to do a final live run.
- **`time`** — the shell builtin. Your throughput measurements lean on it. (`/usr/bin/time -l` on macOS for memory, `/usr/bin/time -v` on Linux.)

## Glossary cheat sheet

Keep this open in a tab.

| Term | Plain English |
|------|---------------|
| **Suspension point** | A spot where `await` appears. The function may pause here and resume later, possibly on a different thread. |
| **Sequencing** | Doing things one after another. Two `await`s in a row are sequenced, not concurrent. |
| **Concurrency** | Multiple tasks making progress in overlapping time. You opt in with `async let` or a task group. |
| **Structured task** | A child task whose lifetime is bound to a lexical scope (`async let`, `TaskGroup`). Cannot outlive its parent scope. |
| **Unstructured task** | A task you create with `Task { }` or `Task.detached { }`. You own its lifetime; it can outlive the function that made it. |
| **Task tree** | The parent/child graph of structured tasks. Cancellation flows from parent to all descendants. |
| **Cooperative cancellation** | Cancellation sets a flag; it does not stop a task by force. Code must *check* the flag and stop itself. |
| **Cooperative thread pool** | The fixed-size pool (≈ core count) that runs all Swift Concurrency work. Blocking one of its threads is a bug. |
| **Back-pressure** | Limiting how much work is in flight so a fast producer can't overwhelm a slow consumer (or a socket/FD limit). |
| **`@TaskLocal`** | A value stored on the task and inherited by child tasks — like a thread-local, but task-scoped and structured. |
| **Continuation** | The bridge that turns a callback-based API into an `async` one (`withCheckedThrowingContinuation`). Resume it exactly once. |
| **GCD / `DispatchQueue`** | Grand Central Dispatch — the 2009-era queue-based concurrency API. Still present; no longer the default for new code. |

---

*If a link 404s, please open an issue so we can replace it.*
