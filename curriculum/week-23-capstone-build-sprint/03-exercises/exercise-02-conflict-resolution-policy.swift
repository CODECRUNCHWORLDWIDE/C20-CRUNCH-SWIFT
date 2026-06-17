// Exercise 2 — The conflict-resolution policy (ADR-0003), in code
//
// Goal: Implement the capstone's deterministic three-way merge as a PURE
//       function `resolve(local:remote:ancestor:) -> ResolvedNote`, and prove
//       with Swift Testing that two devices running the merge in either order
//       CONVERGE to the same note. Determinism is the whole contract: it's
//       what makes next week's conflict chaos drill reproducible.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite (the `import Testing` / `@Test` style shipped
// with Xcode 16). Drop it into a test target of your capstone (or a fresh
// SwiftPM package test target). It has no UI and no SwiftData dependency — the
// resolver operates on a plain Sendable value type so it is trivially testable
// and trivially correct. In the capstone you map your @Model <-> this DTO at
// the resolver boundary.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U (or `swift test`).
//   3. Read the assertions: a field changed on one side wins; a field changed
//      on both sides falls back to per-field last-writer-wins; the merge is
//      ORDER-INDEPENDENT (resolve(a,b) and resolve(b,a) converge).
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] All tests pass.
//   [ ] `resolve` is a PURE function: same inputs -> same output, no globals,
//       no clock reads, no I/O.
//   [ ] The convergence test passes: two devices that merge in opposite orders
//       reach the same ResolvedNote.
//   [ ] You can explain, in one sentence, why determinism is required for the
//       chaos drill to be reproducible.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The note DTO the resolver operates on. A plain value type, Sendable, so it
// crosses actor boundaries freely and is trivial to reason about.
//
// In the capstone you convert your SwiftData @Model into this at the resolver
// boundary and back afterwards — the resolver never touches a ModelContext.
// ----------------------------------------------------------------------------

struct NoteSnapshot: Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var tags: Set<String>
    /// Per-field modification timestamps drive the last-writer-wins tiebreak.
    /// In production these come from the field's last edit on each device.
    var titleEditedAt: Date
    var bodyEditedAt: Date
    var tagsEditedAt: Date
}

// ----------------------------------------------------------------------------
// The resolver. A PURE function of (local, remote, ancestor).
//
// Policy (ADR-0003): field-level three-way merge with per-field last-writer-wins
// as the tiebreak.
//   - If only ONE side changed a field relative to the ancestor, take that side.
//   - If BOTH sides changed a field, take the one with the later edit timestamp
//     (last-writer-wins for THAT field only). Ties broke by a stable rule
//     (compare the values' string form) so the merge is fully deterministic
//     even when timestamps are equal.
// ----------------------------------------------------------------------------

enum ConflictResolver {

    static func resolve(local: NoteSnapshot,
                        remote: NoteSnapshot,
                        ancestor: NoteSnapshot) -> NoteSnapshot {
        precondition(local.id == remote.id && remote.id == ancestor.id,
                     "resolving snapshots of different notes")

        let title = mergeField(
            local: local.title, remote: remote.title, ancestor: ancestor.title,
            localAt: local.titleEditedAt, remoteAt: remote.titleEditedAt
        )
        let body = mergeField(
            local: local.body, remote: remote.body, ancestor: ancestor.body,
            localAt: local.bodyEditedAt, remoteAt: remote.bodyEditedAt
        )
        // Tags merge as a set union of additions, minus the intersection of
        // deletions — an OR-set-style merge that loses no tag either side added.
        let tags = mergeTags(local: local.tags, remote: remote.tags, ancestor: ancestor.tags)

        return NoteSnapshot(
            id: local.id,
            title: title,
            body: body,
            tags: tags,
            // The resolved field timestamps are the max of the two sides, so the
            // result is itself a valid ancestor for the next merge round.
            titleEditedAt: max(local.titleEditedAt, remote.titleEditedAt),
            bodyEditedAt: max(local.bodyEditedAt, remote.bodyEditedAt),
            tagsEditedAt: max(local.tagsEditedAt, remote.tagsEditedAt)
        )
    }

    /// Merge one scalar field three-ways. Returns the winning value.
    /// The tiebreak is value-based (later timestamp, then `max(value)`) so it is
    /// symmetric: resolve(a,b) == resolve(b,a).
    private static func mergeField(
        local: String, remote: String, ancestor: String,
        localAt: Date, remoteAt: Date
    ) -> String {
        let localChanged = local != ancestor
        let remoteChanged = remote != ancestor
        switch (localChanged, remoteChanged) {
        case (false, false): return ancestor      // neither changed
        case (true, false):  return local         // only local changed
        case (false, true):  return remote        // only remote changed
        case (true, true):                          // both changed -> LWW per field
            if local == remote { return local }     // both made the SAME edit
            if localAt != remoteAt { return localAt > remoteAt ? local : remote }
            // Exactly-equal timestamps: a stable, value-based tiebreak so the
            // result does not depend on argument order.
            return max(local, remote)
        }
    }

    /// Tags merge as an OR-set: keep everything either side has, except tags
    /// that were in the ancestor and removed by at least one side.
    private static func mergeTags(local: Set<String>,
                                  remote: Set<String>,
                                  ancestor: Set<String>) -> Set<String> {
        let addedByLocal  = local.subtracting(ancestor)
        let addedByRemote = remote.subtracting(ancestor)
        let removedByLocal  = ancestor.subtracting(local)
        let removedByRemote = ancestor.subtracting(remote)
        let survivingAncestor = ancestor
            .subtracting(removedByLocal)
            .subtracting(removedByRemote)
        return survivingAncestor.union(addedByLocal).union(addedByRemote)
    }
}

// ----------------------------------------------------------------------------
// The test suite
// ----------------------------------------------------------------------------

@Suite("Conflict resolution is deterministic and lossless where it can be")
struct ConflictResolverTests {

    let id = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let t1 = Date(timeIntervalSince1970: 2_000)
    let t2 = Date(timeIntervalSince1970: 3_000)

    func base() -> NoteSnapshot {
        NoteSnapshot(id: id, title: "Groceries", body: "milk", tags: ["home"],
                     titleEditedAt: t0, bodyEditedAt: t0, tagsEditedAt: t0)
    }

    @Test("A field changed on only one side keeps that side's edit")
    func oneSidedEditWins() {
        var local = base();  local.title = "Weekend groceries"; local.titleEditedAt = t1
        let remote = base()  // unchanged title

        let merged = ConflictResolver.resolve(local: local, remote: remote, ancestor: base())
        #expect(merged.title == "Weekend groceries")
        // The body nobody touched is preserved.
        #expect(merged.body == "milk")
    }

    @Test("Non-overlapping edits both survive (no lost edit)")
    func nonOverlappingEditsBothSurvive() {
        var local = base();  local.title = "Shopping"; local.titleEditedAt = t1
        var remote = base(); remote.body = "milk, eggs"; remote.bodyEditedAt = t1

        let merged = ConflictResolver.resolve(local: local, remote: remote, ancestor: base())
        #expect(merged.title == "Shopping")     // local's title edit survived
        #expect(merged.body == "milk, eggs")    // remote's body edit ALSO survived
    }

    @Test("Both sides edit the same field -> later timestamp wins (per-field LWW)")
    func sameFieldLastWriterWins() {
        var local = base();  local.body = "milk, bread";  local.bodyEditedAt = t1
        var remote = base(); remote.body = "milk, butter"; remote.bodyEditedAt = t2 // later

        let merged = ConflictResolver.resolve(local: local, remote: remote, ancestor: base())
        #expect(merged.body == "milk, butter")  // remote was edited later
    }

    @Test("Tags merge as an OR-set: additions from both sides survive")
    func tagsUnionAdditions() {
        var local = base();  local.tags = ["home", "urgent"]; local.tagsEditedAt = t1
        var remote = base(); remote.tags = ["home", "weekend"]; remote.tagsEditedAt = t1

        let merged = ConflictResolver.resolve(local: local, remote: remote, ancestor: base())
        #expect(merged.tags == ["home", "urgent", "weekend"])
    }

    @Test("THE CONTRACT: the merge converges regardless of order")
    func mergeIsOrderIndependent() {
        var a = base(); a.title = "A-title"; a.titleEditedAt = t1; a.body = "A-body"; a.bodyEditedAt = t2
        var b = base(); b.title = "B-title"; b.titleEditedAt = t2; b.body = "B-body"; b.bodyEditedAt = t1
        let ancestor = base()

        // Device 1 sees (a) as local and (b) as remote; device 2 sees the reverse.
        let device1 = ConflictResolver.resolve(local: a, remote: b, ancestor: ancestor)
        let device2 = ConflictResolver.resolve(local: b, remote: a, ancestor: ancestor)

        // They MUST converge — same note on every device — or sync never settles.
        #expect(device1 == device2)
    }

    @Test("Idempotence: re-resolving an already-merged note is a no-op")
    func resolvingTwiceIsStable() {
        var local = base();  local.title = "X"; local.titleEditedAt = t1
        let merged = ConflictResolver.resolve(local: local, remote: base(), ancestor: base())
        // Feeding the merged result back through with itself converges to itself.
        let again = ConflictResolver.resolve(local: merged, remote: merged, ancestor: merged)
        #expect(again == merged)
    }
}

// ----------------------------------------------------------------------------
// WHY determinism matters (write it in your own words before reading):
//
//   The chaos drill (next week) edits the same note on two simulators offline,
//   reconnects them, and asserts they end up identical. That assertion is only
//   meaningful if the resolver is a PURE function: every device, merging the
//   same (local, remote, ancestor) in any order, must compute the SAME result.
//   If the merge read the wall clock, a random number, or argument order, the
//   two devices could diverge and never converge — and the drill could "pass"
//   on one run and "fail" on the next, which is worse than no drill at all.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The order-independence test is the one to design against FIRST. If your
//   tiebreak is "prefer local," it is NOT symmetric and the two devices diverge.
//   Tiebreak on a property of the VALUES (later timestamp, then max(value)), not
//   on the argument position. That is what makes resolve(a,b) == resolve(b,a).
//
// - Equal timestamps are the trap. Real devices DO produce equal millisecond
//   stamps. When titleEditedAt == titleEditedAt on both sides, you must break
//   the tie on something order-independent — here, `max(local, remote)` on the
//   string value. Never leave it to argument order.
//
// - The resolver must not touch SwiftData. Convert @Model -> NoteSnapshot at the
//   boundary, resolve, then write the result back. A resolver that holds a
//   ModelContext is neither pure nor testable, and ModelContext isn't Sendable.
//
// - For tags, an OR-set "additions win, deletions only stick if BOTH removed"
//   is the simplest convergent policy. If you want "either deletion sticks,"
//   change `survivingAncestor` to subtract the union of removals — just keep it
//   symmetric so the order-independence test still passes.
//
// ----------------------------------------------------------------------------
