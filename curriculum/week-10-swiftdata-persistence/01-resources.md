# Week 10 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **SwiftData — framework landing page.** The macro list, the article index, and the API reference root:
  <https://developer.apple.com/documentation/swiftdata>
- **"Preserving your app's model data across launches."** Apple's canonical container/context article — read this before you write a `@Model`:
  <https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches>
- **"Defining data relationships with enumerations and model classes."** The `@Relationship` guide, including inverse and delete rules:
  <https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes>
- **"Filtering and sorting persistent data."** The `@Query` / `#Predicate` / `SortDescriptor` guide:
  <https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data>
- **"Adopting SwiftData for a Core Data app."** The co-existence and migration story — central to lecture note 02:
  <https://developer.apple.com/documentation/coredata/adopting-swiftdata-for-a-core-data-app>

## The macros and types (reference, skim don't memorize)

- **`Model()` macro:** <https://developer.apple.com/documentation/swiftdata/model()>
- **`Attribute` macro and `Schema.Attribute.Option`:** <https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)>
- **`Relationship` macro and `Schema.Relationship.DeleteRule`:** <https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)>
- **`ModelContainer`:** <https://developer.apple.com/documentation/swiftdata/modelcontainer>
- **`ModelContext`:** <https://developer.apple.com/documentation/swiftdata/modelcontext>
- **`ModelConfiguration`:** <https://developer.apple.com/documentation/swiftdata/modelconfiguration>
- **`Query` property wrapper:** <https://developer.apple.com/documentation/swiftdata/query>
- **`FetchDescriptor`:** <https://developer.apple.com/documentation/swiftdata/fetchdescriptor>
- **`Predicate` and the `#Predicate` macro:** <https://developer.apple.com/documentation/foundation/predicate>
- **`VersionedSchema` / `SchemaMigrationPlan`:** <https://developer.apple.com/documentation/swiftdata/schemamigrationplan>
- **`#Index` and `#Unique` (iOS 18+):** <https://developer.apple.com/documentation/swiftdata/index(_:)> and <https://developer.apple.com/documentation/swiftdata/unique(_:)>

## WWDC sessions (free, watch in this order)

- **"Meet SwiftData"** (WWDC23) — the introduction; macros, container, context, `@Query`:
  <https://developer.apple.com/videos/play/wwdc2023/10187/>
- **"Model your schema with SwiftData"** (WWDC23) — `VersionedSchema`, migration plans, relationship modelling:
  <https://developer.apple.com/videos/play/wwdc2023/10195/>
- **"Build an app with SwiftData"** (WWDC23) — the end-to-end build, the same shape as our mini-project:
  <https://developer.apple.com/videos/play/wwdc2023/10154/>
- **"Dive deeper into SwiftData"** (WWDC23) — `ModelContext` internals, `FetchDescriptor`, the Core Data layer below:
  <https://developer.apple.com/videos/play/wwdc2023/10196/>
- **"What's new in SwiftData"** (WWDC24) — `#Index`, `#Unique`, custom `DataStore`, the history API:
  <https://developer.apple.com/videos/play/wwdc2024/10137/>
- **"Create a custom data store with SwiftData"** (WWDC24) — the `DataStore` protocol; useful for the "what does SwiftData hide" lecture:
  <https://developer.apple.com/videos/play/wwdc2024/10138/>
- **"Track model changes with SwiftData history"** (WWDC24) — the history API for sync/outbox patterns:
  <https://developer.apple.com/videos/play/wwdc2024/10075/>

## The Core Data lineage (why this matters)

SwiftData is a front end over Core Data. When SwiftData behaves surprisingly, the explanation is almost always one layer down. You will not write Core Data this week, but you should be able to read it.

- **Core Data framework reference:** <https://developer.apple.com/documentation/coredata>
- **"Creating a Core Data model":** <https://developer.apple.com/documentation/coredata/creating-a-core-data-model>
- **`NSManagedObjectContext`** (this is what a `ModelContext` wraps): <https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext>
- **`NSPredicate`** (this is what `#Predicate` compiles toward): <https://developer.apple.com/documentation/foundation/nspredicate>
- **Faulting and uniquing** — the lazy-loading model SwiftData inherits:
  <https://developer.apple.com/documentation/coredata/faulting-and-uniquing>

## Performance and Instruments

- **"Analyzing the performance of your Core Data app"** (the SwiftData fetch you measure lands in these same templates):
  <https://developer.apple.com/documentation/coredata/analyzing-the-performance-of-your-core-data-app>
- **`OSSignposter`** — the timing API used in this week's exercises:
  <https://developer.apple.com/documentation/os/ossignposter>
- **`OSLog` and `Logger`** — structured logging for the measurements:
  <https://developer.apple.com/documentation/os/logger>
- **Instruments "SwiftData" and "Core Data" templates** — the SQL trace shows you the exact query the predicate generated. Launch Instruments, choose the **SwiftData** template, and record the app.

## Community writing (current, opinionated, correct)

- **Hacking with Swift — SwiftData by Example.** The most complete free SwiftData reference outside Apple; Paul Hudson keeps it current per OS release:
  <https://www.hackingwithswift.com/quick-start/swiftdata>
- **Fatbobman's blog — the deep SwiftData/Core Data series.** The best long-form writing on the layer boundary, migrations, and concurrency:
  <https://fatbobman.com/en/>
- **Donny Wals — "Practical SwiftData."** Production-grade articles on background contexts, `@ModelActor`, and the `Sendable` story:
  <https://www.donnywals.com/category/swift/>
- **Pol Piella — SwiftData migrations and testing notes:**
  <https://www.polpiella.dev/>
- **Swift Forums — the SwiftData category.** Where Apple engineers answer the hard edge-case questions:
  <https://forums.swift.org/c/related-projects/swiftdata/>

## Open-source projects to read this week

You learn more from one hour reading a real SwiftData app than from three hours of tutorials. Pick one and scroll through how they declare the schema and wire the container:

- **`apple/sample-backyard-birds`** — Apple's full SwiftData + StoreKit sample; the schema and container setup are exemplary:
  <https://github.com/apple/sample-backyard-birds>
- **Apple's "Adopting SwiftData for a Core Data app" sample code** (linked from the article above) — the canonical co-existence reference.
- **`fatbobman/SwiftDataKit`** — utilities that expose the Core Data objects under a SwiftData store; instructive even if you never use it in production:
  <https://github.com/fatbobman/SwiftDataKit>

## Tools you'll use this week

- **Xcode 16+** — installed from the Mac App Store. `xcodebuild -version` to confirm.
- **`xcrun simctl`** — the Simulator CLI. You will use `xcrun simctl terminate <udid> <bundle-id>` to force-quit for the relaunch test, and you can `xcrun simctl get_app_container booted <bundle-id> data` to find the SQLite file on disk.
- **A SQLite browser** (optional but illuminating) — open the `.store` file SwiftData writes and look at the actual tables. `sqlite3` on the command line works; **DB Browser for SQLite** (free, <https://sqlitebrowser.org/>) is friendlier. Seeing `ZNOTE` and `Z_2TAGS` join tables makes the Core Data lineage concrete.

## Free books (chapter-level, not whole books)

- **Apple's "SwiftData" sample-driven tutorial chapters** inside the Developer app and on the docs site (linked above) are effectively a free book; read the four article pages in the SwiftData "Essentials" group end to end.

## Paid books (optional, clearly marked)

- **"Practical SwiftData" / "SwiftData Field Guide"** — Donny Wals (paid). The most production-focused SwiftData book in 2026; worth it if you adopt SwiftData at work.
- **"Core Data" — objc.io (Florian Kugler, Daniel Eggert)** (paid). Older, but the definitive deep dive on the engine under SwiftData; the chapters on faulting and contexts are still the clearest explanation in print.

---

*If a link 404s, please open an issue so we can replace it.*
