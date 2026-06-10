# Exercise 1 — Trace one write end to end

**Goal.** Produce the written, hop-by-hop trace of a single note edit moving through your entire capstone — and, for each hop, name the failure mode and the data-loss window. This is the trace-an-event walk from Lecture 1, §5, turned into a `docs/trace-one-write.md` you commit, rehearse, and deliver live in Friday's architecture review. If you can write this honestly, you understand your system. If you can't, you have an integration gap, and finding it now is the whole point.

**Estimated time.** 50 minutes.

**Prerequisites.** Your integrated capstone workspace (the five targets + `NotesCore` + the deployed Vapor backend). You do not need every hop *working* perfectly to write the trace — but every hop you cannot describe is a hop you have not integrated, and the trace is how you surface that.

---

## Step 1 — Set up the observable path

Before you trace, make the path observable so you can *see* the write move, not just assert it. Add a single `Logger` category that every hop writes to, so one `xcrun simctl spawn booted log stream` shows the whole journey:

```swift
import OSLog

extension Logger {
    /// One category every sync hop logs to, so the trace is greppable.
    static let trace = Logger(subsystem: "com.crunch.notes", category: "trace")
}

// At each hop, log with the note id so you can follow ONE write:
Logger.trace.info("hop=local-save note=\(note.id, privacy: .public) updatedAt=\(note.updatedAt)")
```

You will reference these log lines in the trace document and in the review. A write you can grep across hops is a write you can debug.

## Step 2 — Walk the eight hops

Open `docs/trace-one-write.md` and fill in the table below for *your* capstone. Edit a note on the iPhone **while offline**, then bring the device online, and follow the same write all the way to the second device and the Live Activity. For each hop, write the mechanism (the code that runs), the failure mode (what breaks here), and the data-loss window (how much is lost if it breaks, in time or in writes).

| # | Hop | Mechanism (your code) | Failure mode | Data-loss window |
|---|-----|------------------------|--------------|------------------|
| 1 | The edit | `@Bindable` binding mutates the `@Model`; `onChange` stamps `updatedAt` | Re-render storm if state ownership is wrong | none (local mutation) |
| 2 | Local durability | `modelContext.save()` on commit | Crash between mutation and save | one in-flight edit |
| 3 | Outbox enqueue | `SyncEngine.enqueue(noteID)` persists a pending op | Unbounded outbox; duplicate ops | none (deduped by id) |
| 4 | Connectivity returns | `NWPathMonitor` fires; engine drains outbox | Drain races a new edit | none if idempotent |
| 5 | Remote write | CloudKit `CKModifyRecordsOperation` + `NotesClient` replay to Vapor | Partial drain (one leg fails) | inconsistency until retry |
| 6 | Other device pulls | CloudKit push → `SyncEngine` merges into SwiftData | Concurrent edit → conflict | resolved deterministically |
| 7 | Conflict resolution | `ConflictResolver.resolve(local:remote:ancestor:)` | Non-deterministic merge never converges | a field, with LWW tiebreak |
| 8 | Push + Live Activity + Widget | Vapor sends APNs; NSE decrypts; `Activity.update`; `WidgetCenter.reloadTimelines` | Payload ≠ `ContentState` → silent no-op | none (cosmetic) |

The table above is the *shape*; replace each cell with the specifics of your build (your type names, your retry policy, your conflict tiebreak). The cells that are hardest to fill honestly are exactly the ones the reviewer will probe.

## Step 3 — Write the prose walk

Under the table, write the same journey as a 200–300 word narration you can read aloud in under two minutes — the script for the live demo. Name the mechanism at each hop ("the edit lands in SwiftData via an explicit `save()` on commit, *before* anything touches the network…"). This is the §5 trace-one-write walk; rehearse it out loud once before Friday.

## Step 4 — Name the windows out loud

End the document with one paragraph titled **"Where this can lose data, and how much."** Summarise the windows from the table: the crash-before-save window (milliseconds; one edit), the partial-drain window (one sync leg; recovered on retry by idempotency), and the conflict window (one field; resolved by your tiebreak). This paragraph *is* the answer to the reviewer's "where can you lose a write" question — having it written means you never improvise it.

---

## Acceptance criteria

- [ ] `docs/trace-one-write.md` exists with the eight-hop table filled in for *your* capstone (your type names, not the template's).
- [ ] Each hop names a concrete mechanism (code that runs), a failure mode, and a data-loss window.
- [ ] A 200–300 word prose walk you can deliver in under two minutes.
- [ ] A closing "where this can lose data, and how much" paragraph.
- [ ] You added the `Logger.trace` hop logging and confirmed, with `log stream`, that one real edit produces a greppable line at each integrated hop.
- [ ] Committed to your capstone repo.

## What you just proved

You proved your capstone is a *system*, not a pile of parts — that one write flows through every hop and that you can name what breaks at each. The hops you could not fill in honestly are your integration backlog for the rest of the week. And you produced the single most important artifact for Friday: the trace-an-event script that wins the review room (Lecture 1, §5).

---

## Hints (read only if stuck > 15 min)

- **You can't see the write move between hops.** Make sure every hop logs to `Logger.trace` with the *same* note id, then `xcrun simctl spawn booted log stream --predicate 'category == "trace"'`. If a hop produces no line, that hop is not wired — that's the finding.
- **Hop 7 (conflict) has no ancestor to compare against.** You need to persist the last-synced snapshot (the "ancestor") per note, or your merge can only do last-writer-wins. If you shipped LWW, say so honestly in the table — "earlier edit lost" — rather than pretending you have a three-way merge.
- **Hop 8's Live Activity does nothing on push.** The push payload's keys must match the `ActivityAttributes.ContentState` you decode. Print the raw payload in the NSE and diff it against your `ContentState` — a one-key mismatch is the classic silent no-op.
- **The data-loss windows feel like guesses.** They should be *measured* where you can. Force-kill the app between mutation and save and confirm the edit is gone (hop 2's window). Disable the network mid-drain and confirm the retry recovers (hop 5's window). A measured window beats a guessed one in the review.
