# Mini-Project — ActorKV: migrate a callback key-value store to an actor under strict concurrency

> Take a callback-based, thread-unsafe key-value store (provided below as starter code), and migrate it into an `actor` that compiles cleanly under **Swift 6 language mode** with **zero `@unchecked Sendable`**. Along the way you must document **at least three distinct compile-time errors** the migration surfaces — each marking a real data race the old code shipped — and explain the structural fix for each. By the end you have a small, well-tested, race-free KV store any production team would recognise: an `async` API, value-typed entries, a reentrancy-safe `getOrInsert`, and an `AsyncStream` change feed. This is the syllabus skill for the week, end to end: *compile a non-trivial module under strict concurrency without `@unchecked Sendable` shortcuts.*

This is the canonical "make it safe" exercise in Swift 6. Real codebases are full of `Manager`/`Store`/`Cache` singletons written in the callback-and-background-queue style, compiled for years in Swift 5 with data-race checking off, racing intermittently in production. Senior engineers spend a real fraction of 2026 turning those into actors. This mini-project is that experience, in microcosm.

**Estimated time:** ~12.5 hours (split across Friday, Saturday, Sunday in the suggested schedule).

---

## What you will build

A SwiftPM package called `ActorKV` with two targets and a test target:

- `Sources/ActorKVCore/` — the library: the `KeyValueStore` actor, the `StoreEntry` value type, the `StoreError` enum, and the `Change` event type.
- `Sources/ActorKVDemo/` — a tiny executable that exercises the store concurrently and prints a report (proving the store behaves under load).
- `Tests/ActorKVCoreTests/` — Swift Testing tests, including concurrent-access tests that would have failed non-deterministically against the old class.

The deliverable is the migrated package **plus** a `MIGRATION.md` that documents the three-or-more compile errors you hit and how you fixed each.

### Functional surface (the API you must end up with)

```swift
public actor KeyValueStore {
    public init(ttl: Duration? = nil)

    /// Store a value. Overwrites any existing value for the key.
    public func set(_ value: Data, for key: String) -> Void

    /// Read a value. Returns nil if absent or expired.
    public func value(for key: String) -> Data?

    /// Remove a value. Returns the removed value, if any.
    @discardableResult public func remove(_ key: String) -> Data?

    /// Atomic read-or-compute: if the key is present, return it; otherwise run
    /// the (async) producer ONCE even under concurrent callers, store the
    /// result, and return it. Reentrancy-safe.
    public func getOrInsert(_ key: String, producer: @Sendable () async throws -> Data) async throws -> Data

    /// Snapshot of all live (non-expired) entries, as value copies.
    public func snapshot() -> [String: Data]

    /// Number of live entries.
    public var count: Int { get }

    /// A live stream of change events (set / removed / expired).
    public nonisolated func changes() -> AsyncStream<Change>
}

public enum Change: Sendable {
    case set(key: String)
    case removed(key: String)
    case expired(key: String)
}

public enum StoreError: Error, Sendable {
    case producerFailed(key: String)
}
```

---

## The starter code (the "before")

Scaffold the package:

```bash
mkdir ActorKV && cd ActorKV
swift package init --type empty --name ActorKV
```

`Package.swift` — note the targets start in Swift 5 mode with **complete** checking as *warnings*, so you can see the migration light up before you flip to errors:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ActorKV",
    targets: [
        .target(
            name: "ActorKVCore",
            // PHASE 1: complete checking, warnings (Swift 5 semantics).
            // PHASE 4: replace this whole array with [.swiftLanguageMode(.v6)].
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .executableTarget(
            name: "ActorKVDemo",
            dependencies: ["ActorKVCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ActorKVCoreTests",
            dependencies: ["ActorKVCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
)
```

Drop this thread-unsafe starter into `Sources/ActorKVCore/KeyValueStore.swift`. It compiles in Swift 5 mode. It races. **Do not fix it yet — read it, build it, and watch the checker react.**

```swift
import Foundation

// STARTER — callback-based, thread-unsafe. This is what you are migrating.
public final class KeyValueStore {
    private var storage: [String: Data] = [:]
    private var expiry: [String: Date] = [:]
    private let ttl: TimeInterval?
    private var listeners: [(String) -> Void] = []

    public init(ttl: TimeInterval? = nil) {
        self.ttl = ttl
    }

    public func set(_ value: Data, for key: String) {
        storage[key] = value
        if let ttl { expiry[key] = Date().addingTimeInterval(ttl) }
        for listener in listeners { listener(key) }   // notify on caller's thread
    }

    public func value(for key: String, completion: @escaping (Data?) -> Void) {
        // Pretend reads are async (a real store hits disk/network).
        DispatchQueue.global().async {
            if let deadline = self.expiry[key], deadline < Date() {
                self.storage[key] = nil                // WRITE on a background queue
                completion(nil)
                return
            }
            completion(self.storage[key])              // READ on a background queue
        }
    }

    public func getOrInsert(_ key: String,
                            producer: @escaping () -> Data,
                            completion: @escaping (Data) -> Void) {
        if let existing = storage[key] {               // check, on caller's thread
            completion(existing)
            return
        }
        DispatchQueue.global().async {
            let produced = producer()                  // may take a while
            self.storage[key] = produced               // WRITE on a background queue
            completion(produced)
        }
    }

    public func onChange(_ listener: @escaping (String) -> Void) {
        listeners.append(listener)                     // mutate listeners, any thread
    }
}
```

Build it under the warning configuration:

```bash
swift build
```

You will get a cluster of strict-concurrency **warnings** (because the target is Swift 5 mode + complete checking). Read them. They mark exactly the races: `self` (a non-`Sendable` class) captured in the `DispatchQueue.global().async` `@Sendable` closures; the escaping `@Sendable` completion handlers capturing mutable state; the `listeners` array of escaping closures mutated from multiple threads.

---

## The migration, phase by phase

Work in four phases. The order matters — it surfaces the real races first and keeps the diff reviewable.

### Phase 1 — Make the data `Sendable` and model the value type (Friday, ~1h)

The values are `Data`, already `Sendable`. The change event needs to be a `Sendable` value type — define `enum Change: Sendable` as in the surface above. Define `StoreError: Error, Sendable`. Define a private `StoreEntry` value type that pairs a `Data` with an optional expiry `Date`:

```swift
struct StoreEntry: Sendable {
    let value: Data
    let expiresAt: Date?
    func isExpired(now: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt < now
    }
}
```

Switch the TTL to `Duration?` (Swift's modern duration type) instead of `TimeInterval`. This is a value type and `Sendable`. Commit.

### Phase 2 — Convert the class to an actor; delete the callbacks (Friday/Saturday, ~4h)

Change `final class` to `actor`. Replace the completion-handler API with `async`:

- `value(for:)` becomes `func value(for key: String) -> Data?` (no completion; cross-actor callers `await` it). Inside, lazily expire on read.
- `getOrInsert` becomes the reentrancy-safe `async throws` version — store the in-flight `Task` before the first `await` so concurrent callers for the same key run the producer exactly once. This is the Lecture 1 §10 fix, and it is the hardest part of the project. Get it right; the tests check it.
- `set` becomes `func set(_:for:)`, mutating actor storage and broadcasting a `.set` change to the stream.
- Add `remove`, `snapshot`, and the `count` property.

The `getOrInsert` body you are aiming for:

```swift
private enum Slot {
    case ready(StoreEntry)
    case loading(Task<Data, Error>)
}
private var slots: [String: Slot] = [:]

public func getOrInsert(_ key: String,
                        producer: @Sendable () async throws -> Data) async throws -> Data {
    if let slot = slots[key] {
        switch slot {
        case .ready(let entry):
            if !entry.isExpired(now: Date()) { return entry.value }
        case .loading(let task):
            return try await task.value          // join the in-flight producer
        }
    }
    let task = Task { try await producer() }      // producer is @Sendable: safe to run anywhere
    slots[key] = .loading(task)                   // record BEFORE awaiting
    do {
        let data = try await task.value
        store(data, for: key)                     // re-enter on actor: safe
        return data
    } catch {
        slots[key] = nil                          // let the next caller retry
        throw StoreError.producerFailed(key: key)
    }
}
```

### Phase 3 — Replace the listener array with an `AsyncStream` change feed (Saturday, ~2.5h)

Delete `listeners: [(String) -> Void]`. A mutable array of escaping callbacks mutated from multiple threads is a triple offence and there is no honest `Sendable` story for it. Model change broadcast as an `AsyncStream<Change>`, exactly as in Lecture 2 §7: keep a `[UUID: AsyncStream<Change>.Continuation]` inside the actor, register on subscribe, unregister on termination, and `yield` from your isolated `set`/`remove`/expire paths. The `changes()` factory is `nonisolated` (it only constructs the stream; the registration hops onto the actor).

### Phase 4 — Flip to Swift 6 language mode and prove it (Saturday/Sunday, ~2h)

Replace each target's `swiftSettings` with `[.swiftLanguageMode(.v6)]`. Rebuild. If phases 1–3 were honest, you see:

```
Building for debugging...
Build complete! (Swift 6 language mode, 0 warnings)
```

Then write the demo and the tests (below), and the `MIGRATION.md`.

---

## The demo executable

`Sources/ActorKVDemo/main.swift` — exercises the store concurrently and prints a report:

```swift
import ActorKVCore
import Foundation

@main
struct Demo {
    static func main() async throws {
        let store = KeyValueStore(ttl: .seconds(60))

        // Subscribe to the change feed.
        let feed = Task {
            var seen = 0
            for await change in store.changes() {
                seen += 1
                if seen >= 100 { break }
            }
            return seen
        }

        // 100 concurrent writers.
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await store.set(Data("value-\(i)".utf8), for: "key-\(i)")
                }
            }
        }

        let count = await store.count
        print("wrote \(count) keys")

        // Prove getOrInsert runs the producer once under 50 concurrent callers.
        let producerCalls = ProducerCounter()
        try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try await store.getOrInsert("expensive") {
                        await producerCalls.bump()
                        try? await Task.sleep(for: .milliseconds(20))
                        return Data("computed".utf8)
                    }
                }
            }
            for try await _ in group {}
        }
        let calls = await producerCalls.value
        print("producer ran \(calls) time(s) for 50 concurrent getOrInsert calls (must be 1)")

        let observed = await feed.value
        print("change feed observed \(observed) change events")
    }
}

actor ProducerCounter {
    private(set) var value = 0
    func bump() { value += 1 }
}
```

Expected output:

```
wrote 100 keys
producer ran 1 time(s) for 50 concurrent getOrInsert calls (must be 1)
change feed observed 100 change events
```

---

## Tests

`Tests/ActorKVCoreTests/KeyValueStoreTests.swift` — Swift Testing:

```swift
import Testing
import Foundation
@testable import ActorKVCore

@Test func setThenValueRoundTrips() async {
    let store = KeyValueStore()
    await store.set(Data("hi".utf8), for: "greeting")
    let v = await store.value(for: "greeting")
    #expect(v == Data("hi".utf8))
}

@Test func concurrentWritesAllLand() async {
    let store = KeyValueStore()
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<1_000 {
            group.addTask { await store.set(Data("\(i)".utf8), for: "k\(i)") }
        }
    }
    let count = await store.count
    #expect(count == 1_000)          // deterministic: the actor serialises writes
}

@Test func getOrInsertRunsProducerExactlyOnce() async throws {
    let store = KeyValueStore()
    let counter = ProducerCounter()
    try await withThrowingTaskGroup(of: Data.self) { group in
        for _ in 0..<50 {
            group.addTask {
                try await store.getOrInsert("k") {
                    await counter.bump()
                    try? await Task.sleep(for: .milliseconds(10))
                    return Data("v".utf8)
                }
            }
        }
        for try await _ in group {}
    }
    let calls = await counter.value
    #expect(calls == 1)              // reentrancy guard: producer runs once
}

@Test func expiredValuesReadAsNil() async {
    let store = KeyValueStore(ttl: .milliseconds(20))
    await store.set(Data("temp".utf8), for: "k")
    try? await Task.sleep(for: .milliseconds(40))
    let v = await store.value(for: "k")
    #expect(v == nil)
}

actor ProducerCounter {
    private(set) var value = 0
    func bump() { value += 1 }
}
```

`concurrentWritesAllLand` is the test that would have failed non-deterministically against the starter class (`count` would sometimes be 994, sometimes 1000) and passes deterministically against the actor.

---

## Rules

- **You may** read the Swift migration guide, the language docs, lecture notes, your Week 4 exercises, Swift Evolution proposals, and Matt Massicotte's / Donny Wals' concurrency posts.
- **You may NOT** add any third-party dependency. Foundation + the standard library only. (`AsyncStream`, `Task`, `Duration`, `Data` are all you need.)
- **You may NOT** use `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, `NSLock`, `os_unfair_lock`, `Mutex`, or `DispatchQueue` anywhere in the final submission. The CI grep below enforces it. The whole point is to remove the need for them.
- Final target setting: `swiftLanguageMode(.v6)` on all three targets.

---

## Acceptance criteria

### Migration documentation (25%)

- [ ] `MIGRATION.md` documents **at least three distinct compile-time errors** the migration surfaced. For each: the exact diagnostic text, the line it pointed at, the underlying race, and the structural fix. (Candidate errors: `self` captured in a `@Sendable` `DispatchQueue` closure; the escaping non-`Sendable` completion handler; the mutable `listeners` array crossing a boundary; a `static`/global if you added one; the `producer` closure needing `@Sendable`.)
- [ ] `MIGRATION.md` explains, in one paragraph, why none of the three needed `@unchecked Sendable` — what structural change made each one honestly safe.

### Correctness (40%)

- [ ] `KeyValueStore` is an `actor` with the `async` surface specified above. No callbacks remain.
- [ ] `getOrInsert` is reentrancy-safe: 50 concurrent callers for the same key run the producer exactly once. The test proves it.
- [ ] TTL works: an expired value reads as `nil` and emits a `.expired` change (or is lazily dropped on read — your choice, documented).
- [ ] `changes()` returns an `AsyncStream<Change>` that emits `.set` / `.removed` / `.expired` events; multiple subscribers each get their own stream.
- [ ] `swift test` passes all tests, including the concurrent ones, on at least 5 consecutive runs.

### Strict-concurrency cleanliness (25%)

- [ ] `swift build` finishes with `Build complete!` and **zero warnings** under `.swiftLanguageMode(.v6)` on all three targets.
- [ ] `grep -rn "@unchecked Sendable\|nonisolated(unsafe)\|@preconcurrency\|NSLock\|os_unfair_lock\|Mutex\|DispatchQueue" Sources/` returns nothing.
- [ ] Every type that crosses an isolation boundary is honestly `Sendable` (value type, actor, or immutable `final class`).

### Demo (10%)

- [ ] `swift run ActorKVDemo` produces the expected output, including "producer ran 1 time(s)".

---

## Compounding note (read this)

This store is not throwaway. The actor-plus-`Sendable` discipline you build here is the **direct ancestor of the `NotesClient` actor you build in Week 13** (the offline-first networking layer that falls back to SwiftData and replays writes), and the **Keychain + CloudKit sync state in Week 14**. The `getOrInsert` reentrancy guard reappears verbatim as the request-coalescing layer in Week 13. The `AsyncStream` change feed is the pattern Week 12 generalises into debounced search. Keep this package; you will lift code out of it twice more before the capstone.

---

## Submission

Push the package to your Week 4 GitHub repository at `mini-project/ActorKV/`. The instructor reviews by:

1. Cloning the repo.
2. Running `grep -rn "@unchecked Sendable\|nonisolated(unsafe)\|@preconcurrency\|Mutex\|NSLock\|DispatchQueue" Sources/` — must return nothing.
3. Running `swift build` — must print `Build complete!` with zero warnings under `.v6`.
4. Running `swift test` five times — must pass every time (the concurrent tests are the point).
5. Running `swift run ActorKVDemo` — must show "producer ran 1 time(s)".
6. Reading `MIGRATION.md` for the three-plus documented diagnostics and the no-escape-hatch justification.

A submission that builds clean under `.v6` with no escape hatches, whose concurrent tests pass deterministically, and whose `MIGRATION.md` honestly documents three real races removed, is a pass. The most common review-fail is "compiles, but `getOrInsert` runs the producer 3 times under load" — the reentrancy guard is missing or guards the wrong side of the `await`. Verify with the demo before submitting.

---

## Stretch goals (no extra grade)

- **Generic over value type.** Make it `actor KeyValueStore<Value: Sendable>` instead of hard-coding `Data`. Watch the `Sendable` constraint propagate through the API; the change feed and `getOrInsert` stay clean.
- **Bounded capacity with LRU eviction.** Add a `maxCount`; evict the least-recently-used entry on overflow and emit a `.removed` change. The "recently used" bookkeeping is mutable state — confirm it stays inside the actor.
- **A custom global actor.** Define `@globalActor actor StorageActor` and isolate the store to it instead of making the store itself an actor. Then ask yourself, in a comment, when this is ever better than a plain `actor` (answer: when several independent types must share one serial domain).
- **Persist to disk.** Add `func persist(to url: URL) async throws` and `init(loadingFrom:)`. The file I/O is `async`; the encode/decode happens inside the actor over `Sendable` value types. No new escape hatch should be required.

The stretch goals are deliberately harder than the main project. Do not attempt them until the main acceptance criteria pass.

---

**References**

- Swift Migration Guide — Common compiler errors: <https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems>
- `AsyncStream` reference: <https://developer.apple.com/documentation/swift/asyncstream>
- SE-0306 — Actors: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md>
- SE-0302 — Sendable and @Sendable closures: <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md>
- Week 4, Lecture 1 §10 (reentrancy) and Lecture 2 §7 (`AsyncStream` migration).
