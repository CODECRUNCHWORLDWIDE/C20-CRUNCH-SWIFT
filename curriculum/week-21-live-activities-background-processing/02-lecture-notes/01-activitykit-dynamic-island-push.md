# Lecture 1 — Live Activities, the Dynamic Island, and the push that drives them

> "A Live Activity is a window onto an *ongoing event*, rendered by the system on your Lock Screen and in the Dynamic Island, and updated — while your app is asleep — by a push to a token you handed the server."

This is the lecture that introduces the real-time iOS surface. Week 20 taught you to make your app *appear* statically. This week's framing is one sentence: **a Live Activity shows your app's *now*, and the backend moves the pixels.** Hold that, and the otherwise-strange parts — why attributes split into static and dynamic halves, why you hand a push token to a server, why there's a separate "push-to-start" token — all follow. Lose it, and you will treat a Live Activity like a widget you reload, and be confused when it sits frozen on a terminated app's Lock Screen.

We build the model in the order you use it: first the distinction from a Widget (so you never confuse the two surfaces), then `ActivityAttributes` (the data model), then the lifecycle (start/update/end), then the Dynamic Island layouts (the views), and finally the APNs push — including push-to-start — that drives it from the Vapor backend. By the end you should be able to draw the path from a backend event to a moving number on a Lock Screen and name every hop.

---

## 1. Live Activity vs Widget — the distinction that prevents weeks of confusion

They share view code, they share the widget extension, they both can sit on the Lock Screen. They are *completely different mechanisms.* Internalise this table before anything else:

| | **Widget** (Week 20) | **Live Activity** (this week) |
|---|---|---|
| **Update granularity** | Minutes to hours, on a daily *budget* | Seconds, while live |
| **Lifetime** | Indefinite; always present | Up to ~8 hours (or ~12 on the Lock Screen after end); one *event* |
| **What it shows** | A glanceable slice of app state | One *ongoing* event in progress |
| **Update driver** | App reloads its *timeline* (`WidgetCenter.reloadTimelines`) | A push to the activity's *token*, or a local `update` |
| **Starts when** | User adds it from the gallery | App (or a push, iOS 17.2+) *starts* it for an event |
| **Code** | `Widget` + `TimelineProvider` | `ActivityAttributes` + `ActivityConfiguration` (+ `Activity` lifecycle) |
| **Use it for** | "Most recent note," "today's count" | "Delivery arriving," "note being edited now," "game score live" |

The trap is the Lock Screen. A Lock Screen *widget* and a Lock Screen *Live Activity* look adjacent, and you build both in the same extension with SwiftUI. But the widget is a budgeted, timeline-driven glance, and the Live Activity is a push-driven, seconds-granularity window onto an event that *ends.* Choose by asking one question: **is there an ongoing event with a beginning, a live middle, and an end?** Delivery, ride, workout, timer, live score, "someone is editing your note right now" — Live Activity. "How many notes do I have" — widget. Get this wrong and you will fight the budget trying to make a widget update every second (it can't) or leave a Live Activity running forever (it shouldn't).

---

## 2. `ActivityAttributes` — static frame, dynamic content

An activity's data model is one type conforming to `ActivityAttributes`, with a **nested `ContentState`.** The split is the most important design decision in the framework:

```swift
import ActivityKit

struct NoteEditActivityAttributes: ActivityAttributes {
    // --- STATIC: fixed for the entire life of this activity. ---
    // Set once at start; never changes. Identifies WHICH event this is.
    let noteID: String
    let noteTitle: String

    // --- DYNAMIC: the part that updates. Nested type named ContentState. ---
    public struct ContentState: Codable, Hashable {
        var editorName: String        // who is editing right now
        var startedAt: Date           // when this edit session began
        var keystrokes: Int           // a live counter, updated by push
        var isActive: Bool            // still editing, or wrapping up
    }
}
```

Why the split exists:

- **Static attributes** (`noteID`, `noteTitle`) describe *which event* the activity is about. They are fixed when you start the activity and cannot change. The note being edited doesn't change identity mid-session.
- **`ContentState`** is *everything that updates.* Every push and every local `update` replaces the `ContentState`. It must be `Codable` (so it can travel in a push payload) and `Hashable` (so the system can diff it). Keep it **small** — it is serialised into a push payload that has a hard size limit (4 KB for the whole APNs payload). A `ContentState` with a giant string or an image is a design error; carry an id and let the view resolve the rest from the shared App Group store.

This is the same shape as a `TimelineEntry` from Week 20, but with the static/dynamic split made explicit because the dynamic half travels over the wire in a push.

---

## 3. The lifecycle — request, update, end

You drive an activity through three calls. **Request** starts it:

```swift
import ActivityKit

@MainActor
func startEditActivity(noteID: String, title: String, editor: String) throws -> Activity<NoteEditActivityAttributes> {
    // Guard: the user may have Live Activities disabled in Settings.
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        throw ActivityError.notEnabled
    }

    let attributes = NoteEditActivityAttributes(noteID: noteID, noteTitle: title)
    let initialState = NoteEditActivityAttributes.ContentState(
        editorName: editor, startedAt: .now, keystrokes: 0, isActive: true
    )

    let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: .now.addingTimeInterval(60 * 30)),
        pushType: .token   // <- we want to update this over APNs from the backend
    )
    return activity
}
```

**Update** changes the `ContentState` (locally, if the app is foregrounded):

```swift
@MainActor
func bumpKeystrokes(_ activity: Activity<NoteEditActivityAttributes>, to count: Int) async {
    var state = activity.content.state
    state.keystrokes = count
    await activity.update(
        ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 30))
    )
}
```

**End** finishes it, with a dismissal policy:

```swift
@MainActor
func endEditActivity(_ activity: Activity<NoteEditActivityAttributes>) async {
    var final = activity.content.state
    final.isActive = false
    await activity.end(
        ActivityContent(state: final, staleDate: nil),
        dismissalPolicy: .after(.now.addingTimeInterval(10))   // linger 10s, then dismiss
    )
}
```

The pieces that matter:

- **`pushType: .token`** declares this activity will be updated by push. Omit it and you only get local updates (useless once the app is terminated). With it, you observe the push token (§5) and hand it to the server.
- **`staleDate`** tells the system when the content should be considered out of date — after which iOS dims/greys the activity to signal "this might be stale." Set it generously past your expected next update; if a push is late (or throttled in Low Power Mode), a too-tight `staleDate` makes the activity look broken.
- **`dismissalPolicy`** on `end`: `.immediate` removes it at once; `.default` keeps it briefly; `.after(date)` lingers until a time. For "edit finished," a short linger lets the user see the final state.
- **`ActivityAuthorizationInfo().areActivitiesEnabled`** — the user can turn Live Activities off per-app in Settings. Always guard; an unguarded `request` on a disabled app throws.
- **Recovering activities.** After a relaunch, `Activity<NoteEditActivityAttributes>.activities` returns the running activities so you can re-attach (re-observe their token, update them). An app that starts a duplicate activity because it forgot to check `.activities` is a common bug.

---

## 4. The Dynamic Island and Lock Screen layouts

The activity's UI lives in your **widget extension**, as an `ActivityConfiguration`. You provide two things: the **Lock Screen / banner** view, and the **Dynamic Island** with its presentations.

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct NoteEditLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoteEditActivityAttributes.self) { context in
            // --- LOCK SCREEN / banner presentation ---
            LockScreenEditView(context: context)
                .activityBackgroundTint(.orange.opacity(0.15))
                .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // --- EXPANDED (long-press / when it takes the whole island) ---
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.noteTitle, systemImage: "square.and.pencil")
                        .font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .frame(maxWidth: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.editorName) is editing • \(context.state.keystrokes) edits")
                        .font(.footnote)
                }
            } compactLeading: {
                // --- COMPACT (default, sharing the island with other content) ---
                Image(systemName: "square.and.pencil").foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                // --- MINIMAL (multiple activities; you get a tiny circle) ---
                Image(systemName: "pencil").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "notes://open/\(context.attributes.noteID)"))
            .keylineTint(.orange)
        }
    }
}
```

The layout decision tree — what shows where:

- **`compactLeading` / `compactTrailing`** are the *default* state when your activity shares the Dynamic Island with the system (the pill around the camera). You get two tiny slots — a glyph on the left, a number/timer on the right. Pick the single most important live value (here, the elapsed timer) for the trailing slot.
- **`minimal`** is what you get when *multiple* activities are live and the system collapses yours into a single small circle. One glyph. That is the entire budget.
- **`expanded`** is the long-press (or auto-expand) state: leading, trailing, center, and bottom regions, with room for the rich layout. This is your "real" UI.
- **Lock Screen / banner** is the rectangular card on the Lock Screen and the banner when the activity starts/updates. It is the most spacious presentation and where you put the full picture.

Three rules a senior reviewer enforces:

1. **Every presentation reads from `context.state` (the `ContentState`).** The compact timer, the expanded counter, the Lock Screen card all render the *same* dynamic data; you choose how much of it each presentation shows. The static `context.attributes` (title, id) is the frame.
2. **Use `Text(date, style: .timer)` for live time**, not a value you push every second. A countdown/elapsed timer that the *system* ticks costs zero pushes; pushing a new number every second would blow your budget and is exactly what the timer text style exists to avoid.
3. **`widgetURL` routes a tap** into your app's deep-link machinery (Week 9), exactly like a widget tap. The Live Activity is another entry point into the same navigation-as-state.

A fourth, often-skipped rule: **the expanded layout should not assume it gets all four regions filled.** The system sizes regions based on content, and an empty `center` or a too-tall `bottom` produces an awkward island. Put your single most important value in `compactTrailing` (it's what the user sees most), keep the expanded regions balanced, and test the minimal presentation — it's the one that shows when the user has *another* activity running (a timer, a call), and a glyph that's ambiguous at that size is a glyph that fails. Design the minimal circle as if it's the only thing the user will see, because sometimes it is.

### Adapting across `activityFamily` — watch and CarPlay

On iOS 18+, an `ActivityConfiguration` can also render on the **watch Smart Stack** and in **CarPlay**, via `supplementalActivityFamilies`. The same `ContentState` drives a `.small` watch presentation and the phone presentations; you branch on the `\.activityFamily` environment value much like the widget's `\.widgetFamily`:

```swift
struct LockScreenEditView: View {
    @Environment(\.activityFamily) private var family
    let context: ActivityViewContext<NoteEditActivityAttributes>

    var body: some View {
        switch family {
        case .small:   // watch Smart Stack — tiny, one line
            Label("\(context.state.keystrokes)", systemImage: "pencil")
        default:       // .medium — phone Lock Screen card
            FullEditCard(context: context)
        }
    }
}
```

You opt in with `.supplementalActivityFamilies([.small])` on the `ActivityConfiguration`. The payoff is the same as the widget families: one declaration, the activity follows the user from phone to wrist. The discipline is the same too — the `.small` family is watch-complication-sized, so design for one value, and verify on a paired watch (device-only).

---

## 5. The push token flow — updating from the backend

Local `update` only works while your app is foregrounded. The production pattern — and the week's promise — is **remote update via APNs**, so the activity stays live while the app is terminated. The flow:

```swift
@MainActor
func observeAndRegisterToken(for activity: Activity<NoteEditActivityAttributes>) {
    Task {
        // The push token can arrive after start, and can ROTATE. Observe the stream.
        for await tokenData in activity.pushTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            // Hand the hex token to the Vapor backend, keyed by the note id.
            await NotesAPI.shared.registerLiveActivityToken(token, forNoteID: activity.attributes.noteID)
        }
    }
}
```

Now the backend can push updates. A Live Activity APNs push is an ordinary APNs request with a specific **topic** and **payload**:

- **Topic:** `<your-bundle-id>.push-type.liveactivity` (the `.push-type.liveactivity` suffix is mandatory; a normal-notification topic will be rejected).
- **`apns-push-type` header:** `liveactivity`.
- **Payload `aps`:**

```jsonc
{
  "aps": {
    "timestamp": 1718900000,           // when the server generated this update (seconds)
    "event": "update",                 // "update" | "end" | "start" (push-to-start, §6)
    "content-state": {                 // EXACTLY your ContentState shape, JSON-encoded
      "editorName": "Sam",
      "startedAt": 718900000,
      "keystrokes": 142,
      "isActive": true
    },
    "stale-date": 1718901800,          // when iOS should mark it stale
    "alert": {                         // optional: a banner when this update lands
      "title": "Sam is editing \"Groceries\"",
      "body": "142 edits and counting"
    }
  }
}
```

The non-negotiables:

- **`content-state` must match your `ContentState` exactly** — same keys, same JSON encoding (watch `Date` encoding: ActivityKit expects seconds-since-1970 numbers for dates in the payload). A mismatched key means the decode fails and the update silently does nothing.
- **`event: "update"`** updates; **`event: "end"`** ends the activity (with an optional `dismissal-date`).
- **The whole payload must be ≤ 4 KB.** This is why `ContentState` stays small — carry ids, resolve details app-side.
- **`apns-priority`** of 10 for immediate delivery; the system still throttles under Low Power Mode (lecture 2).

This is where the Vapor backend from Phase I earns its keep: when the server learns "device B opened note X for editing," it looks up device A's Live Activity token for note X and sends this push. The pixels on device A's Lock Screen move because the *server* sent a payload — your app never ran.

---

## 6. Push-to-start — beginning an activity from a push (iOS 17.2+)

The flow above updates an activity your *app* started. But the mini-project's scenario is "another device starts editing while your app is *closed*" — so the activity itself must begin from a push. That is **push-to-start.** You register for a separate, app-wide token:

```swift
@MainActor
func observePushToStartToken() {
    Task {
        for await tokenData in Activity<NoteEditActivityAttributes>.pushToStartTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            await NotesAPI.shared.registerPushToStartToken(token)   // app-wide, not per-activity
        }
    }
}
```

The backend then sends a **start** push to that token:

```jsonc
{
  "aps": {
    "timestamp": 1718900000,
    "event": "start",
    "content-state": { "editorName": "Sam", "startedAt": 718900000, "keystrokes": 0, "isActive": true },
    "attributes-type": "NoteEditActivityAttributes",
    "attributes": { "noteID": "ABC-123", "noteTitle": "Groceries" },
    "alert": { "title": "Sam started editing \"Groceries\"", "body": "" }
  }
}
```

The differences from an update push:

- **`event: "start"`** tells iOS to *create* the activity, not update an existing one.
- **`attributes-type`** names your `ActivityAttributes` type (as a string) so iOS knows which activity to construct.
- **`attributes`** carries the *static* half (id, title) — the part that's fixed for the activity's life.
- It goes to the **`pushToStartTokenUpdates`** token (app-wide), not a per-activity token.

With push-to-start, the activity appears on a terminated app's Lock Screen because the *server* started it. iOS automatically begins observing a per-activity push token for the new activity; the backend can then send `update` pushes to it as in §5. This is the full backend-driven lifecycle — start, update, end — none of which requires your app to be running, and it is the challenge for the week.

---

## 7. The failure catalogue (push edition)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Activity.request` **throws** | Live Activities disabled in Settings, or capability/entitlement missing | Guard `areActivitiesEnabled`; add `NSSupportsLiveActivities` to `Info.plist` |
| Activity starts but **never updates** from the backend | No `pushType: .token`, token not sent to server, or wrong APNs topic | Use `.token`, observe `pushTokenUpdates`, push to `<bundle>.push-type.liveactivity` |
| Push accepted by APNs but **nothing changes** | `content-state` keys/encoding don't match `ContentState` (esp. `Date`) | Encode `content-state` to match `ContentState` exactly; dates as seconds numbers |
| Activity looks **greyed/stale** | `staleDate` too tight; an update was late or throttled | Set `staleDate` generously past the next expected update |
| **Dynamic Island blank** in compact mode | `compactLeading`/`compactTrailing` empty or a view crash | Render a glyph + one value; check the extension's `Console` log for a crash |
| **Push-to-start does nothing** | Sent to per-activity token, missing `attributes-type`/`attributes`, or pre-17.2 | Send `event:"start"` with `attributes-type` to the `pushToStartTokenUpdates` token |
| Payload **rejected** by APNs | Over 4 KB, or wrong `apns-push-type` header | Shrink `content-state`; set `apns-push-type: liveactivity` |

The pattern, again: almost every Live Activity failure is *the dynamic state didn't travel correctly over the push,* or *the activity isn't set up to receive a push at all.* Internalise the payload shape and the token flow and you debug these in minutes.

---

## 8. Recap — the backend moves the pixels

You will write a Live Activity this week and lean on it in the capstone. The discipline that separates "an activity that worked in the demo with the app open" from "an activity that stays live on a terminated phone" is one habit: **design the activity to be driven by a push to a token.**

- It models an *ongoing event* → static `ActivityAttributes` for the frame, a small `Codable` `ContentState` for the live part.
- It must stay live while the app sleeps → `pushType: .token`, observe `pushTokenUpdates`, send the token to the backend.
- The backend updates it → an APNs push to `<bundle>.push-type.liveactivity` with `event` and a `content-state` that exactly matches your type.
- It can even *begin* while the app is dead → push-to-start, with `event:"start"`, `attributes-type`, and `attributes` to the app-wide push-to-start token.
- It renders four presentations → expanded, compact, minimal, Lock Screen — each reading the same `ContentState`, using `Text(date, style: .timer)` for live time to spend zero pushes.

A Live Activity is the real-time half of "your app, everywhere on iOS." Lecture 2 covers the other constraint that governs everything real-time: the **background budget** — how `BGAppRefreshTask` and `BGProcessingTask` let you do scheduled work, why the system is stingy with it, and how Low Power Mode reshapes the whole picture. Bring the token-flow diagram with you; the budget is the reason your pushes and tasks don't always run when you want them to.
