# Lecture 1 — One codebase, five platforms: the share/adapt line, topology, and adaptive navigation

> "Multi-platform isn't about writing your app five times, and it isn't about writing it once and shipping the same UI everywhere. It's about drawing one line — what's shared, what adapts — and defending where you drew it."

This is the lecture that decides whether your multi-platform app scales or rots. There are two failure modes, and they're opposite. The first is **forking**: you copy the iOS code into a Mac target, change a few things, and now you have two apps that drift apart with every release. The second is **flattening**: you ship one identical UI on every platform, and now your Mac app is a blown-up iPhone with a navigation bar where a menu should be, and your watch app is unusable. The senior move is neither — it's a *deliberate line* between the layers that are genuinely identical everywhere (the model, the network, the logic) and the layers that must adapt (navigation, input, window management, density). By the end of this lecture you'll have a rubric for where that line goes and the SwiftUI tools to keep the adaptations small.

We build it in order: the line itself (the most important idea), then the project topology that enforces it, then the four ways onto the Mac (the decision that confuses everyone), then `#if os` discipline, then adaptive navigation as the worked example of "the same code, adapting."

---

## 1. The share/adapt line — the one idea this week turns on

Every line of code in a multi-platform app lives on one of two sides:

**Shared (one copy, identical everywhere, no `#if os`):**

- **The model layer** — your SwiftData `@Model` types, your DTOs, your domain entities. A `Note` is a `Note` on every platform.
- **Networking** — the `NotesClient`, request signing, pinning, retry. The Mac talks to the same backend the same way the iPhone does.
- **Persistence** — the SwiftData container and queries. The store schema is platform-agnostic.
- **Domain logic** — search, filtering, the subscription gate, validation, formatting rules. "Does this user have Pro?" has the same answer everywhere.

**Adapted (per platform, smallest possible fork):**

- **Navigation** — sidebar-detail on Mac/iPad, a stack on iPhone, a flat glance on Watch. *Often the same code* via adaptive containers; sometimes a small branch.
- **Input** — touch on iOS, pointer + keyboard on Mac, the Digital Crown on Watch, eyes + pinch on Vision. Different affordances.
- **Window management** — one full-screen scene on iPhone, multiple resizable windows on Mac, a floating window in space on Vision.
- **Density and layout** — what *fits*. A Mac shows three columns; a watch shows three lines. The same data, radically different density.

The rubric, stated as a test you can apply to any piece of code: **if the answer is the same on every platform, it's shared; if the answer depends on what the user is holding (or wearing, or looking at), it adapts.** "What notes does this tag contain?" — same answer everywhere, shared. "How do I show them?" — depends on the screen, adapts.

Two smells tell you the line is in the wrong place:

- **`#if os(...)` inside business logic.** If your search function or your entitlement check has a platform branch, the platform leaked into the core. The core must be platform-agnostic. Push the `#if os` up into the view layer where presentation lives.
- **The same view forked five ways.** If you copy-pasted a list view into five targets and tweaked each, you didn't trust SwiftUI's adaptivity. Most of the time one `NavigationSplitView` adapts to three platforms for free (§5); reach for a fork only when adaptivity genuinely can't express the difference.

The whole week is this line, applied. Hold it through everything that follows.

---

## 2. Project topology — structure that enforces the line

The topology *makes* the line physical. The shared core goes in a **framework or SwiftPM package** that every app target depends on; the platform shells are thin app targets on top.

```text
NotesProWorkspace/
├── NotesCore/                  ← SwiftPM package: SHARED, platform-agnostic
│   ├── Models/                 ← @Model types, DTOs
│   ├── Networking/             ← NotesClient, signing, pinning
│   ├── Persistence/            ← ModelContainer, queries
│   └── Domain/                 ← search, filtering, the subscription gate
│
├── NotesPro-iOS/               ← thin app target: iPhone + iPad + Mac (one target, destinations)
│   └── (imports NotesCore; adaptive SwiftUI shell)
├── NotesPro-Watch/             ← separate watchOS app target (needs its own @main)
│   └── (imports NotesCore; glanceable shell)
├── NotesPro-Vision/            ← visionOS (can be a destination of the iOS target, or its own)
│   └── (imports NotesCore; window shell)
└── NotesPro-WatchComplication/ ← WidgetKit extension for the watch face
    └── (imports NotesCore; timeline provider)
```

Two structural decisions:

- **One app target with multiple destinations** handles iPhone, iPad, and Mac (and often visionOS) from a *single* SwiftUI app. You add destinations in the target's "Supported Destinations" and the *same* `@main App` runs on all of them, adapting via SwiftUI. This is the default and the one you reach for first.
- **A separate target with its own `@main`** is needed when a platform has a genuinely different entry point and lifecycle — **watchOS** (its own app, often a companion) and complications/widgets (extensions). visionOS *can* be a destination of the shared iOS target (it often is), but you may give it its own target if its window/scene model diverges enough.

The package is the enforcement mechanism. Because `NotesCore` must compile for *every* platform, you physically cannot put a `#if os(iOS)`-only UIKit call in it without breaking the watchOS build — the package structure makes the share/adapt line a *compiler-enforced* boundary, not just a convention. That's why we extract the core into a package this week (exercise 3): it's the line, made of build settings.

---

## 3. The four ways onto the Mac — the decision everyone gets confused by

"Run on the Mac" is not one thing; it's four, and picking wrong gives you an awkward app. Here they are, worst-fit to best-fit for a SwiftUI app in 2026:

| Approach | What it is | When it's right |
|----------|------------|-----------------|
| **Mac Catalyst — "Scale to fit iPad"** | Your iPad app, literally scaled onto the Mac. Looks like a big iPad app. | Almost never for new work — it's a stopgap, not a Mac app. |
| **Mac Catalyst — "Optimize for Mac"** | Your UIKit/iPad app with native Mac controls, spacing, and idioms layered on. | A large existing **UIKit** app you can't rewrite in SwiftUI. |
| **SwiftUI multiplatform (native)** | The *same* SwiftUI app target, with macOS as a destination, rendered with native AppKit-backed controls. | **A SwiftUI app — this is the default.** Native feel, shared code, least effort. |
| **A dedicated macOS target** | A separate Mac app target (still SwiftUI), for when the Mac experience diverges enough to warrant its own shell. | When the Mac app is genuinely a different product (a pro tool vs a companion). |

For *this* track — a SwiftUI app — the answer is **SwiftUI multiplatform (native)**: add macOS as a destination of your existing SwiftUI target. You get native Mac controls (a real menu bar, native toolbars, resizable windows) with the shared code, and SwiftUI renders the right thing per platform. The mini-project specifies a "macOS-native target using SwiftUI" precisely to land you here, not on Catalyst.

When does Catalyst still matter? **When you have a big UIKit codebase you can't rewrite.** Catalyst lets a UIKit iPad app run on the Mac with native chrome — a pragmatic bridge. But if you're writing SwiftUI today, you skip Catalyst and use the native SwiftUI path. The syllabus says "Catalyst + native" because you should *understand both*; for new SwiftUI work you *choose* native.

You can tell at compile time which world you're in:

```swift
#if targetEnvironment(macCatalyst)
// Running as a Catalyst app (UIKit-on-Mac). Rare in new SwiftUI work.
#elseif os(macOS)
// Running as a native macOS SwiftUI app. This is our path.
#endif
```

---

## 4. `#if os(...)` discipline — a scalpel, not a sledgehammer

`#if os(...)` is how you conditionally compile platform-specific code. It's necessary — some APIs only exist on some platforms (`UIImpactFeedbackGenerator` is iOS-only; `NSColor` is macOS-only; the Digital Crown is watchOS-only). The discipline is using the *minimum* amount of it, as locally as possible.

The wrong way — a sledgehammer that forks a whole view:

```swift
// BAD: the entire body is forked. Two copies to maintain; they'll drift.
var body: some View {
    #if os(iOS)
    NavigationStack { list }
        .navigationBarTitleDisplayMode(.large)
    #elseif os(macOS)
    NavigationSplitView { sidebar } detail: { list }
        .frame(minWidth: 600)
    #endif
}
```

The right way — a scalpel that branches only the genuinely-different line, and prefers adaptive containers for the rest:

```swift
// GOOD: one adaptive container; a tiny modifier branch only where the API differs.
var body: some View {
    NavigationSplitView {
        sidebar
    } detail: {
        list
    }
    .modifier(PlatformWindowSizing())   // the one bit that's actually platform-specific
}

// The platform fork is isolated in ONE small, named place.
struct PlatformWindowSizing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 600, minHeight: 400)
        #else
        content
        #endif
    }
}
```

The principles:

1. **Prefer adaptivity over branching.** `NavigationSplitView` already collapses to a stack on iPhone (§5). Don't `#if os` what SwiftUI adapts for free.
2. **Branch the smallest unit.** A single modifier, a single property — not a whole `body`. Isolate the fork in a named `ViewModifier`, a small helper, or an `extension`.
3. **Keep `#if os` out of the core entirely.** Business logic in `NotesCore` has zero platform branches (§2). The forks live only in the shell.
4. **Centralize platform constants.** If several views need a platform-specific spacing or color, put it in one `Platform` enum/namespace, not scattered.

The smell to grep for: `#if os` appearing more than a handful of times, or appearing in any file that isn't a view. Each occurrence is a small debt; a pile of them is a forked app wearing a shared-app costume.

---

## 5. Adaptive navigation — the worked example of "the same code, adapting"

Navigation is where the share/adapt line is most beautifully handled by SwiftUI, because `NavigationSplitView` is *adaptive by construction*. The same declaration is:

- **Three columns** (sidebar + content + detail) on a wide Mac window or iPad in landscape,
- **Two columns** (sidebar + detail) on a narrower iPad,
- **A navigation stack** (push/pop) on an iPhone, where there's no room for columns.

You write it once:

```swift
struct NotesRootView: View {
    @State private var selectedTag: Tag?
    @State private var selectedNote: Note?

    var body: some View {
        NavigationSplitView {
            // Column 1: the sidebar (tags). On iPhone this becomes the root of the stack.
            TagSidebar(selection: $selectedTag)
                .navigationTitle("Tags")
        } content: {
            // Column 2: notes for the selected tag.
            NotesList(tag: selectedTag, selection: $selectedNote)
                .navigationTitle(selectedTag?.name ?? "All Notes")
        } detail: {
            // Column 3: the selected note's detail/editor.
            if let note = selectedNote {
                NoteDetailView(note: note)
            } else {
                ContentUnavailableView("Select a note", systemImage: "note.text")
            }
        }
        .navigationSplitViewStyle(.balanced)   // how the columns share width
    }
}
```

On a Mac this is a three-pane productivity layout with a real sidebar. On an iPhone, SwiftUI *automatically* collapses it into a `NavigationStack`: tapping a tag pushes the notes list, tapping a note pushes the detail. **You wrote zero platform branches.** The `selectedTag` / `selectedNote` state — value-typed selection, the Week 9 pattern — is what lets the same declaration drive both the column selection on Mac and the push navigation on iPhone. This is the payoff of modeling navigation as state: it's inherently adaptive.

Where you *do* adapt navigation, it's small and intentional:

- **`.navigationSplitViewStyle(.balanced / .prominentDetail)`** tunes how columns share width — you might want `.prominentDetail` on iPad so the editor dominates.
- **Toolbar placement** resolves per platform automatically when you use semantic placements:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {        // trailing on iOS, in the toolbar on Mac
        Button("Add", systemImage: "plus", action: addNote)
    }
    ToolbarItem(placement: .automatic) {            // SwiftUI picks the right spot per platform
        Button("Filter", systemImage: "line.3.horizontal.decrease", action: showFilter)
    }
}
```

`.primaryAction` and `.automatic` are *semantic* placements — you say "this is the primary action," and SwiftUI puts it in the platform-correct location (trailing nav bar on iOS, the window toolbar on Mac). You avoid `.navigationBarTrailing` (iOS-only, would `#if os` you) by using the semantic placement that adapts.

- **Keyboard shortcuts** are a Mac affordance you add without forking the rest:

```swift
Button("Add", action: addNote)
    .keyboardShortcut("n", modifiers: .command)   // ⌘N on Mac; harmless/ignored elsewhere
```

`.keyboardShortcut` is a no-op where there's no keyboard, so you don't even need an `#if os` — you add the Mac affordance and it's simply inert on the iPhone. That's the ideal: an adaptation that costs nothing on platforms that don't use it.

---

## 6. Size classes and adaptive layout — adapting *within* a platform

The share/adapt line isn't only between platforms; it's also *within* one. An iPad runs your app in full screen, in Split View (half width), and in Slide Over (a narrow column) — three very different widths on the *same device*. An iPhone is compact width in portrait and (on larger models) regular width in landscape. A Mac window resizes continuously. So "adapt the shell" includes adapting to the *space available*, not just the platform identity, and SwiftUI gives you tools that read space rather than platform.

The wrong reflex is to key layout off `#if os` — "iPad gets a sidebar, iPhone gets a stack." That's wrong because an iPad in Slide Over is as narrow as an iPhone and *wants* the stack, while an iPhone 16 Pro Max in landscape is wide enough for a sidebar. The right reflex is to key off **size classes** — the horizontal and vertical size class environment values that describe the *current* space, regardless of device:

```swift
struct AdaptiveRoot: View {
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        // Read the SPACE, not the platform. A compact width (iPhone portrait,
        // iPad in Slide Over) gets the stack; a regular width (iPad full, Mac)
        // gets the split. This adapts correctly WITHIN a platform, too.
        if hSize == .compact {
            NavigationStack { NotesList() }
        } else {
            NavigationSplitView { TagSidebar() } detail: { NotesList() }
        }
    }
}
```

Most of the time you don't even write this — `NavigationSplitView` already collapses based on available width, which *is* the size-class logic, done for you (§5). But when you need a custom adaptive layout (a grid that's two columns when narrow and four when wide), `horizontalSizeClass` is the right input, and `ViewThatFits` is the right tool: it tries layouts in order and picks the first that fits the available space.

```swift
// ViewThatFits: offer a wide layout and a narrow fallback; SwiftUI picks the
// first that fits. Adapts to window resize on Mac and Split View on iPad, with
// no size-class branching at all.
ViewThatFits(in: .horizontal) {
    HStack { detailPane; sidebarPane }   // wide: side by side
    VStack { sidebarPane; detailPane }   // narrow: stacked
}
```

The principle generalizes the whole week's thesis: **adapt to conditions, not identities.** "Is this an iPad?" is the wrong question (an iPad can be narrow); "is there room for two columns right now?" is the right one. Size classes, `ViewThatFits`, and the adaptive containers answer the right question, and they keep working as the user resizes a Mac window or slides an iPad app to half width — situations a `#if os` branch would get wrong, because the platform didn't change but the space did. This is also why size-class-driven layout is *shared* code, not adapted: it reads the environment and does the right thing on every platform, so it lives happily in a shared view with no branches.

---

## 7. Scenes and windows — the lifecycle that differs per platform

One more piece of the adapt side deserves its own section, because it trips people up: **scenes and window management.** The SwiftUI `App`/`Scene`/`WindowGroup` model is shared — every platform uses it — but what a "window" *means* is profoundly different per platform, and a multi-platform app handles those differences at the scene level, above the views.

On iPhone, your app is essentially one full-screen scene; the user sees one window at a time. On iPad, you can have multiple scenes (Split View, Slide Over, multiple windows of the same app). On the Mac, windows are first-class: resizable, multiple, with a menu bar, and the user expects ⌘N to open a *new window*, ⌘W to close one, and the app to keep running with no windows open. On visionOS, a window floats in space and the user can have several arranged around them. The same `WindowGroup` declaration handles all of this, but you tune it per platform:

```swift
@main
struct NotesProApp: App {
    var body: some Scene {
        WindowGroup {
            NotesRootView()
        }
        .modelContainer(for: [Note.self, Tag.self])

        #if os(macOS)
        // Mac-only: a Settings scene gives you the standard ⌘, preferences window.
        Settings {
            SettingsView()
        }
        #endif
    }
}
```

The `Settings` scene is a clean example of the share/adapt line at the *scene* level: macOS has a standard preferences window (⌘,), and you express it with a `Settings` scene — which doesn't exist on iOS, so it's behind an `#if os(macOS)`. The *content* of the settings (which preferences exist) is shared logic; the *scene that hosts it* is a Mac affordance. You branch the scene, not the settings model.

Two more scene-level adaptations worth knowing:

- **`.commands { }`** attaches menu-bar commands on the Mac (File ▸ New Note, with ⌘N). On other platforms the modifier is simply inert — the same "free adaptation" pattern as `.keyboardShortcut`. You add the menu commands and they appear only where there's a menu bar.
- **`WindowGroup(for:)`** with a value type opens a *new window per value* — on the Mac and iPad, double-clicking a note could open it in its own window. This is the multi-window capability that doesn't exist on iPhone; you add it and it's available where the platform supports multiple windows, ignored where it doesn't.

The principle, repeated from §4: the *scene model* is shared (every platform uses `App`/`Scene`/`WindowGroup`), and the *scene-level affordances* (Settings, menu commands, multi-window) adapt — added where the platform has them, inert or `#if os`-guarded where it doesn't. You handle windowing once, at the top, rather than letting it leak into every view.

---

## 8. The decision table — share or adapt?

| Piece of code | Side | Why |
|---------------|------|-----|
| `@Model` types, DTOs | **Shared** | A `Note` is a `Note` everywhere |
| `NotesClient`, signing, pinning | **Shared** | Same backend, same protocol |
| SwiftData container, queries | **Shared** | Platform-agnostic store |
| Search / filter / subscription gate | **Shared** | Same answer on every platform |
| `NavigationSplitView` structure | **Shared (adaptive)** | One declaration adapts to three platforms |
| `.navigationSplitViewStyle`, column widths | **Adapt (small)** | Tuned per idiom |
| Toolbar *placement* | **Shared (semantic)** | `.primaryAction` resolves per platform |
| Keyboard shortcuts | **Adapt (free)** | Mac affordance, inert elsewhere |
| Window sizing (`minWidth`) | **Adapt (`#if os`)** | macOS-only API |
| Haptics, Digital Crown, immersive space | **Adapt (per-platform)** | Platform-exclusive input |
| The watch's glanceable list | **Adapt (own shell)** | Radically different density |

The pattern: the core is shared with zero branches; navigation is shared-via-adaptivity; small per-platform tunings are isolated; and only genuinely platform-exclusive things (window sizing, the Crown, immersion) get a real fork — kept small.

---

## 9. The cost model — why you don't fork, in dollars and hours

It helps to make the share/adapt argument concrete, because "don't fork" can sound like dogma until you count the cost. Consider a feature — say, tag filtering — and what each strategy costs to *build* and to *maintain*.

**The fork strategy.** You copy the iOS tag-filter code into a Mac target, a watch target, and a Vision target, tweaking each. Build cost: roughly 4× (you wrote it four times). But the real cost is *maintenance*: every bug fix, every change to the filter logic, every new edge case must now be applied four times, and the four copies *drift* — a fix lands in the iOS copy and someone forgets the Mac copy, and now the Mac filters differently. Six months in, you have four subtly-different tag filters and a bug report that only reproduces on the watch. The fork's cost isn't the 4× to build; it's the unbounded, compounding cost of keeping four copies in sync forever.

**The flatten strategy.** You write the tag filter once and ship the identical UI everywhere. Build cost: 1×, cheap. But now the Mac has an iPhone-sized filter sheet floating in a huge window, the watch has a filter UI that doesn't fit and is unusable, and the Vision app has touch targets sized for fingers when the user is pinching. The flatten's cost is paid by the *user*, in a worse app on every platform except the one you designed for — and eventually by you, when the one-star reviews say "the Mac app is just a blown-up phone app."

**The share/adapt strategy.** The filter *logic* (`NotesDomain.matching`) is shared — written once, in the core, tested once. The filter *presentation* adapts: a sheet on iPhone, a sidebar section on Mac/iPad, a simplified toggle on the watch, and absent-by-design where it doesn't fit. Build cost: 1× for the logic plus a small per-platform shell — call it 1.5×, not 4×. Maintenance cost: a logic fix lands *once* and is correct everywhere (the shells call the same function), and each shell is small enough to adjust independently. This is the only strategy whose maintenance cost doesn't compound, because the thing most likely to change — the logic — has exactly one copy.

The table, made explicit:

| Strategy | Build cost | Maintenance cost | User experience |
|----------|-----------|------------------|-----------------|
| **Fork** | ~4× | Compounds — four copies drift | Good (if you maintain all four) |
| **Flatten** | ~1× | Low | Bad on every non-primary platform |
| **Share/adapt** | ~1.5× | Logic fixed once; shells small | Good everywhere, fit per platform |

This is why the line isn't dogma — it's the only point on the curve where build cost stays low *and* maintenance doesn't compound *and* the user gets a platform-appropriate app. Forking buys per-platform fit at unbounded maintenance cost; flattening buys low cost at the user's expense; sharing the core and adapting the shell is the engineering optimum. When a teammate proposes forking a view "just for the Mac," the cost model is your answer: the 4× isn't the problem, the *drift* is.

---

## 10. Recap — the iPhone/iPad/Mac half of the week

You now own the foundational half of multi-platform:

1. **The share/adapt line is the whole game.** Shared: model, network, persistence, domain — one copy, no `#if os`, the answer is the same everywhere. Adapted: navigation, input, window, density — the answer depends on what the user is holding. Two smells flag a misplaced line: `#if os` in business logic, and a view forked five ways.
2. **Topology enforces the line.** A `NotesCore` SwiftPM package, compiled for every platform, makes the boundary a compiler-enforced fact. Thin app targets sit on top; watchOS and extensions get their own `@main`.
3. **Pick the native SwiftUI path onto the Mac.** Of the four ways, SwiftUI multiplatform (native, AppKit-backed) is the default for a SwiftUI app. Catalyst is for big UIKit apps you can't rewrite. Understand both; choose native.
4. **`#if os` is a scalpel.** Prefer adaptive containers; branch the smallest unit; isolate forks in named modifiers; keep the core branch-free.
5. **Navigation adapts for free.** One `NavigationSplitView` with value-typed selection is sidebar-detail on Mac/iPad and a stack on iPhone — the Week 9 pattern paying off across platforms. Semantic toolbar placements and free keyboard shortcuts adapt without forking.

In lecture 2 we add the two platforms with their own shells — watchOS (a glanceable companion with a complication) and visionOS (a window in space) — and then extract the shared core into the package that makes the whole thing hold together, and verify parity by running everything side by side. The iPhone/iPad/Mac trio came nearly for free; the Watch and the Vision want their own shells onto the same core. Bring the line; we're about to test it on the two hardest platforms.
