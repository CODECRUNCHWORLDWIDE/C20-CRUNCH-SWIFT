# Lecture 2 — WidgetKit timelines, the App Group that feeds them, and Spotlight

Lecture 1 gave you the verbs (App Intents) and the system-as-client framing. This lecture is about the *content* surfaces: a **Widget** that renders a slice of your app on a published timeline, the **App Group** that lets the widget extension see your store (without which the widget is permanently blank), interactive widgets that run an intent in place, and **Spotlight** indexing that makes your content findable from a search the user types on the Home Screen. These are not toys. A widget that shows stale data, a Lock Screen complication that never updates, a Spotlight result that opens the app but lands nowhere — these are the exact production bugs this lecture inoculates you against.

We take them in the order you hit them on a real project: the App Group first (because nothing else works without it), then the timeline (because that is the widget's core contract), then families and the Lock Screen, then interactive widgets, then Spotlight and the deep-link routing that ties every surface back into your navigation.

---

## 1. The App Group — why a widget can't see your data without it

A widget runs in a **separate process** from your app. Different process, different sandbox, different container. Your app's default SwiftData store lives in *your app's* Application Support directory, which the widget extension **cannot read.** This is the single most common cause of "my widget is blank" or "my widget shows data from three days ago": the extension is looking in its own empty sandbox, not your app's store.

The fix is an **App Group** — a shared container that both the app target and the widget extension target are entitled to, with one shared directory both can read and write.

```swift
// A single source of truth for the group identifier, used by app AND widget.
enum AppGroup {
    static let identifier = "group.com.crunch.hellonotes"

    /// The shared container both processes can reach.
    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }

    /// The SwiftData store, inside the shared container.
    static var storeURL: URL {
        containerURL.appendingPathComponent("Notes.store")
    }
}
```

To enable it: in Xcode, select the **app target ▸ Signing & Capabilities ▸ + Capability ▸ App Groups**, add `group.com.crunch.hellonotes`, then do the **same on the widget extension target** with the **same** group id. Both targets must list the identical group, or they are not actually sharing.

Then you point the SwiftData `ModelContainer` at the group URL — in *both* targets — so they open the same database file:

```swift
import SwiftData

@MainActor
func makeSharedContainer() throws -> ModelContainer {
    let schema = Schema([Note.self, Tag.self])
    let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
    return try ModelContainer(for: schema, configurations: [config])
}
```

The contract:

- **Same group id on both targets**, byte for byte.
- **Same store URL** (`AppGroup.storeURL`) in both the app and the widget — the app writes there, the widget reads there. If the app still uses the *default* store URL and only the widget uses the group URL, they are two different databases and the widget is empty.
- **Small shared values** (a count, a flag) can go in `UserDefaults(suiteName: AppGroup.identifier)` instead of the store — cheaper than opening SwiftData for a single integer the widget needs.

Get this wrong and *every* widget symptom this week is unfixable, because the data simply is not where the widget is looking. Get it right and the rest is straightforward.

---

## 2. The `Widget` and its `TimelineProvider`

A widget is a `Widget` value that pairs a *kind* (a string id), a *configuration*, and a *view*. The configuration carries a **`TimelineProvider`** — the object that hands the system a sequence of dated entries to render over time. The provider has three callbacks, and knowing what each is for is the whole game:

```swift
import WidgetKit
import SwiftUI

// 1. The data each rendered instant needs. Must be a value type; it's snapshotted.
struct RecentNoteEntry: TimelineEntry {
    let date: Date
    let title: String
    let count: Int
}

// 2. The provider that supplies entries.
struct RecentNoteProvider: TimelineProvider {

    // Called for the gallery / loading state. MUST be instant and synchronous.
    // No data fetch here — return believable fake content.
    func placeholder(in context: Context) -> RecentNoteEntry {
        RecentNoteEntry(date: .now, title: "Your most recent note", count: 0)
    }

    // A single representative entry for the widget gallery preview and transitions.
    func getSnapshot(in context: Context, completion: @escaping (RecentNoteEntry) -> Void) {
        completion(currentEntry())
    }

    // The real timeline: zero or more future entries + a reload policy.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentNoteEntry>) -> Void) {
        let entry = currentEntry()
        // Our content only changes when the app writes, so reload "never" on a schedule;
        // we reload explicitly from the app via WidgetCenter when data changes.
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func currentEntry() -> RecentNoteEntry {
        let snapshot = SharedStore.shared.recentNoteSnapshot()   // reads the App Group store
        return RecentNoteEntry(date: .now, title: snapshot.title, count: snapshot.count)
    }
}
```

The three callbacks, demystified:

- **`placeholder(in:)`** must be **instant and data-free.** The system calls it to draw a skeleton while real content loads, and in the gallery. Do *not* fetch from the store here; return believable fake content. A slow placeholder is a janky widget gallery.
- **`getSnapshot`** provides one representative entry for the gallery preview and quick transitions. A real fetch is fine here, but keep it fast.
- **`getTimeline`** is the meat: you return a **`Timeline`** — an array of future-dated `TimelineEntry` values plus a **`TimelineReloadPolicy`**. The system renders each entry at its `date`, then, per the policy, asks you for a new timeline.

### Reload policies and the refresh budget

`TimelineReloadPolicy` decides *when the system comes back to ask for fresh entries*:

- **`.atEnd`** — reload after the last entry's date passes. Use when you can predict the content forward (a countdown, a schedule).
- **`.after(date:)`** — reload at a specific future time. Use for "refresh in an hour."
- **`.never`** — do not reload on a schedule; the app will trigger reloads explicitly. **This is what the notes widget uses,** because note content changes only when the user writes, not on a clock.

Critically: **widget refreshes are budgeted.** The system grants each widget a limited number of timeline refreshes per day (on the order of dozens, not thousands), throttled by usage, battery, and budget. You cannot poll. The two ways content actually updates are: (1) entries you scheduled *ahead of time* in the timeline, and (2) an **explicit reload from the app** when data changes:

```swift
import WidgetKit

// Call this in the app whenever a note is added/edited/deleted.
func notesDidChange() {
    WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
    // or reloadAllTimelines() to refresh every widget you vend
}
```

This is why the App Intent in lecture 1 ended with `WidgetCenter.shared.reloadTimelines(...)`: the intent wrote to the store off-process, and the reload tells WidgetKit "come ask me for a new timeline, the data moved." Together they keep the widget honest.

### Assembling the widget

```swift
struct RecentNoteWidget: Widget {
    let kind = "RecentNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNoteProvider()) { entry in
            RecentNoteWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)   // required iOS 17+
        }
        .configurationDisplayName("Recent Note")
        .description("Shows your most recently edited note.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct HelloNotesWidgets: WidgetBundle {
    var body: some Widget {
        RecentNoteWidget()
        NoteCountWidget()       // the Lock Screen circular, §3
    }
}
```

`StaticConfiguration` is the no-user-configuration form (the widget always shows "the recent note"). If you want the user to pick *which* note in the widget's edit sheet, you use `AppIntentConfiguration` with a configuration intent — same App Intents framework from lecture 1, doing double duty. `.containerBackground(_:for: .widget)` is **required** on iOS 17+; omit it and your widget is rejected and renders wrong on StandBy.

---

## 3. Families — Home Screen, Lock Screen, and StandBy from one view

`supportedFamilies` declares where your widget can live. The families split into groups:

- **Home Screen:** `.systemSmall`, `.systemMedium`, `.systemLarge`, `.systemExtraLarge` (iPad). Full-colour, rich layout.
- **Lock Screen / watch accessories:** `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`. **Monochrome, tiny, vibrant-rendered** — you get a tint, not full colour, and very little space.
- **StandBy** reuses the system families in a landscape, always-on context (device-only).

You adapt one view across families by reading the `\.widgetFamily` environment value:

```swift
struct RecentNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentNoteEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock Screen circular: just the count in a gauge. No room for text.
            Gauge(value: Double(min(entry.count, 99)), in: 0...99) {
                Image(systemName: "note.text")
            } currentValueLabel: {
                Text("\(entry.count)")
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            // Lock Screen rectangular: one line of title + count.
            VStack(alignment: .leading) {
                Text(entry.title).font(.headline).lineLimit(1)
                Text("\(entry.count) notes").font(.caption)
            }

        default:
            // Home Screen small/medium: the full card.
            VStack(alignment: .leading, spacing: 6) {
                Label("Recent", systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
                Text(entry.title).font(.headline).lineLimit(family == .systemSmall ? 3 : 2)
                Spacer()
                Text("\(entry.count) notes total").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
```

The discipline for Lock Screen accessories specifically:

- **Assume monochrome.** The system renders accessory widgets with a vibrancy/tint pass; colour you set is mostly ignored. Design for legibility in a single tint.
- **Assume tiny.** `.accessoryCircular` is a watch-complication-sized circle. One number, one glyph, a gauge — that is the budget. Do not try to fit a sentence.
- **`Gauge`, `Text`, `Image`, `ViewThatFits`** are your tools. Rich SwiftUI mostly does not apply at this size.

For the mini-project's "today's note count on the Lock Screen," a `.accessoryCircular` with a `Gauge` (or just a big `Text("\(count)")`) is exactly right.

---

## 4. Interactive widgets — running an intent in place

Since iOS 17, a widget view can contain a `Button` or `Toggle` that runs an **App Intent** without launching the app. This is where lecture 1 and lecture 2 fuse: the widget renders content, and an embedded intent mutates it, and the system reloads the timeline — all on the Home Screen.

```swift
struct RecentNoteWidgetView: View {
    let entry: RecentNoteEntry

    var body: some View {
        VStack {
            Text(entry.title).font(.headline)
            // Tapping this runs PinNote(note:) in place — no app launch.
            Button(intent: PinNote(noteID: entry.id)) {
                Label(entry.isPinned ? "Pinned" : "Pin", systemImage: entry.isPinned ? "pin.fill" : "pin")
            }
            .tint(.orange)
        }
    }
}
```

The rules:

- **Only `Button(intent:)` and `Toggle(isOn:intent:)`** are interactive inside a widget. Arbitrary gestures are not.
- The intent's `perform()` runs **off-process** (lecture 1's whole point), mutates the **shared App Group store**, and should end by reloading the timeline so the widget redraws with the new state. The system also reloads automatically after an interactive intent completes, but an explicit reload of *related* widgets is still your job.
- The intent must be a **lightweight, fast** action — a flag flip, a counter bump. A long network call inside an interactive widget intent is a bad experience; the user tapped a button on their Home Screen and expects an instant visual response.

This is the challenge for the week: a `Button(intent: ToggleNotePinned(...))` in the widget that pins a note, mutating the shared store, with the change then visible *in the app* when it opens — proving the widget and app are two views of one store.

---

## 5. Spotlight — making content findable, and routing the tap

The last surface: a user searches from the Home Screen, your note's text matches, the result appears, they tap it, and your app deep-links straight to that note. Two halves: **indexing** the content, and **handling the tap**.

### Indexing with `CSSearchableIndex`

```swift
import CoreSpotlight
import UniformTypeIdentifiers

func indexNotesForSpotlight(_ notes: [Note]) async throws {
    let items = notes.map { note -> CSSearchableItem in
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = note.title
        attributes.contentDescription = note.body
        attributes.keywords = note.tags.map(\.name)

        return CSSearchableItem(
            uniqueIdentifier: note.persistentModelID.spotlightID,   // stable, routable id
            domainIdentifier: "notes",                              // lets you batch-delete a domain
            attributeSet: attributes
        )
    }
    try await CSSearchableIndex.default().indexSearchableItems(items)
}

// When a note is deleted, remove it from the index too — or Spotlight shows a ghost.
func deindexNote(id: String) async throws {
    try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id])
}
```

Key points:

- **`uniqueIdentifier`** is what comes back when the user taps the result, so make it a value you can route — derive it from the note's `persistentModelID` (or its `UUID`). This is your deep-link key.
- **`domainIdentifier`** groups items so you can `deleteSearchableItems(withDomainIdentifiers:)` to clear a whole category at once.
- **Keep the index in sync.** Index on add/edit, **de-index on delete.** A note you deleted that still appears in Spotlight (and taps to nothing) is the classic "ghost result" bug.
- On iOS 18, an `AppEntity` that also conforms to **`IndexedEntity`** can index itself through App Intents, unifying the lecture-1 entity with the Spotlight index — one declaration, both surfaces. `CSSearchableIndex` directly is the explicit path you should understand first.

### Handling the tap — the activity continuation

When the user taps a Spotlight result, iOS launches (or foregrounds) your app with an `NSUserActivity` of type `CSSearchableItemActionType`, carrying the `uniqueIdentifier` you indexed. You handle it and route into your navigation — exactly like the `notes://open/:id` deep link from Week 9:

```swift
import CoreSpotlight

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            NotesListView()
                .navigationDestination(for: Note.self) { NoteDetailView(note: $0) }
        }
        // A Spotlight tap arrives here.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let note = SharedStore.shared.note(forSpotlightID: id) else { return }
            path.append(note)   // route into the existing navigation stack
        }
    }
}
```

A **widget** tap routes the same way, via `widgetURL(_:)` (a deep-link URL on the whole widget) or a `Link` (per-element), arriving at your `onOpenURL` — the Week 9 machinery, reused. Every off-process surface — Spotlight result, widget tap, App Intent with `openAppWhenRun` — funnels into the *same* deep-link routing you already built. That is the payoff of modelling navigation as state: a new entry point is a new `path.append`, not a new navigation system.

---

## 6. The failure catalogue — measured, not guessed

Each surface has a signature failure. Learn to recognise the puddle:

| Symptom | Cause | Fix |
|---------|-------|-----|
| Widget is **blank** or shows fake placeholder forever | Extension can't see the store — App Group missing or store URL not shared | Add the *same* App Group to both targets; point `ModelConfiguration(url:)` at `AppGroup.storeURL` in **both** |
| Widget shows **stale** data after the app changed it | No reload was triggered | Call `WidgetCenter.shared.reloadTimelines(ofKind:)` on every write (intent and app) |
| Widget **never** updates even with `.atEnd` | Refresh budget exhausted, or policy is `.never` with no explicit reload | Use explicit `reloadTimelines` for event-driven content; don't expect schedule-based polling |
| Siri **won't match** the phrase | Phrase missing `\(.applicationName)`, or `AppShortcutsProvider` not registered | Put the app-name token in every phrase; confirm the provider type exists and is in the app target |
| Intent **crashes off-process** | Captured a non-`Sendable` singleton / main-actor state that isn't there when the app is terminated | Construct data access inside `perform()` against the shared store; return `Sendable` values |
| Spotlight tap **opens the app but lands nowhere** | `onContinueUserActivity(CSSearchableItemActionType)` not handled, or id not routable | Handle the continuation; route the `uniqueIdentifier` into the nav stack |
| Spotlight shows a **ghost** result (taps to nothing) | Index not updated on delete | `deleteSearchableItems` whenever a note is deleted |

Notice the pattern: almost every widget/intent failure is *the off-process surface can't see, or didn't get told about, the shared store.* Internalise that and you debug this week's surfaces in seconds instead of hours.

---

## 7. Recap

Lecture 1 gave you the verbs; this lecture gave you the content surfaces and the plumbing that feeds them. Three habits carry it:

1. **The App Group is the foundation.** A widget extension is a separate process that cannot see your app's default store. Put the SwiftData store in a shared App Group container, point *both* targets at the same URL, and the widget can finally read what the app wrote. Get this wrong and nothing else works.
2. **Timelines are published, not polled.** You hand the system a `Timeline` of future entries and a reload policy; refreshes are budgeted. For content that changes on user action (like notes), use `.never` and reload explicitly from the app and from your intents with `WidgetCenter.reloadTimelines`. Adapt one view across families by reading `\.widgetFamily`; design Lock Screen accessories for monochrome and tiny.
3. **Every off-process surface routes back through your deep links.** A Spotlight tap (`onContinueUserActivity`), a widget tap (`widgetURL`/`onOpenURL`), an interactive widget intent (`Button(intent:)`) — they all funnel into the navigation-as-state machinery from Week 9. Index content into Spotlight, keep the index in sync on delete, and route the `uniqueIdentifier` into the stack.

You now have both halves of the week: the App Intents that let the system *act* on your app, and the WidgetKit + Spotlight surfaces that let the system *show* and *find* it — all over one shared store. The exercises stand up a real timeline, a real intent, and a real Spotlight index; the mini-project surfaces Hello, Notes on the Home Screen, the Lock Screen, in Siri, and in Spotlight, and proves it all works *without launching the app.* Go make your app appear where the user already is.
