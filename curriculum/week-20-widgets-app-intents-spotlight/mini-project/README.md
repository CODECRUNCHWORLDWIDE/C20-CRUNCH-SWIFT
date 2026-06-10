# Mini-Project — Hello, Notes: surfaced everywhere

This week the notes app leaves its window. You will extend **Hello, Notes** — your SwiftData app from Week 10, well-architected from Week 11 — so that it appears across iOS *without being launched*: a **Home Screen widget** showing the most recent note, a **Lock Screen widget** showing today's note count, an **`AddNote` App Intent** wired into an **App Shortcut** so Siri can add a note with zero setup, and **Spotlight indexing** so searching a note's text from the Home Screen deep-links straight into it.

This is a *compounding* project. It is not a new app. You start from the Week 11 codebase — SwiftData store, `NavigationStack`/`NavigationSplitView` layout, the `notes://open/:id` deep link — and you add a widget extension target, an App Intents surface, and a Spotlight index *on top of the existing store.* The point of the week is to feel how every new surface is just another *client* of the data layer you already built, and how every entry point routes back through the navigation-as-state you got right in Week 9.

---

## Where you're starting from

Your Week 11 app has, roughly:

- A `@Model final class Note` (and `Tag`) persisted in SwiftData, queried via `@Query`.
- A `NavigationSplitView` (iPad/Mac) / `NavigationStack` (iPhone) layout with a list and a detail editor.
- A `notes://open/:id` deep link handled in `onOpenURL` that pushes a note onto the navigation path.
- A clean data layer (a store/repository or a thin context wrapper from Week 11).

If you don't have a clean Week 11 checkpoint, the Week 10 SwiftData version is enough to build on; the surface work is the same either way.

## What you're building toward

By the end you have:

- The SwiftData store relocated into a shared **App Group** container, readable by the widget extension.
- A **Home Screen widget** (`.systemSmall` + `.systemMedium`) showing the most recent note via a `TimelineProvider`, reloaded on every write.
- A **Lock Screen widget** (`.accessoryCircular` + `.accessoryRectangular`) showing today's note count.
- An **`AddNote` App Intent** whose `perform()` writes to the shared store off-process, plus a **`ShowNoteCount`** query intent.
- An **`AppShortcutsProvider`** registering Siri phrases (every one with `\(.applicationName)`), so "add a note in Hello Notes" works with no user setup.
- **Spotlight indexing** of every note, kept in sync on delete, with a tapped result deep-linking into the navigation stack.
- A passing **"without launching the app" proof**: add via Siri/Shortcuts while terminated, see the widget update, search Spotlight and land on the note — all without foregrounding the app first.

---

## Milestone 1 — Move the store into an App Group (≈ 1 h)

Nothing else works until the widget can see the data. Create the shared constant, enable the capability on the **app target** (and, after Milestone 2, the widget target), and point the container at the group URL.

```swift
import Foundation

enum AppGroup {
    static let identifier = "group.com.yourname.hellonotes"
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }
    static var storeURL: URL { containerURL.appendingPathComponent("Notes.store") }
}
```

```swift
@main
struct HelloNotesApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema([Note.self, Tag.self])
            let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch { fatalError("shared container: \(error)") }
    }()
    var body: some Scene {
        WindowGroup { RootView() }.modelContainer(container)
    }
}
```

Decisions you must defend in review:

- **Why an App Group at all?** The widget extension is a separate process with its own sandbox; it cannot read the app's default store. The group is the only shared directory both can reach. (Lecture 2, §1.)
- **Why relocate the existing store?** If the app keeps writing to the default location and only the widget reads the group, they are two databases and the widget is empty. One store, one URL, both targets. *(If you have existing user data in the default store, copy it into the group on first launch — note that as a real migration concern.)*

## Milestone 2 — The Home Screen widget (≈ 2 h)

Add a **Widget Extension** target (`NotesWidget`), enable the **same** App Group on it, and give it membership of `Note.swift`, `AppGroup.swift`, and a shared read helper. Build a `TimelineProvider` and a view.

```swift
struct RecentNoteEntry: TimelineEntry {
    let date: Date
    let noteUID: UUID
    let title: String
    let count: Int
}

struct RecentNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentNoteEntry {
        RecentNoteEntry(date: .now, noteUID: UUID(), title: "Your most recent note", count: 0)
    }
    func getSnapshot(in context: Context, completion: @escaping (RecentNoteEntry) -> Void) {
        Task { @MainActor in completion(SharedStore.recentEntry()) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentNoteEntry>) -> Void) {
        Task { @MainActor in
            completion(Timeline(entries: [SharedStore.recentEntry()], policy: .never))
        }
    }
}
```

The view reads `\.widgetFamily` and adapts (lecture 2, §3). Use `fetchLimit = 1` and `fetchCount` in the read helper — the Week 10 footguns matter doubly in a budget-constrained extension. Reload from the app on every write:

```swift
func notesDidChange() {
    WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
}
```

Call `notesDidChange()` from your store wherever a note is added/edited/deleted. Add the widget to the simulated Home Screen and confirm it shows the current most recent note.

## Milestone 3 — The Lock Screen widget (≈ 1 h)

Add `.accessoryCircular` and `.accessoryRectangular` to `supportedFamilies` and branch the view. The circular shows today's note count; the rectangular shows the recent note's title plus the count. Design for **monochrome and tiny** (lecture 2, §3).

```swift
case .accessoryCircular:
    Gauge(value: Double(min(entry.count, 99)), in: 0...99) {
        Image(systemName: "note.text")
    } currentValueLabel: {
        Text("\(entry.count)")
    }
    .gaugeStyle(.accessoryCircular)
```

"Today's count" means notes created since `Calendar.current.startOfDay(for: .now)` — compute it with a `#Predicate` in the read helper, not by fetching all and filtering. Add the widget to the Lock Screen in the Simulator (Settings ▸ customise the Lock Screen, or the lock-screen editor) and confirm the count.

## Milestone 4 — The `AddNote` App Intent + App Shortcut (≈ 2 h)

Add `AddNote` and `ShowNoteCount` intents (lecture 1, §2) to the app target. Each constructs its own store access against `AppGroup.storeURL` and returns only `Sendable` values. Register the shortcuts:

```swift
struct NotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddNote(),
                    phrases: ["Add a note in \(.applicationName)",
                              "New \(.applicationName) note"],
                    shortTitle: "Add Note", systemImageName: "square.and.pencil")
        AppShortcut(intent: ShowNoteCount(),
                    phrases: ["How many notes in \(.applicationName)"],
                    shortTitle: "Note Count", systemImageName: "number")
    }
}
```

`AddNote.perform()` ends with `WidgetCenter.shared.reloadTimelines(...)` so the widget reflects the new note. Test from the **Shortcuts app**: find "Hello Notes," run "Add Note," type text, confirm a row appears in the app *and* the widget total ticks up.

Decisions you must defend:

- **Why construct the store inside `perform()`?** The intent runs off-process, possibly with the app terminated. A captured app singleton would be nil. (Lecture 1, §2; §7.)
- **Why `\(.applicationName)` in every phrase?** It's the anchor token Siri uses to route the request to your app. A phrase without it is ignored. (Lecture 1, §3.)

## Milestone 5 — Spotlight indexing + deep-link routing (≈ 1.5 h)

Index every note into Core Spotlight, keep the index in sync on delete, and route a tapped result into the navigation stack (lecture 2, §5). Add a stable `var uid = UUID()` to `Note` and index/resolve by it.

```swift
.onContinueUserActivity(CSSearchableItemActionType) { activity in
    guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
          let note = notes.first(where: { $0.uid.uuidString == id }) else { return }
    path.append(note)
}
```

Index on add/edit and at launch; `deleteSearchableItems` on delete so there are no ghost results. Search a note's text from the Home Screen, tap it, and land on the exact note via the *same* `NavigationPath` your `NavigationLink`s use.

## Milestone 6 — Schema versioning for the new field (≈ 0.5 h)

Adding `uid` and (if you do the challenge) `isPinned` are schema changes. Wrap them in a `VersionedSchema` V2 with a **lightweight** `MigrationStage` (both are additive/defaulted), exactly as Week 10's exercise 03 taught. Test the *upgrade* path (seed a V1 store, open with V2), not just a fresh install — or the next release deletes a user's notes.

## Milestone 7 — The "without launching the app" proof (≈ 0.5 h)

The acceptance bar for the whole week.

1. Launch the app once, add two notes. Force-quit: `xcrun simctl terminate booted <your.bundle.id>`.
2. From the **Shortcuts app** (app still terminated), run "Add Note" with text "buy milk." A note is created.
3. Look at the Home Screen widget — it shows "buy milk" as the most recent note, and the count went up — **without the app foregrounding.**
4. Look at the Lock Screen widget — today's count reflects the three notes.
5. Search Spotlight (swipe down on the Home Screen) for "milk," tap the result — the app opens **directly on that note.**

Record this as a short clip or screenshot sequence in your repo's README. "It surfaced without launching" is the deliverable.

---

## Acceptance criteria

- [ ] The SwiftData store lives in a shared **App Group**; the capability is on **both** the app and widget targets with the **same** id; the container points at `AppGroup.storeURL` in both.
- [ ] A **Home Screen widget** (`.systemSmall` + `.systemMedium`) shows the current most recent note via a `TimelineProvider`, reloaded on every write.
- [ ] A **Lock Screen widget** (`.accessoryCircular` + `.accessoryRectangular`) shows today's note count, computed with a `#Predicate` (not fetch-all-then-filter).
- [ ] An **`AddNote` App Intent** whose `perform()` writes to the shared store off-process and reloads the widget, plus a **`ShowNoteCount`** query intent.
- [ ] An **`AppShortcutsProvider`** with Siri phrases that all contain `\(.applicationName)`; running "Add Note" from the Shortcuts app adds a durable note.
- [ ] **Spotlight indexing** of notes, kept in sync on delete, with a tapped result deep-linking into the navigation stack via `onContinueUserActivity(CSSearchableItemActionType)`.
- [ ] The Week 9/10 navigation (`NavigationSplitView`/`NavigationStack`, value-typed links, the `notes://open/:id` deep link) **still works** unchanged.
- [ ] A `VersionedSchema` + lightweight `SchemaMigrationPlan` covering the new `uid`/`isPinned` fields, with the upgrade path tested.
- [ ] **The "without launching" proof passes:** add via Shortcuts while terminated, widget updates, Spotlight result deep-links — all without foregrounding the app first.
- [ ] Build with **0 warnings, 0 errors** across all targets, including Swift 6 strict concurrency.

## Stretch goals

- **Interactive pin button** (the challenge): a `Button(intent: ToggleNotePinned(...))` in the widget, mutating the shared store off-process.
- **Configurable widget.** Use `AppIntentConfiguration` so the user picks *which* tag's notes the widget shows — a configuration intent with an `AppEnum` or `AppEntity` parameter (lecture 1, §4).
- **`IndexedEntity` (iOS 18).** Replace the explicit `CSSearchableIndex` calls by making `NoteEntity` conform to `IndexedEntity` and let App Intents index it — one declaration feeding both Shortcuts and Spotlight.
- **StandBy layout.** Tune the `.systemSmall` view for StandBy (device-only to verify), with a larger, glanceable title.

## What this milestone earns you

You can now ship a Widget Timeline and an App Intent that survives the Shortcuts gallery — the literal "skill earned" line for the week. More than that: you turned a single-window app into a service the system surfaces on the Home Screen, the Lock Screen, in Siri, and in Spotlight, all over one shared store, with every entry point routing back through the navigation you built in Week 9. That "my app appears where the user already is" capability is a third of the capstone's Widgets/Intents/Live-Activity rubric. Week 21 adds the real-time half — a Live Activity that updates live via a backend push — but the off-process, shared-state discipline you earned this week is exactly what that builds on.
