# Week 6 Homework

Six practice problems that reinforce the week's topics: the shared-types pattern, `Codable` discipline, the event-loop model, swift-collections, and `URLSession` on Linux. The full set should take about **4.5 hours**. Work in your Week 6 Git repository so each problem produces at least one commit you can point to later.

Each problem includes a **problem statement**, **deliverables**, **acceptance criteria**, a **hint**, and an **estimated time**.

---

## Problem 1 — The `path:` vs URL dependency note

**Problem statement.** In `notes/dependencies.md`, explain in your own words (150–250 words) the difference between a `.package(path: "../NotesCore")` dependency and a `.package(url: "https://github.com/you/NotesCore.git", from: "1.0.0")` dependency. Cover: when you use each, what changes for the consumer's `Package.resolved`, and why the import code in the consuming target is *identical* either way.

**Deliverables.** `notes/dependencies.md`.

**Acceptance criteria.**

- [ ] The file exists, 150–250 words.
- [ ] It states at least one concrete reason `path:` is right during active development and one reason the URL form is right for a published package.
- [ ] It notes that `import NotesCore` is the same in both cases.
- [ ] Committed.

**Hint.** `path:` resolves to a local directory and tracks whatever is on disk — edits are picked up on the next build with no version bump. The URL form pins a version and requires a tag + push to release a change. The point of both is that the *consuming code* never knows the difference.

**Estimated time.** 20 minutes.

---

## Problem 2 — A schema-evolution round-trip test

**Problem statement.** In your `NotesCore` test target, add a test that proves the wire format can evolve without breaking old clients. Define a `NoteV2` struct (in the test file is fine) that is `Note` plus one new **optional** field, `color: String?`. Encode a current `Note`, then decode the bytes into `NoteV2`, and assert it succeeds with `color == nil`. Then encode a `NoteV2` *with* a color and decode it back into a plain `Note`, and assert that *also* succeeds (the unknown `color` key is ignored).

**Deliverables.** A `@Test` function in `NotesCoreTests`.

**Acceptance criteria.**

- [ ] The test encodes `Note`, decodes `NoteV2`, asserts `color == nil`.
- [ ] The test encodes `NoteV2` (with a color), decodes `Note`, asserts success.
- [ ] `swift test` passes.
- [ ] The test uses the `.iso8601` date strategy on both ends.
- [ ] Committed.

**Hint.** Forward compatibility (old payload → new type) works because the new field is optional and an absent key decodes to `nil`. Backward compatibility (new payload → old type) works because `Codable` ignores unknown keys by default. This is the exact property that lets your server add a field without a coordinated client deploy.

**Estimated time.** 45 minutes.

---

## Problem 3 — Explain the blocking bug

**Problem statement.** Write a 250–350 word explanation in `notes/event-loop.md` of why this Vapor handler destroys throughput, and what the one-line fix is:

```swift
app.get("slow") { req async -> String in
    Thread.sleep(forTimeInterval: 2)   // "simulate latency"
    return "done"
}
```

Your explanation must: (1) describe what an `EventLoop` is and the "one connection, one loop, one thread" invariant; (2) explain precisely what `Thread.sleep` does to *other* connections on the same loop; (3) give the fix and explain why `Task.sleep` is non-blocking where `Thread.sleep` is not.

**Deliverables.** `notes/event-loop.md`.

**Acceptance criteria.**

- [ ] The file exists, 250–350 words.
- [ ] It correctly states the pinned-to-one-loop invariant.
- [ ] It explains the difference between blocking the thread (`Thread.sleep`) and suspending the function (`Task.sleep`).
- [ ] It gives the corrected handler.
- [ ] Committed.

**Hint.** The event loop is one thread multiplexing thousands of connections. `Thread.sleep` parks that thread; every connection it serves stalls for two seconds. `Task.sleep` suspends the `async` function and yields the thread back to the loop, which keeps serving other connections. See Lecture 2 §2.3.

**Estimated time.** 45 minutes.

---

## Problem 4 — Three collections, three justifications

**Problem statement.** In `homework/p4-collections/main.swift`, build a small program that uses each of `OrderedDictionary`, `Deque`, and `Heap` once, each for a *different* realistic task (not the same tasks as Exercise 3). For each, print a result and add a one-line comment stating the access pattern that makes that structure the right choice. Then, in `homework/p4-collections/justification.md`, write one paragraph per structure giving the Big-O of the operation that motivated it versus the obvious `Array`/`Dictionary` alternative.

**Deliverables.** A runnable `homework/p4-collections/` package and `justification.md`.

**Acceptance criteria.**

- [ ] The program builds and runs (`swift run`), printing one result per structure.
- [ ] Each structure is used for a task *different* from Exercise 3's.
- [ ] `justification.md` has three paragraphs, each naming the operation and both Big-O values.
- [ ] `swift build`: 0 warnings under Swift 6 mode.
- [ ] Committed.

**Hint.** Fresh tasks: `OrderedDictionary` for an HTTP header map that must serialize in a stable order; `Deque` for a sliding-window rate limiter; `Heap` for a Dijkstra-style frontier or a top-K stream. Add the `swift-collections` dependency exactly as in Exercise 3's HINT 0.

**Estimated time.** 1 hour.

---

## Problem 5 — Harden the CLI's error handling

**Problem statement.** Extend your `notes-cli` (or a copy under `homework/p5-cli/`) so that *every* failure path produces a clean, single-line message to `stderr` and a non-zero exit code — never a stack trace or a raw `Error` dump. Handle at least: a connection refused (server down), a 401 (bad token), a 404 (`get` of a missing id), a 400 (malformed create), and a decode failure (server returned unexpected JSON). For the non-2xx cases, surface the `APIError.reason`.

**Deliverables.** The hardened CLI and a `homework/p5-cli/errors.md` listing each failure case and the exact message your CLI prints.

**Acceptance criteria.**

- [ ] Each of the five failure cases prints a clean one-line message and exits non-zero.
- [ ] Non-2xx responses surface `APIError.reason`, not a status-code dump.
- [ ] A connection-refused error (server down) is caught and reported, not crashed on.
- [ ] `errors.md` documents the five cases and their messages.
- [ ] Committed.

**Hint.** Wrap the `do/catch` at the top level of `main.swift`. Make your error type `CustomStringConvertible` (Exercise 2 already starts this) so `print(error)` reads cleanly. For exit codes, `Foundation.exit(1)` or return from `@main`. Test "server down" by stopping the server and running the CLI.

**Estimated time.** 1 hour.

---

## Problem 6 — Mini reflection

**Problem statement.** Write a 300–400 word reflection at `notes/week-06-reflection.md` answering:

1. Before this week, where did you previously keep "the type that goes on the wire" in a client/server system you have built? What did that cost you?
2. The drift experiment (rename a field, watch both targets fail to build): did it land the way you expected? What surprised you?
3. Which was harder to internalize — the shared-types pattern or the event-loop model — and why?
4. Now that Phase I is closing, what is the one thing about server-side Swift you most want to carry into the Phase II SwiftUI client?

**Deliverables.** `notes/week-06-reflection.md`.

**Acceptance criteria.**

- [ ] File exists, 300–400 words, each numbered question in its own paragraph.
- [ ] Committed.

**Hint.** This is for you, not a grade. Be honest. Future-you, debugging a sync conflict in Phase III, will be glad you wrote down what the shared type bought you.

**Estimated time.** 30 minutes.

---

## Time budget recap

| Problem | Estimated time |
|--------:|---------------:|
| 1 | 20 min |
| 2 | 45 min |
| 3 | 45 min |
| 4 | 1 h 0 min |
| 5 | 1 h 0 min |
| 6 | 30 min |
| **Total** | **~4 h 20 min** |

---

## Rubric

Each problem is scored 0–4; the homework total is out of 24.

| Score | Meaning |
|------:|---------|
| **4** | Complete, correct, idiomatic. Code builds with 0 warnings under Swift 6 mode; prose is precise and uses the right terms. |
| **3** | Complete and correct, with minor rough edges (a vague sentence, a missing edge case, a stylistic slip). |
| **2** | Mostly there; one acceptance box unmet or a conceptual imprecision (e.g. confuses blocking the thread with suspending the function). |
| **1** | Attempted but substantially incomplete or incorrect. |
| **0** | Missing or non-functional. |

| Problem | Max | What earns full marks |
|--------:|----:|-----------------------|
| 1 — Dependency note | 4 | Correct `path:` vs URL distinction; notes identical import code. |
| 2 — Schema evolution | 4 | Both forward and backward compat tests pass with `.iso8601`. |
| 3 — Blocking bug | 4 | Correct event-loop invariant + the thread-vs-function distinction. |
| 4 — Collections | 4 | Three distinct tasks; correct Big-O for each motivating op. |
| 5 — CLI hardening | 4 | All five failure cases clean; `APIError.reason` surfaced. |
| 6 — Reflection | 4 | All four questions addressed thoughtfully, in range. |

**Pass mark: 18/24.** Below that, revisit the lectures for the problems you lost points on before sitting the quiz.

When you've finished all six, push your repo and open the [mini-project](./07-mini-project/00-overview.md) — the Phase I gate deliverable.
