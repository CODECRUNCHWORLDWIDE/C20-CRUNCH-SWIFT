# Week 8 — Resources

Every resource on this page is **free**. Apple's developer documentation and WWDC session videos are free without a paid membership. The community blogs (Hacking with Swift, Swift with Majid, Point-Free's free episodes, SwiftLee, Donny Wals) are free to read. The Apple sample projects are downloadable without a membership. No paywalled material is required for the week; one optional Point-Free episode is behind their subscription and is marked as such.

This is the state-management week, so the resource list is curated tightly around five ideas: the Observation framework, the `@State`/`@Binding`/`@Environment`/`@Bindable` primitives, view identity and lifetime, the legacy `ObservableObject` model (for reading old code), and re-render performance.

## Required reading (work it into your week)

- **Apple — "Managing model data in your app"** — the canonical guide to `@Observable`, `@State` for models, `@Bindable`, and `@Environment`. Read this first; everything else elaborates on it:
  <https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app>
- **Apple — "Managing user interface state"** — the `@State`/`@Binding` guide for local UI state. Short, foundational:
  <https://developer.apple.com/documentation/swiftui/managing-user-interface-state>
- **Apple — "Migrating from the Observable Object protocol to the Observable macro"** — the official migration guide. The before/after tables are the fastest way to map legacy code to modern code:
  <https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro>
- **WWDC23 — "Discover Observation in SwiftUI"** — the 20-minute session that introduced `@Observable`. Watch it twice; the per-property-tracking explanation is the heart of the week:
  <https://developer.apple.com/videos/play/wwdc2023/10149/>
- **WWDC21 — "Demystify SwiftUI"** — still the single best explanation of *identity*, *lifetime*, and *dependencies* — the three concepts that decide every re-render. Required even though it predates Observation, because identity and lifetime are unchanged:
  <https://developer.apple.com/videos/play/wwdc2021/10022/>

## Apple framework documentation

- **`Observation` framework reference** (the `@Observable` macro, `ObservationRegistrar`, the `Observable` protocol):
  <https://developer.apple.com/documentation/observation>
- **`State` property wrapper reference**:
  <https://developer.apple.com/documentation/swiftui/state>
- **`Binding` property wrapper reference**:
  <https://developer.apple.com/documentation/swiftui/binding>
- **`Bindable` property wrapper reference**:
  <https://developer.apple.com/documentation/swiftui/bindable>
- **`Environment` property wrapper reference**:
  <https://developer.apple.com/documentation/swiftui/environment>
- **`EnvironmentValues` reference** (the system key paths: `\.dismiss`, `\.colorScheme`, `\.modelContext`, …):
  <https://developer.apple.com/documentation/swiftui/environmentvalues>
- **`environment(_:)` view modifier** (object injection, the modern form):
  <https://developer.apple.com/documentation/swiftui/view/environment(_:)>
- **`id(_:)` view modifier** (explicit identity):
  <https://developer.apple.com/documentation/swiftui/view/id(_:)>
- **`onChange(of:initial:_:)` view modifier** (the two-value, `initial:`-aware form):
  <https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-8wgw9>
- **`task(id:priority:_:)` view modifier** (lifetime-scoped async work, identity re-run):
  <https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:)>
- **Legacy: `StateObject`, `ObservedObject`, `EnvironmentObject`** — keep these bookmarked for reading old code:
  <https://developer.apple.com/documentation/swiftui/stateobject> · <https://developer.apple.com/documentation/swiftui/observedobject> · <https://developer.apple.com/documentation/swiftui/environmentobject>

## WWDC sessions worth watching

- **WWDC23 — "Discover Observation in SwiftUI"** (listed in Required, repeated for completeness):
  <https://developer.apple.com/videos/play/wwdc2023/10149/>
- **WWDC21 — "Demystify SwiftUI"** (identity / lifetime / dependencies):
  <https://developer.apple.com/videos/play/wwdc2021/10022/>
- **WWDC20 — "Data Essentials in SwiftUI"** — the original treatment of the source-of-truth model; still the clearest framing of "single source of truth" even though it predates Observation:
  <https://developer.apple.com/videos/play/wwdc2020/10040/>
- **WWDC23 — "Analyze hangs with Instruments"** — for the performance side of the re-render storm; you will use this in earnest in Week 15 but it is worth a first watch now:
  <https://developer.apple.com/videos/play/wwdc2023/10248/>
- **WWDC24 — "What's new in SwiftUI"** — for the most recent refinements to state and previews; skim the state/Observation portions:
  <https://developer.apple.com/videos/play/wwdc2024/10144/>

## Community deep dives (free, high signal)

- **Hacking with Swift (Paul Hudson) — "What's the difference between @State, @Binding, @ObservedObject, @StateObject, and @EnvironmentObject?"** — the canonical plain-English mapping of every wrapper. The single best one-page orientation:
  <https://www.hackingwithswift.com/quick-start/swiftui/whats-the-difference-between-observedobject-state-and-environmentobject>
- **Hacking with Swift — "How to use @Observable to manage state"**:
  <https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-observable-to-make-your-data-models-observable>
- **Swift with Majid (Majid Jabrayilov) — "Discovering app architecture with @Observable"** — Majid's blog is the most consistently rigorous SwiftUI writing online; this post and his Observation series cover the modern model end to end:
  <https://swiftwithmajid.com/2023/09/05/discovering-app-architecture-with-observable/>
- **Swift with Majid — "Mastering the Environment in SwiftUI"** — the deepest free treatment of `@Environment` as dependency injection:
  <https://swiftwithmajid.com/2025/01/14/mastering-the-environment-in-swiftui/>
- **SwiftLee (Antoine van der Lee) — "@Observable Macro performance increase over ObservableObject"** — the concrete, measured case for migrating, with the re-render counts:
  <https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/>
- **Donny Wals — "Understanding how and when SwiftUI decides to redraw views"** — the best free article specifically on the re-render question this week is built around:
  <https://www.donnywals.com/understanding-how-and-when-swiftui-decides-to-redraw-views/>
- **Point-Free — "Observation: The Past" / "Observation: The Present"** (free episodes; the deep dives are subscriber-only) — the most precise explanation of *why* the Observation framework is shaped the way it is, from the team that pre-built much of it in `swift-composable-architecture`:
  <https://www.pointfree.co/collections/swiftui/observation>

## Sample code and source to read

- **Apple — "Backyard Birds: Building an app with SwiftData and widgets"** — a full Apple sample that uses `@Observable`, `@Environment`, and SwiftData together. Read how the model is created once and injected:
  <https://developer.apple.com/documentation/swiftui/backyard-birds-sample>
- **Apple — "Migrating to SwiftData"** sample (uses `@Observable` model objects alongside SwiftData):
  <https://developer.apple.com/documentation/swiftdata/adding-and-editing-persistent-data-in-your-app>
- **`swiftlang/swift` — the Observation implementation** — read `stdlib/public/Observation/Sources/Observation/` to see what the `@Observable` macro actually generates (`ObservationRegistrar`, `access`, `withMutation`):
  <https://github.com/swiftlang/swift/tree/main/stdlib/public/Observation>
- **`swift-evolution` — SE-0395 "Observability"** — the proposal that defined the Observation framework. The "Detailed design" section is the authoritative description of what `@Observable` generates and why:
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0395-observability.md>
- **`pointfreeco/swift-composable-architecture`** — even if you do not adopt TCA (that is Week 11), reading how its `@ObservableState` interoperates with the system Observation framework is instructive:
  <https://github.com/pointfreeco/swift-composable-architecture>

## Reference: the legacy model (for reading old code only)

You will not write these from scratch, but you will read millions of lines of them:

- **Apple — "Combine" `ObservableObject` protocol**:
  <https://developer.apple.com/documentation/combine/observableobject>
- **Apple — "Published" property wrapper**:
  <https://developer.apple.com/documentation/combine/published>
- **Hacking with Swift — "What is the @StateObject property wrapper?"** (and the `@ObservedObject` companion) — the clearest articulation of the create-vs-observe distinction and the "restarts every render" bug:
  <https://www.hackingwithswift.com/quick-start/swiftui/what-is-the-stateobject-property-wrapper>

## How to use this resource list

The two lectures cite specific URLs at decision points. You do not need to read everything; for this week, the four pieces to read end-to-end are:

1. **Apple — "Managing model data in your app"** (Required). Foundational; do not skip.
2. **WWDC23 — "Discover Observation in SwiftUI"** (Required). 20 minutes; the heart of the week.
3. **WWDC21 — "Demystify SwiftUI"** (Required). The identity/lifetime/dependencies model you will use every render.
4. **Donny Wals — "Understanding how and when SwiftUI decides to redraw views"**. ~25 minutes; the companion to Lecture 2.

The rest are reference material — bookmark them and return when a specific question arises. The Apple migration guide in particular is worth keeping open the first time you inherit an `ObservableObject` codebase.

---

*Bookmarks decay. If a link rots, search the title — these are all canonical pieces and Apple/the community keep them alive across reorganisations. Apple WWDC session numbers are stable; the `developer.apple.com/videos/play/wwdcYYYY/NNNNN/` URL pattern is durable.*
