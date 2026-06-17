# Mini-Project — A Generic `Cache<Key, Value>` with TTL Eviction and a Pluggable Store

> Build a generic, protocol-backed cache: `Cache<Key: Hashable, Value>` with time-to-live eviction, an in-memory backing store, and a disk-backed alternative — both hidden behind a single `CacheStore` protocol. Ship it with **property tests**, using only the Swift standard library and Foundation. No Vapor. No SwiftUI. Just Swift 6 on the open-source toolchain.

This is the project that makes the whole week land at once. You will design a generic type, a protocol with an associated type, a custom error enum, and you will make a deliberate `some`/`any`/generic decision at every API boundary and write down *why*. The output is a small SwiftPM library you could drop into a real app — and which you literally will, in spirit, when you build the offline-first sync layer in Phase III.

**Estimated time:** ~11 hours (split across Thursday, Friday, Saturday in the suggested schedule).

---

## What you will build

A SwiftPM library package `CacheKit` exposing:

```swift
// The generic cache. Key is Hashable; Value is Codable (so the disk store can serialise it).
let memCache = Cache(store: InMemoryStore<String, [String]>(), defaultTTL: 60)
try memCache.set(["swift", "generics"], for: "post-42")
let tags = try memCache.value(for: "post-42")        // ["swift", "generics"]
let maybe = memCache.valueIfPresent(for: "missing")  // nil — no throw

// Same cache type, different store, identical API.
let diskCache = Cache(store: try DiskStore<String, [String]>(directory: cacheDir), defaultTTL: 3600)
try diskCache.set(["persisted"], for: "post-7")
// Relaunch the process: the value is still there (until its TTL elapses).
```

The cache is **generic over its key and value**, the store is **a protocol with associated types**, the two stores are **interchangeable without changing the cache**, and every failure flows through **one custom error enum**.

By the end you will have a public GitHub repo of ~250–350 lines of Swift (excluding tests) that round-trips through memory and disk, expires entries on TTL deterministically, and is proven correct by property tests rather than a handful of hand-picked examples.

---

## Rules

- **You may** read the Swift book, the standard-library docs, the lecture notes, and the source of the standard library and `swift-collections`.
- **You may NOT** depend on any third-party package except, optionally, `apple/swift-collections` (allowed — it ships from Apple) for `OrderedDictionary` in the stretch.
- No third-party caching library. No `NSCache` wrapper (the point is to build it). Write the TTL and the disk serialisation yourself.
- Build with **warnings treated as errors**: every `swift build` must pass `swift build -Xswiftc -warnings-as-errors`. A warning is a bug this week.
- Swift tools version `6.0`+. Swift language mode `6`. The package must compile on **Linux** (CI uses the `swift:6.0` Docker image) — so no Apple-only APIs.
- **Zero `try!`** in the source except, if you must, over a value you literally created as a literal in the same scope (and comment why). **Zero force-unwraps (`!`)** on optionals you did not just create.

---

## Acceptance criteria

- [ ] A new public GitHub repo named `c20-week-02-cachekit-<yourhandle>`.
- [ ] Package layout matches the C20 standard:
  ```
  CacheKit/
  ├── Package.swift
  ├── .gitignore
  ├── README.md
  ├── Sources/
  │   └── CacheKit/
  │       ├── CacheError.swift      (the custom error enum)
  │       ├── Clock.swift           (injectable time source)
  │       ├── Entry.swift           (the stored value + timestamp + ttl)
  │       ├── CacheStore.swift      (the protocol with associated types)
  │       ├── InMemoryStore.swift   (one conformer)
  │       ├── DiskStore.swift       (the other conformer)
  │       └── Cache.swift           (the generic cache over a CacheStore)
  └── Tests/
      └── CacheKitTests/
          ├── CacheTests.swift
          ├── InMemoryStoreTests.swift
          ├── DiskStoreTests.swift
          └── CacheProperties.swift  (the property tests)
  ```
- [ ] `swift build -Xswiftc -warnings-as-errors`: zero warnings, zero errors.
- [ ] `swift test`: **at least 20 passing tests** across the four test files, including the property tests.
- [ ] `Cache` is **generic over `Key` and `Value`** and stores its data through a `CacheStore` whose `Key`/`Value` are constrained to match (`where Store.Key == Key, Store.Value == Value`).
- [ ] `CacheStore` is a **protocol with `associatedtype Key: Hashable` and `associatedtype Value`**, and there are **two** conformers (`InMemoryStore`, `DiskStore`) with no shared base class.
- [ ] TTL eviction is **deterministic** under an **injectable `Clock`** — no `Thread.sleep`, no wall-clock flakiness in tests.
- [ ] Every failure path throws a `CacheError` case (or returns it inside a `Result` where the API exposes one). No stringly-typed `NSError`, no `fatalError` on a recoverable path.
- [ ] The `DiskStore` survives a process relaunch: a value written, then read back by a fresh `DiskStore` over the same directory, is identical (within TTL).
- [ ] Your `README.md` includes:
  - One paragraph describing the project.
  - The exact commands to build and test from a fresh clone.
  - A **"`some` / `any` / generic decision log"** — for at least four API boundaries, one line each on which you chose and why. This is graded.
  - A "Things I learned" section with at least three specific items.

---

## Suggested order of operations

Build incrementally. Each phase ends with a green `swift test`.

### Phase 1 — Package skeleton (~1h)

```bash
mkdir CacheKit && cd CacheKit
swift package init --type library --name CacheKit
git init
```

Open `Package.swift`, confirm `// swift-tools-version: 6.0` (bump if lower), and set the Swift language mode and warnings-as-errors for the target:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CacheKit",
    targets: [
        .target(
            name: "CacheKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CacheKitTests",
            dependencies: ["CacheKit"]
        ),
    ]
)
```

First commit: `Package skeleton`.

### Phase 2 — Error enum, Clock, and Entry (~1h)

`Sources/CacheKit/CacheError.swift`:

```swift
public enum CacheError: Error, Equatable {
    case keyNotFound
    case expired
    case storeUnavailable(reason: String)
    case serializationFailed
}
```

`Sources/CacheKit/Clock.swift` — an injectable time source so tests never touch the wall clock:

```swift
import Foundation

public struct Clock: Sendable {
    public var now: @Sendable () -> Date
    public init(now: @escaping @Sendable () -> Date) { self.now = now }
    public static let system = Clock(now: { Date() })
}
```

`Sources/CacheKit/Entry.swift` — what actually gets stored: the value, when it was stored, and its TTL. `Codable` so the disk store can serialise it:

```swift
import Foundation

public struct Entry<Value: Codable & Sendable>: Codable, Sendable {
    public let value: Value
    public let storedAt: Date
    public let ttl: TimeInterval

    public func isExpired(at instant: Date) -> Bool {
        instant.timeIntervalSince(storedAt) >= ttl
    }
}
```

Commit: `Error, Clock, Entry`.

### Phase 3 — The `CacheStore` protocol (~1h)

`Sources/CacheKit/CacheStore.swift` — the associated-type protocol that both stores satisfy. This is the heart of the design:

```swift
public protocol CacheStore {
    associatedtype Key: Hashable
    associatedtype Value: Codable & Sendable

    func read(_ key: Key) throws -> Entry<Value>?
    func write(_ entry: Entry<Value>, for key: Key) throws
    func remove(_ key: Key) throws
    func allKeys() throws -> [Key]
    func clear() throws
}
```

Note the store methods `throws` — disk operations fail, and the protocol is honest about it. The in-memory store will never actually throw, but it conforms to the same throwing signature so the cache code is identical regardless of backing store.

Commit: `CacheStore protocol`.

### Phase 4 — `InMemoryStore` (~1h)

`Sources/CacheKit/InMemoryStore.swift`:

```swift
public final class InMemoryStore<Key: Hashable, Value: Codable & Sendable>: CacheStore {
    private var storage: [Key: Entry<Value>] = [:]

    public init() {}

    public func read(_ key: Key) throws -> Entry<Value>? { storage[key] }
    public func write(_ entry: Entry<Value>, for key: Key) throws { storage[key] = entry }
    public func remove(_ key: Key) throws { storage[key] = nil }
    public func allKeys() throws -> [Key] { Array(storage.keys) }
    public func clear() throws { storage.removeAll() }
}
```

Write `InMemoryStoreTests.swift`: round-trip write/read, overwrite, remove, `allKeys`, `clear`. Commit: `InMemoryStore + tests`.

### Phase 5 — `DiskStore` (~2h)

`Sources/CacheKit/DiskStore.swift`. The disk store names one JSON file per key, so its `Key` must be expressible as a filename — constrain it to `LosslessStringConvertible`:

```swift
import Foundation

public final class DiskStore<Key, Value>: CacheStore
where Key: Hashable & LosslessStringConvertible, Value: Codable & Sendable {

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) throws {
        self.directory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CacheError.storeUnavailable(reason: "cannot create \(directory.path): \(error)")
        }
    }

    private func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(key).json")
    }

    public func read(_ key: Key) throws -> Entry<Value>? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Entry<Value>.self, from: data)
        } catch {
            throw CacheError.serializationFailed
        }
    }

    public func write(_ entry: Entry<Value>, for key: Key) throws {
        do {
            let data = try encoder.encode(entry)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            throw CacheError.serializationFailed
        }
    }

    public func remove(_ key: Key) throws {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func allKeys() throws -> [Key] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            return Key(url.deletingPathExtension().lastPathComponent)
        }
    }

    public func clear() throws {
        for key in try allKeys() { try remove(key) }
    }
}
```

Note `options: .atomic` on `write` — a crash mid-write must never leave a half-written cache file. That is the kind of detail that separates a toy from something you would actually ship.

Write `DiskStoreTests.swift`: write a value to a temp directory, read it back through a **second** `DiskStore` instance over the same directory (this proves persistence survives "relaunch"), test `allKeys` round-trips, and test that a corrupt file throws `.serializationFailed`. Commit: `DiskStore + tests`.

### Phase 6 — The generic `Cache` (~2h)

`Sources/CacheKit/Cache.swift` — generic over `Key`, `Value`, and the concrete `Store`, with the store's associated types pinned to match:

```swift
import Foundation

public final class Cache<Key, Value, Store>
where Key: Hashable, Value: Codable & Sendable, Store: CacheStore,
      Store.Key == Key, Store.Value == Value {

    private let store: Store
    private let defaultTTL: TimeInterval
    private let clock: Clock

    public init(store: Store, defaultTTL: TimeInterval, clock: Clock = .system) {
        self.store = store
        self.defaultTTL = defaultTTL
        self.clock = clock
    }

    /// Store a value with an optional per-key TTL override.
    public func set(_ value: Value, for key: Key, ttl: TimeInterval? = nil) throws {
        let entry = Entry(value: value, storedAt: clock.now(), ttl: ttl ?? defaultTTL)
        try store.write(entry, for: key)
    }

    /// Read a value, throwing `.keyNotFound` if absent and lazily evicting if expired.
    public func value(for key: Key) throws -> Value {
        guard let entry = try store.read(key) else { throw CacheError.keyNotFound }
        if entry.isExpired(at: clock.now()) {
            try store.remove(key)               // lazy eviction on read
            throw CacheError.expired
        }
        return entry.value
    }

    /// Read a value, returning nil for any failure (miss, expiry, store error).
    public func valueIfPresent(for key: Key) -> Value? {
        try? value(for: key)
    }

    /// Read a value as a Result, mapping any thrown error to CacheError.
    public func result(for key: Key) -> Result<Value, CacheError> {
        Result { try value(for: key) }
            .mapError { ($0 as? CacheError) ?? .storeUnavailable(reason: "\($0)") }
    }

    public func remove(_ key: Key) throws { try store.remove(key) }
    public func clear() throws { try store.clear() }
}
```

Notice the deliberate API choices you must justify in your README:

- `Store` is a **generic type parameter**, not `any CacheStore`. Why? The store is fixed at construction; there is no run-time heterogeneity; the generic preserves the concrete type and pays no existential box. (Lecture 2's matrix, row 5 inverted: you do *not* need run-time choice.)
- `value(for:)` `throws`; `valueIfPresent(for:)` returns `Value?` via `try?`; `result(for:)` returns a `Result`. Three flavours of the same read, each for a different caller need — this is exactly the `throws` / `try?` / `Result` triad from Lecture 2.
- Expiry is **lazy** (checked on read), not swept on a timer — simpler, deterministic, and good enough for a cache. Note this trade-off in your README.

Write `CacheTests.swift`: set then get; get a missing key throws `.keyNotFound`; an entry past its TTL throws `.expired` (advance the injected clock, do not sleep); `valueIfPresent` returns nil instead of throwing; `result(for:)` returns `.failure(.keyNotFound)`; per-key TTL override beats the default. Commit: `Generic Cache + tests`.

### Phase 7 — Property tests (~1.5h)

`Tests/CacheKitTests/CacheProperties.swift`. Hand-picked examples test the cases you thought of; property tests test the cases you didn't. Use Swift Testing's parameterized `@Test(arguments:)` plus a seeded RNG. Assert invariants that must hold for *any* input:

```swift
import Testing
import Foundation
@testable import CacheKit

@Suite("Cache properties")
struct CacheProperties {

    // Round-trip: anything set (within TTL) reads back identical, for many random keys/values.
    @Test("set-then-get round-trips", arguments: 0..<100)
    func roundTrip(seed: Int) throws {
        var rng = SeededGenerator(seed: UInt64(seed))
        let clock = Clock(now: { Date(timeIntervalSince1970: 1000) })
        let cache = Cache(store: InMemoryStore<Int, Int>(), defaultTTL: 60, clock: clock)
        let key = Int.random(in: 0...1000, using: &rng)
        let value = Int.random(in: .min ... .max, using: &rng)
        try cache.set(value, for: key)
        #expect(try cache.value(for: key) == value)
    }

    // Age invariant: no entry older than its TTL is ever returned.
    @Test("expired entries are never returned", arguments: 0..<100)
    func expiryInvariant(seed: Int) throws {
        var rng = SeededGenerator(seed: UInt64(seed))
        var t = Date(timeIntervalSince1970: 0)
        let clock = Clock(now: { t })
        let ttl = TimeInterval(Int.random(in: 1...100, using: &rng))
        let cache = Cache(store: InMemoryStore<Int, Int>(), defaultTTL: ttl, clock: clock)
        try cache.set(7, for: 1)
        t = t.addingTimeInterval(ttl + Double.random(in: 0...100, using: &rng)) // jump past TTL
        #expect(cache.valueIfPresent(for: 1) == nil)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

Add at least one more property: "two different keys never collide" and "removing a key then reading it always throws `.keyNotFound`." Commit: `Property tests`.

### Phase 8 — Polish (~0.5h)

- Run `swift build -Xswiftc -warnings-as-errors` and fix every warning.
- Write the README, including the `some`/`any`/generic decision log (graded).
- Add a one-line CI: `.github/workflows/ci.yml` running `swift test` on the `swift:6.0` Linux image on every push. (Optional this week; required from Week 4.)
- Push to GitHub.

---

## Example behaviour

A short script you can drop inside a function (or a test) to smoke-test. Note: under Swift 6 strict concurrency the injected `Clock` closure is `@Sendable`, so it cannot capture a top-level mutable `var` directly — keep the mutable time inside a small reference box or a local function (the test files do exactly this). The snippet below is written as a top-level demo for clarity; wrap it in `func demo() throws { ... }` and store `fakeNow` in a `final class Box: @unchecked Sendable { var t = ... }` if you run it under `-swift-version 6`:

```swift
import CacheKit
import Foundation

var fakeNow = Date(timeIntervalSince1970: 0)
let clock = Clock(now: { fakeNow })

let cache = Cache(store: InMemoryStore<String, String>(), defaultTTL: 10, clock: clock)
try cache.set("hello", for: "greeting")
print(try cache.value(for: "greeting"))      // hello

fakeNow = fakeNow.addingTimeInterval(5)
print(cache.valueIfPresent(for: "greeting") ?? "gone")  // hello  (5s < 10s TTL)

fakeNow = fakeNow.addingTimeInterval(10)
print(cache.valueIfPresent(for: "greeting") ?? "gone")  // gone   (15s >= 10s TTL)

switch cache.result(for: "greeting") {
case .success(let v): print("got \(v)")
case .failure(let e): print("error: \(e)")                // error: expired (or keyNotFound after eviction)
}
```

---

## Rubric

| Criterion | Weight | What "great" looks like |
|----------|-------:|-------------------------|
| Builds and tests | 25% | `swift build -Xswiftc -warnings-as-errors` and `swift test` both clean on a fresh clone (Linux included) |
| Generic + protocol design | 20% | `Cache` is generic; `CacheStore` is an associated-type protocol; two conformers, no base class |
| `some`/`any`/generic decisions | 15% | The README decision log is correct and the code matches it; no gratuitous `any` |
| Error handling | 15% | One `CacheError` enum; `throws` / `try?` / `Result` triad used appropriately; no `try!`, no force-unwraps |
| Property tests | 15% | At least four invariants tested over generated input with a seeded RNG; deterministic via injected `Clock` |
| Persistence + README | 10% | DiskStore survives "relaunch"; README lets a stranger build and run in under five minutes |

---

## Stretch (optional)

- Add `OrderedDictionary` from `swift-collections` and a capacity bound to `InMemoryStore`, evicting in insertion order when full. (This is the on-ramp to the challenge's LRU policy.)
- Make `Cache` an `actor` instead of a `final class` so concurrent `set`/`value` calls are safe. (You will *have* to do this in Week 4 under strict concurrency — try it now and note what the compiler complains about.)
- Add a `subscript(_ key: Key) -> Value?` to `Cache` that proxies `valueIfPresent`, so callers can write `cache["greeting"]`.
- Add a `peek(_ key:) -> Entry<Value>?` that returns the raw entry (including `storedAt` and `ttl`) without triggering lazy eviction — useful for diagnostics. Decide whether it should be in the public API and defend it.
- Write a `BenchmarkStore` decorator (a `CacheStore` that wraps another store and counts reads/writes) to prove your cache calls the store the number of times you expect. This previews the decorator-via-protocol pattern.

---

## What this prepares you for

- **Week 3 (async/await)** makes the store `async`: `func read(_:) async throws -> Entry<Value>?`. The disk I/O you wrote synchronously becomes a cancellable async call.
- **Week 4 (actors, strict concurrency)** turns `Cache` into an `actor` so concurrent access is data-race-free — the compiler will *require* it under Swift 6 strict concurrency.
- **The challenge** grafts a pluggable `EvictionPolicy` (LRU vs TTL) onto this exact cache, behind a protocol, with property tests — proving you can change the policy without touching the cache.
- **Phase III (offline-first sync, Week 13)** reuses this shape: a protocol-backed store with a memory and a disk implementation, swapped at run time when the network drops.

---

## Submission

When done:

1. Push your repo to GitHub with a public URL.
2. Make sure `README.md` includes the build/test commands and the `some`/`any`/generic decision log.
3. Make sure `swift build -Xswiftc -warnings-as-errors` and `swift test` are green on a freshly cloned copy.
4. Post the repo URL in your cohort tracker. You did real work; show it.
