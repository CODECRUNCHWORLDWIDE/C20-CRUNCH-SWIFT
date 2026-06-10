# Challenge 1 — Remove the Escape Hatch

> **Estimated time:** 90–150 minutes. Worth more than its time-cost suggests: "I removed an `@unchecked Sendable` by reworking the data model, not the annotation" is the exact sentence that lands a senior iOS offer in 2026.

You are handed a small module that compiles cleanly under Swift 6 language mode — but *only* because someone wrote a single `@unchecked Sendable` to make the last error go away. That annotation is a lie. There is no lock behind it, no documented thread-safe C type, no synchronisation mechanism the compiler cannot see. It is the illegitimate use from Lecture 2 §10: the escape hatch written purely to silence the checker.

Your job is to **delete the `@unchecked Sendable` and rework the data model so the module still compiles under `.v6` with zero warnings.** You may not move the lie somewhere else (no `nonisolated(unsafe)` on the offending field, no wrapping it in a hand-rolled lock just to keep the same shape). You must change the *shape* of the data so that the thing which used to be unsafe to send is now genuinely safe — because it is immutable, because it is a value type, or because it now lives inside an isolation domain.

This is the canonical shape of senior strict-concurrency work. Junior engineers reach for `@unchecked`. Senior engineers ask "why does this need to cross a boundary at all, and what is the smallest change that makes it safe to?"

## The starting code

Scaffold a library package and set it to Swift 6 mode:

```bash
mkdir FeedCache && cd FeedCache
swift package init --type library --name FeedCache
```

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeedCache",
    targets: [
        .target(
            name: "FeedCache",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "FeedCacheTests",
            dependencies: ["FeedCache"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
```

Now drop the following into `Sources/FeedCache/FeedCache.swift`. This is a feed cache of the kind every news/social app has: it holds the most recently fetched articles, lets a background refresher swap the snapshot atomically, and lets UI code read the current snapshot. It compiles under `.v6` today — because of the `@unchecked Sendable` on `Article`. Find it. It is on line one of the type.

```swift
import Foundation

// The lie. There is no synchronisation here. This was written to silence the checker.
final class Article: @unchecked Sendable {
    var id: UUID
    var title: String
    var body: String
    var fetchedAt: Date
    var isRead: Bool        // mutated from the UI; read from the refresher

    init(id: UUID, title: String, body: String, fetchedAt: Date, isRead: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.fetchedAt = fetchedAt
        self.isRead = isRead
    }
}

actor FeedCache {
    private var articles: [Article] = []

    /// The background refresher calls this with a freshly-fetched batch.
    func replace(with newArticles: [Article]) {
        articles = newArticles
    }

    /// UI reads the current snapshot.
    func snapshot() -> [Article] {
        articles
    }

    /// UI marks an article read. THIS is where the race lives:
    /// `markRead` mutates an Article that `snapshot()` already handed out,
    /// and the refresher may be reading `article.isRead` on its own task.
    func markRead(_ id: UUID) {
        if let article = articles.first(where: { $0.id == id }) {
            article.isRead = true       // mutating a shared reference type
        }
    }
}

// A consumer that demonstrates the problem.
public struct FeedDemo {
    public init() {}

    public func run() async {
        let cache = FeedCache()
        let a = Article(id: UUID(), title: "Swift 6 ships", body: "...", fetchedAt: .now)
        await cache.replace(with: [a])

        // The UI grabs a snapshot...
        let shown = await cache.snapshot()

        // ...and a background task mutates the SAME Article objects concurrently.
        async let mark: Void = cache.markRead(shown[0].id)
        async let refresh: Void = cache.replace(with: [
            Article(id: UUID(), title: "Newer story", body: "...", fetchedAt: .now)
        ])
        _ = await (mark, refresh)

        print("done; first article read = \(shown[0].isRead)")
    }
}
```

## Why the `@unchecked Sendable` is a lie here

Walk the data flow. `snapshot()` returns `[Article]` — an array of *references*. The UI now holds pointers to the very same `Article` objects the actor still holds in `articles`. When the UI calls `markRead`, the actor mutates `article.isRead` on an object the UI is simultaneously reading. When the refresher calls `replace`, it does not copy the old articles — it just drops the array, but the UI still holds references to the old objects and may read `isRead` on them while `markRead` writes it.

`Article` is a mutable `class`. Two isolation domains (the actor's, and whoever holds the snapshot) share the same instances and both mutate/read `isRead`. That is a textbook data race. The `@unchecked Sendable` told the compiler "trust me, sending an `Article` across a boundary is safe." It is not. There is no lock. The annotation is false.

If you remove the `@unchecked Sendable` and rebuild, you get exactly the diagnostic that was being suppressed:

```
error: type 'Article' does not conform to the 'Sendable' protocol
   func replace(with newArticles: [Article]) {
                            ^
note: class 'Article' cannot conform to 'Sendable' because it has
      mutable stored property 'id'
```

(plus the same note for `title`, `body`, `fetchedAt`, and `isRead`).

## Your task

Rework the data model so that:

1. The `@unchecked Sendable` annotation is **gone**.
2. There is **no** `nonisolated(unsafe)`, no `@unchecked Sendable` moved elsewhere, and no hand-rolled `Mutex`/`NSLock` introduced just to preserve the mutable-class shape.
3. The module compiles under `swiftLanguageMode(.v6)` with **zero warnings**.
4. The API still supports: replacing the batch, reading a snapshot, and marking an article read — and the "mark read" change is actually reflected in the cache's state (a later `snapshot()` shows it read).

The intended solution is to make `Article` a `Sendable` value type and move the "mark read" mutation *into* the actor's owned storage, so that crossing the boundary copies the value (safe) and the only mutable state lives inside the actor (serialised). You will discover, when you do this, that `markRead` on a value-type array element is a different operation than mutating a shared reference — and that this difference *is the bug fix*. The UI's snapshot becomes an immutable copy; mutating the cache no longer reaches into the UI's data.

A sketch of the destination (you write the real thing):

```swift
// A value type. Sendable for free: every stored property is Sendable.
public struct Article: Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let body: String
    public let fetchedAt: Date
    public var isRead: Bool
    // ... init ...
}

actor FeedCache {
    private var articles: [Article] = []
    // replace / snapshot / markRead — but markRead now mutates the actor's
    // OWN copy of the value, found by index, not a shared reference.
}
```

Note the consequence you must reason about in your writeup: after the fix, the UI's `shown` array is a *snapshot in time*. Marking an article read on the cache no longer mutates the UI's copy. That is correct — the UI must re-fetch the snapshot (or observe a stream) to see the change. The data race is gone precisely because the two domains no longer share mutable storage. Document that this is a behaviour change you made deliberately, not an accident.

## Acceptance criteria

- [ ] `grep -rn "@unchecked Sendable" Sources/` returns nothing.
- [ ] `grep -rn "nonisolated(unsafe)" Sources/` returns nothing.
- [ ] `grep -rn "NSLock\|os_unfair_lock\|Mutex\|DispatchQueue" Sources/` returns nothing (you did not just hide the lie behind a lock).
- [ ] `swift build` finishes with `Build complete!` and **zero warnings** under `.swiftLanguageMode(.v6)`.
- [ ] `Article` conforms to `Sendable` without any escape hatch (it is a value type, or a `final class` with only immutable `Sendable` stored properties).
- [ ] A Swift Testing test proves the API still works: `replace` then `snapshot` returns the batch; `markRead(id)` then `snapshot` shows that article's `isRead == true`.
- [ ] A second test proves the snapshot is now a copy: after `let s = await cache.snapshot()`, calling `await cache.markRead(s[0].id)` does **not** change `s[0].isRead` (because `s` is a value copy). This test is the proof that the shared-mutable-reference race is structurally impossible now.

## A small test harness

Put this in `Tests/FeedCacheTests/FeedCacheTests.swift`:

```swift
import Testing
import Foundation
@testable import FeedCache

@Test func snapshotReflectsReplace() async {
    let cache = FeedCache()
    let a = Article(id: UUID(), title: "One", body: "...", fetchedAt: .now)
    await cache.replace(with: [a])
    let snap = await cache.snapshot()
    #expect(snap.count == 1)
    #expect(snap[0].title == "One")
}

@Test func markReadPersistsInCache() async {
    let cache = FeedCache()
    let id = UUID()
    await cache.replace(with: [Article(id: id, title: "One", body: "...", fetchedAt: .now)])
    await cache.markRead(id)
    let snap = await cache.snapshot()
    #expect(snap[0].isRead == true)
}

@Test func snapshotIsAnIndependentCopy() async {
    let cache = FeedCache()
    let id = UUID()
    await cache.replace(with: [Article(id: id, title: "One", body: "...", fetchedAt: .now)])
    let snap = await cache.snapshot()          // copy taken here
    await cache.markRead(id)                    // mutate the cache, not the copy
    #expect(snap[0].isRead == false)            // the UI's copy is unaffected — no shared mutable state
    let fresh = await cache.snapshot()
    #expect(fresh[0].isRead == true)            // the cache itself did update
}
```

If `snapshotIsAnIndependentCopy` passes, you have proven the race is structurally impossible: the two domains hold independent value copies, so there is no shared memory to race on.

## What to submit

Push to your Week 4 GitHub repository at `challenges/challenge-01-feedcache/` containing:

- The full SwiftPM package (`Package.swift`, `Sources/`, `Tests/`).
- A `WRITEUP.md` (250–400 words) covering:
  - The exact diagnostic the compiler produced when you removed the `@unchecked Sendable`.
  - The data-model change you made and *why it makes the race structurally impossible* (not just "it compiles now").
  - The behaviour change the fix introduced (snapshot is now a copy) and why that is correct, not a regression.
  - One sentence on what you would do if `Article` genuinely needed reference semantics across domains (answer: isolate it to the actor and never hand out references — hand out value DTOs).

## Hints

<details>
<summary>If you make Article a struct but markRead "doesn't stick"</summary>

Mutating a struct found via `first(where:)` mutates a *copy* — the change is thrown away. Find the **index** with `firstIndex(where:)` and mutate `articles[index].isRead = true`. Arrays of value types support in-place element mutation by index; that mutation happens inside the actor's owned storage, which is exactly what you want.

</details>

<details>
<summary>If you are tempted to keep Article a class for "performance"</summary>

You are not handling 100,000 articles in a feed cache; you are handling a screen's worth. Value semantics here cost a struct copy on snapshot — nanoseconds. The reference-semantics "optimisation" buys you a data race. This is not a real trade-off. If you genuinely had a million-element hot path, the answer is *still* not a shared mutable class across domains — it is a single owner (the actor) that exposes immutable views. Reference semantics across isolation boundaries is the thing strict concurrency exists to prevent.

</details>

<details>
<summary>If you want Article to be a final class anyway</summary>

It is allowed — a `final class Article: Sendable` compiles *if every stored property is immutable* (`let`) and itself `Sendable`. But then `isRead` cannot be a `var`, so "mark read" must produce a *new* `Article` (immutable update), and the actor replaces the element. That is more ceremony than the `struct` for no benefit here. Prefer the `struct`. Mention in your writeup that the immutable-`final`-`class` form is the right tool when you specifically need reference identity (e.g. `===` checks) — which a feed cache does not.

</details>

---

**References**

- *Swift Migration Guide — Common compiler errors* (the `Sendable` conformance section): <https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems>
- *`Sendable` — official API reference*: <https://developer.apple.com/documentation/swift/sendable>
- *SE-0302 — Sendable and @Sendable closures*: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md>
- *SE-0414 — Region-based isolation* (why the compiler sometimes lets a non-Sendable value cross anyway): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md>
- Week 4, Lecture 2 §10 — "When `@unchecked Sendable` is actually defensible."
