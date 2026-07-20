# Week 6 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 10/13 before the Phase I gate. Answer key at the bottom — don't peek.

---

**Q1.** Why does the shared `NotesCore.Note` type eliminate the "DTO drift" bug class?

- A) Because `Codable` validates the JSON schema at runtime on both sides.
- B) Because the server and client compile against the *same* type declaration, so a field change breaks the build on both sides at compile time.
- C) Because SwiftPM regenerates the client type from the server type on every build.
- D) Because `Sendable` prevents the type from being modified after creation.

---

**Q2.** You move `Note` into `NotesCore`, it compiles in the package, but the server reports "cannot find `Note` in scope" even after importing `NotesCore`. The most likely cause is:

- A) You forgot to run `swift package resolve`.
- B) The type or its members are not marked `public` (a `struct`'s synthesized memberwise init is `internal`).
- C) `NotesCore` needs to depend on Vapor.
- D) You must use a Git URL dependency, not a `path:` dependency.

---

**Q3.** Why should `NotesCore` depend on Foundation only — and *not* on Vapor?

- A) Vapor does not compile on Linux.
- B) Because every consumer of `NotesCore` (including the future SwiftUI client) would otherwise drag the entire server framework into its build.
- C) Because `Codable` is not available when Vapor is imported.
- D) It is a stylistic preference with no real consequence.

---

**Q4.** The `notes-api` server needs `NotesCore.Note` to conform to Vapor's `Content`. Where should that conformance live?

- A) Add `Content` to the `Note` declaration inside `NotesCore`.
- B) In a `@retroactive Content` extension in the *server* target, keeping `NotesCore` Vapor-free.
- C) In a separate `NotesCoreVapor` package that both depend on.
- D) Nowhere — `Codable` types are automatically `Content`.

---

**Q5.** Given:

```swift
public struct UpdateNoteRequest: Codable, Sendable {
    public var title: String?
    public var body: String?
}
```

What does `JSONDecoder().decode(UpdateNoteRequest.self, from: Data("{}".utf8))` produce?

- A) A `DecodingError.keyNotFound` for `title`.
- B) A value with `title == nil` and `body == nil` — absent keys decode to `nil` for optionals.
- C) A compile error; `Codable` requires non-optional properties.
- D) A value with `title == ""` and `body == ""`.

---

**Q6.** For an optional `Codable` property, how does `JSONDecoder` treat an absent key versus an explicit `null`?

- A) Absent throws; `null` decodes to `nil`.
- B) They are treated identically — both decode to `nil`.
- C) Absent decodes to `nil`; `null` throws.
- D) Both throw unless you write a custom `init(from:)`.

---

**Q7.** Why is `NotesCore.Note` `Sendable` "for free"?

- A) Because it is marked `@unchecked Sendable`.
- B) Because it is a `struct` whose every stored property (`UUID`, `String`, `[String]`, `Date`) is itself `Sendable`.
- C) Because Foundation marks all its types `Sendable`.
- D) Because `Codable` implies `Sendable`.

---

**Q8.** In the swift-nio model, what is the relationship between a `Channel` and an `EventLoop`?

- A) A `Channel` rotates across all event loops in the group for load balancing.
- B) Each `Channel` is pinned to exactly one `EventLoop` for its entire life; all work for that connection runs on that one thread.
- C) Each `EventLoop` owns exactly one `Channel`.
- D) `Channel` and `EventLoop` are two names for the same thing.

---

**Q9.** A junior engineer adds `Thread.sleep(forTimeInterval: 2)` inside a Vapor route handler to simulate latency and throughput collapses. Why?

- A) `Thread.sleep` allocates a new thread per call, exhausting the pool.
- B) It blocks the entire event loop for two seconds, stalling every connection assigned to that loop — not just the one request.
- C) Vapor forbids `Thread.sleep` and crashes.
- D) It triggers a deadlock with the database driver.

The correct fix is `try await Task.sleep(for: .seconds(2))`. Why is that fine?

- E) It suspends the `async` function without blocking the event-loop thread, which is freed to serve other connections.

---

**Q10.** How does `async`/`await` bridge swift-nio's `EventLoopFuture`?

- A) `await future` blocks the calling thread until the future completes.
- B) `EventLoopFuture` has an `async` `get()` method that suspends the calling function until the future completes, without blocking the loop.
- C) `async`/`await` cannot interoperate with `EventLoopFuture`; you must rewrite everything.
- D) `await` converts the future into a `Result` synchronously.

---

**Q11.** You need a bounded "most recent 100" buffer: push at the back, drop the oldest from the front on overflow. Which structure, and why?

- A) `Array` — `append` and `removeFirst` are both O(1).
- B) `Deque` — O(1) at both ends; `Array.removeFirst` is O(n) because it shifts every element.
- C) `Heap` — it keeps the elements sorted.
- D) `OrderedDictionary` — it remembers insertion order.

---

**Q12.** You need O(1) lookup by note id *and* deterministic iteration in the order entries were inserted. Which structure?

- A) `Dictionary` — it already iterates in insertion order.
- B) `Array` of `(id, value)` pairs.
- C) `OrderedDictionary` — O(1) lookup plus stable insertion order in one structure.
- D) `Set` of notes.

---

**Q13.** What is the honest, one-sentence difference between Vapor and Hummingbird in 2026?

- A) Hummingbird is faster because it is not built on swift-nio.
- B) Vapor is the larger-ecosystem, batteries-included default (Fluent, more packages); Hummingbird is the lighter, async-first core you assemble pieces around — both stand on swift-nio.
- C) Vapor only runs on macOS; Hummingbird only runs on Linux.
- D) They are the same framework under two names.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — The whole point: one declaration, two consumers, so the compiler catches a field change on both sides at build time. `Codable` does no runtime schema validation (A is false); SwiftPM does not codegen client types (C is false); `Sendable` is about concurrency, not mutation (D is false).
2. **B** — A `struct`'s members are `internal` by default and its synthesized memberwise initializer is `internal`. Crossing a module boundary requires `public` on the type, its properties, and a hand-written `public init`. This is the single most common extraction mistake.
3. **B** — A shared package's dependencies become every consumer's dependencies. If `NotesCore` imported Vapor, your future SwiftUI client would have to build Vapor to decode a note. Keep the shared package pure; add framework conformances in the consuming target.
4. **B** — `@retroactive Content` in the server target keeps `NotesCore` framework-free while still letting Vapor serialize the shared types. A separate package (C) works but is overkill for this; A pollutes the shared package; D is false.
5. **B** — For optional `Codable` properties, an absent key decodes to `nil`. `{}` therefore decodes to all-`nil`. This is the documented behaviour and the reason `UpdateNoteRequest` uses optionals for "leave unchanged."
6. **B** — `JSONDecoder` treats an absent key and an explicit `null` identically for optionals: both yield `nil`. To distinguish the three states (absent / null / value) you must write a custom `init(from:)` that calls `container.contains(.key)`. We do not need that for `notes-api`.
7. **B** — A `struct` is `Sendable` when all its stored properties are `Sendable`. `UUID`, `String`, `[String]`, and `Date` are all `Sendable` value types, so the compiler synthesizes `Sendable` and *verifies* it under Swift 6 mode. No `@unchecked` needed (A is wrong); `Codable` does not imply `Sendable` (D is wrong).
8. **B** — The cardinal nio invariant: one connection, one loop, one thread, for the connection's whole life. That is how nio gets concurrency *across* connections without data races *within* a connection.
9. **B / E** — `Thread.sleep` blocks the OS thread the event loop runs on, stalling every connection on that loop. `Task.sleep` suspends the `async` function and frees the loop to serve others. Understanding this distinction is the core of the event-loop model.
10. **B** — `EventLoopFuture.get()` is `async`; awaiting it suspends your function (not the thread) until the future completes, then resumes. This is exactly why Vapor route handlers can be plain `async` functions.
11. **B** — `Deque` is O(1) at both ends (ring buffer). `Array.removeFirst()` is O(n) because it shifts every remaining element left. The difference is invisible at N=10 and a real problem at N=100,000.
12. **C** — `OrderedDictionary` gives O(1) keyed lookup *and* stable insertion order in one structure. `Dictionary` does not promise iteration order (A is false). An `Array` of pairs gives order but O(n) lookup (B). 
13. **B** — Both are built on swift-nio. Vapor is the bigger-ecosystem, batteries-included default with Fluent; Hummingbird is the lighter, async-first core you assemble around. A, C, and D are all factually wrong.

</details>

---

If you scored under 10, re-read the lectures for the questions you missed — especially anything about the event loop or the shared-types rationale, since those are the Phase I gate's intellectual core. If you scored 12 or 13, you're ready for the [homework](./homework.md) and the [mini-project](./mini-project/README.md).
