# Week 9 — Navigation, Deep Links, and Scenes

Welcome to **C20 · Crunch Swift**, Week 9. Week 7 made SwiftUI ordinary: you learned that `body` is a function from state to a view tree, and that the framework diffs that tree for you. Week 8 made state ownership precise: you learned who owns `@State`, who borrows a `@Binding`, what `@Observable` actually generates, and why injecting a store through `@Environment` beats threading it through fifteen initializers. This week we take the next inevitable step. An app is not one screen. The moment you have two screens you have a navigation problem, and the moment a user can tap a push notification, a Spotlight result, or a link in Messages and land *inside* your app, you have a deep-linking problem. Both of those problems, done right, reduce to the same discipline you already practised in Week 8: **navigation is state, and you model it the same way you model everything else.**

By Friday you should be able to stand up a `NavigationStack` bound to a `[Route]` path array, push screens by appending values to that array rather than by wiring up `NavigationLink` destinations imperatively, build a three-column `NavigationSplitView` that collapses to a stack on iPhone and expands to sidebar-content-detail on iPad and Mac, persist the navigation path across a cold launch with `SceneStorage`, persist a user's tab and sidebar selection with `AppStorage`, and translate an incoming `notes://open/<id>` URL into a deterministic mutation of your navigation state so the right note opens whether the app was already running or launched from nothing.

This is the third week of Phase II — **SwiftUI & State Management** — and it is the week where the two halves of the phase fuse. Everything before this taught you to render a screen and own its state. Everything after this (SwiftData in Week 10, architecture in Week 11, reactive search in Week 12) assumes you can already move between screens predictably and restore where the user was. Navigation is the connective tissue. Get it wrong and every later feature inherits the bug; get it right and deep links, universal links, state restoration, and Handoff all fall out of the same model almost for free.

The first thing to internalize is that **the post-iOS-16 navigation APIs exist because the old ones could not be deep-linked.** `NavigationView` and `NavigationLink(destination:)` modelled navigation as a *tree of views you had already built*. To push the third screen you had to have rendered the first and second, because the link to the third lived inside the second's `body`. There was no value you could set to say "be three screens deep into this note." Programmatic navigation worked through a tangle of `isActive` booleans — one per possible push — that did not compose, did not survive serialization, and produced the infamous "pop two screens, push one" glitches whenever you tried to drive them from outside the view. `NavigationStack` (iOS 16, 2022) replaced that tree with a single `path` — an array of `Hashable` values — and a set of `navigationDestination(for:)` modifiers that map a value's *type* to the view that renders it. The path is plain data. You can append to it, replace it wholesale, serialize it to disk, and reconstruct it from a URL. Deep links stopped being a special case and became "decode the URL into path values, then set the path."

The second thing to internalize is that **value-typed navigation is what makes deep links correct by construction, not by effort.** When a screen is identified by a value — `Route.note(id: UUID)` rather than "whatever view is currently on top" — a deep link is just a function `(URL) -> [Route]`. You write that function once. It is pure, it is testable without a simulator, and it is the same function whether the link arrived from a cold launch, a warm `onOpenURL`, a Spotlight tap, or a universal link from Safari. Lecture 1 builds the post-iOS-16 model from `NavigationStack` and `navigationDestination` up through `NavigationSplitView`, `TabView`, and the scene/storage layer. Lecture 2 makes the argument explicitly: it walks the same deep-link feature implemented twice — once on the old `isActive` model (and shows you where it breaks) and once on the value-typed model (and shows you why it does not) — so you can defend the choice in a code review with a concrete failure in hand.

The third thing to internalize is that **state restoration is not an Apple checkbox; it is a property of how you store your navigation state.** iOS terminates backgrounded apps aggressively to reclaim memory. When the user returns, the system relaunches your app from scratch — a *cold launch* — and a well-built app puts them back exactly where they were: same tab, same sidebar selection, same depth in the same note, scrolled to the same place. SwiftUI gives you `SceneStorage` (per-scene, automatically scoped to the window/scene, ideal for navigation paths) and `AppStorage` (a typed `UserDefaults` wrapper, app-wide, ideal for the selected tab or a sidebar preference). The trick is that both want their value to be a small, `Codable` or primitive type — which is exactly what value-typed navigation already gives you. A `[Route]` of `Codable` enums round-trips through `SceneStorage` with a few lines of `JSONEncoder`/`JSONDecoder` glue. We will write that glue and prove restoration in the simulator with the "terminate and relaunch" gesture.

The fourth thing to internalize is that **`onOpenURL` and universal links are two transports for the same payload, and you should write your link handling so it does not care which one delivered it.** A custom scheme (`notes://open/<id>`) is trivial to register and arrives through `onOpenURL` — but anyone can register `notes://`, it does not work from a web page, and Apple discourages it for anything user-facing. A *universal link* (`https://notes.example.com/open/<id>`) requires an `apple-app-site-association` (AASA) file on your server, the Associated Domains entitlement in your app, and it arrives through `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` — but it works from Safari, Messages, and Mail, it falls back to your website when the app is not installed, and it cannot be spoofed by another app. Both decode to the same `Route`. The challenge this week wires up a real universal link end to end and proves it opens the correct note from both a warm and a cold launch in the simulator.

## Learning objectives

By the end of this week, you will be able to:

- **Build** a `NavigationStack` whose state lives in a `@State private var path: [Route]` array, push screens with `NavigationLink(value:)`, and register destinations with `navigationDestination(for:)` keyed on the route's type.
- **Drive** navigation programmatically — push, pop, pop-to-root, and replace-the-whole-path — by mutating the path array from a button action, a `task`, or an incoming event, with no `isActive` booleans anywhere.
- **Distinguish** `NavigationStack` (a push/pop column for iPhone and the detail pane) from `NavigationSplitView` (a two- or three-column sidebar-content-detail layout for iPad and Mac that collapses to a stack on compact width) and choose the right one per platform from one codebase.
- **Compose** a `TabView` with value-typed `selection`, knowing when tabs own independent navigation stacks and how a deep link selects the right tab *and* the right stack depth atomically.
- **Persist** a navigation path across a cold launch with `SceneStorage`, encoding the `[Route]` to `Data` with `JSONEncoder`, and restore it on relaunch — proving it with the simulator's terminate-and-relaunch gesture.
- **Persist** small UI selections (selected tab, sidebar column, preferred detail) with `AppStorage`, and articulate the `SceneStorage`-vs-`AppStorage` decision (per-scene navigation vs app-wide preference).
- **Handle** a custom-scheme deep link with `onOpenURL`, parsing `notes://open/<id>` into a `Route` and applying it to the path whether the app was warm or cold.
- **Wire** the Associated Domains entitlement and an `apple-app-site-association` file so a real universal link (`https://…/open/<id>`) opens the app through `onContinueUserActivity`, and prove it works warm and cold in the simulator.
- **Write** a pure `Route.from(url:) -> [Route]?` decoder that is unit-testable with Swift Testing, with zero SwiftUI or simulator dependency.
- **Defend** value-typed navigation over the legacy `isActive` model in a code review, citing the specific failure modes (non-composable booleans, serialization impossibility, mid-animation glitches) the new model removes.

## Prerequisites

- **Weeks 7 and 8 of C20 complete.** You can build a SwiftUI view hierarchy, reason about modifier order, and you are fluent with `@State`, `@Binding`, `@Observable`, `@Bindable`, and `@Environment`. This week treats navigation *as* state, so the Week 8 ownership rules are load-bearing, not optional.
- **The Week 8 "Hello, Notes" CRUD app** in your working tree. This week's mini-project compounds directly on it: you add the navigation layer and deep linking to the app you already gave full create/read/update/delete. If you skipped Week 8, build the in-memory `@Observable NotesStore` first; the mini-project README restates the minimum surface you need.
- **Xcode 16+** on macOS, with the iOS 18 / iPadOS 18 / macOS 15 simulators installed. Everything this week runs in the simulator — no device, no Apple Developer membership. The universal-links challenge uses the simulator's `xcrun simctl openurl` and a locally served AASA file; you do **not** need a paid account or a public domain.
- **Comfort with `Codable`** from Phase I. `SceneStorage` restoration and URL decoding both lean on `Codable` enums and `JSONEncoder`/`JSONDecoder`. If `enum Route: Codable` with associated values is unfamiliar, re-read the Week 2 error-handling notes on enums before Tuesday.
- **A terminal.** The universal-link work uses `xcrun simctl openurl booted`, `python3 -m http.server`, and `swift test`. Nothing exotic, but you will live in the terminal alongside Xcode this week.

## Topics covered

- **`NavigationStack` and the `path` model.** The `NavigationStack(path:)` initializer, the `[Hashable]` / `NavigationPath` choice, `navigationDestination(for:)`, `NavigationLink(value:)`, and why the path is the single source of truth for "how deep am I."
- **`NavigationPath` vs a typed array.** When to reach for the type-erased `NavigationPath` (heterogeneous routes, third-party values you do not control) and when a concrete `[Route]` enum is the better engineering choice (homogeneous, `Codable`, exhaustively switchable).
- **Programmatic navigation.** Push (`path.append`), pop (`path.removeLast`), pop-to-root (`path.removeAll` / `path = []`), and replace (`path = [.note(id)]`). Driving all of them from outside the view — a button, a `task`, a notification, a deep link.
- **`navigationDestination(for:)` placement rules.** Why the modifier must live *inside* the `NavigationStack` and *above* the content, why one per value type is enough no matter how many links produce that type, and the common "destination not found" runtime warning and its cause.
- **`NavigationSplitView`.** Two-column and three-column initializers, `columnVisibility`, `preferredCompactColumn`, automatic collapse to a stack at compact size class, and the sidebar `List(selection:)` binding that drives the content column.
- **The compact-vs-regular size class.** How one `NavigationSplitView` renders as sidebar-detail on iPad/Mac and as a navigation stack on iPhone, and how to keep selection state coherent across the collapse.
- **`TabView` and value-typed selection.** `TabView(selection:)`, `Tab` value tags (iOS 18) vs the legacy `.tag()` modifier, per-tab `NavigationStack`s, and the rule that a deep link must set the selected tab *and* that tab's path together.
- **`onOpenURL`.** Registering a custom URL scheme in the target's `Info`/`URL Types`, receiving the `URL` in `.onOpenURL { }`, and why it fires for both warm foreground delivery and cold launch.
- **Universal links and Associated Domains.** The `applinks:` entitlement, the `apple-app-site-association` (AASA) JSON file, where it must be served (`/.well-known/apple-app-site-association`, HTTPS, `application/json`, no redirects), and `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`.
- **The link decoder.** Writing a pure `Route.from(url:) -> [Route]?` that handles both the custom scheme and the universal-link host, validating the id, and returning `nil` for garbage so the app does nothing rather than crashing.
- **`SceneStorage`.** Per-scene persistence scoped to the window, surviving cold launch, restricted to small `Codable`/primitive values; the `JSONEncoder`/`Data`/`String` bridge for storing a `[Route]`.
- **`AppStorage`.** The typed `UserDefaults` wrapper, app-wide scope, ideal for selected tab and sidebar preference; the `RawRepresentable` conformance that lets an enum back an `@AppStorage`.
- **State restoration end to end.** What a cold launch is, how the simulator's terminate gesture reproduces it, and how `SceneStorage` + a value-typed path combine to land the user exactly where they left.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract. The deep-link and universal-link work is best done with the simulator and a terminal side by side; do not leave the AASA wiring for the last 30 minutes of an evening — DNS-free local serving has its own footguns.

| Day       | Focus                                                       | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|-------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | `NavigationStack`, value-typed routes, `navigationDestination` |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `NavigationSplitView`, `TabView`, programmatic navigation   |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Wednesday | `SceneStorage` / `AppStorage`, cold-launch restoration      |    1.5h  |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5h      |
| Thursday  | `onOpenURL`, the link decoder, universal-links challenge    |    0.5h  |    0h     |     2h     |    0.5h   |   1h     |     2h       |    0.5h    |     6.5h    |
| Friday    | Mini-project — split view + deep link on "Hello, Notes"     |    0h    |    0h     |     1h     |    0.5h   |   1h     |     3h       |    0.5h    |     6h      |
| Saturday  | Mini-project deep work, restoration + universal-link proof  |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish                                        |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                             | **6h**   | **4.5h**  | **3h**     | **3.5h**  | **5h**   | **8.5h**     | **2.5h**   | **33h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Apple's navigation/scene docs, the AASA validator, the relevant WWDC sessions, and the open-source repos worth reading |
| [lecture-notes/01-navigation-the-post-ios16-model.md](./lecture-notes/01-navigation-the-post-ios16-model.md) | `NavigationStack`, `navigationDestination`, `NavigationLink(value:)`, `NavigationSplitView`, `TabView`, `SceneStorage`, `AppStorage` — the full post-iOS-16 model, end to end |
| [lecture-notes/02-why-value-typed-navigation-enables-deep-links.md](./lecture-notes/02-why-value-typed-navigation-enables-deep-links.md) | The argument: the same deep-link feature on the legacy `isActive` model vs the value-typed model, where the old one breaks, and how `onOpenURL` + universal links + restoration all reduce to one pure decoder |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-value-typed-stack.md](./exercises/exercise-01-value-typed-stack.md) | Build a value-typed `NavigationStack` with `NavigationLink(value:)` and `navigationDestination`, then drive it programmatically from a button |
| [exercises/exercise-02-scene-restoration.swift](./exercises/exercise-02-scene-restoration.swift) | Persist and restore the navigation path across a cold launch with `SceneStorage`/`AppStorage` |
| [exercises/exercise-03-open-url-deep-link.swift](./exercises/exercise-03-open-url-deep-link.swift) | Handle an `onOpenURL` deep link that selects a specific item and pushes its detail screen |
| [challenges/README.md](./challenges/README.md) | Index of the weekly challenge |
| [challenges/challenge-01-universal-links.md](./challenges/challenge-01-universal-links.md) | Wire up Associated Domains so a real universal link opens the app to the correct note, proven warm and cold in the simulator |
| [quiz.md](./quiz.md) | 12 multiple-choice questions on navigation, scenes, storage, and deep links |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for the Week 9 "Hello, Notes" navigation upgrade: split view for iPad/Mac, stack for iPhone, `notes://open/:id` from cold launch |

## The "it restores" promise

C20 treats one behaviour as a contract from this week forward: **terminate the app from the simulator, relaunch it, and the user is exactly where they were.** Same tab, same sidebar selection, same navigation depth, same note open. If your app drops the user back at the root list after a cold launch, you are not done — the same way a `dotnet build` with warnings means you are not done in C9. We add a second contract: **a deep link applied warm and the same deep link applied cold land on the identical screen.** If `notes://open/<id>` works while the app is running but shows the root list when the app was killed, the link handling is wired into the wrong lifecycle point, and we will show you where.

## A note on what's not here

Week 9 introduces SwiftUI navigation, scenes, storage, and deep linking. It does **not** introduce:

- **SwiftData and `@Query`.** This week's "store" is still the in-memory `@Observable NotesStore` from Week 8. Navigation must work *before* persistence so that Week 10 can drop SwiftData in underneath an already-correct navigation layer. We deliberately keep the data layer dumb this week.
- **`NavigationView` and `NavigationLink(destination:)`.** The deprecated APIs. We name them, we show one screenshot of where they break, and we never write them. If you find them in a Stack Overflow answer, the answer is older than iOS 16.
- **Routers, coordinators, and TCA navigation.** Architecture for navigation — a `Router` object, the Coordinator pattern, TCA's `NavigationStackStore` — is Week 11 material. This week you model navigation with plain SwiftUI state so you understand the substrate those patterns sit on. Reach for a router *after* you can do it without one.
- **Deferred deep links, deferred attribution, and marketing-link SDKs.** Branch, AppsFlyer, Adjust, and the "install then route" flow are a product concern, not a platform one. We teach the platform primitive (`onOpenURL`, universal links) the SDKs are built on.
- **Handoff and `NSUserActivity` continuation across devices.** We use `NSUserActivity` only as the *transport* for universal links. Cross-device Handoff is a Phase IV multi-platform topic.
- **Window management on macOS (`openWindow`, `WindowGroup` with values, `MenuBarExtra`).** Mac multi-window is Week 19. This week's macOS target is a single `WindowGroup` running the same `NavigationSplitView` as iPad.

The point of Week 9 is a single discipline expressed five ways: navigation is state, the state is value-typed, value-typed state is `Codable`, `Codable` state restores across a cold launch, and a deep link is just another way to set that state. Internalize that and every later week — SwiftData, search, multi-platform, App Intents — inherits a navigation layer that already works.

## Stretch goals

If you finish the regular work early and want to push further:

- Read the SwiftUI navigation API reference end to end: <https://developer.apple.com/documentation/swiftui/navigation>. Note every initializer of `NavigationStack` and `NavigationSplitView`.
- Watch **WWDC22 "The SwiftUI cookbook for navigation"** (<https://developer.apple.com/videos/play/wwdc2022/10054/>) — the session that introduced the post-iOS-16 model. Reproduce its `Recipe` example from memory.
- Read Apple's **"Supporting universal links in your app"** and validate a real AASA file with the **AASA Validator** (<https://branch.io/resources/aasa-validator/>). Even though we serve ours locally, understand what the validator checks.
- Implement a `NavigationPath`-based heterogeneous stack (mixing `Note`, `Tag`, and `Settings` route values) and serialize it with `NavigationPath`'s `codable` representation. Compare the ergonomics with the typed `[Route]` enum.
- Add `userActivity(_:isActive:)` to your detail screen so the *current* note advertises itself for Handoff and Spotlight, then observe it surface in the simulator's recent activities.

## Up next

Continue to **Week 10 — SwiftData: the modern persistence story** once you have shipped Week 9's mini-project with cold-launch restoration and a working `notes://open/:id` deep link. Week 10 replaces the in-memory `NotesStore` with a SwiftData `ModelContainer` — and because you modelled navigation as value-typed `Route`s keyed on a note's stable `id` rather than on an object reference, the navigation layer keeps working as the data layer changes underneath it. That is not luck. That is the payoff for treating navigation as state this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
