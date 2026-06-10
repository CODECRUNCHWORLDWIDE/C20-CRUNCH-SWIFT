# Week 20 — Exercises

Short, focused drills. Each one should take 40–60 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A first widget on a shared timeline](exercise-01-first-widget-timeline.md)** — add a widget extension, wire an App Group so the extension can see the app's data, and render a `TimelineProvider` that shows the most recent note on the Home Screen. The whole "system surfaces my content" promise, in one exercise. (~55 min)
2. **[Exercise 2 — An `AddNote` App Intent + App Shortcut](exercise-02-add-note-app-intent.swift)** — write an `AppIntent` whose `perform()` mutates the store, register an `AppShortcut` so it works in Siri/Shortcuts with no setup, and reload the widget after the write. You run it from the Shortcuts app and confirm a row appears. (~50 min)
3. **[Exercise 3 — Spotlight indexing + deep-link routing](exercise-03-spotlight-index-and-route.swift)** — index notes into Core Spotlight, keep the index in sync on delete, and route a search-result tap into the navigation stack via the `CSSearchableItemActionType` continuation. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Run on the **iOS Simulator** (iOS 18 recommended, iOS 17 floor). Add the widget to the simulated Home Screen, run the intent from the Shortcuts app, and search Spotlight from the Home Screen — all without a device. (Siri *voice* and StandBy are device-only; the tap/Shortcuts paths exercise the same code.)
- The `.swift` exercises are written to drop into your Hello, Notes app target (and its widget/test targets) over the shared App Group store. Each file's header says where it goes.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — an App Intent's `perform()` runs off-process and the compiler is right to hold you to it.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-20` to compare.
