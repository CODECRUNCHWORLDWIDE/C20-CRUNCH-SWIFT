# Week 19 — Multi-platform: iOS, iPadOS, macOS (Catalyst + native), watchOS, visionOS

Welcome to Week 19 of **C20 · Crunch Swift** — the first week of Phase IV, Capstone & Polish. For eighteen weeks you built one app for one platform, and you built it well: persistent, networked, secure, monetized, instrumented. This week that one codebase learns to run on *five* Apple platforms. By Friday "Notes Pro v1" has a macOS-native target, a watchOS companion that shows your three most recent notes, and a visionOS window — all sharing the SwiftData models, the `NotesClient`, and the business logic you already wrote, and all running side-by-side in their respective simulators.

The throughline this week is **share the core, adapt the shell.** The mistake people make with multi-platform is one of two extremes: either they fork the codebase per platform (and now have five apps to maintain) or they ship one identical UI everywhere (and now have a Mac app that's an awkward blown-up iPhone and a watch app that's unusable). The senior move is in between, and it's a *line you draw deliberately*: the model layer, the networking, the persistence, the domain logic — that's shared, one copy, used everywhere. The presentation layer — navigation idioms, input methods, window management, what even *fits* on the screen — that adapts per platform, sometimes with `#if os(...)`, more often by letting SwiftUI's adaptive containers do the right thing on each device. Knowing *where* that line goes, and resisting the urge to either fork or flatten, is the whole skill. We spend the week on the line.

The mental shift is from "my iOS app" to "my product, which iOS is one surface of." A `NavigationSplitView` is a sidebar-detail layout on a Mac, a column layout on an iPad, and collapses to a stack on an iPhone — *the same code*, because SwiftUI's containers are adaptive by design. A watchOS app is not a tiny iPhone app; it's a glanceable, wrist-sized view onto the *same data* with a radically simpler interaction model. A visionOS window is your SwiftUI floating in space, mostly unchanged, with optional depth and immersion you add where it earns its keep. You stop asking "how do I port this?" and start asking "what does *this platform* want, given the core I already have?" That question, asked five times, is a multi-platform app.

We close the week by extending Notes Pro v1 to four new surfaces and demonstrating all of them running at once. You will add a **macOS-native target** (SwiftUI on macOS, not just Catalyst — and you'll understand the difference), a **watchOS companion** showing the three most recent notes with a complication, and a **visionOS window**. You will share the SwiftData schema and the `NotesClient` across all targets via a shared framework, gate platform-specific UI behind `#if os(...)` only where SwiftUI's adaptivity isn't enough, and prove — by running iPhone, Mac, Watch, and Vision simulators side by side — that one codebase reaches all of them. This is the multi-platform foundation the capstone builds on.

## Learning objectives

By the end of this week, you will be able to:

- **Structure** a multi-platform Xcode project: a shared SwiftUI app target with platform destinations, plus separate targets where a platform needs its own entry point (watchOS, visionOS), and a **shared framework/package** holding the models, networking, and logic used by all.
- **Distinguish** the four ways to "run on the Mac" — SwiftUI multiplatform (native AppKit-backed), Mac Catalyst ("Optimize for Mac" vs "Scale to fit iPad"), and a separate macOS target — and pick the right one for a given app, defending the trade-off.
- **Use** `#if os(...)` discipline: conditionally compile the *minimum* platform-specific code, prefer adaptive SwiftUI containers (`NavigationSplitView`, `.toolbar` placements) over branching, and keep platform forks small and localized.
- **Adapt** navigation per platform: a `NavigationSplitView` that's sidebar-detail on Mac/iPad and a stack on iPhone, with `.navigationSplitViewStyle` and column visibility tuned per idiom.
- **Build** a watchOS app: the `WKApplication`/`App` structure, a glanceable view of the most recent notes, the watch's simpler navigation, and a **complication** (a `WidgetKit` widget on the watch face) showing the note count.
- **Build** a visionOS window: a `WindowGroup` rendered in the Shared Space, the basics of `.windowStyle`, and where `ImmersiveSpace` and RealityKit volumetric content would fit (without over-building — a window is the right scope this week).
- **Decide** the share/adapt line: which layers are shared (model, network, persistence, domain) and which adapt (navigation, input, window management, density), and articulate *why* a given piece falls on each side.
- **Verify** parity: run the same feature on iPhone, Mac, Watch, and Vision simulators side by side, confirm the shared core behaves identically, and confirm each shell fits its platform.

## Prerequisites

This week assumes you have completed **C20 weeks 1–18**, or have equivalent fluency. Specifically:

- You can structure a SwiftUI view hierarchy, reason about state ownership (`@State`/`@Observable`/`@Environment`/`@Bindable`), and model navigation as state — Weeks 7–9. Multi-platform is *applied* SwiftUI: the same primitives, asked to adapt. The value-typed navigation from Week 9 is what makes the `NavigationSplitView`/`NavigationStack` adaptivity work across platforms.
- You can model a SwiftData schema and share codable types via a SwiftPM package — Weeks 6, 10. The shared framework this week is the Week 6 "shared `Models` package" pattern, now shared across *clients* instead of client-and-server.
- You have **Notes Pro v1** from Week 18 — a SwiftUI app with SwiftData, a `NotesClient`, a subscription gate, and push. This week's mini-project adds platforms to *that* app; the shared core is what you've spent eighteen weeks building.
- You're comfortable with `WidgetKit` at least conceptually — the watch complication is a widget. (WidgetKit proper is Week 20; this week you build a minimal complication and we flag the deeper material as next week's.)

**Toolchain & simulators.** Xcode 16+ on macOS (Apple Silicon strongly recommended — you'll run multiple simulators at once). Targeting iOS 18, macOS 15, watchOS 11, visionOS 2 (or the current equivalents). **All four new surfaces run in their simulators** — no physical Watch or Vision Pro is required for this week (the macOS target runs natively on your Mac). The visionOS simulator is a large download; install it before Friday. Apple Developer membership (from Week 15) is assumed but the week's work is simulator-based.

## Topics covered

- **Multi-platform project topology.** One app target with multiple destinations vs separate targets per platform; when a platform needs its own `@main` (watchOS, visionOS) and when a shared target with `#if os` suffices; the shared framework/SwiftPM package for models, networking, and logic.
- **The four ways onto the Mac.** SwiftUI multiplatform (native, AppKit-backed) vs Mac Catalyst ("Optimize for Mac" — native-feeling, vs "Scale to fit iPad" — literal port) vs a dedicated macOS target. The decision matrix and what each gives up.
- **`#if os(...)` discipline.** Conditional compilation as a *scalpel*, not a *sledgehammer*: branch the minimum, localize the forks, prefer adaptive containers, and keep `#if os` out of business logic entirely. The smell of `#if os` scattered through a view body.
- **Adaptive navigation.** `NavigationSplitView` (two/three columns) vs `NavigationStack`, `.navigationSplitViewStyle(.balanced/.prominentDetail)`, `.navigationSplitViewColumnWidth`, column visibility, and how the same code yields sidebar-detail on Mac/iPad and a stack on iPhone.
- **Toolbar and input adaptation.** `.toolbar` with `ToolbarItem(placement:)` that resolves correctly per platform (`.primaryAction`, `.navigationBarTrailing`, `.automatic`), keyboard shortcuts on Mac (`.keyboardShortcut`), context menus, and pointer vs touch affordances.
- **watchOS app structure.** The watchOS target, the `App`/`WindowGroup` (watchOS uses SwiftUI's `App` protocol), the glanceable list, the watch's simpler navigation (`NavigationStack`, no split view), `.containerBackground`, and the digital crown.
- **Watch complications.** A complication as a `WidgetKit` widget (`Widget`, `TimelineProvider`) on the watch face, the supported families (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`), and a minimal "note count" complication.
- **visionOS basics.** The Shared Space and a `WindowGroup` window, `.windowStyle(.plain/.volumetric)`, ornaments, where `ImmersiveSpace` and RealityKit volumetric/3D content fit, and why a window (not an immersive experience) is the right scope for a notes app.
- **The share/adapt line.** A concrete rubric for which layers are shared and which adapt, applied to the notes app: models/network/persistence/domain shared; navigation/input/window/density adapted. Defending the line in review.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                            | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Project topology; the share/adapt line; the four ways onto the Mac |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | `#if os` discipline; adaptive navigation; toolbar/input per platform |  2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | watchOS app + complication; visionOS window; the challenge       |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Shared framework extraction; parity verification; integration begins |  1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — add macOS, watchOS, visionOS to Notes Pro v1       |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; four simulators side-by-side             |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                       |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                  | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's multi-platform / watchOS / visionOS docs, the WWDC sessions, the Mac Catalyst reference, and the canonical writing on the share/adapt line |
| [lecture-notes/01-one-codebase-five-platforms.md](./02-lecture-notes/01-one-codebase-five-platforms.md) | The share/adapt line, project topology, the four ways onto the Mac, `#if os` discipline, and adaptive navigation across iPhone/iPad/Mac |
| [lecture-notes/02-watchos-visionos-and-the-shared-core.md](./02-lecture-notes/02-watchos-visionos-and-the-shared-core.md) | The watchOS app and complication, the visionOS window (and where immersion fits), extracting the shared framework, and verifying parity across simulators |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-adaptive-navigation.md](./03-exercises/exercise-01-adaptive-navigation.md) | Build one `NavigationSplitView` that's sidebar-detail on Mac/iPad and a stack on iPhone, and prove it in three simulators |
| [exercises/exercise-02-platform-conditional-views.swift](./03-exercises/exercise-02-platform-conditional-views.swift) | Practice `#if os` discipline and toolbar-placement adaptation with a shared view that adapts its shell per platform — the minimum-fork way |
| [exercises/exercise-03-shared-core-package.swift](./03-exercises/exercise-03-shared-core-package.swift) | Extract the model + a platform-agnostic view-model into a shared package and prove it compiles and behaves identically on every platform |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-watch-complication-and-parity.md](./04-challenges/challenge-01-watch-complication-and-parity.md) | Add a watchOS complication that shows the live note count, and produce a parity matrix proving the shared core behaves identically across all five surfaces |
| [quiz.md](./05-quiz.md) | 13 questions on topology, the four Mac options, `#if os` discipline, adaptive navigation, watchOS, visionOS, and the share/adapt line |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec: add a macOS-native target, a watchOS companion with a complication, and a visionOS window to Notes Pro v1, all sharing one core |

## The "share the core, adapt the shell" promise

Week 18 gave you "prove the pipeline, not the demo." Week 19 adds the discipline a multi-platform reviewer actually checks:

> **Every line of code lives on exactly one side of the share/adapt line, and you can say which and why.** Model, networking, persistence, and domain logic are *shared* — one copy, identical on every platform, no `#if os`. Navigation, input, window management, and visual density are *adapted* — per platform, with the smallest possible fork. If business logic has an `#if os(...)` in it, that's a smell: the platform leaked into the core. If the same view is forked five ways, that's a smell: you didn't trust SwiftUI's adaptivity. The skill is keeping the shared core platform-agnostic and the adaptations small and localized — neither forking the app nor flattening it.

You will *prove* this by extracting a shared core package that compiles unchanged for all five platforms, and by running iPhone, Mac, Watch, and Vision side by side to confirm the shared logic behaves identically while each shell fits its surface. "It runs on the Mac" is not the bar; "the same core, adapted five ways, with the line drawn deliberately" is.

## A note on what's not here

Week 19 is the *multi-platform foundation* week. It deliberately does **not** cover:

- **Deep visionOS / RealityKit.** `ImmersiveSpace`, RealityView, 3D content, hand tracking, and spatial audio are a rich topic; this week a visionOS *window* is the right scope for a notes app, and we flag where immersion would fit without building it. A notes app that forces you into an immersive space is a worse notes app.
- **WidgetKit in depth.** The watch complication is a minimal widget; Home Screen / Lock Screen widgets, timelines, and App Intents are **Week 20**. We build the smallest complication and point forward.
- **Per-platform App Store submission.** Shipping each target to its store, platform-specific review, and pricing per platform are App Review topics (Week 24). This week is "it runs everywhere"; shipping everywhere comes later.

The point of Week 19 is one codebase reaching five platforms with the share/adapt line drawn deliberately — shared core, adapted shell, proven side by side.

## Up next

Continue to **Week 20 — Widgets, App Intents, Shortcuts, Spotlight** once you have the four new surfaces running and a parity matrix proving the shared core behaves identically. Week 20 takes the multi-platform app and extends it *out of the app* — into the Home Screen and Lock Screen (widgets), into Siri and Shortcuts (App Intents), and into Spotlight. The watch complication you built this week was your first WidgetKit timeline; Week 20 generalizes it. Phase III made the app a product; Phase IV is making it an ecosystem, and the multi-platform core you shared this week is what every Phase IV feature stands on. Earn the share/adapt reflex here — the capstone's "multi-platform parity" rubric line is worth 15 points, and it's this week's skill, scaled up.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
