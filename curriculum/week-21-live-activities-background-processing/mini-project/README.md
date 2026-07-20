# Mini-Project — The "shared-note edit in progress" Live Activity

This week the notes app goes real-time. You will add a **Live Activity** to Hello, Notes that appears when another device starts editing a note you have open: it shows who is editing and for how long, rendered in **compact, minimal, and expanded** Dynamic Island layouts and on the Lock Screen, and it updates *live* — driven by an **APNs push from the Vapor backend** — while your app sits terminated. You will also wire a **`BGAppRefreshTask`** that keeps notes and the widget fresh on the system's schedule, and prove the whole thing degrades sanely under Low Power Mode.

This is a *compounding* project. It is not a new app. You start from the Week 20 codebase — SwiftData store, the widget extension, the App Group, the APNs pipeline from Week 18, the Vapor backend from Phase I — and you add an `ActivityAttributes`, the Dynamic Island UI (in the *same* widget extension), the backend push, and a background task. The point of the week is to feel the real-time surface: a backend event moving pixels on a terminated phone, plus the background work that keeps everything current within the system's budget.

---

## Where you're starting from

Your Week 20 app has, roughly:

- A `@Model Note` in a SwiftData store inside a shared **App Group** container.
- A **widget extension** with Home Screen + Lock Screen widgets and `App Intents`.
- The **APNs pipeline** from Week 18: an auth key (`.p8`), device-token registration, and a Notification Service Extension.
- The **Vapor backend** from Phase I that can send APNs pushes.

If you don't have a clean Week 20 checkpoint, you can build the activity over the Week 10 SwiftData app plus a fresh widget extension; the real-time work is the same.

## What you're building toward

By the end you have:

- A `NoteEditActivityAttributes` with static attributes (`noteID`, `noteTitle`) and a small `ContentState` (`editorName`, `startedAt`, `keystrokes`, `isActive`).
- An `ActivityConfiguration` rendering the **Lock Screen card** and all four Dynamic Island presentations (expanded, compactLeading, compactTrailing, minimal).
- A **local start** path: a debug control starts the activity for testing.
- A **push-driven update** path: the activity is requested with `pushType: .token`, the token is sent to Vapor, and the backend pushes `update`s that change the Lock Screen *with the app terminated*.
- (Stretch / challenge) A **push-to-start** path: the backend *starts* the activity on a terminated app via the app-wide push-to-start token.
- A **`BGAppRefreshTask`** that pulls latest notes and reloads the widget, with a correct expiration handler and exactly-once completion.
- **Low Power Mode** detection that degrades the work gracefully.
- A passing **real-time proof**: start the activity, force-quit, push an update from Vapor, watch the Lock Screen change with the app asleep.

---

## Where each piece lives (target layout)

Before you start, know which target each new file belongs to — a mismatch here is the most common "won't build / won't render" cause:

| File | Target(s) | Why |
|------|-----------|-----|
| `NoteEditActivityAttributes.swift` | **App + Widget extension** | Both need the type: the app starts/updates; the extension renders |
| `NoteEditLiveActivity.swift` (`ActivityConfiguration`) | **Widget extension** | The activity UI lives with the widgets, not in the app |
| `EditActivityController.swift` (start/update/end) | **App** | Lifecycle control runs in the app process |
| `BackgroundJobs.swift` (`BGTask` handlers) | **App** | Background tasks register and run in the app |
| `PowerProfile.swift` (LPM policy) | **App** (+ extension if it reads it) | One source of truth for degradation |
| The Vapor sender (push payloads) | **Backend repo** | Server-side; not in the iOS project |

The Info.plist keys (`NSSupportsLiveActivities`, `BGTaskSchedulerPermittedIdentifiers`) and the Background Modes capability go on the **app target.**

## Build order

Work the milestones in this order — each unblocks the next, and the early ones run entirely in the Simulator so you get a fast inner loop before the device-only push work:

1. **Model + render + local lifecycle** (Milestones 1–3) — Simulator only. Prove the four presentations and the start/update/end flow before any backend.
2. **Push-driven update** (Milestone 4) — device required. Swap local `update` for an APNs push from Vapor.
3. **Background task + LPM** (Milestones 5–6) — Simulator (LLDB-fired). The freshness net and graceful degradation.
4. **The proof** (Milestone 7) — device. The whole point: terminated app, backend push, Lock Screen moves.

---

## Milestone 1 — Model the activity (≈ 1 h)

Define the attributes, shared by app and extension (lecture 1, §2). The static/dynamic split is the key decision: identity in `attributes`, everything-that-moves in `ContentState`, kept small because it travels in a ≤ 4 KB push.

```swift
import ActivityKit
import Foundation

struct NoteEditActivityAttributes: ActivityAttributes {
    let noteID: String
    let noteTitle: String

    public struct ContentState: Codable, Hashable {
        var editorName: String
        var startedAt: Date
        var keystrokes: Int
        var isActive: Bool
    }
}
```

Add `NSSupportsLiveActivities` = `true` to the app's `Info.plist`. Add the file to **both** targets.

Decisions you must defend in review:

- **Why is `noteTitle` in `attributes` and `keystrokes` in `ContentState`?** The note's identity and title don't change during one edit session (static); the editor, elapsed time, and edit count do (dynamic). Putting a changing value in `attributes` means you can't update it; putting a static value in `ContentState` bloats every push. (Lecture 1, §2.)
- **Why keep `ContentState` small?** It's JSON-encoded into the APNs payload, which is capped at 4 KB. Carry ids and counts, resolve rich details app-side from the App Group store. (Lecture 1, §5.)

## Milestone 2 — Render the Dynamic Island + Lock Screen (≈ 2 h)

Add the `ActivityConfiguration` to the **widget extension** (lecture 1, §4), rendering the Lock Screen card and all four presentations. Use `Text(date, style: .timer)` for the elapsed time so the system ticks it locally and you spend zero pushes on the clock.

The layout decision tree:

- **compactLeading:** a pencil glyph. **compactTrailing:** the elapsed timer. (The two slots you get by default.)
- **minimal:** one glyph (when multiple activities collapse yours to a circle).
- **expanded:** title (leading), timer (trailing), "Sam • 142 edits" (bottom).
- **Lock Screen:** the full card — title, editor, timer, edit count.

Add `.widgetURL(URL(string: "notes://open/\(context.attributes.noteID)"))` so a tap routes into the navigation stack (Week 9 deep links), just like a widget tap.

## Milestone 3 — Start and update locally (≈ 1 h)

Add an `EditActivityController` (lecture 1, §3) that starts, updates, and ends the activity, guarding `areActivitiesEnabled`. Wire a debug control to exercise it. This is your fast inner loop in the Simulator before the backend is involved — prove the four presentations render and the lifecycle is clean.

## Milestone 4 — Drive it from the Vapor backend (≈ 2.5 h)

Switch the activity to `pushType: .token`, observe `pushTokenUpdates`, and send the token to Vapor keyed by `noteID` (lecture 1, §5). On the backend, when "device B opened note X," look up device A's activity token for note X and send the `update` push:

- **Topic:** `<bundle>.push-type.liveactivity`. **Header:** `apns-push-type: liveactivity`.
- **Payload `aps`:** `event: "update"`, `content-state` matching `ContentState` **exactly** (dates as seconds numbers), a generous `stale-date`.
- Sign with the `.p8` JWT from Week 18.

Decisions you must defend:

- **Why does the backend move the pixels?** Local `update` only works while the app runs. The week's promise is updates while *terminated*, which only a push to the activity token achieves. (Lecture 1, §1; §5.)
- **Why a generous `stale-date`?** A push may be late or throttled (Low Power Mode). Too tight a `stale-date` greys out a perfectly-good activity. (Lecture 1, §3; lecture 2, §4.)

## Milestone 5 — The background refresh task (≈ 1.5 h)

Add a `BGAppRefreshTask` (lecture 2, §2) that pulls latest notes and reloads the widget. Honour the full contract: list the id in `BGTaskSchedulerPermittedIdentifiers`, register the handler at launch, submit a request when backgrounding, and in the handler **re-schedule, set a cancelling expiration handler, do the work, complete exactly once.** Detect Low Power Mode and shrink the work when it's on.

Fire it on demand with the LLDB `_simulateLaunchForTaskWithIdentifier:` trick — don't wait hours. Test the expiration path with `_simulateExpirationForTaskWithIdentifier:` and confirm your handler cancels cleanly without the app being killed.

## Milestone 6 — Low Power Mode degradation (≈ 0.5 h)

Detect `ProcessInfo.processInfo.isLowPowerModeEnabled` and observe `.NSProcessInfoPowerStateDidChange`. Under LPM: the background refresh pulls fewer rows, the `stale-date` on the activity is lengthened, and (if you control cadence) the backend is told to slow updates. Document what you changed and why — "the acceptable experience at 14% battery is the one you ship" (lecture 2, §4).

## Milestone 7 — The real-time proof (≈ 0.5 h)

The acceptance bar for the whole week (device required).

1. Start the edit activity (locally or via push-to-start). The Lock Screen shows the card; the Dynamic Island shows the compact timer.
2. **Force-quit the app.** `xcrun simctl terminate` won't help here — actually swipe it away on the device.
3. From the Vapor backend, send an `update` push (new `keystrokes`). **The number on the Lock Screen and in the Dynamic Island changes — app still terminated.**
4. Send an `end` push. The activity shows the final state and dismisses.

Record this with the app demonstrably closed. "It updated while the app was asleep, driven by the backend" is the deliverable.

---

## The data flow, drawn once

Keep this picture in front of you while you build — every milestone is one hop on it:

```text
   Device B opens note X            Vapor backend                Device A (terminated app)
   ──────────────────────           ─────────────                ────────────────────────
   "I'm editing note X"  ───POST──▶  knows: A holds an
                                     activity token for X
                                            │
                                            │  APNs POST
                                            │  topic: <bundle>.push-type.liveactivity
                                            │  aps.event: "update"
                                            │  aps.content-state: {editorName, keystrokes…}
                                            ▼
                                     api.push.apple.com  ───────▶  Lock Screen / Dynamic Island
                                                                   re-renders from ContentState
                                                                   (app never woke)
```

The token came *from* device A (`pushTokenUpdates` → `NotesAPI.register…`) earlier; the backend stored it keyed by note X; now a real event triggers the push that moves A's pixels. That is the whole architecture of every real-time iOS feature: **client hands the server a token, server pushes a payload to it on an event, the system renders the change with the app asleep.**

## Common pitfalls (and how to spot them)

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| Activity works with app open, frozen when closed | You're on the local `update` path, not push | Confirm `pushType: .token` and that the backend pushes to the activity token |
| Push 200s but Lock Screen doesn't move | `content-state` keys/`Date` encoding don't match `ContentState` | Diff the JSON keys against the struct; dates must be seconds *numbers* |
| Activity greys out between updates | `staleDate` too tight for the push cadence | Lengthen it, especially under Low Power Mode |
| Dynamic Island blank in compact | `compactLeading`/`compactTrailing` empty or a view crash | Check the extension's `Console` log; render a glyph + one value |
| Background refresh never runs | Contract step skipped (id/register/reschedule/complete) | Walk lecture 2's four-step contract; fire it with the LLDB trick |
| Two activities for one note | Started a new one without checking `Activity.activities` | Recover and reuse running activities after relaunch/wake |

Most of these are *the dynamic state didn't travel correctly* or *the activity isn't set up to receive a push* — the two failure families from lecture 1, §7. When something's wrong, ask first: is the activity push-enabled, and does the payload match the type?

---

## Acceptance criteria

- [ ] A `NoteEditActivityAttributes` with a correct static/dynamic split and a small, `Codable`, `Hashable` `ContentState`; `NSSupportsLiveActivities` set.
- [ ] An `ActivityConfiguration` (in the widget extension) rendering the Lock Screen card and **all four** Dynamic Island presentations, with `Text(date, style: .timer)` for live time.
- [ ] The activity is requested with `pushType: .token`; the token is observed via `pushTokenUpdates` and sent to the backend (re-sent on rotation).
- [ ] The Vapor backend sends an `update` push (topic `<bundle>.push-type.liveactivity`, `apns-push-type: liveactivity`, `content-state` matching `ContentState` exactly) that changes the Lock Screen **with the app terminated**.
- [ ] A `BGAppRefreshTask` honouring the full contract (id in `Info.plist`, registered at launch, re-scheduled in-handler, cancelling expiration handler, `setTaskCompleted` exactly once), refreshing notes + the widget.
- [ ] Low Power Mode is detected and the work degrades gracefully (fewer rows, longer stale date).
- [ ] The Week 9/20 deep links and widgets still work; a Live Activity tap routes via `widgetURL`.
- [ ] **The real-time proof passes:** start, force-quit, backend `update` push, Lock Screen changes with the app asleep, `end` dismisses.
- [ ] Build with **0 warnings, 0 errors** across all targets, including Swift 6 strict concurrency.

## Stretch goals

- **Push-to-start** (the challenge): the backend *starts* the activity on a terminated app via the app-wide `pushToStartTokenUpdates` token.
- **`BGProcessingTask` re-index.** A long, idle-time task that re-indexes all notes into Spotlight (Week 20) when the device is charging, with `requiresExternalPower = true`.
- **Smart Stack / watch (iOS 18).** Add `.supplementalActivityFamilies` so the activity renders on the watch Smart Stack; verify on a paired watch.
- **Frequent updates.** Set `NSSupportsLiveActivitiesFrequentUpdates` and measure how the budget responds — and document when *not* to use it.

## What this milestone earns you

You can now ship a Live Activity driven by a backend push — the literal "skill earned" line for the week. More than that: you built the real-time iOS surface end to end — a backend event moving pixels on a terminated phone, the four Dynamic Island presentations, and the background task that keeps the rest current within the system's budget, degrading gracefully under Low Power Mode. Combined with Week 20's widgets and App Intents, you now own the entire "your app, everywhere on iOS" surface the capstone scores. Week 22 stops adding features and builds the CI net that proves all of it keeps working — because a Live Activity that regresses silently in beta is exactly the bug a test suite and a GitHub Actions pipeline are there to catch.
