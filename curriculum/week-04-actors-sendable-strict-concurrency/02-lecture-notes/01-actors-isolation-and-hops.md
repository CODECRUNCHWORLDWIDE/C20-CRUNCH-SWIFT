# Lecture 1 — Actors, Isolation, and Hops

> **Duration:** ~2 hours of reading + hands-on.
> **Outcome:** You can declare an actor, explain why its state is safe without a lock, point at every actor hop in a call graph and price it, use `@MainActor` and `nonisolated` deliberately, state which types are `Sendable`, and recognise a reentrancy bug on sight.

If you remember one sentence from this lecture, remember this:

> **Mutable state belongs to exactly one isolation domain. Crossing a domain boundary costs an `await` (a hop) and requires that whatever crosses is `Sendable`.** Every rule this week falls out of those two facts.

Week 3 taught you to spawn concurrent work. It did *not* teach you to share mutable state between concurrent work safely — we deliberately avoided it. This week we share, and we do it without locks, without `DispatchQueue.sync`, and without the class of bug that has kept iOS engineers employed debugging crash reports for fifteen years.

---

## 1. The problem actors solve

Here is a perfectly ordinary, perfectly broken cache. It compiles fine in Swift 5 mode. It will corrupt itself the first time two tasks touch it concurrently.

```swift
final class Cache {
    private var storage: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        storage[key]
    }

    func set(_ key: String, _ value: Data) {
        storage[key] = value
    }
}
```

`Dictionary` is a value type with copy-on-write storage. If task A is in the middle of `storage[key] = value` (which may be reallocating the backing buffer) while task B reads `storage[key]`, you have a classic data race: two threads, one piece of mutable memory, no synchronisation. The symptoms are the worst kind — intermittent crashes, corrupted values, "works on my machine," heisenbugs that vanish under the debugger because the debugger changes the timing.

The traditional fix is a lock:

```swift
final class Cache {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    func set(_ key: String, _ value: Data) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }
}
```

This works. It is also error-prone in exactly the way locks always are: forget one `lock.lock()` and you reintroduce the race; hold a lock across a callback and you deadlock; nest two locks in different orders and you deadlock differently. The compiler does not help you. It cannot see that `storage` is "supposed to be" protected by `lock`.

An actor encodes that intention into the type system:

```swift
actor Cache {
    private var storage: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        storage[key]
    }

    func set(_ key: String, _ value: Data) {
        storage[key] = value
    }
}
```

No lock. No `defer`. The `actor` keyword tells the compiler: *this type's mutable state is isolated.* The compiler now guarantees that `storage` is only ever touched from one place at a time, and it enforces that guarantee at every call site.

---

## 2. What "isolation" actually means

An `actor` is a reference type (like a `class`) with one extra property: it has an associated **serial executor**. Think of the executor as a private, invisible queue. Every call to an isolated method or property runs *on* that executor, one at a time. Two calls cannot run concurrently against the same actor instance. Ever. That is the whole guarantee.

This is why actor state is safe without a lock: the executor *is* the synchronisation. You did not write the lock because the runtime owns it, and the compiler knows the runtime owns it, so it can verify that you never reach around it.

The region of code that runs on a given actor's executor is that actor's **isolation domain**. The mental model from WWDC22's "Eliminate data races" talk is worth adopting: picture each actor as an *island*. Inside the island, code runs serially and can touch the island's mutable state freely. To get from one island to another you take a *boat* — and the boat trip is an `await`. You cannot teleport; you cannot reach across the water and grab something off another island synchronously.

There are three kinds of isolation domain you will meet:

1. **A specific actor instance.** `Cache()` has its own domain. Another `Cache()` has a *different* domain.
2. **A global actor**, most commonly `@MainActor` — a single shared domain whose executor is the main thread.
3. **Nonisolated** — code that belongs to *no* actor. It runs wherever it is called from and therefore may not touch any actor's isolated state. To compensate, everything it deals with across a boundary must be `Sendable`.

---

## 3. The rule: cross-actor access is async

Watch what happens when we call the actor `Cache` from outside it:

```swift
let cache = Cache()

func warmUp() async {
    await cache.set("greeting", Data("hello".utf8))   // await required
    let value = await cache.get("greeting")             // await required
    print(value as Any)
}
```

`set` and `get` are not `async` in their declaration — yet we must `await` them from outside. That is the rule: **a cross-actor reference to isolated state or methods is implicitly `async` and must be `await`ed.** The `await` is the boat trip to the island. From *inside* the actor — one method calling another method on `self` — no `await` is needed, because you are already on the island:

```swift
actor Cache {
    private var storage: [String: Data] = [:]
    private var hits = 0

    func get(_ key: String) -> Data? {
        let value = storage[key]          // no await: same domain
        if value != nil { recordHit() }   // no await: same domain (self)
        return value
    }

    private func recordHit() { hits += 1 }
}
```

Try to drop the `await` from a cross-actor call and the compiler stops you cold:

```
error: actor-isolated instance method 'get' can not be referenced
       from a nonisolated context
```

There is one important exception: an actor's `let` constants are **nonisolated** and can be read synchronously from anywhere, because an immutable value cannot race. So `actor Cache { let id = UUID() }` lets you write `cache.id` with no `await`. Only mutable state is isolated.

---

## 4. Actor hops: what they are and what they cost

An **actor hop** is the runtime switching execution from one isolation domain to another. It happens at exactly one place: an `await` that crosses a domain boundary. Not every `await` is a hop — `await someAsyncFunctionInTheSameDomain()` may not switch domains — but every cross-domain call is.

Pricing a hop honestly matters, because juniors either fear hops (and contort code to avoid them) or ignore them (and ship death-by-a-thousand-hops). A hop costs three things:

**Cost 1 — Suspension.** The calling function suspends. Its state (locals, the continuation) is saved. This is cheap relative to a thread block — no OS thread is parked — but it is not free; there is a heap allocation for the continuation and bookkeeping on Swift's cooperative thread pool.

**Cost 2 — A possible executor switch.** If the target actor's executor is currently busy, your work is enqueued and resumed later, possibly on a *different* physical thread from the cooperative pool. The "Swift concurrency: behind the scenes" talk (WWDC21) details this: there is no thread-per-task; a small pool of threads runs continuations. A hop may mean your continuation runs on thread 4 when it started on thread 2. That is fine — but it means you cannot assume thread-local state survives a hop.

**Cost 3 — The loss of atomicity (the one that bites).** This is the cost engineers forget. Across an `await`, *other work runs*. The actor you hopped to may process other messages; the actor you hopped *from* is free to process other messages too. Anything you assumed about the world before the `await` may be false after it. We will spend §9 on this, because it is the source of the nastiest concurrency bugs that survive into Swift 6.

A concrete picture. Consider:

```swift
@MainActor
final class FeedViewModel {
    private let cache: Cache
    var items: [Item] = []

    init(cache: Cache) { self.cache = cache }

    func refresh() async {
        // (A) main actor domain
        let raw = await cache.get("feed")   // HOP: main -> cache, then HOP: cache -> main
        // (B) back on main actor domain
        items = decode(raw)
    }
}
```

There are **two hops** in that one `await cache.get("feed")`: one out of the main actor into the `cache` actor's domain to run `get`, and one back into the main actor to resume `refresh`. Between (A) and (B), the main actor is free to run other work — a button tap handler, another view model update. That is desirable (the UI stays responsive) and dangerous (your `items` and the world may have moved on). Hold that thought for §9.

> **Rule of thumb for pricing:** a hop is roughly in the order of hundreds of nanoseconds when uncontended, dominated by allocation and scheduling — far cheaper than a `DispatchQueue.sync` thread block, far more expensive than a direct method call. Do not architect to avoid a hop on a cold path. *Do* avoid a hop in a tight inner loop — batch instead. The homework has you measure it.

---

## 5. Batching to avoid hop storms

The single most common performance mistake with actors is hopping in a loop:

```swift
// SLOW: one hop per iteration — 10,000 round trips to the actor.
func sumAll(keys: [String], cache: Cache) async -> Int {
    var total = 0
    for key in keys {
        if let data = await cache.get(key) {   // hop, every iteration
            total += data.count
        }
    }
    return total
}
```

The fix is to move the loop *inside* the actor so the whole thing runs in one domain entry:

```swift
actor Cache {
    private var storage: [String: Data] = [:]

    // Runs entirely on the cache's executor: one hop in, one hop out.
    func totalBytes(forKeys keys: [String]) -> Int {
        keys.reduce(0) { sum, key in sum + (storage[key]?.count ?? 0) }
    }
}
```

`await cache.totalBytes(forKeys: keys)` is now two hops total, not `2 * keys.count`. The principle generalises: **design the actor's API around the work the caller wants done, not around field-level getters and setters.** A getter-per-field actor forces hop storms onto every caller. A task-oriented actor API ("give me the total", "apply this batch of writes") keeps the loop on the right island.

---

## 6. `@MainActor` — the UI island

The main actor is a built-in global actor whose executor is the main thread. All UIKit, AppKit, and SwiftUI mutation must happen there — that has always been true; before Swift Concurrency we enforced it by hand with `DispatchQueue.main.async`. Now we enforce it with the type system.

You can apply `@MainActor` at four scopes:

```swift
// 1. On a whole type: every member is main-actor-isolated.
@MainActor
final class FeedViewModel {
    var items: [Item] = []          // main-actor-isolated
    func reload() { /* on main */ } // main-actor-isolated
}

// 2. On a single method.
final class Logger {
    nonisolated func log(_ s: String) { print(s) }

    @MainActor
    func updateBadge(_ count: Int) { /* must run on main */ }
}

// 3. On a stored property.
final class Coordinator {
    @MainActor var activeScreen: Screen = .home
}

// 4. On a closure parameter.
func onMain(_ work: @MainActor @Sendable () -> Void) { /* ... */ }
```

SwiftUI leans on this hard. The `View` protocol's `body` is `@MainActor`-isolated, which is why you can read `@State` synchronously inside it without an `await` — you are already on the main island. When you write `@Observable final class FeedViewModel` and mutate it from a SwiftUI view, the compiler wants those mutations on the main actor, and strict concurrency will tell you when you have wandered off it.

A `@MainActor` method called from a non-main context needs an `await`, exactly like any other actor:

```swift
func handleNetworkResponse(_ data: Data) async {
    let items = parse(data)              // nonisolated work, off main
    await viewModel.apply(items)         // HOP to main actor
}
```

That `await` is doing real work: it ensures the `apply` runs on the main thread, where it is safe to drive UIKit/SwiftUI. You are not "wasting" a hop; you are buying main-thread safety the compiler will hold you to.

---

## 7. `nonisolated` — opting out

Sometimes a member of an actor genuinely does not touch isolated state, and you want callers to reach it without an `await`. Mark it `nonisolated`:

```swift
actor Account {
    let id: UUID
    private var balanceCents: Int

    init(id: UUID, openingCents: Int) {
        self.id = id
        self.balanceCents = openingCents
    }

    // No isolated state touched -> nonisolated -> callable without await.
    nonisolated var shortID: String { String(id.uuidString.prefix(8)) }

    // Touches mutable state -> must stay isolated.
    func deposit(_ cents: Int) { balanceCents += cents }
}
```

`shortID` reads only `id`, an immutable `let`. Marking it `nonisolated` means `account.shortID` needs no `await`. The compiler enforces the promise: if you try to read `balanceCents` from a `nonisolated` member, you get an error. `nonisolated` is a *constraint you accept in exchange for synchronous access* — you are telling the compiler "this code is safe to run from any domain," and it holds you to it.

`nonisolated` is also how you conform an actor to a synchronous protocol. `CustomStringConvertible` requires a non-`async` `description`. An actor can only satisfy it if `description` is `nonisolated`:

```swift
extension Account: CustomStringConvertible {
    nonisolated var description: String { "Account(\(shortID))" }
}
```

### `nonisolated(unsafe)` — the deliberate escape

There is a sharp-edged variant, `nonisolated(unsafe)`, that disables the isolation check for one declaration:

```swift
final class LegacyBridge {
    // We hand-synchronise this with an OSAllocatedUnfairLock; tell the
    // compiler to stop checking it. We are now responsible for correctness.
    nonisolated(unsafe) private var cachedToken: String?
}
```

Use it only when you are providing your own synchronisation and the compiler cannot see it (bridging C APIs, a hand-rolled lock, a value you can prove is written exactly once before any concurrent read). It is the per-property cousin of `@unchecked Sendable`, and like that escape hatch, every use is a place a future race can hide. We spend the challenge this week *removing* these, not adding them.

---

## 8. `Sendable` — what may cross the water

A hop is a boat trip, and not everything is allowed on the boat. **`Sendable`** is the marker protocol for "values of this type are safe to hand from one isolation domain to another." When you call `await cache.set(key, value)`, the `value` is crossing from your domain into the cache's domain — so `value` must be `Sendable`. `Data` is. A `class` with mutable fields generally is not.

The rules for what is `Sendable`:

- **Value types** (`struct`, `enum`) are *implicitly* `Sendable` if all their stored properties are `Sendable`. `struct Item { let id: UUID; let title: String }` is `Sendable` for free — `UUID` and `String` are `Sendable`, and the struct is a value, so handing it across a boundary copies it; no shared mutable state, no race.
- **`actor` types** are always `Sendable`. The whole point of an actor is that it is safe to share — its state is protected by its executor.
- **A `final class`** can be `Sendable` *only if* it is immutable (all stored properties are `let` and themselves `Sendable`) or it is internally synchronised. You declare the conformance explicitly:

  ```swift
  final class Config: Sendable {
      let timeout: TimeInterval
      let retries: Int
      init(timeout: TimeInterval, retries: Int) {
          self.timeout = timeout
          self.retries = retries
      }
  }
  ```

  Add a `var` and the compiler rejects the `Sendable` conformance — correctly, because a mutable shared reference is exactly the thing that races.
- **Functions and closures** are made sendable with `@Sendable` (next section).
- **Generic types** are `Sendable` conditionally: `Array<Element>` is `Sendable` when `Element` is; `Optional<Wrapped>` is `Sendable` when `Wrapped` is. The standard library declares these conditional conformances for you.

The compiler checks `Sendable` at every boundary crossing. The diagnostic you will see most this week is:

```
error: passing argument of non-sendable type 'Foo' into actor-isolated
       context may introduce data races
```

It means: you tried to put something on the boat that is not safe to share. The fix is almost never `@unchecked Sendable`. The fix is to make the type *actually* safe — turn it into a value type, make its fields immutable, or pass a copy.

---

## 9. `@Sendable` closures

A closure can capture variables. If a closure is going to run in a *different* isolation domain than where it was written — for example, the body of a `Task { }`, or a `TaskGroup.addTask { }` block, or a completion handler invoked from another actor — then its captures cross a boundary too. `@Sendable` is the annotation that says "this closure is safe to run in another domain," and it imposes two constraints the compiler checks:

1. **Every captured value must be `Sendable`.**
2. **You may not capture a mutable variable by reference** (`var` captures are copied in, not shared out — actually the compiler forbids the mutable capture entirely unless it is a `Sendable` reference type).

```swift
func schedule(work: @Sendable @escaping () -> Void) {
    Task { work() }
}

func caller() {
    let name = "Ada"          // String is Sendable -> ok to capture
    schedule { print(name) }  // fine

    var counter = 0
    // schedule { counter += 1 }   // ERROR: mutable capture of 'counter'
    //                              //        in a @Sendable closure
}
```

`Task { }` requires a `@Sendable` closure because the task body may run on any thread in the cooperative pool. That is why this is an error under strict concurrency:

```swift
final class Counter {            // not Sendable: mutable class
    var value = 0
}

func bump(_ c: Counter) {
    Task {
        c.value += 1   // error: capture of 'c' with non-sendable type
                       //        'Counter' in a '@Sendable' closure
    }
}
```

The fix is to make `Counter` an `actor` (then `c.value += 1` becomes `await c.bump()`), or to make it a `Sendable` value type if it does not need reference semantics. Notice the compiler is not being pedantic: passing a mutable class into a `Task` and mutating it is *precisely* the data race actors exist to prevent.

> **A subtlety that confuses everyone once:** a closure passed to a `@MainActor` API does not need to be `@Sendable` if it is *guaranteed* to run on the main actor (it never leaves the island). Conversely, a closure handed to `Task.detached` always needs `@Sendable`. When in doubt, the compiler tells you which it wants. Read the diagnostic; do not guess.

---

## 10. Reentrancy — the bug that survives the migration

Actors prevent data races. They do **not** prevent *logic* races across suspension points, because Swift actors are **reentrant** by design. Reentrancy means: while one call to an actor method is suspended at an `await`, the actor is free to start *another* call. This is good — it stops one slow call from blocking the whole actor — but it means **state can change across every `await` inside an actor method.**

Here is the canonical bug. An image loader that tries to avoid duplicate downloads:

```swift
actor ImageLoader {
    private var cache: [URL: Image] = [:]

    func image(at url: URL) async throws -> Image {
        if let cached = cache[url] {        // (1) check
            return cached
        }
        let downloaded = try await download(url)  // (2) AWAIT — suspends here
        cache[url] = downloaded                    // (3) act
        return downloaded
    }
}
```

Trace two concurrent calls for the same URL:

- Call A enters, sees nothing in `cache` at (1), suspends at (2) to download.
- While A is downloading, Call B enters (reentrancy!), *also* sees nothing in `cache` at (1) — A hasn't written it yet — and *also* starts a download at (2).
- Both downloads complete. Both write `cache[url]` at (3). You downloaded the same image twice and may have torn work in flight.

No data race — every `cache` access is properly serialised. But a logic race: the "check" at (1) is stale by the time the "act" at (3) runs, because an `await` sat between them. The lock-based version had the same bug class unless you held the lock across the download (which you must never do — you would serialise all downloads).

**Fix 1 — coalesce in-flight work.** Store the *task*, not just the result, so the second caller awaits the first caller's download:

```swift
actor ImageLoader {
    private enum Entry {
        case inFlight(Task<Image, Error>)
        case ready(Image)
    }
    private var cache: [URL: Entry] = [:]

    func image(at url: URL) async throws -> Image {
        if let entry = cache[url] {
            switch entry {
            case .ready(let image):
                return image
            case .inFlight(let task):
                return try await task.value   // join the existing download
            }
        }
        let task = Task { try await self.download(url) }
        cache[url] = .inFlight(task)          // record BEFORE awaiting
        do {
            let image = try await task.value
            cache[url] = .ready(image)
            return image
        } catch {
            cache[url] = nil                  // let the next caller retry
            throw error
        }
    }

    private func download(_ url: URL) async throws -> Image { /* ... */ Image() }
}
```

The key move: we mutate `cache` to `.inFlight(task)` *before* the first `await`. By the time a reentrant call arrives, the entry already exists, so it joins the existing task instead of starting a new one.

**Fix 2 — re-validate after the await.** For check-then-act on a value, re-check the invariant *after* the suspension:

```swift
func setIfStillEmpty(_ key: String, _ value: Data) async {
    guard storage[key] == nil else { return }
    let validated = await validate(value)   // suspends
    guard storage[key] == nil else { return }  // RE-CHECK: state may have changed
    storage[key] = validated
}
```

The discipline you must build this week: **every `await` inside an actor is a place the world can change. Treat the code before and after an `await` as two separate transactions, and re-establish any invariant you depended on.** This is not a Swift quirk — it is the cost of reentrancy, and reentrancy is the price of not blocking the actor. Swift chose responsiveness over the surprise of non-reentrant deadlocks, and you must code accordingly.

---

## 11. A worked end-to-end picture

Let us pull it together with a small subsystem you might actually ship: a download coordinator that fetches JSON, decodes it off the main actor, and publishes results to a SwiftUI view model on the main actor.

```swift
import Foundation

// A Sendable value type: safe to cross any boundary by copy.
struct Article: Sendable, Decodable, Identifiable {
    let id: Int
    let title: String
}

// The networking island. Owns its own URLSession and an in-flight task map.
actor ArticleService {
    private let session: URLSession
    private var inFlight: [URL: Task<[Article], Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func articles(from url: URL) async throws -> [Article] {
        if let existing = inFlight[url] {
            return try await existing.value          // coalesce reentrant calls
        }
        let task = Task { try await self.fetch(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }

    private func fetch(_ url: URL) async throws -> [Article] {
        let (data, _) = try await session.data(from: url)   // hop into URLSession
        return try JSONDecoder().decode([Article].self, from: data)
    }
}

// The UI island. Every member runs on the main actor.
@MainActor
@Observable
final class ArticleListModel {
    private let service: ArticleService
    var articles: [Article] = []
    var errorMessage: String?

    init(service: ArticleService) {
        self.service = service
    }

    func load(from url: URL) async {
        do {
            // HOP: main -> ArticleService -> (URLSession) -> back to main.
            let fetched = try await service.articles(from: url)
            // We are guaranteed back on the main actor here. Safe to mutate UI state.
            articles = fetched
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Walk the isolation: `Article` is `Sendable`, so `[Article]` crosses the boundary back to the main actor cleanly. `ArticleService` is an actor (hence `Sendable`), so the `@MainActor` model can hold a reference to it. The `Task` inside `articles(from:)` captures `self` (an actor, `Sendable`) and `url` (`Sendable`), so its closure is `@Sendable`-clean. The reentrancy guard coalesces duplicate fetches. And every UI mutation in `load` is provably on the main actor. This whole subsystem compiles under Swift 6 language mode with zero warnings and zero `@unchecked Sendable`. That is the bar for the week.

---

## 12. Common misconceptions, named and corrected

- **"Actors make my code thread-safe automatically, so I can stop thinking."** No. They eliminate *data* races. They do not eliminate *logic* races across `await` (reentrancy). You still think.
- **"Every `await` is expensive, so I should minimise actor calls."** Hops are cheap individually. The expensive pattern is hops *in a loop*. Batch the loop into the actor (§5); do not contort the architecture to shave one hop on a cold path.
- **"`@MainActor` everything to be safe."** That serialises your whole app onto the main thread and reintroduces the hangs you were trying to avoid. `@MainActor` is for UI and UI-adjacent state. Networking, parsing, and caching belong on their own actors, off the main thread.
- **"`@unchecked Sendable` is a quick fix."** It is a quick way to *hide* a race the compiler just found. Every one is a TODO that says "I owe this code a real synchronisation strategy."
- **"`nonisolated` means thread-unsafe."** No — `nonisolated` means "does not touch isolated state, so it is safe from any domain." It is a *safety* annotation. `nonisolated(unsafe)` is the unsafe one.

---

## 13. Recap

You should now be able to:

- Declare an `actor` and explain why its state is safe without a lock (the serial executor *is* the synchronisation).
- State the rule: cross-actor access to mutable state is `async` and must be `await`ed; `let` constants are nonisolated.
- Identify every hop in a call graph and price it: suspension, possible executor switch, and the loss of atomicity across the `await`.
- Batch work into an actor to avoid hop storms in loops.
- Apply `@MainActor` to UI state and `nonisolated` to members that touch no isolated state, and justify `nonisolated(unsafe)` only when you provide your own synchronisation.
- State which types are `Sendable` (value types of `Sendable` parts, actors, immutable `final class`es) and use `@Sendable` closures correctly.
- Recognise and fix an actor reentrancy bug by recording state before the first `await` and re-validating invariants after every `await`.

Next up: what the Swift 6 compiler enforces project-wide, and a worked migration that removes a real data race. Continue to [Lecture 2 — Strict concurrency and a worked migration](./02-strict-concurrency-and-a-worked-migration.md).

---

## References

- *The Swift Programming Language — Concurrency*: <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>
- *SE-0306 — Actors*: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md>
- *SE-0302 — Sendable and @Sendable closures*: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md>
- *SE-0316 — Global actors*: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md>
- *WWDC21 — Protect mutable state with Swift actors*: <https://developer.apple.com/videos/play/wwdc2021/10133/>
- *WWDC22 — Eliminate data races using Swift Concurrency*: <https://developer.apple.com/videos/play/wwdc2022/110351/>
- *WWDC21 — Swift concurrency: Behind the scenes*: <https://developer.apple.com/videos/play/wwdc2021/10254/>
