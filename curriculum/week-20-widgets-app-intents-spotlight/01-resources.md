# Week 20 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **WidgetKit — framework landing page.** The provider protocols, the families, the article index:
  <https://developer.apple.com/documentation/widgetkit>
- **"Creating a widget extension."** Apple's canonical first-widget walkthrough — read this before you add the target:
  <https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension>
- **"Keeping a widget up to date."** Timelines, reload policies, and the refresh budget — the single most important article for "why is my widget stale":
  <https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date>
- **App Intents — framework landing page.** `AppIntent`, `AppEntity`, `AppShortcut`, the whole modern surface:
  <https://developer.apple.com/documentation/appintents>
- **"Adding actions to Siri and Apple Intelligence" / App Shortcuts.** How an intent becomes a zero-setup Siri phrase:
  <https://developer.apple.com/documentation/appintents/app-shortcuts>
- **Core Spotlight — framework landing page.** `CSSearchableIndex`, `CSSearchableItem`, the continuation:
  <https://developer.apple.com/documentation/corespotlight>

## The types you'll touch (reference, skim don't memorize)

- **`TimelineProvider`:** <https://developer.apple.com/documentation/widgetkit/timelineprovider>
- **`TimelineEntry`:** <https://developer.apple.com/documentation/widgetkit/timelineentry>
- **`TimelineReloadPolicy`:** <https://developer.apple.com/documentation/widgetkit/timelinereloadpolicy>
- **`WidgetFamily`:** <https://developer.apple.com/documentation/widgetkit/widgetfamily>
- **`WidgetCenter`:** <https://developer.apple.com/documentation/widgetkit/widgetcenter>
- **`AppIntent`:** <https://developer.apple.com/documentation/appintents/appintent>
- **`AppShortcutsProvider`:** <https://developer.apple.com/documentation/appintents/appshortcutsprovider>
- **`AppEntity` / `EntityQuery`:** <https://developer.apple.com/documentation/appintents/appentity> and <https://developer.apple.com/documentation/appintents/entityquery>
- **`IndexedEntity` (App Intents ↔ Spotlight bridge, iOS 18+):** <https://developer.apple.com/documentation/appintents/indexedentity>
- **`CSSearchableItem` / `CSSearchableItemAttributeSet`:** <https://developer.apple.com/documentation/corespotlight/cssearchableitem>
- **App Group entitlement (`com.apple.security.application-groups`):** <https://developer.apple.com/documentation/xcode/configuring-app-groups>

## WWDC sessions (free, watch in this order)

- **"Meet WidgetKit"** (WWDC20) — the provider model, the timeline, the families. Still the clearest introduction:
  <https://developer.apple.com/videos/play/wwdc2020/10028/>
- **"Dive into App Intents"** (WWDC22) — the framework that replaced `.intentdefinition`; `AppIntent`, `AppEntity`, `AppShortcut`:
  <https://developer.apple.com/videos/play/wwdc2022/10032/>
- **"Bring your app's core features to users with App Intents"** (WWDC23) — the design guidance for which actions to expose:
  <https://developer.apple.com/videos/play/wwdc2023/10210/>
- **"Bring widgets to life"** (WWDC23) — interactive widgets with `Button(intent:)` / `Toggle(isOn:intent:)`, and animations:
  <https://developer.apple.com/videos/play/wwdc2023/10028/>
- **"Bring your widget to new places"** (WWDC23) — Lock Screen accessories, StandBy, and the watch families:
  <https://developer.apple.com/videos/play/wwdc2023/10027/>
- **"What's new in App Intents"** (WWDC24) — `IndexedEntity`, the Spotlight bridge, and the latest entity ergonomics:
  <https://developer.apple.com/videos/play/wwdc2024/10134/>
- **"Design App Shortcuts"** (WWDC22) — the phrase rules Siri matches against; short but essential for getting Siri to recognise your shortcut:
  <https://developer.apple.com/videos/play/wwdc2022/10169/>

## The App Group story (why widgets show stale or empty data)

The number-one widget bug is "the extension can't see the app's data." It is always an App Group / shared-store problem. Read these until the shared-container URL is reflex.

- **"Configuring app groups":** <https://developer.apple.com/documentation/xcode/configuring-app-groups>
- **`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`** — how the widget finds the shared store:
  <https://developer.apple.com/documentation/foundation/filemanager/1412643-containerurl>
- **SwiftData `ModelConfiguration(url:)`** — pointing the container at the App Group URL so app and widget share one store:
  <https://developer.apple.com/documentation/swiftdata/modelconfiguration>

## Spotlight and deep linking

- **"Making content searchable":** <https://developer.apple.com/documentation/corespotlight/making-content-searchable>
- **`CSSearchableItemActionType`** — the continuation key you handle when the user taps a result:
  <https://developer.apple.com/documentation/corespotlight/cssearchableitemactiontype>
- **`onContinueUserActivity` (SwiftUI):** <https://developer.apple.com/documentation/swiftui/view/oncontinueuseractivity(_:perform:)>
- **`widgetURL(_:)` and `Link` in widgets** — routing a widget tap to a deep link:
  <https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — "WidgetKit" and "App Intents" tutorials.** Paul Hudson keeps these current per OS release; the App Group + SwiftData widget article is the one to read:
  <https://www.hackingwithswift.com/quick-start/swiftui> (filter for WidgetKit / App Intents)
- **Donny Wals — App Intents and widget articles.** Production-grade, especially on the off-process concurrency rules and SwiftData in extensions:
  <https://www.donnywals.com/category/swift/>
- **Pol Piella — App Intents and interactive widget notes:**
  <https://www.polpiella.dev/>
- **Fatbobman — SwiftData in widgets and shared containers** (the same author from the Week 10 SwiftData reading):
  <https://fatbobman.com/en/>
- **Swift Forums — WidgetKit and App Intents discussions.** Where Apple engineers answer the hard edge cases:
  <https://forums.swift.org/>

## Open-source projects to read this week

You learn more from one hour reading a real widget + intents app than from three tutorials. Pick one and scroll through how they wire the App Group and the intent surface:

- **`apple/sample-backyard-birds`** — Apple's SwiftData sample (from Week 10) also ships widgets and App Intents over the shared store; the App Group + widget setup is exemplary:
  <https://github.com/apple/sample-backyard-birds>
- **Apple's "Adopting App Intents to support system experiences" sample code** (linked from the App Intents docs) — the canonical App Shortcut + entity reference.
- **Apple's "Making your app's content searchable in Spotlight" sample** — the `CSSearchableIndex` reference build.

## Tools you'll use this week

- **Xcode 16+** — installed from the Mac App Store. Add a widget extension via **File ▸ New ▸ Target ▸ Widget Extension.**
- **The Shortcuts app** (in the Simulator and on device) — your App Shortcut shows up here automatically once registered; run it to test the intent without Siri voice.
- **`xcrun simctl`** — boot a simulator, launch the app, and (as in Week 10) `xcrun simctl get_app_container booted <group-id> data` to find the **App Group** container and confirm the shared store is where you think it is.
- **The Widget gallery in the Simulator** — long-press the Home Screen, tap **+**, find your widget, and add each family. The "Edit Widget" view exercises your `IntentConfiguration` if you add one.
- **Console.app / `Logger`** — widget extensions log here; when a widget is blank, the extension's `Logger` output in Console is where the App Group / store error surfaces.

## Free books (chapter-level, not whole books)

- **Apple's "App Intents" and "WidgetKit" article groups** in the Developer app and on the docs site are effectively a free book; read the WidgetKit "Essentials" group and the App Intents "Essentials" group end to end.

## Paid books (optional, clearly marked)

- **"Practical App Intents" / "App Intents Field Guide"** — community authors (paid). The most production-focused App Intents writing in 2026; worth it if you adopt intents at work.
- **"SwiftUI Field Guide" extensions chapters** (paid) — for the widget-view layout details across families.

---

*If a link 404s, please open an issue so we can replace it.*
