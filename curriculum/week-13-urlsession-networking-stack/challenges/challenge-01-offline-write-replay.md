# Challenge 1 — Offline-first write-replay (and prove it survives a drop)

**Time.** 90–150 minutes.
**Deliverable.** An offline-first write-replay layer in an `OfflineNotes` repo, a hermetic test that simulates a network drop and reconnect, and a `OFFLINE.md` documenting the order and idempotency guarantees. Committed.

## The premise

The single thing that separates a real iOS product from a tutorial app is what happens when the network disappears. A tutorial app shows a spinner forever or loses the user's note. A real app keeps working — the write succeeds *locally and instantly*, queues for the server, and reconciles when connectivity returns, with nothing lost and nothing duplicated. The skill this challenge builds is the **outbox pattern**, and the bar is not "I wrote some queuing code" — it is "I proved, with a deterministic test, that a write made during a 30-second outage survives, replays in order, and is applied exactly once."

You will build the outbox, then prove it against a stubbed network that goes offline and comes back.

## What to build

### The local store and the outbox

```swift
import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var syncState: String   // "synced" | "pending"
    init(id: UUID = UUID(), title: String, body: String = "", syncState: String = "synced") {
        self.id = id; self.title = title; self.body = body; self.syncState = syncState
    }
}

@Model
final class PendingMutation {
    var id: UUID            // IDEMPOTENCY KEY — stable across replays
    var kind: String        // "create" | "update" | "delete"
    var noteID: UUID
    var payload: Data?      // encoded fields for create/update
    var createdAt: Date     // ORDER — replay sorted by this
    var attempts: Int
    init(id: UUID = UUID(), kind: String, noteID: UUID, payload: Data?, createdAt: Date = .now) {
        self.id = id; self.kind = kind; self.noteID = noteID
        self.payload = payload; self.createdAt = createdAt; self.attempts = 0
    }
}
```

### The repository — write locally, queue, replay

```swift
actor NotesRepository {
    private let context: ModelContext
    private let client: NotesClient
    init(context: ModelContext, client: NotesClient) {
        self.context = context; self.client = client
    }

    /// Create a note: apply locally NOW, then try the server; queue if offline.
    func create(title: String, body: String) async {
        let note = Note(title: title, body: body, syncState: "pending")
        context.insert(note)
        try? context.save()                       // UI sees it immediately

        do {
            try await client.createNote(id: note.id, title: title, body: body)
            note.syncState = "synced"
        } catch let e as NetworkError where !e.isRetryable && e != .offline {
            // permanent failure (e.g. 400) — surface it; don't queue a doomed write
        } catch {
            // offline / transient — QUEUE it for replay
            let payload = try? JSONEncoder().encode(["title": title, "body": body])
            context.insert(PendingMutation(id: note.id, kind: "create",
                                           noteID: note.id, payload: payload))
        }
        try? context.save()
    }

    /// Replay the outbox in order, idempotently. Call on reconnect.
    func drainOutbox() async {
        let pending = (try? context.fetch(
            FetchDescriptor<PendingMutation>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        for mutation in pending {
            do {
                try await replay(mutation)        // sends the IDEMPOTENCY KEY as a header
                markSynced(mutation.noteID)
                context.delete(mutation)          // success: dequeue
            } catch let e as NetworkError where e.isRetryable || e == .offline {
                break                             // still down — stop; try the whole queue later
            } catch {
                mutation.attempts += 1            // permanent failure — park it (alert after N)
            }
        }
        try? context.save()
    }

    private func replay(_ m: PendingMutation) async throws { /* re-send per kind, with m.id as Idempotency-Key */ }
    private func markSynced(_ noteID: UUID) { /* set the note's syncState to "synced" */ }
}
```

(Fill in `replay`, `markSynced`, and the `NotesClient` create/update/delete with the idempotency header. The `NotesClient` is exercise 1's actor extended with mutating endpoints.)

## What to prove

This is the heart of the challenge — a *deterministic* test of the drop-and-reconnect cycle, using a `URLProtocol` stub (exercise 2) you can flip between "online" and "offline."

### Test 1 — a write during an outage survives and replays

```
1. Stub the network as OFFLINE (handler throws URLError(.notConnectedToInternet)).
2. create(title: "Offline note") — assert it's in SwiftData with syncState == "pending",
   and there is exactly ONE PendingMutation queued.
3. Flip the stub to ONLINE (handler returns 200 and records the request).
4. drainOutbox() — assert the note's syncState is now "synced", the outbox is EMPTY,
   and the server (the stub) received exactly ONE create request.
```

### Test 2 — order is preserved

```
1. Offline. Make three writes: create A, update A, delete A (in that order).
2. Online. drainOutbox().
3. Assert the stub received the requests in the order create→update→delete.
   (A reordered replay would leave a ghost note — assert it doesn't.)
```

### Test 3 — idempotency (the hard one)

```
1. Offline. create(title: "X") — one PendingMutation queued.
2. Online, but the stub ACKS the request then "drops the response" (return 200 the
   first time, but your replay logic doesn't see it — simulate by having the stub
   record the idempotency key and, on a SECOND request with the same key, return
   the SAME resource without creating a duplicate).
3. drainOutbox() twice (simulating a replay after a lost ack).
4. Assert the server recorded the create only ONCE (deduped by idempotency key),
   and there is exactly ONE note locally.
```

Test 3 is the one that proves you understand offline-first: the network is unreliable in *both* directions, so a replayed write must be safe to apply twice. The idempotency key (`PendingMutation.id` sent as `Idempotency-Key`) is what makes the second apply a no-op.

## Acceptance criteria

- [ ] Writes apply to SwiftData **locally and immediately** (the note exists with `syncState == "pending"` before any network success).
- [ ] Offline/transient failures **queue** a `PendingMutation`; permanent failures (4xx, decoding) do **not** queue.
- [ ] `drainOutbox()` replays **in order** (`sortBy createdAt`) and **stops** (doesn't lose the queue) if still offline.
- [ ] A replayed write carries an **idempotency key** so a re-apply after a lost ack does **not** create a duplicate.
- [ ] Three hermetic tests (survive-outage, order-preserved, idempotent-replay) pass with a `URLProtocol` stub — **zero real network**.
- [ ] `OFFLINE.md` documents the order guarantee, the idempotency mechanism, and what happens to a permanently-failing mutation.
- [ ] Everything builds with **0 warnings**, including Swift 6 strict concurrency.

## What "great" looks like

A weak submission queues writes and replays them. A great submission says:

> Writes apply to SwiftData synchronously, so the UI never waits on the network — a note created in airplane mode appears instantly with `syncState: pending`. The outbox is a SwiftData-persisted queue ordered by `createdAt`, so a create→update→delete sequence replays in exactly that order (proven: the stub recorded the three requests in order; a set-based queue would have lost the ordering and left a ghost note). Each `PendingMutation` carries a stable UUID sent as `Idempotency-Key`; my drop-the-ack test calls `drainOutbox()` twice and the stubbed server, deduping on the key, recorded the create once — so a lost response on reconnect doesn't duplicate the note. A mutation that fails permanently (a 400) increments `attempts` and is parked rather than blocking the queue; after 3 attempts the UI surfaces "couldn't sync this change." The outbox survives an app kill because it's in SwiftData, so a write made offline and the app force-quit before reconnect still replays on next launch.

Order, idempotency, persistence-across-kill, and a permanent-failure escape hatch — all proven, not asserted. That's the senior offline-first answer.

## Where this reappears

The outbox you built — apply locally, queue, replay in order, dedupe by key — is the *single-client* version of the conflict resolution Week 14 builds for *multiple devices* over CloudKit. The idempotency discipline reappears every time the network is unreliable: StoreKit transaction replay (Week 18), APNs delivery (Week 18), and the capstone's chaos-drill offline-edit-conflict scenario (Phase IV) all rest on "a write that might be applied twice must be safe." Build the instinct here; the whole production phase compounds on it.
