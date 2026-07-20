# Exercise 1 — A first widget on a shared timeline

**Goal.** Stand up the smallest possible real widget: a widget extension target, an App Group that lets that extension see the app's data, and a `TimelineProvider` that renders the most recent note on the Home Screen. This is the entire promise of the week distilled to one screen — if the widget shows the *correct current* note without you launching the app, the hard part (the App Group) works, and everything else this week is refinement.

**Estimated time.** 55 minutes.

**Prerequisites.** Xcode 16+, an iOS 18 Simulator (iOS 17 works). You need the Hello, Notes app from Week 10 on SwiftData, *or* the `Scratch` app from Week 10's exercise 1 — either gives you a `@Model Note` and a store. We will move that store into an App Group so the widget can read it.

---

## Step 1 — Define the shared App Group constant

Create a Swift file `AppGroup.swift` and add it to **both** the app target and (after step 2) the widget target's membership:

```swift
import Foundation

enum AppGroup {
    static let identifier = "group.com.yourname.hellonotes"

    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }

    static var storeURL: URL {
        containerURL.appendingPathComponent("Notes.store")
    }
}
```

Replace the identifier with your own reverse-DNS group id.

## Step 2 — Enable the App Group capability on the app

Xcode ▸ **app target ▸ Signing & Capabilities ▸ + Capability ▸ App Groups.** Add `group.com.yourname.hellonotes` (the same string). You will repeat this on the widget target in step 4.

## Step 3 — Point the app's SwiftData store at the group

In your app's `@main` App, build the container against `AppGroup.storeURL` instead of the default location, so the widget can later open the *same* file:

```swift
import SwiftUI
import SwiftData

@main
struct HelloNotesApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema([Note.self])
            let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(container)
    }
}
```

Run the app, add a couple of notes. The store now lives in the shared container.

## Step 4 — Add the widget extension target

Xcode ▸ **File ▸ New ▸ Target ▸ Widget Extension.** Name it `NotesWidget`. **Uncheck** "Include Configuration Intent" for now (we want a plain `StaticConfiguration`). Activate the scheme when prompted.

Then: select the **NotesWidget target ▸ Signing & Capabilities ▸ + Capability ▸ App Groups**, and add the **same** `group.com.yourname.hellonotes`. Add `AppGroup.swift` and `Note.swift` (your `@Model`) to the widget target's membership (File Inspector ▸ Target Membership). The widget needs the model definition and the group constant.

## Step 5 — A shared read helper the widget can call

The widget reads the store on a background-ish, off-process basis. Give it a tiny synchronous read that opens the shared container and returns plain values (never live model objects):

```swift
import SwiftData
import Foundation

struct NoteSnapshot {
    let title: String
    let count: Int
}

enum SharedStore {
    @MainActor
    static func recentNote() -> NoteSnapshot {
        do {
            let schema = Schema([Note.self])
            let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            let total = try context.fetchCount(FetchDescriptor<Note>())
            let recent = try context.fetch(descriptor).first
            return NoteSnapshot(title: recent?.title ?? "No notes yet", count: total)
        } catch {
            return NoteSnapshot(title: "No notes yet", count: 0)
        }
    }
}
```

Add this file to **both** targets. Note `fetchLimit = 1` (don't fetch the whole table to read one row) and `fetchCount` for the number (don't materialise objects to count them) — the Week 10 footguns still apply, and a widget is the *last* place you want a slow fetch.

## Step 6 — The provider and the widget

Replace the generated widget file's provider and widget with:

```swift
import WidgetKit
import SwiftUI

struct RecentNoteEntry: TimelineEntry {
    let date: Date
    let title: String
    let count: Int
}

struct RecentNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentNoteEntry {
        RecentNoteEntry(date: .now, title: "Your most recent note", count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentNoteEntry) -> Void) {
        Task { @MainActor in
            let s = SharedStore.recentNote()
            completion(RecentNoteEntry(date: .now, title: s.title, count: s.count))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentNoteEntry>) -> Void) {
        Task { @MainActor in
            let s = SharedStore.recentNote()
            let entry = RecentNoteEntry(date: .now, title: s.title, count: s.count)
            // Content changes on user action, not on a clock: reload "never",
            // and we'll reload explicitly from the app (exercise 2).
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

struct RecentNoteWidgetView: View {
    let entry: RecentNoteEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recent", systemImage: "note.text")
                .font(.caption).foregroundStyle(.secondary)
            Text(entry.title).font(.headline).lineLimit(3)
            Spacer()
            Text("\(entry.count) notes total")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct RecentNoteWidget: Widget {
    let kind = "RecentNoteWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNoteProvider()) { entry in
            RecentNoteWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)   // required iOS 17+
        }
        .configurationDisplayName("Recent Note")
        .description("Shows your most recently created note.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NotesWidgetBundle: WidgetBundle {
    var body: some Widget { RecentNoteWidget() }
}
```

## Step 7 — Run, add the widget, SEE the note

1. Run the **app** scheme first and add a couple of notes (so the shared store has data).
2. Switch to the **NotesWidget** scheme and run — it launches the widget in the simulated Home Screen preview, or run the app then long-press the Home Screen ▸ **+** ▸ find "Recent Note" ▸ add the small and medium families.
3. The widget should show your most recent note's title and the total count — **without the app being in the foreground.**

```text
┌──────────────────┐
│ 📝 Recent        │
│                  │
│ Buy milk         │
│                  │
│ 4 notes total    │
└──────────────────┘
```

## Step 8 — Prove the App Group is real (optional, illuminating)

```bash
# The shared App Group container, not the app's own sandbox:
GROUP=$(xcrun simctl get_app_container booted group.com.yourname.hellonotes 2>/dev/null)
# Older Xcode: find it under the data container; the Notes.store is inside the group.
find "$GROUP" -name "Notes.store" 2>/dev/null
sqlite3 "$GROUP/Notes.store" "SELECT ZTITLE FROM ZNOTE ORDER BY ZCREATEDAT DESC LIMIT 1;"
```

Seeing the SQLite store inside the **group** container (not the app's container) is the concrete proof that app and widget share one database.

---

## Acceptance criteria

- [ ] An `AppGroup` constant shared by both targets; the App Group capability enabled on **both** the app and the widget target with the **same** id.
- [ ] The app's `ModelContainer` points at `AppGroup.storeURL` (not the default location).
- [ ] A `TimelineProvider` with `placeholder` (instant, data-free), `getSnapshot`, and `getTimeline` returning a `.never` policy.
- [ ] The widget reads via `fetchLimit = 1` / `fetchCount` — no full-table fetch, no `.count` on a materialised array.
- [ ] Build with **0 warnings, 0 errors** (both targets).
- [ ] The widget shows your **current most recent note** on the Home Screen, with the app **not** in the foreground.

## What you just proved

You proved the App Group works: a *separate process* (the widget extension) read the *same SwiftData store* the app wrote, and rendered it on the Home Screen on a published timeline. The thing that makes 90% of widget bugs — "the extension can't see my data" — is now behind you. Exercise 2 adds an App Intent that *writes* to that same store from Siri, and exercise 3 makes the content findable in Spotlight.

---

## Hints (read only if stuck > 10 min)

- **Widget is permanently blank or shows the placeholder.** The extension can't open the store. Almost always: the App Group capability is missing on the widget target, the group id differs by a character, or the app is still writing to the *default* store URL while the widget reads the group URL. Make both point at `AppGroup.storeURL`.
- **`containerURL(forSecurityApplicationGroupIdentifier:)` returns nil (crash on `!`).** The capability isn't actually enabled on the target you're running, or the id string doesn't match the capability. Re-check Signing & Capabilities on *that* target.
- **Widget shows old data even after adding a note in the app.** Expected for now — the policy is `.never` and we haven't wired a reload. Exercise 2 calls `WidgetCenter.shared.reloadTimelines`. For this exercise, re-add the widget or re-run to force a fresh timeline.
- **"Missing container background" warning / odd rendering.** You omitted `.containerBackground(_:for: .widget)`. It's required on iOS 17+.
- **Build fails: "Cannot find type 'Note' in scope" in the widget.** Add `Note.swift` (and `AppGroup.swift`, `SharedStore`) to the widget target's membership in the File Inspector.
