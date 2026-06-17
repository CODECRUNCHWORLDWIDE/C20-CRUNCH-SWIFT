# Week 21 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **ActivityKit — framework landing page.** `Activity`, `ActivityAttributes`, the lifecycle:
  <https://developer.apple.com/documentation/activitykit>
- **"Displaying live data with Live Activities."** Apple's canonical end-to-end article — read this before you write an `ActivityAttributes`:
  <https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities>
- **"Starting and updating Live Activities with ActivityKit push notifications."** The push-token flow and the payload — the central article for "update from the backend":
  <https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications>
- **"Update Live Activities with push notifications" (push-to-start included):**
  <https://developer.apple.com/documentation/usernotifications/sending-channel-management-requests-to-apns> (and the ActivityKit push article above)
- **BackgroundTasks — framework landing page.** `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask`:
  <https://developer.apple.com/documentation/backgroundtasks>
- **"Using background tasks to update your app."** The register/schedule/handle/complete contract:
  <https://developer.apple.com/documentation/backgroundtasks/using-background-tasks-to-update-your-app>

## The types you'll touch (reference, skim don't memorize)

- **`Activity`:** <https://developer.apple.com/documentation/activitykit/activity>
- **`ActivityAttributes`:** <https://developer.apple.com/documentation/activitykit/activityattributes>
- **`ActivityContent`:** <https://developer.apple.com/documentation/activitykit/activitycontent>
- **`DynamicIsland` (WidgetKit):** <https://developer.apple.com/documentation/widgetkit/dynamicisland>
- **`ActivityConfiguration`:** <https://developer.apple.com/documentation/widgetkit/activityconfiguration>
- **`BGTaskScheduler`:** <https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler>
- **`BGAppRefreshTaskRequest`:** <https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtaskrequest>
- **`BGProcessingTaskRequest`:** <https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest>
- **`ProcessInfo.isLowPowerModeEnabled`:** <https://developer.apple.com/documentation/foundation/processinfo/1617047-islowpowermodeenabled>
- **APNs payload key reference (`aps.event`, `content-state`, `stale-date`, `dismissal-date`):**
  <https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification>

## WWDC sessions (free, watch in this order)

- **"Meet ActivityKit"** (WWDC23) — the introduction; attributes, content state, the lifecycle:
  <https://developer.apple.com/videos/play/wwdc2023/10184/>
- **"Design dynamic Live Activities"** (WWDC23) — the Dynamic Island layout rules; essential for getting the presentations right:
  <https://developer.apple.com/videos/play/wwdc2023/10194/>
- **"Update Live Activities with push notifications"** (WWDC23) — the push-token flow and the payload, including the broadcast/channel model:
  <https://developer.apple.com/videos/play/wwdc2023/10185/>
- **"What's new in ActivityKit"** (WWDC24) — push-to-start refinements, the `activityFamily` for watch/Smart Stack, and broadcast push:
  <https://developer.apple.com/videos/play/wwdc2024/10068/>
- **"Bring widgets to new places" / Live Activities on watchOS** (WWDC24) — the Smart Stack and watch surfaces:
  <https://developer.apple.com/videos/play/wwdc2024/10157/>
- **"Efficiency awaits: Background tasks in SwiftUI"** (WWDC22) — `BGTaskScheduler` and the SwiftUI `backgroundTask` scene modifier:
  <https://developer.apple.com/videos/play/wwdc2022/10142/>
- **"Optimize for the spatial web" is NOT this** — instead watch **"Reduce network delays with App Store Connect"** only if backend-curious; the background-tasks session above is the load-bearing one.

## The APNs Live Activity payload (the part people get wrong)

A Live Activity push is an APNs push with a specific topic suffix and payload shape. Read these until the `event`/`content-state` shape is reflex.

- **The `liveactivity` push type and the `<bundle-id>.push-type.liveactivity` topic:** in the ActivityKit push article above.
- **Token rotation** — the push token can change; observe `pushTokenUpdates` and resend to the backend:
  <https://developer.apple.com/documentation/activitykit/activity/pushtokenupdates>
- **Push-to-start token** — `Activity.pushToStartTokenUpdates` (iOS 17.2+):
  <https://developer.apple.com/documentation/activitykit/activity/pushtoStartTokenUpdates> (see the ActivityKit reference index)

## Background processing depth

- **"Choosing background strategies for your app":** <https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app>
- **`BGTaskSchedulerPermittedIdentifiers` in `Info.plist`** — the array your task identifiers must be listed in or registration fails:
  <https://developer.apple.com/documentation/bundleresources/information-property-list/bgtaskschedulerpermittedidentifiers>
- **Debugging background tasks** — the `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"..."]` LLDB trick to fire a task on demand:
  <https://developer.apple.com/documentation/backgroundtasks/starting-and-terminating-tasks-during-development>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — "ActivityKit" and "Live Activities" tutorials.** Paul Hudson keeps these current per OS release:
  <https://www.hackingwithswift.com/quick-start/swiftui> (filter for Live Activities / ActivityKit)
- **Donny Wals — Live Activities and background tasks.** Production-grade, especially on the push-token flow and Low Power Mode:
  <https://www.donnywals.com/category/swift/>
- **Pol Piella — Live Activity push notes** (the payload shape from a real backend):
  <https://www.polpiella.dev/>
- **Vapor APNS — `apns` package docs** (sending the Live Activity push from your Vapor backend):
  <https://github.com/swift-server-community/APNSwift> and <https://github.com/vapor/apns>
- **Swift Forums — ActivityKit / push discussions.** Where the hard payload edge cases get answered:
  <https://forums.swift.org/>

## Open-source projects to read this week

- **Apple's "Displaying live data with Live Activities" sample code** (linked from the article) — the canonical attributes + Dynamic Island + push reference.
- **`swift-server-community/APNSwift`** — read how a Live Activity push is constructed server-side; the `APNSLiveActivityNotification` type is exactly what your Vapor sender uses.
- **`vapor/apns`** — the Vapor integration; the `liveActivity` send path.

## Tools you'll use this week

- **Xcode 16+** — add the Live Activity UI to your existing **widget extension** (`ActivityConfiguration` lives there alongside your `Widget`s from Week 20).
- **A physical iPhone (14 Pro or later for the Dynamic Island)** — the Simulator renders Live Activities on the Lock Screen but APNs push to a real activity token, and the Dynamic Island hardware, need a device. You hold the Apple Developer membership from Phase III.
- **An APNs sender** — your **Vapor backend** (the production path) or, for quick tests, a CLI like `curl` with a JWT, or a tool such as `Apns-Tool`/`PushNotifications` GUI. The payload shape is the same.
- **`Console.app`** — Live Activity and background-task logs surface here; when a push doesn't land or a task doesn't fire, the device console is where the reason appears.
- **The LLDB simulate-launch trick** (link above) to fire a `BGAppRefreshTask` on demand instead of waiting hours for the system to schedule it.

## Free books (chapter-level, not whole books)

- **Apple's "ActivityKit" and "BackgroundTasks" article groups** in the Developer app and on the docs site are effectively a free book; read the ActivityKit "Essentials" group and the BackgroundTasks overview end to end.

## Paid books (optional, clearly marked)

- **"Practical Live Activities" / community ActivityKit guides** (paid) — the most production-focused Live Activity writing in 2026; worth it if you ship activities at work.
- **"Server-Side Swift with Vapor" — raywenderlich/Kodeco** (paid) — for the backend half, including APNs sending from Vapor.

---

*If a link 404s, please open an issue so we can replace it.*
