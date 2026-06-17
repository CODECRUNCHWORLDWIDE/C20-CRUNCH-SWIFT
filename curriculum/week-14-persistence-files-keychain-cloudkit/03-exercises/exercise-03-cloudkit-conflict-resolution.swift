// Exercise 3 — Deterministic CloudKit conflict resolution
//
// Goal: Model a CloudKit-SAFE @Model (optional relationships, no .unique,
//       defaulted properties), then write the conflict-resolution policy as a
//       PURE FUNCTION over two snapshots — and prove it is DETERMINISTIC
//       (order-independent: resolve(a,b) == resolve(b,a)) and keeps the later
//       edit. This is the trick that makes multi-device sync testable without a
//       paid account or two devices: resolution is a function, not a side effect.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite. Drop it into a test target (iOS 17+/macOS 14+).
// It needs NO CloudKit entitlement and NO network: the whole point is that the
// resolution LOGIC is a pure function you can unit-test in isolation. The @Model
// is here to show the CloudKit-safe SHAPE; the tests exercise the resolver.
//
//   1. Add to your test target.
//   2. Run with Cmd-U.
//   3. The tests assert: the resolver keeps the later-updatedAt version, is
//      order-independent, and a field-level merge keeps NON-overlapping edits.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] The @Model compiles as a CloudKit-safe shape (every relationship
//       optional, no @Attribute(.unique), every non-optional property defaulted).
//   [ ] `resolveLWW` keeps the later-updatedAt snapshot.
//   [ ] `resolveLWW(a, b) == resolveLWW(b, a)` for all inputs (determinism).
//   [ ] `mergeFields` keeps a title edit from one side AND a body edit from the
//       other when they don't overlap.
//   [ ] You can explain why CloudKit's default record-LWW-by-network-timing can
//       silently lose data, and why timestamp-LWW fixes it.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import SwiftData
import Testing

// ----------------------------------------------------------------------------
// A CloudKit-SAFE @Model. Compare to the Week 10 version:
//   - every stored property has a DEFAULT (records sync out of order),
//   - the relationship is OPTIONAL (the target may not have synced yet),
//   - NO @Attribute(.unique) (CloudKit has no uniqueness constraint).
// ----------------------------------------------------------------------------

@Model
final class Note {
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now            // the LWW tiebreaker — bumped on every edit
    var tags: [Tag]? = []                      // optional to-many, CloudKit-safe

    init(title: String = "", body: String = "",
         createdAt: Date = .now, updatedAt: Date = .now, tags: [Tag]? = []) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }

    /// Route EVERY mutation through here so updatedAt is never forgotten.
    func edit(title: String? = nil, body: String? = nil, now: Date = .now) {
        if let title { self.title = title }
        if let body  { self.body = body }
        self.updatedAt = now
    }
}

@Model
final class Tag {
    var name: String = ""                      // no .unique — dedupe in app logic
    var notes: [Note]? = []

    init(name: String = "", notes: [Note]? = []) {
        self.name = name
        self.notes = notes
    }
}

// ----------------------------------------------------------------------------
// The resolution policy as a PURE FUNCTION over snapshots. A snapshot is a
// Sendable value type, so it crosses actor/sync boundaries cleanly and is
// trivially testable. This is the key design move of the whole exercise.
// ----------------------------------------------------------------------------

struct NoteSnapshot: Sendable, Equatable {
    var title: String
    var body: String
    var updatedAt: Date
}

/// Record-level last-write-wins, deterministic on updatedAt.
/// Determinism requirement: resolveLWW(a, b) MUST equal resolveLWW(b, a).
func resolveLWW(_ a: NoteSnapshot, _ b: NoteSnapshot) -> NoteSnapshot {
    if a.updatedAt != b.updatedAt {
        return a.updatedAt > b.updatedAt ? a : b
    }
    // Tie on timestamp: break it deterministically by a stable, content-based
    // rule so both devices agree even when the clocks matched exactly.
    return a.body >= b.body ? a : b
}

// ----------------------------------------------------------------------------
// A field-level merge: track a timestamp PER FIELD so non-overlapping edits on
// two devices both survive (record-LWW would discard one).
// ----------------------------------------------------------------------------

struct FieldVersioned: Sendable, Equatable {
    var title: String;  var titleUpdatedAt: Date
    var body: String;   var bodyUpdatedAt: Date
}

func mergeFields(_ a: FieldVersioned, _ b: FieldVersioned) -> FieldVersioned {
    var result = a
    if b.titleUpdatedAt > a.titleUpdatedAt {
        result.title = b.title
        result.titleUpdatedAt = b.titleUpdatedAt
    }
    if b.bodyUpdatedAt > a.bodyUpdatedAt {
        result.body = b.body
        result.bodyUpdatedAt = b.bodyUpdatedAt
    }
    return result
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

struct ConflictResolutionTests {

    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)
    private let t2 = Date(timeIntervalSince1970: 3_000)

    @Test("LWW keeps the later-updatedAt version")
    func laterWins() {
        let older = NoteSnapshot(title: "A", body: "old body", updatedAt: t1)
        let newer = NoteSnapshot(title: "A", body: "new body", updatedAt: t2)
        #expect(resolveLWW(older, newer) == newer)
        #expect(resolveLWW(newer, older) == newer)
    }

    @Test("LWW is deterministic — order-independent for all inputs")
    func deterministic() {
        let samples: [NoteSnapshot] = [
            .init(title: "X", body: "alpha", updatedAt: t0),
            .init(title: "Y", body: "beta",  updatedAt: t1),
            .init(title: "Z", body: "gamma", updatedAt: t1),   // same ts as above -> tiebreak
            .init(title: "W", body: "delta", updatedAt: t2),
        ]
        for a in samples {
            for b in samples {
                // The whole correctness property: resolving (a,b) and (b,a) agree.
                #expect(resolveLWW(a, b) == resolveLWW(b, a))
            }
        }
    }

    @Test("Field-level merge keeps NON-overlapping edits from both devices")
    func fieldMergeKeepsBoth() {
        // Base: title "Standup", body "blockers?" at t0.
        // Device A edits the TITLE at t1. Device B edits the BODY at t1.
        let deviceA = FieldVersioned(title: "Standup (daily)", titleUpdatedAt: t1,
                                     body: "blockers?",        bodyUpdatedAt: t0)
        let deviceB = FieldVersioned(title: "Standup",         titleUpdatedAt: t0,
                                     body: "blockers + demo",  bodyUpdatedAt: t1)

        let merged = mergeFields(deviceA, deviceB)
        // BOTH edits survive — that's the win over record-LWW.
        #expect(merged.title == "Standup (daily)")
        #expect(merged.body  == "blockers + demo")
    }

    @Test("Field merge falls back to LWW on a true same-field conflict")
    func fieldMergeSameFieldConflict() {
        let a = FieldVersioned(title: "A", titleUpdatedAt: t1, body: "x", bodyUpdatedAt: t0)
        let b = FieldVersioned(title: "B", titleUpdatedAt: t2, body: "x", bodyUpdatedAt: t0)
        // Both edited title; the later one (t2) wins that field.
        #expect(mergeFields(a, b).title == "B")
    }

    @Test("edit() always bumps updatedAt so the tiebreak stays valid")
    @MainActor
    func editBumpsTimestamp() throws {
        let schema = Schema([Note.self, Tag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let note = Note(title: "Hello", body: "world", updatedAt: t0)
        context.insert(note)
        note.edit(body: "world!", now: t1)

        #expect(note.updatedAt == t1)     // bumped — never left stale
        #expect(note.body == "world!")
    }
}

// ----------------------------------------------------------------------------
// WHY the default loses data, and why timestamp-LWW fixes it (write first):
//
//   CloudKit's default resolution is record-level last-WRITE-wins, where "last"
//   means "last RECEIVED" — which depends on network timing (which device
//   reconnected first, retry order). That is NON-deterministic and overwrites
//   the WHOLE record, so an edit to a different field on the losing device
//   vanishes silently. Timestamp-LWW makes "last" mean "last EDITED" via
//   updatedAt, which every device computes identically regardless of arrival
//   order — deterministic, and matching the user's mental model.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The determinism test is the heart of the exercise. If resolveLWW(a,b) !=
//   resolveLWW(b,a) for any pair, your tiebreak (when timestamps are EQUAL) is
//   order-dependent. Break ties on a stable, content-based rule (e.g. compare
//   `body`), NOT on "whichever was passed first."
//
// - "Pure function over snapshots" is the design that makes this testable. Do
//   NOT write resolution inside a CloudKit completion handler reading live
//   @Model objects — you couldn't unit-test it and it wouldn't be obviously
//   deterministic. Snapshot -> resolve -> apply.
//
// - The @Model here exists to show the CloudKit-safe shape. If you try to add
//   @Attribute(.unique) or a non-optional relationship and then enable
//   cloudKitDatabase, SwiftData rejects it at container creation — that's the
//   constraint, enforced.
//
// - `NoteSnapshot` is `Sendable` on purpose: a snapshot can cross the sync
//   actor boundary, where a `Note` @Model (not Sendable) cannot.
//
// ----------------------------------------------------------------------------
