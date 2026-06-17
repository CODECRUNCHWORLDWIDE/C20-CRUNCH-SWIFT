# Challenge 1 — Push-to-start a Live Activity from Vapor (the full lifecycle over the wire)

**Time.** 90–150 minutes (a physical device is required).
**Deliverable.** A working push-to-start flow plus a short report (`PUSH-LIFECYCLE.md`) documenting the three payloads (start / update / end) you sent and a screen recording of the activity beginning on a *terminated* app's Lock Screen, committed to your Week 21 repo.

## The premise

Exercise 2 updated an activity your *app* started. But the real scenario — and the mini-project's — is "another device starts editing while your app is closed," so the activity itself must *begin* from a push. Since iOS 17.2, that is **push-to-start**: the app registers an app-wide token, and the backend sends a `start` payload that creates the activity with the app terminated. The skill this challenge builds is the complete backend-driven lifecycle: **start, update, and end an activity over APNs, your app a passive recipient the whole time.**

This is the most current, most senior iOS capability in the track. Most engineers have never shipped it. You will.

## What to build

Start from your exercise-1 activity (the `NoteEditActivityAttributes` and the `ActivityConfiguration`) and your exercise-2 token plumbing. You need your **Vapor backend** sending APNs (the auth key from Week 18) and a **physical device** (the activity push token only exists on real hardware).

### Step 1 — Register for the push-to-start token (app-wide)

Unlike the per-activity token, the push-to-start token is registered once for the *type*, at launch, and survives app termination:

```swift
import ActivityKit

@MainActor
func registerForPushToStart() {
    Task {
        for await tokenData in Activity<NoteEditActivityAttributes>.pushToStartTokenUpdates {
            let hex = tokenData.map { String(format: "%02x", $0) }.joined()
            await NotesAPI.registerPushToStartToken(hex)   // store on the backend, app-wide
        }
    }
}
```

Call this early (app `init` / launch) so the token is registered even when the app is later terminated. The backend stores it keyed to the user/device.

### Step 2 — Send the `start` payload from Vapor

The `start` push goes to the **push-to-start token** (not a per-activity token) and carries the *static* attributes plus the initial content state:

```jsonc
// POST https://api.push.apple.com/3/device/<push-to-start-token-hex>
// apns-push-type: liveactivity
// apns-topic:     com.crunch.hellonotes.push-type.liveactivity
// apns-priority:  10
// authorization:  bearer <JWT from your .p8>
{
  "aps": {
    "timestamp": 1718900000,
    "event": "start",
    "attributes-type": "NoteEditActivityAttributes",
    "attributes": { "noteID": "ABC-123", "noteTitle": "Groceries" },
    "content-state": { "editorName": "Sam", "startedAt": 718900000,
                       "keystrokes": 0, "isActive": true },
    "alert": { "title": "Sam started editing \"Groceries\"", "body": "" }
  }
}
```

The four start-specific fields, vs an update:

- **`event: "start"`** — create, don't update.
- **`attributes-type`** — the string name of your `ActivityAttributes` type, so iOS knows what to construct.
- **`attributes`** — the static half (id, title), fixed for the activity's life.
- It goes to the **push-to-start token**, not a per-activity token.

### Step 3 — Vapor sender shape

Adapt this into your backend's APNs path (APNSwift / vapor-apns):

```swift
// Pseudo-Vapor; the headers and body are the contract.
func sendStart(pushToStartToken: String, noteID: String, title: String, editor: String) async throws {
    let body = StartPayload(
        aps: .init(
            timestamp: Int(Date().timeIntervalSince1970),
            event: "start",
            attributesType: "NoteEditActivityAttributes",
            attributes: .init(noteID: noteID, noteTitle: title),
            contentState: .init(editorName: editor,
                                startedAt: Int(Date().timeIntervalSince1970),
                                keystrokes: 0, isActive: true)
        )
    )
    try await apns.send(
        rawBytes: JSONEncoder().encode(body),
        to: pushToStartToken,
        pushType: .liveActivity,
        topic: "com.crunch.hellonotes.push-type.liveactivity",
        priority: 10
    )
}
```

### Step 4 — Update and end over the wire

Once the activity starts from the push, iOS begins vending a **per-activity** push token for it (observe `pushTokenUpdates` on the newly-started activity, or `Activity.activities` after a `start`). Send the per-activity token back to the backend, then drive `update` and `end` exactly as exercise 2 — so the entire life of the activity runs from the server.

### Step 5 — Prove it with the app terminated

This is the graded part. Do it in this exact order:

1. Install on the device, launch once (so the push-to-start token registers), then **force-quit** the app.
2. From the backend (or curl), send the `start` payload to the push-to-start token. **A Live Activity appears on the Lock Screen — the app never launched.**
3. Send an `update` payload (new `keystrokes`) to the per-activity token. The number on the Lock Screen changes, app still closed.
4. Send an `end` payload (`event: "end"`, `isActive: false`, a `dismissal-date`). The activity shows the final state and dismisses.
5. Record the whole sequence with the app demonstrably terminated.

### Step 6 — Document the lifecycle

In `PUSH-LIFECYCLE.md`, paste the three payloads you actually sent (redact the tokens), and trace the flow:

> The app registered a push-to-start token via `Activity<NoteEditActivityAttributes>.pushToStartTokenUpdates` at launch and sent it to Vapor. With the app force-quit, the backend POSTed the `start` payload (with `attributes-type` and `attributes`) to that token at `api.push.apple.com` with topic `com.crunch.hellonotes.push-type.liveactivity` and `apns-push-type: liveactivity` — iOS created the activity on the Lock Screen. iOS then vended a per-activity push token, which the app's `pushTokenUpdates` observer sent back to Vapor; the backend used it to POST `update` (new `content-state`) and finally `end` (with `dismissal-date`). The app was terminated for the entire start→update→end sequence.

## Acceptance criteria

- [ ] The app registers for `pushToStartTokenUpdates` at launch and sends the token to the backend.
- [ ] A `start` payload from the backend **creates** the activity with the app **terminated** (`event: "start"`, `attributes-type`, `attributes` all present).
- [ ] After start, the per-activity push token is captured and sent to the backend; `update` changes the Lock Screen content.
- [ ] An `end` payload ends the activity with a sensible `dismissal-date`.
- [ ] All pushes use topic `<bundle>.push-type.liveactivity` and header `apns-push-type: liveactivity`; payloads are ≤ 4 KB with `content-state` matching `ContentState` exactly.
- [ ] `PUSH-LIFECYCLE.md` with the three payloads and the flow trace; a screen recording with the app demonstrably terminated.
- [ ] Build with **0 warnings**, including Swift 6 strict concurrency.

## What "great" looks like

A weak submission shows an activity updating. A great submission says:

> The activity's entire lifecycle ran server-side with the app force-quit. The `start` push to the push-to-start token created it (the `attributes-type: "NoteEditActivityAttributes"` and `attributes: {noteID, noteTitle}` told iOS what to build); the per-activity token that iOS then issued was POSTed back to Vapor and used for two `update`s and an `end`. The one gotcha: my first `start` was rejected because I sent it to a *per-activity* token I'd cached from a previous run — push-to-start requires the *app-wide* `pushToStartTokenUpdates` token, which is a different value. And my `update` initially did nothing because I encoded `startedAt` as an ISO-8601 string; ActivityKit wants a seconds-since-1970 *number* in `content-state`, so the decode silently failed.

Backend-driven, app-terminated, and honest about the two gotchas that bite everyone. That's the senior answer.

## Where this reappears

Push-to-start is the capstone's "drive a Live Activity from a real-time event" requirement, done to production depth, and the literal answer to the interview-prep system-design prompt "design a Live Activity for a food-delivery order." The backend-as-the-thing-that-moves-the-pixels model — server learns an event, looks up a token, pushes a payload, the user's Lock Screen updates with the app asleep — is the architectural shape of every real-time iOS feature you will ship.
