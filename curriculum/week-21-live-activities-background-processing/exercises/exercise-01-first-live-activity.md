# Exercise 1 — A first Live Activity, started locally

**Goal.** Stand up the smallest possible real Live Activity: an `ActivityAttributes` with a `ContentState`, a Lock Screen card, all three Dynamic Island presentations, and start/update/end driven from the app. No backend yet — we update it locally to feel the lifecycle. If the activity appears, updates, and ends cleanly, the real-time surface works; exercise 2 swaps the local updates for an APNs push.

**Estimated time.** 55 minutes.

**Prerequisites.** Xcode 16+. Your Hello, Notes app with the **widget extension** from Week 20 (the `ActivityConfiguration` lives in that extension). Live Activities render on the **simulated** Lock Screen; the Dynamic Island shows fully only on an iPhone 14 Pro+ device, but you can develop everything here in the Simulator.

---

## Step 1 — Enable Live Activities

Add to the **app target's** `Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

(There's also `NSSupportsLiveActivitiesFrequentUpdates` for high-frequency updates; leave it off for now.)

## Step 2 — Define the attributes (shared by app and extension)

Create `NoteEditActivityAttributes.swift` and add it to **both** the app target and the widget extension target's membership:

```swift
import ActivityKit
import Foundation

struct NoteEditActivityAttributes: ActivityAttributes {
    // STATIC: fixed for the life of the activity.
    let noteID: String
    let noteTitle: String

    // DYNAMIC: the updatable part. Small, Codable, Hashable.
    public struct ContentState: Codable, Hashable {
        var editorName: String
        var startedAt: Date
        var keystrokes: Int
        var isActive: Bool
    }
}
```

## Step 3 — Render the activity (in the widget extension)

Create `NoteEditLiveActivity.swift` in the **widget extension** and add it to the extension's `WidgetBundle`:

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct NoteEditLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoteEditActivityAttributes.self) { context in
            // Lock Screen / banner
            VStack(alignment: .leading, spacing: 4) {
                Label(context.attributes.noteTitle, systemImage: "square.and.pencil")
                    .font(.headline).lineLimit(1)
                HStack {
                    Text("\(context.state.editorName) is editing")
                    Spacer()
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                        .frame(maxWidth: 64, alignment: .trailing)
                }
                .font(.subheadline)
                Text("\(context.state.keystrokes) edits")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.orange.opacity(0.15))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.noteTitle, systemImage: "square.and.pencil")
                        .font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit()).frame(maxWidth: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.editorName) • \(context.state.keystrokes) edits")
                        .font(.footnote)
                }
            } compactLeading: {
                Image(systemName: "square.and.pencil").foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit()).frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "pencil").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "notes://open/\(context.attributes.noteID)"))
            .keylineTint(.orange)
        }
    }
}
```

Add `NoteEditLiveActivity()` to your extension's `@main WidgetBundle` alongside the Week 20 widgets.

## Step 4 — Start / update / end from the app

Create `EditActivityController.swift` in the **app target**:

```swift
import ActivityKit
import Foundation

@MainActor
final class EditActivityController {
    private var activity: Activity<NoteEditActivityAttributes>?

    func start(noteID: String, title: String, editor: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are disabled in Settings."); return
        }
        let attributes = NoteEditActivityAttributes(noteID: noteID, noteTitle: title)
        let state = NoteEditActivityAttributes.ContentState(
            editorName: editor, startedAt: .now, keystrokes: 0, isActive: true
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 30)),
                pushType: nil   // local-only for now; exercise 2 switches to .token
            )
        } catch {
            print("Failed to start activity: \(error)")
        }
    }

    func bump(to keystrokes: Int) async {
        guard let activity else { return }
        var state = activity.content.state
        state.keystrokes = keystrokes
        await activity.update(
            ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 30))
        )
    }

    func finish() async {
        guard let activity else { return }
        var final = activity.content.state
        final.isActive = false
        await activity.end(
            ActivityContent(state: final, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(8))
        )
        self.activity = nil
    }
}
```

## Step 5 — Drive it from a screen

Add buttons to a debug view so you can exercise the lifecycle by hand:

```swift
struct ActivityDebugView: View {
    @State private var controller = EditActivityController()
    @State private var edits = 0

    var body: some View {
        Form {
            Button("Start edit activity") {
                controller.start(noteID: "ABC-123", title: "Groceries", editor: "Sam")
            }
            Button("Bump edits (+10)") {
                edits += 10
                Task { await controller.bump(to: edits) }
            }
            Button("End activity", role: .destructive) {
                Task { await controller.finish() }
            }
        }
    }
}
```

## Step 6 — Run and SEE it

1. Run on the Simulator. Tap **Start edit activity.** Lock the simulator (Device ▸ Lock, or Cmd-L) — the Live Activity card appears on the Lock Screen with the title, editor, and a ticking timer.
2. Tap **Bump edits** a few times — the keystroke count updates live.
3. On a device (iPhone 14 Pro+), the Dynamic Island shows the compact timer; long-press to see the expanded layout.
4. Tap **End activity** — it shows the final state, lingers ~8s, then dismisses.

```text
Lock Screen:
┌─────────────────────────────────────┐
│ ✏️  Groceries                        │
│ Sam is editing            00:42 ⏱   │
│ 30 edits                             │
└─────────────────────────────────────┘
```

---

## Acceptance criteria

- [ ] `NSSupportsLiveActivities` is `true` in the app's `Info.plist`.
- [ ] An `ActivityAttributes` with a small, `Codable`, `Hashable` `ContentState`, shared by app and extension.
- [ ] An `ActivityConfiguration` rendering the Lock Screen card and **all four** presentations (expanded, compactLeading, compactTrailing, minimal).
- [ ] `start` guards `areActivitiesEnabled`, `update` mutates the `ContentState`, `end` uses a sensible `dismissalPolicy`.
- [ ] Live time uses `Text(date, style: .timer)` (system-ticked) — not a value you push every second.
- [ ] Build with **0 warnings, 0 errors** (both targets).
- [ ] The activity appears on the Lock Screen, updates when you bump, and ends cleanly.

## What you just proved

You proved the activity lifecycle works end to end *locally*: request put a card on the Lock Screen, update changed its content, end dismissed it. You also met the four presentations and the static/dynamic split. The one thing this exercise *can't* show is the week's actual promise — updating while the app is **terminated** — because local `update` only works while the app runs. Exercise 2 fixes that by handing a push token to a backend and driving the activity over APNs.

---

## Hints (read only if stuck > 10 min)

- **`Activity.request` throws immediately.** Either `NSSupportsLiveActivities` isn't set, or Live Activities are disabled for the app in Settings. Guard `areActivitiesEnabled` and check Settings ▸ your app ▸ Live Activities.
- **Nothing appears on the Lock Screen.** Make sure `NoteEditLiveActivity()` is actually in the extension's `WidgetBundle`, and that `NoteEditActivityAttributes` is a member of **both** targets — the extension can't render an activity type it can't see.
- **The timer doesn't tick / shows a frozen time.** Use `Text(context.state.startedAt, style: .timer)`, not `Text("\(elapsed)")`. The `.timer` style is system-driven and updates without a push.
- **Dynamic Island looks empty in the Simulator.** The Simulator's Dynamic Island support is partial; the Lock Screen card is the reliable Simulator surface. Verify the island on an iPhone 14 Pro+ device.
- **Strict-concurrency warning on the controller.** Mark it `@MainActor` (ActivityKit's main APIs are main-actor friendly) and keep the `Activity` reference on the main actor.
