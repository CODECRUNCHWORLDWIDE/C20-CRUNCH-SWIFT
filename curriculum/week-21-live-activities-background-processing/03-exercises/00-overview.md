# Week 21 — Exercises

Short, focused drills. Each one should take 40–60 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — A first Live Activity, started locally](./exercise-01-first-live-activity.md)** — define an `ActivityAttributes` with a `ContentState`, render the Lock Screen card and all three Dynamic Island presentations, and start/update/end the activity from the app. The whole real-time surface, in one exercise, no backend yet. (~55 min)
2. **[Exercise 2 — Updating the activity over APNs](./exercise-02-push-driven-update.swift)** — observe the activity's `pushToken`, model the `content-state` payload so it matches your `ContentState` exactly, and update the activity remotely (with the Vapor sender shape spelled out). You prove the Lock Screen changes while the app is terminated. (~55 min, device for the push)
3. **[Exercise 3 — A background refresh task](./exercise-03-background-refresh-task.swift)** — register and schedule a `BGAppRefreshTask` that refreshes notes and reloads the widget, handle the expiration handler correctly, complete exactly once, and detect Low Power Mode. (~50 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- Exercise 1 runs in the **Simulator** (Live Activities render on the simulated Lock Screen; the Dynamic Island is fully visible only on iPhone 14 Pro+ *hardware*). Exercise 2's push path needs a **physical device** — you hold the Apple Developer membership from Phase III. Exercise 3 runs in the Simulator with the LLDB simulate-launch trick.
- The `.swift` exercises drop into your Hello, Notes app and its widget extension (the same extension from Week 20). Each file's header says where it goes.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — `ContentState` crosses into a push payload and the background handler runs under strict concurrency.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-21` to compare.
