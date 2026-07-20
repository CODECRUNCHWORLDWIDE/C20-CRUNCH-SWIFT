# Week 20 — Widgets, App Intents, Shortcuts, Spotlight

Welcome to Week 20 of **C20 · Crunch Swift**. For nineteen weeks your app has lived inside its own window. The user launches it, it draws a screen, they tap around, they leave. This week the app breaks out of that box. By Friday a fragment of your notes app renders on the Home Screen without anyone launching it, today's note count shows on the Lock Screen, and a user can say "Hey Siri, add a note saying buy milk" — and a row appears in your SwiftData store — *without your app's UI ever coming to the foreground.* This is the week the app stops being a place you go and becomes a service the system surfaces on your behalf.

Three Apple frameworks make that happen, and they share one big idea: **the rest of iOS becomes a client of your app's data and actions.** **WidgetKit** lets the system render slices of your content on the Home Screen, Lock Screen, and in StandBy, on a timeline you publish ahead of time. **App Intents** declares the things your app can *do* — "add a note," "show today's count," "pin a note" — as typed, parameterised, system-discoverable verbs, which iOS then offers up in Shortcuts, Siri, the action button, Spotlight, and (since iOS 17) inside the widgets themselves as tappable buttons. **Core Spotlight** indexes your content so a user searching from the Home Screen finds the actual note, taps it, and deep-links straight in. Underneath, the common thread is that you are no longer in control of *when* your code runs. The widget extension is woken by the system on a budget. The intent is invoked from a Siri request you never see coming. The Spotlight index is queried by a process that is not yours. Designing for "the system calls me, not the other way around" is the mental shift of the week.

The thing that makes 2026 different from the iOS-14-widget era is **App Intents as the spine**. The old world had three disconnected technologies: `IntentDefinition` files for Siri (a visual editor, code-gen, and a separate intents extension), `WidgetKit` configuration done with those same intent files, and `CSSearchableItem` for Spotlight done by hand. The App Intents framework — pure Swift, no `.intentdefinition` file, no code-gen — unified all of it. One `struct AddNote: AppIntent` is simultaneously a Shortcuts action, a Siri phrase, an interactive widget button's payload, an App Shortcut that needs no user setup, and (with `IndexedEntity`) a Spotlight-searchable entity. You write the verb once; the system wires it into every surface. This week teaches App Intents *first* and treats Widgets and Spotlight as consumers of it, because that is how the platform is actually shaped now.

We close the week by extending **Hello, Notes** (now a real SwiftData app from Week 10, well-architected from Week 11) with a full surface area: a **Home Screen widget** that shows the most recent note via a `TimelineProvider`, a **Lock Screen widget** showing today's note count in an `.accessoryCircular` family, an `AddNote` **App Intent** wired into an **App Shortcut** so "add a note saying …" works in Siri with zero user configuration, and **Spotlight indexing** so searching a note's text from the Home Screen deep-links into it. You will share the SwiftData store with the widget extension through an **App Group**, because the number-one reason a widget shows stale or empty data is that the extension cannot see the app's database — and getting the App Group right is half the battle this week wins.

## Learning objectives

By the end of this week, you will be able to:

- **Explain** the system-as-client model — that a Widget extension, an App Intent, and a Spotlight query each run *outside* your app process, on the system's schedule, against shared storage — and design data access accordingly.
- **Build** a Widget with the `Widget` / `TimelineProvider` protocols: implement `placeholder`, `snapshot`, and `timeline`, choose a `TimelineReloadPolicy`, and select the right `WidgetFamily` for Home Screen, Lock Screen (`.accessory*`), and StandBy.
- **Share** data into a widget extension through an **App Group** container, reading the same SwiftData store the app writes, and trigger widget reloads with `WidgetCenter.shared.reloadTimelines`.
- **Author** an `AppIntent` with typed `@Parameter`s, a `perform()` that mutates the SwiftData store, and a human-readable `title`/`description`, and expose it to Shortcuts.
- **Register** an `AppShortcutsProvider` so an intent works in Siri with a fixed phrase and **no** user setup, and understand the phrase-and-synonym rules Siri matches against.
- **Wire** an interactive widget: a `Button(intent:)` / `Toggle(isOn:intent:)` inside a widget that runs an App Intent in place, with no app launch.
- **Index** content into Spotlight with `CSSearchableIndex` (or `IndexedEntity` via App Intents), handle the `userActivity`/`spotlight` deep-link continuation, and route the result into your navigation stack.
- **Diagnose** the canonical failures — a widget that never updates, a blank widget, an intent Siri won't match, a Spotlight tap that opens the app but lands nowhere — and fix each at the right layer.

## Prerequisites

This week assumes you have completed **C20 weeks 1–19**, or have equivalent fluency. Specifically:

- You can model and query a **SwiftData** schema — `@Model`, `ModelContainer`, `ModelContext`, `@Query`, `#Predicate` — from Week 10. The widget reads the same store the app writes; everything this week sits on top of that persistence layer.
- You understand `Sendable`, `@MainActor`, and actor isolation from Week 4. An App Intent's `perform()` is `async`, runs outside your app, and is held to Swift 6 strict concurrency — and a `ModelContext` is still not `Sendable`.
- You can model navigation as state and handle deep links with `onOpenURL` / `onContinueUserActivity` from Week 9. A Spotlight tap and a widget tap both arrive as a deep link you must route, exactly like `notes://open/:id`.
- You have the **Hello, Notes** app from Weeks 7–11 in Git, on SwiftData, with its `NavigationStack`/`NavigationSplitView` layout. This week's mini-project compounds directly onto it: a widget extension target, an intents surface, and a Spotlight index, all over the existing store.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 with an iOS 17 floor. Widgets, App Intents, and Core Spotlight all run in the **Simulator** for the bulk of this week — you can add a widget to the simulated Home Screen, invoke an intent from the Shortcuts app, and search Spotlight. Two things need a **physical device** and therefore (per the syllabus) an Apple Developer membership you already have from Phase III: Siri voice invocation of an App Shortcut, and the StandBy widget environment. We flag those as device-only as we reach them; everything else is Simulator-friendly.

## Topics covered

- **The extension model.** What a widget extension is (a separate process, a separate target, a separate bundle), why it cannot see your app's main store without an App Group, and the memory/time budget the system enforces on it.
- **`Widget` and `TimelineProvider`.** The three callbacks — `placeholder(in:)`, `snapshot(for:in:)`, `timeline(for:in:)` — what each is for, when the system calls each, and why `placeholder` must be instant and data-free.
- **Timelines and reload policies.** `TimelineEntry`, building a `Timeline` of future entries, `TimelineReloadPolicy` (`.atEnd`, `.after(date:)`, `.never`), the daily refresh budget, and `WidgetCenter.shared.reloadTimelines(ofKind:)` for event-driven updates.
- **Widget families.** `.systemSmall/.systemMedium/.systemLarge/.systemExtraLarge` (Home Screen), `.accessoryCircular/.accessoryRectangular/.accessoryInline` (Lock Screen + watch), StandBy, and `supportedFamilies`. The `WidgetFamily` environment value and adapting one view across families.
- **App Groups.** `group.com.example.notes` capability, the shared container URL, putting the SwiftData store in the group so app and widget share it, and `UserDefaults(suiteName:)` for small shared values.
- **App Intents — the framework.** `AppIntent`, `@Parameter`, `perform()` returning `some IntentResult`, `static var title`, parameter summaries, `openAppWhenRun`, and why this replaces `.intentdefinition` entirely.
- **App Shortcuts.** `AppShortcutsProvider`, `AppShortcut(intent:phrases:)`, the `\(.applicationName)` phrase token, why App Shortcuts need **zero** user setup, and the synonym/phrase matching rules.
- **Interactive widgets.** `Button(intent:)` and `Toggle(isOn:intent:)` inside `WidgetKit` views (iOS 17+), running an intent in place, and the reload that follows.
- **App Entities and Spotlight.** `AppEntity`, `EntityQuery`, `IndexedEntity`, `CSSearchableIndex`, `CSSearchableItem` and `CSSearchableItemAttributeSet`, indexing notes, and the `CSSearchableItemActionType` continuation.
- **Deep-link routing.** `onContinueUserActivity(CSSearchableItemActionType)`, `widgetURL(_:)` and `Link` inside widgets, and routing a Spotlight/widget tap into the existing navigation state.
- **The failure catalogue.** Stale/blank widget (App Group missing, store not shared, reload never triggered), Siri won't match (phrase rules, App Shortcut not registered), Spotlight tap lands nowhere (continuation not handled), intent crashes off-process (main-actor/Sendable mistakes).

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | The extension model; App Intents framework; `perform()`            |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `Widget` + `TimelineProvider`; families; App Groups                |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | App Shortcuts + Siri; interactive widgets; challenge starts        |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | App Entities + Spotlight indexing; deep-link routing; challenge    |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — widget + Lock Screen + AddNote intent over the store |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; Spotlight index + deep-link verification    |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                          |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Apple's WidgetKit / App Intents / Core Spotlight docs, the WWDC sessions, and the canonical community writing on App Groups, interactive widgets, and Spotlight |
| [lecture-notes/01-app-intents-the-new-contract.md](./lecture-notes/01-app-intents-the-new-contract.md) | App Intents end to end: the system-as-client model, `AppIntent`/`@Parameter`/`perform()`, `AppShortcutsProvider` + Siri, `AppEntity`/`EntityQuery`, and why this replaced `.intentdefinition` |
| [lecture-notes/02-widgetkit-timelines-app-groups-spotlight.md](./lecture-notes/02-widgetkit-timelines-app-groups-spotlight.md) | WidgetKit timelines, families and Lock Screen accessories, the App Group that shares the SwiftData store, interactive widgets, Spotlight indexing, and the deep-link routing that ties it together |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-first-widget-timeline.md](./exercises/exercise-01-first-widget-timeline.md) | Stand up a widget extension, share data via an App Group, and render a `TimelineProvider` on the Home Screen |
| [exercises/exercise-02-add-note-app-intent.swift](./exercises/exercise-02-add-note-app-intent.swift) | Write an `AddNote` `AppIntent` that mutates the store, register an `AppShortcut`, and test it in Shortcuts/Siri |
| [exercises/exercise-03-spotlight-index-and-route.swift](./exercises/exercise-03-spotlight-index-and-route.swift) | Index notes into Core Spotlight and route a search-result tap into the navigation stack via the activity continuation |
| [challenges/README.md](./challenges/README.md) | Index of the challenge |
| [challenges/challenge-01-interactive-widget-pin.md](./challenges/challenge-01-interactive-widget-pin.md) | Add an interactive `Button(intent:)` to the widget that pins/unpins a note in place — no app launch — and prove the reload propagates back to the app |
| [quiz.md](./quiz.md) | 13 questions on the extension model, timelines, App Groups, App Intents, App Shortcuts, interactive widgets, and Spotlight |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for "Hello, Notes — surfaced everywhere": Home + Lock Screen widgets, an `AddNote` App Intent + Shortcut, and Spotlight deep-linking, all over the shared store |

## The "without launching the app" promise

Week 10 gave you "survives a cold launch." Week 20 adds the surface-area contract a senior reviewer checks before they believe your widget feature is real:

> **The app's value must appear without the app being open.** The widget must show the *correct current* most-recent note when the user looks at the Home Screen, without launching the app first. The App Shortcut must run from Siri while the app is fully terminated. The Spotlight result must appear from a search the user types on the Home Screen, and tapping it must land on the exact note. If any of these only works *after* you open the app once, the feature is broken — the whole point is that the system surfaces your content while your UI is asleep.

You will *prove* this by force-quitting the app, adding the widget, invoking the intent from Siri/Shortcuts, and searching Spotlight — all without bringing the app to the foreground first. "It worked after I opened the app" is not the test; the system surfaces are supposed to run *instead of* opening the app.

## A note on what's not here

Week 20 is the *static surfaces and discrete actions* week. It deliberately does **not** cover:

- **Live Activities and the Dynamic Island.** Real-time, continuously-updating activities driven by a push are Week 21's entire topic. This week's widgets refresh on a *timeline* (minutes-to-hours granularity, a daily budget); a Live Activity updates in seconds and lives in a different part of ActivityKit. Don't confuse a Lock Screen *widget* with a Lock Screen *Live Activity* — they look adjacent and are completely different mechanisms.
- **Background fetch and processing.** Refreshing widget data on a schedule with `BGAppRefreshTask` is also Week 21. This week we reload the timeline from the app on a data change (`WidgetCenter.reloadTimelines`) and let the system's timeline budget handle the rest.
- **Push-driven widget updates.** Updating a widget from an APNs push is real but it leans on the same background machinery as Week 21; we do data-change-driven reloads here and push-driven updates there.

The point of Week 20 is narrow and deep: one shared store, the widget timeline that renders it, the App Intent that mutates it from anywhere, the App Shortcut that gives it a Siri phrase, and the Spotlight index that makes its content findable — the four ways the system surfaces an app that is not currently open.

## Up next

Continue to **Week 21 — Live Activities, ActivityKit, background processing** once you have shipped this week's mini-project and proven the "without launching the app" surfaces. Week 21 takes the same notes app real-time: when another device starts editing your note, a **Live Activity** appears on your Lock Screen and in the Dynamic Island and updates *live* via an APNs push from the Vapor backend, and a **background task** keeps the widget's data fresh on a schedule. Week 20 surfaced your app statically; Week 21 surfaces it in motion. Both are the "your app, everywhere on iOS" half of the capstone, and the capstone rubric scores Widgets, App Intents, and Live Activities together — earn the static half this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
