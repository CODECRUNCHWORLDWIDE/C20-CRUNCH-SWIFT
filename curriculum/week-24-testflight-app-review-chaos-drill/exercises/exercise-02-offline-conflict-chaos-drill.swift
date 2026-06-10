// Exercise 2 — The offline-edit-conflict chaos drill, as a deterministic test
//
// Goal: Model the capstone's offline-edit-conflict drill (two devices edit the
//       same note offline, reconnect within 60s) as a Swift Testing suite that
//       asserts CONVERGENCE (both devices end identical) and ZERO LOSS for
//       non-overlapping edits. This is the repeatable proof behind the LIVE
//       drill your postmortem documents — the test pins the logic so the live
//       run is a confirmation, not a discovery.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite. Drop it into a test target. It has no UI, no
// SwiftData, and no network — it models two device replicas as plain value
// types and a deterministic resolver, so the drill is reproducible in CI. The
// LIVE drill (against two simulators + real CloudKit) is what the capstone
// requires; this is how you prove the merge logic is correct first.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U (or `swift test`).
//   3. Read the assertions: non-overlapping edits both survive; the same-field
//      conflict resolves by the tiebreak; BOTH devices converge to one note.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] All tests pass.
//   [ ] The resolver is a PURE function (same inputs -> same output).
//   [ ] The convergence test passes: after exchanging edits, the two device
//       replicas hold the IDENTICAL note.
//   [ ] You can explain why the LIVE drill still matters even though this test
//       passes (it measures real CloudKit propagation latency).
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The replicated note. Each device holds its own copy plus the last-synced
// snapshot (the "ancestor") needed for a three-way merge.
// ----------------------------------------------------------------------------

struct Note: Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var titleEditedAt: Date
    var bodyEditedAt: Date
}

/// A device replica: its current note and the ancestor it last synced from.
struct DeviceReplica: Sendable {
    var current: Note
    var ancestor: Note   // the last value both devices agreed on
}

// ----------------------------------------------------------------------------
// The deterministic three-way resolver. Pure: no clock reads, no I/O, no
// argument-order dependence. Field-level merge with per-field last-writer-wins.
// ----------------------------------------------------------------------------

enum Resolver {
    static func resolve(local: Note, remote: Note, ancestor: Note) -> Note {
        Note(
            id: local.id,
            title: mergeString(local: local.title, remote: remote.title, ancestor: ancestor.title,
                               localAt: local.titleEditedAt, remoteAt: remote.titleEditedAt),
            body: mergeString(local: local.body, remote: remote.body, ancestor: ancestor.body,
                              localAt: local.bodyEditedAt, remoteAt: remote.bodyEditedAt),
            titleEditedAt: max(local.titleEditedAt, remote.titleEditedAt),
            bodyEditedAt: max(local.bodyEditedAt, remote.bodyEditedAt)
        )
    }

    private static func mergeString(local: String, remote: String, ancestor: String,
                                    localAt: Date, remoteAt: Date) -> String {
        let localChanged = local != ancestor
        let remoteChanged = remote != ancestor
        switch (localChanged, remoteChanged) {
        case (false, false): return ancestor
        case (true, false):  return local
        case (false, true):  return remote
        case (true, true):
            if local == remote { return local }
            if localAt != remoteAt { return localAt > remoteAt ? local : remote }
            return max(local, remote)   // equal timestamps: value-based, order-independent
        }
    }
}

// ----------------------------------------------------------------------------
// The drill harness: simulate "both offline, edit, reconnect, sync."
// ----------------------------------------------------------------------------

enum Drill {
    /// Both devices start from the same ancestor. Each applies its own edit
    /// while "offline." Then they "reconnect" and exchange: each device merges
    /// the OTHER's current note against the shared ancestor. Returns the two
    /// devices' resulting notes — which MUST be identical (convergence).
    static func runOfflineConflict(ancestor: Note,
                                   editA: (inout Note) -> Void,
                                   editB: (inout Note) -> Void) -> (a: Note, b: Note) {
        var a = ancestor; editA(&a)   // device A's offline edit
        var b = ancestor; editB(&b)   // device B's offline edit

        // Reconnect: each device resolves the other's note against the ancestor.
        let resolvedOnA = Resolver.resolve(local: a, remote: b, ancestor: ancestor)
        let resolvedOnB = Resolver.resolve(local: b, remote: a, ancestor: ancestor)
        return (resolvedOnA, resolvedOnB)
    }
}

// ----------------------------------------------------------------------------
// The test suite
// ----------------------------------------------------------------------------

@Suite("Offline-edit-conflict chaos drill: convergence and zero loss")
struct OfflineConflictDrillTests {

    let id = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let t1 = Date(timeIntervalSince1970: 2_000)
    let t2 = Date(timeIntervalSince1970: 3_000)

    func ancestor() -> Note {
        Note(id: id, title: "Groceries", body: "milk", titleEditedAt: t0, bodyEditedAt: t0)
    }

    @Test("Non-overlapping edits both survive (no lost edit)")
    func nonOverlappingEditsSurvive() {
        let (a, b) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.title = "Weekend groceries"; $0.titleEditedAt = t1 },  // A edits title
            editB: { $0.body = "milk, eggs"; $0.bodyEditedAt = t1 }            // B edits body
        )
        // Both devices converged...
        #expect(a == b)
        // ...and BOTH edits survived.
        #expect(a.title == "Weekend groceries")
        #expect(a.body == "milk, eggs")
    }

    @Test("Same-field conflict resolves to the later edit, deterministically")
    func sameFieldConflictResolves() {
        let (a, b) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.body = "milk, bread"; $0.bodyEditedAt = t1 },
            editB: { $0.body = "milk, butter"; $0.bodyEditedAt = t2 }  // later -> wins
        )
        #expect(a == b)                 // converged
        #expect(a.body == "milk, butter")  // later edit won
    }

    @Test("THE DRILL CONTRACT: both devices converge regardless of edit roles")
    func convergesRegardlessOfRoles() {
        // Run the same conflict twice with A and B swapped. Convergence must hold
        // both times, and to the SAME note — because the resolver is order-free.
        let (a1, b1) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.title = "X"; $0.titleEditedAt = t2 },
            editB: { $0.title = "Y"; $0.titleEditedAt = t1 }
        )
        let (a2, b2) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.title = "Y"; $0.titleEditedAt = t1 },
            editB: { $0.title = "X"; $0.titleEditedAt = t2 }
        )
        #expect(a1 == b1)
        #expect(a2 == b2)
        #expect(a1 == a2)   // swapping roles produced the SAME converged note
    }

    @Test("Identical edits on both sides are not a conflict")
    func identicalEditsAreNoConflict() {
        let (a, b) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.title = "Same"; $0.titleEditedAt = t1 },
            editB: { $0.title = "Same"; $0.titleEditedAt = t1 }
        )
        #expect(a == b)
        #expect(a.title == "Same")
    }

    @Test("Zero loss across 50 randomized non-overlapping conflicts", arguments: 0..<50)
    func zeroLossAcrossManyTrials(seed: Int) {
        var rng = SeededGenerator(seed: UInt64(seed))
        let newTitle = "title-\(Int.random(in: 0...9_999, using: &rng))"
        let newBody = "body-\(Int.random(in: 0...9_999, using: &rng))"
        let (a, b) = Drill.runOfflineConflict(
            ancestor: ancestor(),
            editA: { $0.title = newTitle; $0.titleEditedAt = t1 },   // A: title only
            editB: { $0.body = newBody; $0.bodyEditedAt = t1 }       // B: body only
        )
        #expect(a == b)                  // always converges
        #expect(a.title == newTitle)     // A's edit never lost
        #expect(a.body == newBody)       // B's edit never lost
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

// ----------------------------------------------------------------------------
// WHY the LIVE drill still matters (write it before reading):
//
//   This test proves the merge LOGIC converges and loses no non-overlapping
//   edit, deterministically, in microseconds. The LIVE drill proves something
//   this test cannot: that the real SYSTEM converges within the time budget
//   under real CloudKit propagation latency. The merge is microseconds; the
//   CloudKit push to the second device can be seconds. The live drill measures
//   that real timing and is what the postmortem reports. Test the logic here;
//   measure the system live. Both are required; neither replaces the other.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The convergence test is the one to design against first. If `resolvedOnA`
//   and `resolvedOnB` differ, your tiebreak depends on argument order (e.g.
//   "prefer local"). Tiebreak on the VALUES (later timestamp, then max(value)),
//   never on which argument is "local."
//
// - The ancestor is load-bearing. Without it, you cannot tell which side CHANGED
//   a field versus carried it forward, and field-merge collapses to LWW. The
//   harness passes the same ancestor to both resolves — that's the shared
//   last-synced snapshot your capstone must persist per note.
//
// - For the live drill: two simulators signed into the same iCloud sandbox
//   account, both offline (network condition / airplane mode), edit, reconnect
//   within 60s, and watch both converge. Measure the reconnect-to-converge time
//   — it will be longer than this test because of CloudKit push latency, and
//   THAT number is your postmortem finding.
//
// ----------------------------------------------------------------------------
