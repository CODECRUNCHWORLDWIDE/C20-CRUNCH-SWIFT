# Week 21 — Live Activities, ActivityKit, background processing

Welcome to Week 21 of **C20 · Crunch Swift**. Last week your app learned to *appear* where the user already is — a static widget on the Home Screen, a Lock Screen complication, a Siri phrase, a Spotlight result. This week it learns to appear *in motion.* By Friday, when another device starts editing one of your shared notes, a **Live Activity** materialises on your Lock Screen and in the **Dynamic Island**, and it updates *live* — second by second — driven by an **APNs push from the Vapor backend**, while your app sits terminated in the background. And a **background task** keeps the app's data fresh on a schedule the system grants you, not one you demand. This is the real-time iOS surface: the part of the platform that shows your app's *now*, not its last-saved state.

Two ideas separate this week from Week 20, and getting them straight is the whole game. The first is **time granularity.** A widget refreshes on a *timeline* — minutes to hours, on a tight daily budget; you publish entries ahead and the system renders them when their date arrives. A **Live Activity** updates on the order of *seconds*, lives for up to several hours, and is meant for one *ongoing event* — a delivery en route, a game in progress, a workout, a note being edited right now. They look adjacent on the Lock Screen and are completely different mechanisms. The second idea is **who drives the update.** A widget you reload from your own app on a data change. A Live Activity, once started, is updated either locally (when your app is foregrounded) or — the production pattern — remotely, by an **APNs push to the activity's push token**, so it stays live even though your app is asleep. The backend becomes the thing that moves the pixels on the user's Lock Screen.

The third pillar of the week is **background processing**, because real-time and background are two sides of the same constraint: *the system decides when your code runs, and it is stingy about it.* The **BackgroundTasks** framework gives you two scheduled lanes — `BGAppRefreshTask` for short, frequent freshness work ("pull the latest, update the widget") and `BGProcessingTask` for longer, deferrable work ("re-index everything, run maintenance") that the system runs when the device is idle and charging. You register them, you schedule them, and then you *wait* — the OS runs them on its terms, throttled by usage patterns, battery, and **Low Power Mode**, which changes everything: background refresh is curtailed, Live Activity updates slow, push delivery is deprioritised. A senior engineer designs for the device that is at 12% battery in Low Power Mode, not the one plugged in on the desk.

We close the week by adding a **"shared-note edit in progress" Live Activity** to Hello, Notes: when another device starts editing a note you have open, an activity appears showing who is editing and for how long, rendered in compact, minimal, and expanded **Dynamic Island** layouts and on the Lock Screen, and updated *live* by an **APNs push from the Vapor backend** — including the iOS 17+ **push-to-start** path where the activity begins from a push without your app starting it. You will also wire a `BGAppRefreshTask` that refreshes the notes and the widget on the system's schedule, and prove the whole thing degrades sanely under Low Power Mode. This is the capstone's real-time surface, built end to end.

## Learning objectives

By the end of this week, you will be able to:

- **Distinguish** a Live Activity from a Widget — by time granularity (seconds vs minutes-to-hours), lifetime (hours, one event vs indefinite), and update driver (push to a token vs app-side timeline reload) — and pick the right one for a given feature.
- **Define** an `ActivityAttributes` with a static configuration and a dynamic `ContentState`, and start, update, and end an activity from your app with `Activity.request`, `activity.update`, and `activity.end`.
- **Build** the three Dynamic Island presentations (compact leading/trailing, minimal, expanded) plus the Lock Screen / banner view, and choose what each shows from the same `ContentState`.
- **Drive** a Live Activity remotely with an **APNs push** to the activity's `pushToken`, including the `content-state` JSON payload, the `event` (`update`/`end`), `stale-date`, and `dismissal-date`.
- **Implement** iOS 17+ **push-to-start**: register for `pushToStartToken`, send the start payload from the backend, and have the activity begin while the app is terminated.
- **Register and schedule** background work with `BGAppRefreshTask` (short freshness) and `BGProcessingTask` (long, idle-time), handle the expiration handler, and complete the task correctly.
- **Reason** about Low Power Mode and the background budget — what gets throttled, how to detect it (`ProcessInfo.isLowPowerModeEnabled`), and how to degrade gracefully (longer `stale-date`, fewer pushes, deferrable processing).
- **Diagnose** the canonical failures — an activity that won't start, a push that never lands, a Dynamic Island that's blank, a background task that never fires — and fix each at the right layer.

## Prerequisites

This week assumes you have completed **C20 weeks 1–20**, or have equivalent fluency. Specifically:

- You shipped a **Widget**, an **App Intent**, an **App Group**, and Spotlight routing in Week 20. A Live Activity's UI is built with the *same WidgetKit view code*, in the *same widget extension*, and shares data through the *same App Group* — this week stands directly on that scaffolding.
- You built the **APNs push pipeline** and a **Notification Service Extension** in Week 18, and you have the **Vapor backend** from Phase I that sends pushes. A Live Activity is updated by an APNs push with a different topic suffix; you already know how to mint an auth key and send a payload.
- You understand `Sendable`, `@MainActor`, actor isolation (Week 4), and `async/await` (Week 3). Starting and updating an activity is `async`, the push token arrives over an `AsyncSequence`, and background tasks run under strict concurrency.
- You have **Hello, Notes** on SwiftData with the Week 20 widget extension and App Group in Git. This week's mini-project compounds onto it: a new `ActivityAttributes`, the Dynamic Island views, the backend push, and a background refresh task.

**Toolchain.** Xcode 16+ on macOS, targeting iOS 18 with an iOS 17 floor (Live Activities require iOS 16.1+; push-to-start and broadcast features are 17.2+). **This is a device-heavy week** — and you already hold the Apple Developer membership from Phase III. The Dynamic Island exists only on iPhone 14 Pro and later *hardware*; the Simulator renders Live Activities on the Lock Screen but its Dynamic Island support is partial, and **APNs push to a real activity token requires a physical device.** You can develop the attributes, the views, and the local start/update entirely in the Simulator; you must verify the push-driven path and the Dynamic Island on a device. We flag device-only steps as we reach them.

## Topics covered

- **Live Activity vs Widget.** Time granularity, lifetime, the update driver, the `.activityFamily` surfaces, and the decision matrix for which to reach for.
- **`ActivityAttributes`.** The static attributes (fixed for the life of the activity) vs the nested `ContentState` (the dynamic, updatable part), and why the split exists.
- **The activity lifecycle.** `Activity.request(attributes:content:pushType:)`, `activity.update(_:)`, `activity.end(_:dismissalPolicy:)`, `Activity.activities` to recover running activities, and `activityStateUpdates` / `contentUpdates`.
- **Dynamic Island layouts.** `DynamicIsland { }` with `expanded`, `compactLeading`, `compactTrailing`, `minimal`; the `expandedRegion`s (leading/trailing/center/bottom); and the Lock Screen / banner presentation. The layout decision tree.
- **The push token flow.** `pushType: .token`, observing `activity.pushTokenUpdates`, sending the token to the backend, and the APNs payload shape for a Live Activity (`aps.event`, `aps.content-state`, `aps.timestamp`, `aps.stale-date`, `aps.dismissal-date`).
- **Push-to-start (iOS 17.2+).** `Activity.pushToStartTokenUpdates`, the `aps.event = "start"` payload with `attributes-type` and `attributes`, and starting an activity while the app is terminated.
- **The Vapor side.** Minting the activity push (the `liveactivity` topic suffix `.push-type.liveactivity`), the `content-state` JSON, priority and `apns-expiration`, and rotating the token when it changes.
- **BackgroundTasks.** `BGTaskScheduler`, registering a `BGAppRefreshTaskRequest` and a `BGProcessingTaskRequest`, the `Info.plist` `BGTaskSchedulerPermittedIdentifiers`, the expiration handler, `setTaskCompleted(success:)`, and re-scheduling.
- **Background modes.** The capability checkboxes, `backgroundTasks`, and what each background mode actually permits.
- **Low Power Mode and the budget.** `ProcessInfo.processInfo.isLowPowerModeEnabled`, the `NSProcessInfoPowerStateDidChange` notification, what gets throttled, and the graceful-degradation playbook.
- **The failure catalogue.** Activity won't start (entitlement, `supportsLiveActivities`), push never lands (wrong topic, wrong token, payload shape), Dynamic Island blank (layout regions empty, view crash), background task never fires (not registered, identifier mismatch, never scheduled).

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Live Activity vs Widget; `ActivityAttributes`; the lifecycle       |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Dynamic Island layouts; local start/update; the push token flow    |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | APNs push payloads; push-to-start; the Vapor sender; challenge      |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | BackgroundTasks; Low Power Mode + the budget; challenge             |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — shared-note-edit Live Activity, push-driven          |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; push + Dynamic Island + Low-Power verify     |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                          |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's ActivityKit / BackgroundTasks docs, the WWDC sessions, the APNs Live Activity payload reference, and the canonical community writing on push-driven activities |
| [lecture-notes/01-activitykit-dynamic-island-push.md](./02-lecture-notes/01-activitykit-dynamic-island-push.md) | Live Activities end to end: vs Widget, `ActivityAttributes`/`ContentState`, the lifecycle, the Dynamic Island layouts, and the APNs push (including push-to-start) that drives them from the backend |
| [lecture-notes/02-background-tasks-low-power-and-the-budget.md](./02-lecture-notes/02-background-tasks-low-power-and-the-budget.md) | BackgroundTasks (`BGAppRefreshTask`/`BGProcessingTask`), the expiration handler and completion contract, Low Power Mode and the system budget, and how real-time work degrades gracefully |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-first-live-activity.md](./03-exercises/exercise-01-first-live-activity.md) | Define an `ActivityAttributes`, render the Dynamic Island + Lock Screen, and start/update/end an activity locally |
| [exercises/exercise-02-push-driven-update.swift](./03-exercises/exercise-02-push-driven-update.swift) | Observe the activity's `pushToken`, model the APNs `content-state` payload, and update the activity remotely (with the Vapor sender shape) |
| [exercises/exercise-03-background-refresh-task.swift](./03-exercises/exercise-03-background-refresh-task.swift) | Register and schedule a `BGAppRefreshTask` that refreshes notes + the widget, handle expiration, and detect Low Power Mode |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-push-to-start-from-vapor.md](./04-challenges/challenge-01-push-to-start-from-vapor.md) | Start a Live Activity from the Vapor backend via push-to-start while the app is terminated, then update and end it over the wire — the full backend-driven lifecycle |
| [quiz.md](./05-quiz.md) | 13 questions on Live Activity vs Widget, the lifecycle, Dynamic Island, the push payload, push-to-start, BackgroundTasks, and Low Power Mode |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for the "shared-note edit in progress" Live Activity: compact/minimal/expanded Dynamic Island, Lock Screen, backend push, and a background refresh task |

## The "updates while the app is asleep" promise

Week 10 gave you "survives a cold launch." Week 20 gave you "appears without launching." Week 21 adds the real-time contract a senior reviewer checks before they believe your Live Activity is real:

> **The activity must change on the user's Lock Screen while the app is terminated, driven by the backend.** Start a Live Activity, force-quit the app, then send an `update` push from the Vapor backend — and the number on the Lock Screen and Dynamic Island must change *without the app running.* If the activity only updates when the app is foregrounded, it is not a Live Activity; it is a fancy widget. The whole point is that a remote event moves the pixels while your UI is asleep.

You will *prove* this on a device: start the activity, kill the app, fire an APNs push from the backend, and watch the Dynamic Island update live. "It updated when I had the app open" is not the test — that is the local-update path, which any view can do. Kill the app and push.

## A note on what's not here

Week 21 is the *real-time and background* week. It deliberately does **not** cover:

- **The static widget timeline.** That was Week 20. A Lock Screen *widget* (timeline, budget, `WidgetCenter.reloadTimelines`) and a Lock Screen *Live Activity* (push token, seconds-granularity, ActivityKit) are different mechanisms that happen to share view code and the same extension. Don't conflate them.
- **The full APNs setup from scratch.** Auth keys, device-token registration, and the Notification Service Extension were Week 18. We reuse that pipeline and add the Live Activity *topic* and *payload* on top; we do not re-teach minting an `.p8` key.
- **StoreKit, CloudKit, or sync.** The "another device is editing" trigger in the mini-project is modelled by the backend (the Vapor service knows a second device opened the note); the actual multi-device sync engine is the capstone's concern. Here, the backend *says* "someone's editing" and we render and update the activity from that signal.

The point of Week 21 is narrow and deep: one ongoing event, the `ActivityAttributes`/`ContentState` that models it, the Dynamic Island and Lock Screen that render it, the APNs push that updates it live from the backend, and the background task that keeps the rest of the app's data fresh — the real-time surface, plus the scheduled work that feeds it.

## Up next

Continue to **Week 22 — Testing at scale, CI on GitHub Actions, fastlane** once you have shipped this week's mini-project and proven the push-driven update on a device. Week 22 stops adding features and starts proving they *stay working*: Swift Testing and XCUITest at scale, snapshot tests, a GitHub Actions pipeline that runs them on every PR, and a fastlane lane that ships to TestFlight. Everything you built in Phases I–IV — including this week's Live Activity and last week's widget — needs a CI net under it before the capstone, because "it worked on my machine the day I shipped it" is how regressions reach beta testers. Week 22 builds that net.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
