# Challenge 1 — An interactive "pin" widget (with the round-trip proven)

**Time.** 60–120 minutes.
**Deliverable.** An interactive widget with a working pin/unpin button, plus a short report (`WIDGET-LOOP.md`) tracing the tap → intent → store → reload → redraw loop, committed to your Week 20 repo with a screen recording or screenshot sequence.

## The premise

Static widgets show content. Since iOS 17, widgets can also *do* things: a `Button(intent:)` or `Toggle(isOn:intent:)` runs an App Intent in place, without launching the app. The skill this challenge builds is not "know interactive widgets exist" — it is **mutate shared state from a process that isn't your app, and prove the mutation is durable.** A widget button that flips a colour but doesn't persist is a parlour trick; a widget button that pins a note in your real store, surviving into the app, is the production pattern.

You will add a pin button to your widget, wire it to an intent that toggles `isPinned` on the shared SwiftData store, and prove the round-trip: pin from the Home Screen with the app closed, open the app, and the note is pinned.

## What to build

Start from your exercise-1 widget and exercise-2 intent. Your `Note` model needs a pin flag (this is the V2 field from the mini-project's schema versioning — add it as a lightweight migration):

```swift
@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date
    var isPinned: Bool = false      // additive, defaulted -> lightweight migration

    init(title: String, body: String = "", createdAt: Date = .now, isPinned: Bool = false) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}
```

### Step 1 — A stable id you can pass into the intent

The widget entry needs to carry *which* note to pin, by a stable id (the widget can't hand the intent a live model object — it's not `Sendable` and the intent runs off-process). Add a `uid` to the model and carry it on the entry:

```swift
@Model final class Note {
    var uid: UUID = UUID()          // stable, Sendable id for routing
    // ...rest as above...
}

struct RecentNoteEntry: TimelineEntry {
    let date: Date
    let noteUID: UUID
    let title: String
    let isPinned: Bool
    let count: Int
}
```

### Step 2 — The toggle intent

A small, fast intent that opens the shared store, flips the flag, saves, and reloads the widget. It runs off-process, so it constructs its own store access (the lecture-1 rule):

```swift
import AppIntents
import SwiftData
import WidgetKit
import Foundation

struct ToggleNotePinned: AppIntent {
    static let title: LocalizedStringResource = "Toggle Note Pin"

    @Parameter(title: "Note ID")
    var noteUID: String

    init() {}
    init(noteUID: UUID) { self.noteUID = noteUID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uid = UUID(uuidString: noteUID) else { return .result() }
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.uid == uid })
        if let note = try context.fetch(descriptor).first {
            note.isPinned.toggle()
            try context.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
        return .result()
    }
}
```

### Step 3 — The button in the widget view

```swift
struct RecentNoteWidgetView: View {
    let entry: RecentNoteEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).font(.headline).lineLimit(2)
            Spacer()
            // Tapping runs the intent in place. No app launch.
            Button(intent: ToggleNotePinned(noteUID: entry.noteUID)) {
                Label(entry.isPinned ? "Pinned" : "Pin",
                      systemImage: entry.isPinned ? "pin.fill" : "pin")
            }
            .tint(.orange)
            Text("\(entry.count) notes").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
```

The provider's `getTimeline` now reads `isPinned` and `uid` from the most recent note into the entry, so the button reflects current state and carries the right id.

### Step 4 — Prove the round-trip

This is the graded part. Do it in this exact order, with the app **terminated** for the tap:

1. Run the app, add a note, confirm `isPinned == false`. Force-quit the app (`xcrun simctl terminate booted <bundle-id>`).
2. On the Home Screen, the widget shows the note with a **"Pin"** button. Tap it. The label flips to **"Pinned"** — *the app never opened.*
3. Open the app. The note is **pinned** in your store (show it sorted pinned-first, or display a pin glyph). Durable, not cosmetic.
4. Tap the widget button again (app closed again) to unpin; reopen; confirm it unpinned.

### Step 5 — Trace the loop in writing

In `WIDGET-LOOP.md`, walk the full path with the actual symbol names from your code:

> Tap on `Button(intent: ToggleNotePinned(noteUID:))` → WidgetKit invokes `ToggleNotePinned.perform()` in the widget extension's process (the app is terminated) → `perform()` opens the App Group store at `AppGroup.storeURL`, fetches the note by `uid` with a `#Predicate`, toggles `isPinned`, saves → calls `WidgetCenter.shared.reloadTimelines(ofKind:)` → WidgetKit re-invokes `getTimeline`, which re-reads the now-pinned note into a fresh `RecentNoteEntry` → the widget redraws with "Pinned". When the app later opens, its `@Query` reads the same store and shows the note pinned, because both processes share one database.

## Acceptance criteria

- [ ] The widget contains a working `Button(intent:)` (or `Toggle(isOn:intent:)`) — not a `Link`, not a tap gesture.
- [ ] The intent toggles `isPinned` on the **shared App Group store** and is constructed off-process (no captured app singleton).
- [ ] Pinning from the widget with the **app terminated** is durable — opening the app shows the note pinned.
- [ ] The intent ends by reloading the timeline; the widget label reflects the new state after the tap.
- [ ] `WIDGET-LOOP.md` traces the full tap → intent → store → reload → redraw loop with your real symbol names.
- [ ] A screen recording or screenshot sequence showing the app-closed pin and the app-open confirmation.
- [ ] Build with **0 warnings** (both targets), including Swift 6 strict concurrency.

## What "great" looks like

A weak submission says "the button toggles a pin." A great submission says:

> The widget's `Button(intent: ToggleNotePinned(noteUID: entry.noteUID))` runs entirely in the `NotesWidget` extension process while `HelloNotes` is terminated. `perform()` opens the `group.com.yourname.hellonotes` store, fetches the note by `uid` via `#Predicate` (one row, not the table), toggles `isPinned`, and saves — so the change is in SQLite before the tap animation finishes. The subsequent `reloadTimelines(ofKind: "RecentNoteWidget")` makes WidgetKit re-read a fresh entry, so the button shows "Pinned" without any app launch. On reopening, the app's `@Query` reflects the pin because app and extension are two readers of one App Group store. The only non-obvious bug I hit: passing the note by `persistentModelID` failed across the process boundary, so I added a `UUID uid` and routed by that — a `PersistentIdentifier` isn't a stable cross-process key the way a UUID is.

Durable, off-process, and honest about the cross-process id gotcha. That's the senior answer.

## Where this reappears

The off-process-intent-mutates-shared-store pattern is the exact shape of a Live Activity update (Week 21) and a push-driven widget refresh — the system invokes your code while your UI is asleep, you touch shared state, you reload the surface. The capstone scores Widgets + App Intents + Live Activity together; this challenge is the Widgets-plus-interactive-intent third of that, done to production depth.
