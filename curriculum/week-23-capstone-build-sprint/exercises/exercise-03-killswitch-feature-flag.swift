// Exercise 3 — The feature-flag killswitch the runbook depends on
//
// Goal: Build the remote killswitch from Lecture 2, §2.3 — a flag store that
//       (1) fetches flags from your Vapor backend, (2) CACHES the last-known
//       values so the app works offline, and (3) falls back to a hard-coded
//       SAFE DEFAULT when there is neither a cached value nor a fresh fetch.
//       With this in place you can disable a broken feature in production
//       WITHOUT an App Store resubmission — the difference between a 20-minute
//       mitigation and a multi-day "1.0.1" review cycle.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite. Drop it into a test target. The "network" is
// behind a protocol so the tests inject a fake transport — no real HTTP, no
// flakiness, runs in milliseconds. The store is an `actor` so concurrent reads
// during a refresh are data-race-free under Swift 6 strict concurrency.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U (or `swift test`).
//   3. Read the assertions: a fresh fetch updates the flag; an offline fetch
//      keeps the cached value; with no cache and no network, the SAFE DEFAULT
//      wins; and a kill (flag=false from the server) disables the feature.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] All tests pass.
//   [ ] The store is an `actor`; the transport is a protocol; tests inject a fake.
//   [ ] Offline behaviour is correct: cached value survives a failed fetch.
//   [ ] The safe default is used only when there is NO cache and NO fresh fetch.
//   [ ] You can explain why "fail safe" means defaulting a risky feature to OFF.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The flags. A Sendable value type the backend serialises as JSON. Each flag
// has a SAFE DEFAULT that is used when we have no better information — and the
// safe default for a risky feature is OFF, so a backend outage never turns a
// half-baked feature ON.
// ----------------------------------------------------------------------------

struct FeatureFlags: Codable, Equatable, Sendable {
    var sharedNoteLiveActivity: Bool
    var cloudKitSync: Bool
    var experimentalFieldMerge: Bool

    /// The values the app ships with and falls back to when it has nothing else.
    /// Risky/new features default OFF; load-bearing stable features default ON.
    static let safeDefault = FeatureFlags(
        sharedNoteLiveActivity: true,   // shipped & stable -> on
        cloudKitSync: true,             // load-bearing -> on
        experimentalFieldMerge: false   // new & risky -> OFF by default
    )
}

// ----------------------------------------------------------------------------
// The transport. A protocol so the store doesn't know about URLSession and the
// tests can inject a fake. `Sendable` because the actor stores it.
// ----------------------------------------------------------------------------

protocol FlagTransport: Sendable {
    /// Fetch the current flags from the backend, or throw if unreachable.
    func fetchFlags() async throws -> FeatureFlags
}

/// The real transport (sketch — your capstone wires this to the Vapor /flags
/// endpoint via the NotesClient). Shown for completeness; the tests use the fake.
struct HTTPFlagTransport: FlagTransport {
    let url: URL
    let session: URLSession
    func fetchFlags() async throws -> FeatureFlags {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FlagError.badResponse
        }
        return try JSONDecoder().decode(FeatureFlags.self, from: data)
    }
}

enum FlagError: Error { case badResponse, offline }

// ----------------------------------------------------------------------------
// The cache. A protocol over "persist the last-known flags" so the store can
// use UserDefaults in production and an in-memory fake in tests.
// ----------------------------------------------------------------------------

protocol FlagCache: Sendable {
    func load() -> FeatureFlags?
    func save(_ flags: FeatureFlags)
}

// ----------------------------------------------------------------------------
// The store. An actor: it owns the cached flags and serialises refresh vs read.
//
// Resolution order on read:
//   1. The freshest in-memory value (last successful fetch this session), else
//   2. the persisted cache (last successful fetch any session), else
//   3. the hard-coded safe default.
// A failed fetch NEVER downgrades a good value — it just leaves the last-known
// in place. That is the offline contract.
// ----------------------------------------------------------------------------

actor FeatureFlagStore {
    private let transport: FlagTransport
    private let cache: FlagCache
    private var current: FeatureFlags?      // freshest value this session

    init(transport: FlagTransport, cache: FlagCache) {
        self.transport = transport
        self.cache = cache
        // Warm from the persisted cache so even the very first read offline is
        // the last-known value, not the safe default.
        self.current = cache.load()
    }

    /// The value the app reads. Always returns *something* — never throws.
    var flags: FeatureFlags {
        current ?? cache.load() ?? .safeDefault
    }

    /// Convenience accessors the call sites use at feature gates.
    func isEnabled(_ keyPath: KeyPath<FeatureFlags, Bool>) -> Bool {
        flags[keyPath: keyPath]
    }

    /// Refresh from the backend. On success, updates in-memory AND persists.
    /// On failure, leaves the last-known value untouched (offline-safe).
    /// Returns true if the fetch succeeded.
    @discardableResult
    func refresh() async -> Bool {
        do {
            let fetched = try await transport.fetchFlags()
            current = fetched
            cache.save(fetched)
            return true
        } catch {
            // Intentionally swallow: a failed refresh must not break the app or
            // change behaviour. Log it in production for the runbook.
            return false
        }
    }
}

// ----------------------------------------------------------------------------
// Test doubles
// ----------------------------------------------------------------------------

/// A transport whose result the test controls. `@unchecked Sendable` is honest
/// here: it's a test-only mutable box guarded by serial test execution. In
/// production code you would not reach for this — but a controllable fake is
/// exactly when a documented @unchecked is acceptable.
final class FakeTransport: FlagTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _result: Result<FeatureFlags, Error>
    init(_ result: Result<FeatureFlags, Error>) { _result = result }
    func set(_ result: Result<FeatureFlags, Error>) {
        lock.withLock { _result = result }
    }
    func fetchFlags() async throws -> FeatureFlags {
        try lock.withLock { try _result.get() }
    }
}

final class InMemoryCache: FlagCache, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: FeatureFlags?
    init(seed: FeatureFlags? = nil) { stored = seed }
    func load() -> FeatureFlags? { lock.withLock { stored } }
    func save(_ flags: FeatureFlags) { lock.withLock { stored = flags } }
}

// ----------------------------------------------------------------------------
// The test suite
// ----------------------------------------------------------------------------

@Suite("The killswitch fetches, caches, and fails safe")
struct FeatureFlagStoreTests {

    @Test("Cold start with no cache and no network uses the safe default")
    func coldStartFallsBackToSafeDefault() async {
        let transport = FakeTransport(.failure(FlagError.offline))
        let store = FeatureFlagStore(transport: transport, cache: InMemoryCache())

        // No cache, fetch fails -> safe default. The risky feature is OFF.
        let ok = await store.refresh()
        #expect(ok == false)
        #expect(await store.flags == .safeDefault)
        #expect(await store.isEnabled(\.experimentalFieldMerge) == false)
    }

    @Test("A successful fetch updates the flags and persists them")
    func successfulFetchUpdatesAndPersists() async {
        let server = FeatureFlags(sharedNoteLiveActivity: false, // server KILLS this feature
                                  cloudKitSync: true,
                                  experimentalFieldMerge: true)
        let transport = FakeTransport(.success(server))
        let cache = InMemoryCache()
        let store = FeatureFlagStore(transport: transport, cache: cache)

        #expect(await store.refresh() == true)
        #expect(await store.isEnabled(\.sharedNoteLiveActivity) == false) // killed
        // And it was persisted, so a future cold start reads it offline.
        #expect(cache.load() == server)
    }

    @Test("THE KILLSWITCH: server flag=false disables a feature live")
    func killswitchDisablesFeature() async {
        // App starts with the feature ON (safe default / prior cache)...
        let cache = InMemoryCache(seed: .safeDefault)
        // ...then the backend ships a kill: sharedNoteLiveActivity = false.
        let kill = FeatureFlags(sharedNoteLiveActivity: false, cloudKitSync: true, experimentalFieldMerge: false)
        let transport = FakeTransport(.success(kill))
        let store = FeatureFlagStore(transport: transport, cache: cache)

        #expect(await store.isEnabled(\.sharedNoteLiveActivity) == true)  // before refresh
        await store.refresh()
        #expect(await store.isEnabled(\.sharedNoteLiveActivity) == false) // after the kill
    }

    @Test("Offline after a good fetch keeps the cached value, not the default")
    func offlineKeepsLastKnown() async {
        let good = FeatureFlags(sharedNoteLiveActivity: true, cloudKitSync: true, experimentalFieldMerge: true)
        let transport = FakeTransport(.success(good))
        let cache = InMemoryCache()
        let store = FeatureFlagStore(transport: transport, cache: cache)

        #expect(await store.refresh() == true)        // first fetch succeeds
        transport.set(.failure(FlagError.offline))    // now we go offline
        #expect(await store.refresh() == false)       // refresh fails...
        // ...but the flags are still the last-known GOOD value, NOT the safe default.
        #expect(await store.flags == good)
        #expect(await store.isEnabled(\.experimentalFieldMerge) == true)
    }

    @Test("A persisted cache survives a fresh store (simulated relaunch)")
    func persistedCacheSurvivesRelaunch() async {
        let saved = FeatureFlags(sharedNoteLiveActivity: false, cloudKitSync: true, experimentalFieldMerge: false)
        let cache = InMemoryCache(seed: saved)
        // A brand-new store with no network at all reads the persisted value.
        let store = FeatureFlagStore(transport: FakeTransport(.failure(FlagError.offline)), cache: cache)
        #expect(await store.flags == saved)
    }
}

// ----------------------------------------------------------------------------
// WHY "fail safe" means defaulting risky features OFF (write it before reading):
//
//   The killswitch's whole job is to make a backend OUTAGE harmless. If the
//   safe default turned a new, under-tested feature ON, then a backend failure
//   (or a brand-new install that can't reach the backend) would expose users to
//   the very feature you might need to kill. So: stable, load-bearing features
//   default ON (the app must work offline); new, risky features default OFF
//   (a failure to reach the backend can only make the app MORE conservative,
//   never less). The server can turn a risky feature ON deliberately; it can
//   never be turned on by an outage.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The offline test is the contract. The mistake is to clear `current` on a
//   failed fetch. DON'T. A failed refresh must be a NO-OP on the stored value —
//   that's how the app keeps working through a backend blip.
//
// - `flags` must never throw and never block on the network. It reads only
//   in-memory state (current -> cache -> default). The network only ever runs
//   in `refresh()`, which you call on launch and on a timer, not on every read.
//
// - Under strict concurrency the store is an `actor`, so `flags` and
//   `isEnabled` are accessed with `await`. That's correct: reads serialise
//   against an in-flight refresh, so a read never sees a half-updated value.
//
// - The @unchecked Sendable on the test doubles is fine BECAUSE they're guarded
//   by NSLock and used only in tests. In your production HTTPFlagTransport and a
//   UserDefaults-backed cache you won't need @unchecked — URLSession and
//   UserDefaults are already Sendable-safe to use this way.
//
// - In the capstone, wire a gate like:
//       if await flagStore.isEnabled(\.experimentalFieldMerge) {
//           note = ConflictResolver.fieldMerge(...)   // new path
//       } else {
//           note = ConflictResolver.lastWriterWins(...) // safe path
//       }
//   so the runbook can flip the experimental path off without a resubmission.
//
// ----------------------------------------------------------------------------
