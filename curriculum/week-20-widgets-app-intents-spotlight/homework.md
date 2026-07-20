# Week 20 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 20 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+ (iOS 18 for `IndexedEntity` and StandBy), Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**.

---

## Problem 1 — Prove the App Group container is shared

**Problem statement.** With your Hello, Notes app and widget both pointed at the App Group store, add five notes in the app, then locate the **App Group** container (not the app's own sandbox) and inspect the store. Write your findings into `notes/app-group-anatomy.md`: the path to the group container, the path to `Notes.store` inside it, the `ZNOTE` row count from `sqlite3`, and one sentence on why the widget reads *this* file and not the app's default Application Support store.

**Acceptance criteria.**

- `notes/app-group-anatomy.md` exists with the group container path, the store path, the `ZNOTE` count, and the explanation sentence.
- The paths and count are quoted from your actual run, not invented.
- Committed.

**Hint.** `xcrun simctl get_app_container booted group.com.yourname.hellonotes` (note the **group** id, not the app bundle id) gives the shared container. `find` for `Notes.store`, then `sqlite3 <path> "SELECT COUNT(*) FROM ZNOTE;"`.

**Estimated time.** 30 minutes.

---

## Problem 2 — A parameterized App Intent with a confirmation

**Problem statement.** Add a `DeleteNotesOlderThan` App Intent with an `@Parameter var days: Int` (default 30) that deletes notes older than `days` from the shared store and returns a `ProvidesDialog` confirming how many it deleted. Because deletion is destructive, require confirmation before it runs.

**Acceptance criteria.**

- The intent takes a typed `Int` parameter with a default and a `parameterSummary`.
- It requests confirmation (`requestConfirmation`) before deleting and returns a dialog like "Deleted 4 notes older than 30 days."
- It constructs its store access against `AppGroup.storeURL` (off-process safe) and reloads the widget after.
- 0 warnings. Committed.

**Hint.** Inside `perform()`, `try await requestConfirmation(result: .result(dialog: "Delete N notes older than \(days) days?"))` before doing the delete. Compute the cutoff with `Calendar.current.date(byAdding: .day, value: -days, to: .now)` and a `#Predicate { $0.createdAt < cutoff }`.

**Estimated time.** 50 minutes.

---

## Problem 3 — A second widget family: today's notes list

**Problem statement.** Add a `.systemMedium` widget that lists the **three** most recent notes (title + time), reading from the shared store with a bounded fetch. Make sure the placeholder is instant and data-free, and that the timeline reloads when the app writes.

**Acceptance criteria.**

- A `.systemMedium` view showing up to three recent notes; `placeholder` returns fake data instantly.
- The read uses `FetchDescriptor` with `fetchLimit = 3` and a `createdAt` sort — not a full-table fetch.
- The widget refreshes after an app-side `reloadTimelines`.
- 0 warnings. Committed.

**Hint.** Your `TimelineEntry` can carry a small `[NoteSnapshot]` value (titles + dates), not live model objects. `ViewThatFits` or a simple `ForEach` over the three snapshots renders the list.

**Estimated time.** 45 minutes.

---

## Problem 4 — App Shortcut phrases that Siri actually matches

**Problem statement.** Audit your `AppShortcutsProvider`. For each `AppShortcut`, list at least three natural phrasings, **all** containing `\(.applicationName)`. Then write `notes/shortcut-phrases.md` explaining: why every phrase needs the app-name token, why you list synonyms, and what happens to a phrase that omits the token.

**Acceptance criteria.**

- Each App Shortcut has ≥ 3 phrases, each with `\(.applicationName)`.
- `notes/shortcut-phrases.md` answers the three questions correctly and in your own words.
- The shortcuts appear and run in the Simulator's Shortcuts app.
- Committed.

**Hint.** Run the app, then pull-to-refresh the Shortcuts gallery to see your app's section populate. If a shortcut doesn't appear, the provider isn't registered or the app hasn't run since you added it.

**Estimated time.** 35 minutes.

---

## Problem 5 — Keep the Spotlight index honest

**Problem statement.** Wire Spotlight indexing so that adding, editing, and deleting a note each keep the index correct: add/edit re-indexes the item, delete removes it. Then write a test (or a documented manual procedure) proving a deleted note no longer appears in Spotlight and an edited note's new title is findable.

**Acceptance criteria.**

- Indexing happens on add and edit (`indexSearchableItems`) and de-indexing on delete (`deleteSearchableItems`).
- A documented proof (test or step-by-step with screenshots) that: a deleted note is gone from Spotlight, and an edited title is findable under the new text.
- The `uniqueIdentifier` is a stable, routable key (a `UUID`), used identically at index and resolve time.
- 0 warnings. Committed.

**Hint.** Edit = re-index the single item (indexing the same `uniqueIdentifier` overwrites it). For the "edited title findable" proof, change a note's title, re-index, then search the new title. For the ghost test, delete and confirm it's gone after `deleteSearchableItems`.

**Estimated time.** 45 minutes.

---

## Problem 6 — Route a widget tap into the navigation stack

**Problem statement.** Make the Home Screen widget tappable so tapping it opens the app on the most-recent note. Use `widgetURL(_:)` (whole-widget) with a `notes://open/<uid>` URL, handle it in `onOpenURL`, and route into the same `NavigationPath` your `NavigationLink`s use — reusing the Week 9 deep-link machinery.

**Acceptance criteria.**

- The widget sets `.widgetURL(URL(string: "notes://open/\(entry.noteUID)")!)`.
- `onOpenURL` parses the host/path, resolves the `uid` to a note, and `path.append`s it.
- Tapping the widget opens the app directly on that note.
- 0 warnings. Committed.

**Hint.** This is the exact shape of the Spotlight continuation (exercise 3), just arriving via `onOpenURL` instead of `onContinueUserActivity`. Parse the URL, look up the note by `uid`, append. Both entry points should funnel into one routing function so you don't duplicate the logic.

**Estimated time.** 45 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/WidgetKit/App Intents, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a full-table fetch where a bounded one was the point, a missing `reloadTimelines` on one write path). |
| 3 | Works, but misses one criterion (e.g. a phrase without `\(.applicationName)`, an intent capturing an app singleton, Spotlight not de-indexed on delete). |
| 2 | Compiles and partially works; a core idea is wrong (widget reads the app's default store instead of the App Group; intent crashes when the app is terminated). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for a widget or intent that reads the app's default store instead of the shared App Group store; **−1** for a full-table fetch where a `fetchLimit`/`fetchCount`/`#Predicate` was the point.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the App Group that shares the store (problems 1, 3, 6) and the off-process `perform()` (problems 2, 4) — so re-run exercises 01 and 02 before resubmitting.
