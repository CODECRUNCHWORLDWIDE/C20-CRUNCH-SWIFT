# Challenge 1 — Pluggable Eviction Policy via a Protocol

**Time estimate:** ~120 minutes.

## Problem statement

The mini-project's `Cache<Key, Value>` evicts on TTL: entries die when they age past their time-to-live. That is one policy. Real caches need to switch policy without rewriting the cache: an in-memory image cache wants **LRU** (evict the least-recently-used when over capacity); a token cache wants **TTL** (evict on age); a session cache might want both.

Your job is to make the eviction policy **pluggable behind a protocol**, so the policy can be swapped at construction time **without changing the cache's public generic API**, and to **prove the behaviour with property tests**. This is the canonical "strategy behind a protocol so the host code never changes" design — and it is exactly the protocol-oriented, generic-API skill the whole week builds toward.

You must:

1. Define an `EvictionPolicy` **protocol with an `associatedtype Key`**, with hooks the cache calls on every mutation:
   - `mutating func recordInsert(_ key: Key, at instant: Date)`
   - `mutating func recordAccess(_ key: Key, at instant: Date)`
   - `mutating func recordRemove(_ key: Key)`
   - `func keysToEvict(currentCount: Int, capacity: Int, now: Date) -> [Key]`
2. Provide **two** conforming policies:
   - `LRUPolicy<Key>` — when `currentCount > capacity`, evict the least-recently-*accessed* keys until back at capacity.
   - `TTLPolicy<Key>` — evict keys whose age (`now - insertedAt`) meets or exceeds `maxAge`, regardless of capacity.
3. Wire the policy into the cache as a **generic type parameter** (`Cache<Key, Value, Store, Policy>` with a `where Policy.Key == Key` constraint), so swapping the policy is a compile-time choice with **zero existential cost** and **no change to `set` / `value(for:)`'s signatures**.
4. Call the policy hooks from the cache at the right moments: `recordInsert` on `set`, `recordAccess` on a successful `value(for:)`, `recordRemove` on eviction, and run `keysToEvict` after every `set`, evicting the returned keys from the store.
5. Prove behaviour with **property tests** using Swift Testing's parameterized tests plus generated random inputs.

## Acceptance criteria

- [ ] A SwiftPM library package (extend your mini-project package or start `EvictingCache`).
- [ ] `swift build -Xswiftc -warnings-as-errors`: zero warnings, zero errors.
- [ ] `swift test`: **at least 12 passing tests**, including the property tests below.
- [ ] The cache's `set` and `value(for:)` signatures are **identical** to the TTL-only mini-project version. Swapping `LRUPolicy` for `TTLPolicy` is a change to the *construction site only* — grep the diff to prove it.
- [ ] **The policy is a generic type parameter, not `any EvictionPolicy`.** You must be able to explain in one sentence why the generic (zero-cost, type-preserved) is correct here and `any` would be wasteful.
- [ ] Property tests cover at least these invariants:
  - **Capacity invariant (LRU):** after any sequence of inserts, the cache never holds more than `capacity` live entries.
  - **Recency invariant (LRU):** the key accessed most recently before an over-capacity insert is never the one evicted.
  - **Age invariant (TTL):** no entry older than `maxAge` is ever returned by `value(for:)`.
  - **Round-trip invariant:** for any key set then immediately read (within TTL, under capacity), `value(for:)` returns exactly what was set.
- [ ] An **injectable clock** so tests are deterministic — no `Thread.sleep`, no wall-clock flakiness.
- [ ] A short `README.md` documenting the policy protocol, the two policies, and one paragraph: *"why a generic policy parameter and not `any EvictionPolicy`."*
- [ ] Committed to your Week 2 repo under `challenges/challenge-01/`.

## Hints

<details>
<summary>The policy protocol and the two conformers</summary>

```swift
import Foundation

public protocol EvictionPolicy {
    associatedtype Key: Hashable
    mutating func recordInsert(_ key: Key, at instant: Date)
    mutating func recordAccess(_ key: Key, at instant: Date)
    mutating func recordRemove(_ key: Key)
    func keysToEvict(currentCount: Int, capacity: Int, now: Date) -> [Key]
}

public struct LRUPolicy<Key: Hashable>: EvictionPolicy {
    private var lastAccess: [Key: Date] = [:]
    public init() {}
    public mutating func recordInsert(_ key: Key, at instant: Date) { lastAccess[key] = instant }
    public mutating func recordAccess(_ key: Key, at instant: Date) { lastAccess[key] = instant }
    public mutating func recordRemove(_ key: Key) { lastAccess[key] = nil }
    public func keysToEvict(currentCount: Int, capacity: Int, now: Date) -> [Key] {
        guard currentCount > capacity else { return [] }
        let overflow = currentCount - capacity
        return lastAccess.sorted { $0.value < $1.value }.prefix(overflow).map(\.key)
    }
}

public struct TTLPolicy<Key: Hashable>: EvictionPolicy {
    public let maxAge: TimeInterval
    private var insertedAt: [Key: Date] = [:]
    public init(maxAge: TimeInterval) { self.maxAge = maxAge }
    public mutating func recordInsert(_ key: Key, at instant: Date) { insertedAt[key] = instant }
    public mutating func recordAccess(_ key: Key, at instant: Date) {}
    public mutating func recordRemove(_ key: Key) { insertedAt[key] = nil }
    public func keysToEvict(currentCount: Int, capacity: Int, now: Date) -> [Key] {
        insertedAt.filter { now.timeIntervalSince($0.value) >= maxAge }.map(\.key)
    }
}
```

</details>

<details>
<summary>Wiring the policy into the cache as a generic parameter</summary>

```swift
public final class EvictingCache<Key, Value, Store, Policy>
where Store: CacheStore, Policy: EvictionPolicy,
      Store.Key == Key, Store.Value == Value, Policy.Key == Key {

    private let store: Store
    private var policy: Policy
    private let capacity: Int
    private let clock: Clock

    public init(store: Store, policy: Policy, capacity: Int, clock: Clock = .system) {
        self.store = store
        self.policy = policy
        self.capacity = capacity
        self.clock = clock
    }

    public func set(_ value: Value, for key: Key) throws {
        let entry = Entry(value: value, storedAt: clock.now(), ttl: .greatestFiniteMagnitude)
        try store.write(entry, for: key)
        policy.recordInsert(key, at: clock.now())

        let count = try store.allKeys().count
        for victim in policy.keysToEvict(currentCount: count, capacity: capacity, now: clock.now()) {
            try store.remove(victim)
            policy.recordRemove(victim)
        }
    }

    public func value(for key: Key) throws -> Value {
        guard let entry = try store.read(key) else { throw CacheError.keyNotFound }
        policy.recordAccess(key, at: clock.now())
        return entry.value
    }
}
```

The key move: `Policy` is a **type parameter** with a `where Policy.Key == Key` constraint. `EvictingCache(..., policy: LRUPolicy())` and `EvictingCache(..., policy: TTLPolicy(maxAge: 60))` differ **only at the call site** — the cache body is policy-agnostic, fully specialised, and pays no existential box.

</details>

<details>
<summary>Why a generic policy parameter and not `any EvictionPolicy`?</summary>

`EvictionPolicy` has an `associatedtype Key`, so it is a PAT — `any EvictionPolicy` would require pinning the key (`any EvictionPolicy<Key>`) and would still box the policy and dispatch every hook dynamically, on the hot path of every `set`. The policy is chosen **once, at construction**, and never varies for the life of the cache — there is no run-time heterogeneity to justify the box. A generic parameter preserves the concrete policy type, inlines the hooks, and is the textbook `some`-over-`any` call from Lecture 2's matrix. (You could alternatively expose `some EvictionPolicy<Key>` at the init boundary; the generic parameter is the cleaner expression for a stored strategy.)

</details>

<details>
<summary>Property tests with Swift Testing</summary>

```swift
import Testing
import Foundation
@testable import EvictingCache

@Suite("LRU eviction properties")
struct LRUProperties {

    // Capacity invariant: never exceed capacity, for many random insert sequences.
    @Test("never exceeds capacity", arguments: 0..<200)
    func capacityInvariant(seed: Int) throws {
        var rng = SeededGenerator(seed: UInt64(seed))
        let capacity = Int.random(in: 1...8, using: &rng)
        var t = Date(timeIntervalSince1970: 0)
        let clock = Clock(now: { t })
        let cache = EvictingCache(
            store: InMemoryStore<Int, Int>(),
            policy: LRUPolicy<Int>(),
            capacity: capacity,
            clock: clock
        )
        for _ in 0..<50 {
            t = t.addingTimeInterval(1)
            try cache.set(Int.random(in: 0...3, using: &rng), for: Int.random(in: 0...20, using: &rng))
            #expect(try cache.store.allKeys().count <= capacity)
        }
    }

    // Recency invariant: the most-recently-accessed key survives an over-capacity insert.
    @Test("most-recently-accessed key is not evicted")
    func recencyInvariant() throws {
        var t = Date(timeIntervalSince1970: 0)
        let clock = Clock(now: { t })
        let cache = EvictingCache(store: InMemoryStore<String, Int>(),
                                  policy: LRUPolicy<String>(),
                                  capacity: 2, clock: clock)
        t = t.addingTimeInterval(1); try cache.set(1, for: "a")
        t = t.addingTimeInterval(1); try cache.set(2, for: "b")
        t = t.addingTimeInterval(1); _ = try cache.value(for: "a")   // touch a — now most recent
        t = t.addingTimeInterval(1); try cache.set(3, for: "c")      // forces eviction of b
        #expect((try? cache.value(for: "a")) == 1)                   // a survived
        #expect((try? cache.value(for: "b")) == nil)                 // b evicted
    }
}
```

Expose a `var store: Store` (or a `liveKeyCount` helper) so tests can assert the invariant. A small `SeededGenerator: RandomNumberGenerator` makes the property tests reproducible — write one (about ten lines) so a failing seed is debuggable.

</details>

## Stretch

- Add a third policy `LFUPolicy<Key>` (least-frequently-used): track a hit count per key and evict the lowest. Confirm it drops in with no cache changes.
- Make the cache hold **`any EvictionPolicy<Key>`** in an alternate initializer so the policy can be chosen from a config string at run time. Benchmark the `any` version against the generic version with a tight `set` loop and report the difference — this is the cost from Lecture 2 made measurable.
- Combine policies: a `CompositePolicy<A, B>` that runs TTL first then LRU. Decide whether it is a generic-over-two-policies type or an `any`-array; defend the choice in your README.
- Use `OrderedDictionary` from `swift-collections` to make LRU O(1) instead of the O(n log n) sort in the hint. Add a benchmark.

## Submission

Commit under `challenges/challenge-01/` in your Week 2 GitHub repo. Make sure `swift build -Xswiftc -warnings-as-errors` and `swift test` both pass on a fresh clone. Include the one-paragraph "why generic, not `any`" justification in the README — the *reasoning* is what is being graded as much as the code.

## Why this matters

"Swap the strategy without touching the host" is one of the highest-leverage designs in production Swift, and the protocol-plus-generic-parameter form (rather than the `any` form most engineers reach for first) is the version that costs nothing at run time. You will reuse the exact shape for:

- **Retry policies** in the networking layer (Week 13) — exponential vs fixed vs jittered, behind one protocol.
- **Conflict-resolution policies** for CloudKit sync (Week 14) — last-writer-wins vs merge, swapped without touching the sync engine.
- **Dependency injection** (Week 11) — every dependency is a protocol witness chosen at composition time.

Internalise "policy behind a protocol, injected as a generic parameter" now, and three later weeks will feel like review.
