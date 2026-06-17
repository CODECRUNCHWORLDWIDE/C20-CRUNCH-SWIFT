# Lecture 1 — Navigation in SwiftUI: the post-iOS-16 model

> **Reading time:** ~90 minutes. **Hands-on time:** ~60 minutes (you build a value-typed stack, collapse it into a split view, and restore it across a cold launch).

SwiftUI shipped in 2019 with a navigation API — `NavigationView` and `NavigationLink(destination:)` — that was wrong in a way that took Apple three years to admit and fix. In iOS 16 (2022) they shipped the replacement: `NavigationStack`, `NavigationSplitView`, `navigationDestination`, and value-typed `NavigationLink(value:)`. In 2026, on iOS 18 / iPadOS 18 / macOS 15, the new model is the *only* model a senior engineer writes. This lecture builds it from the ground up: the stack, the destination registry, value-typed links, programmatic control, the split view, the tab view, and the storage layer that makes all of it survive a cold launch.

The thesis of the whole week is one sentence: **navigation is state, you own that state as plain `Hashable` (ideally `Codable`) values, and every navigation operation — push, pop, deep link, restore — is a mutation of that state.** Hold that sentence in your head; everything below is an elaboration of it.

## 1.1 — Why `NavigationView` had to die

Here is the old model, so you recognize it when you see it in a five-year-old answer online:

```swift
// LEGACY — do not write this in 2026. Shown so you can identify it.
NavigationView {
    List(notes) { note in
        NavigationLink(destination: NoteDetailView(note: note)) {
            Text(note.title)
        }
    }
}
```

There are three fatal problems with this, and they are all the same problem wearing different hats.

**Problem one: the destination is built eagerly, inside the row.** `NoteDetailView(note: note)` is constructed for *every* row in the list, whether or not the user ever taps it. For a list of ten notes that is wasteful; for a list of ten thousand it is a performance bug. SwiftUI later added a lazy variant, but the eager form was the default for years and produced real hitches.

**Problem two: there is no value you can set to navigate.** To push a screen programmatically you used `NavigationLink(destination:, isActive: $someBool)` and flipped `someBool`. One boolean per possible destination. They did not compose — to go three screens deep you needed three booleans coordinated by hand — and flipping two at once mid-animation produced the classic glitch where the stack popped and pushed in the wrong order. There was no answer to "put me three screens into note X," because the only state was a scatter of booleans, none of which encoded *depth* or *order*.

**Problem three — the one that matters for this week: you could not serialize it.** A tree of `NavigationLink` views with `isActive` bindings is not data. You cannot write it to disk, you cannot reconstruct it from a URL, you cannot diff two of them. Deep linking and state restoration both require navigation to *be data*, and the old model's navigation was code.

`NavigationStack` fixes all three by making the navigation state a single value: an array.

## 1.2 — `NavigationStack` and the `path`

The new model has two pieces:

1. A **path** — an ordered collection of `Hashable` values, one per pushed screen. The array's `count` is your depth. The array's contents are *which* screens, in order.
2. A set of **destinations** — `navigationDestination(for:)` modifiers that map a value's *type* to the view that renders it.

```swift
import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(Note.samples) { note in
                NavigationLink("Open \(note.title)", value: Route.note(id: note.id))
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .note(let id):
                    NoteDetailView(noteID: id)
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

enum Route: Hashable {
    case note(id: UUID)
    case settings
}
```

Read this carefully because every line earns its place.

- `@State private var path: [Route] = []` — the navigation state. Empty array means "at the root." This view *owns* the path; that is a Week 8 ownership decision and it is the correct one here, because this view is the navigation container.
- `NavigationStack(path: $path)` — binds the stack to your array. The stack renders `path.count` screens on top of the root content. When the user taps a link, SwiftUI appends to `path`. When the user taps Back, SwiftUI removes the last element. The binding is two-way: the system mutates it on user gestures, and *you* mutate it for programmatic navigation.
- `NavigationLink("…", value: Route.note(id: note.id))` — the link does not name a destination view. It names a *value*. Tapping it appends that value to the path. The link is now trivial data; it does not build `NoteDetailView` until the screen is actually shown.
- `.navigationDestination(for: Route.self) { route in … }` — the registry. "When a `Route` value appears in the path, render it like this." One modifier handles every `Route` in the path, no matter how many links produced them.

The destination closure is the *only* place destination views are constructed, and only for routes actually in the path. Lazy by default. No eager allocation.

### Two rules about `navigationDestination` placement

Beginners trip on both:

**Rule 1 — it must be inside the `NavigationStack`.** The modifier registers with the nearest enclosing stack. Put it outside and you get a purple runtime warning: *"A navigationDestination for "Route" was declared earlier on the stack. Only the destination declared closest to the root view of the stack will be used."* — or, if it is entirely outside, the link does nothing.

**Rule 2 — it attaches to content *within* the stack, not to the stack itself, and it should be on a view that is always present.** Putting it on a conditionally-rendered view means the destination disappears when that view does, and the push silently fails. Attach it to the root content (the `List` above), not to a row.

## 1.3 — `[Route]` vs `NavigationPath`

There are two ways to type the path.

**A concrete typed array — `[Route]`.** Every element is the same `Hashable` type, usually an `enum`. This is what you saw above. Its advantages are everything good about enums: it is exhaustively switchable (the compiler tells you when you forgot a case), it is trivially `Codable` (so it serializes for restoration and decodes from URLs), and it is the entire navigation contract written down in one type you can read top to bottom. **Reach for this by default.** For an app you control, it is almost always right.

**`NavigationPath` — a type-erased path.** It can hold *heterogeneous* `Hashable` values: a `Note.ID`, a `Tag`, a `URL`, a third-party value you do not own — all in the same path. You register a separate `navigationDestination(for:)` per type. Its advantage is exactly that heterogeneity; its cost is that you lose the exhaustive switch and you serialize through `NavigationPath.CodableRepresentation`, which only works if every value type conforms to `Codable`.

```swift
@State private var path = NavigationPath()

// pushing
path.append(note.id)        // a UUID
path.append(someTag)        // a Tag
// popping
path.removeLast()
// depth
path.count
```

The decision rule: **use `[Route]` when your routes are a closed set you control (almost always); use `NavigationPath` only when the path genuinely must mix types you cannot unify into one enum.** For "Hello, Notes" the routes are a closed set, so we use the enum. We will mention `NavigationPath` again only where its `CodableRepresentation` matters for restoration.

## 1.4 — Programmatic navigation: it is just array mutation

Because the path is a plain array, every navigation operation is an array operation. No `isActive`, no coordinator, no magic.

```swift
struct NotesListView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Button("Open the first note") {
                    path.append(.note(id: Note.samples[0].id))   // PUSH
                }
                Button("Open Settings") {
                    path.append(.settings)                        // PUSH
                }
                Button("Open note then Settings (two deep)") {
                    path = [.note(id: Note.samples[0].id), .settings]  // REPLACE whole path
                }
            }
            .navigationDestination(for: Route.self, destination: destination)
            .toolbar {
                Button("Pop to root") { path.removeAll() }        // POP TO ROOT
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id): NoteDetailView(noteID: id)
        case .settings:     SettingsView()
        }
    }
}
```

The four canonical operations:

| Operation | Code | Meaning |
|-----------|------|---------|
| **Push** | `path.append(.note(id))` | Add one screen on top |
| **Pop** | `path.removeLast()` | Remove the top screen |
| **Pop to root** | `path.removeAll()` (or `path = []`) | Back to depth 0 |
| **Replace** | `path = [.note(id), .settings]` | Set the entire stack at once |

That last one — **replace** — is the deep-link primitive. A deep link does not "navigate step by step"; it computes the destination path and assigns it. `path = decode(url)`. We build exactly that in Lecture 2 and the exercises.

This is also why you must own the path with `@State` at the container, not bury it in a child. Anything with access to the binding can drive navigation: a button, a `.task`, an `.onReceive`, an `.onOpenURL`. They all do the same thing — mutate the array — so they all compose. That is the whole win over `isActive`.

### A note on `NavigationLink(value:)` inside pushed screens

Links work at any depth. A `NavigationLink(value: Route.tag(id))` inside `NoteDetailView` appends to the *same* path owned by the container, pushing a third screen. You do not re-declare `navigationDestination` in the child — the registration on the root handles every `Route` in the path regardless of which screen emitted it. One registry, any depth.

## 1.5 — `NavigationSplitView`: sidebar–content–detail

`NavigationStack` is a single column of pushed screens. That is the right shape for iPhone. On iPad and Mac, a single narrow column wastes a 13-inch display; the platform idiom is two or three columns side by side — a sidebar, a content list, and a detail pane. `NavigationSplitView` is that.

```swift
struct RootSplitView: View {
    @State private var selectedTag: Tag.ID?       // sidebar selection
    @State private var selectedNote: Note.ID?     // content selection
    @State private var detailPath: [Route] = []   // pushes within detail

    let store: NotesStore

    var body: some View {
        NavigationSplitView {
            // Column 1 — sidebar
            List(store.tags, selection: $selectedTag) { tag in
                Label(tag.name, systemImage: "tag")
                    .tag(tag.id)
            }
            .navigationTitle("Tags")
        } content: {
            // Column 2 — content (notes in the selected tag)
            List(store.notes(in: selectedTag), selection: $selectedNote) { note in
                Text(note.title)
                    .tag(note.id)
            }
            .navigationTitle("Notes")
        } detail: {
            // Column 3 — detail (the selected note, plus a stack for deeper pushes)
            NavigationStack(path: $detailPath) {
                if let id = selectedNote {
                    NoteDetailView(noteID: id)
                        .navigationDestination(for: Route.self, destination: destination)
                } else {
                    ContentUnavailableView("Select a Note", systemImage: "note.text")
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id): NoteDetailView(noteID: id)
        case .settings:     SettingsView()
        case .tag:          EmptyView()
        }
    }
}
```

The key facts:

- The split view takes **two or three** view builders. Two-column is `NavigationSplitView { sidebar } detail: { detail }`. Three-column adds the middle `content:`.
- Each column's selection is **`@State` you own**, bound through `List(selection:)`. Selecting a sidebar row sets `selectedTag`, which feeds the content column's data; selecting a content row sets `selectedNote`, which feeds the detail.
- The detail column commonly wraps a `NavigationStack` so the user can push *further* (note → linked note → tag) without leaving the detail pane. That nested stack has its own `path`.
- `ContentUnavailableView` (iOS 17+) is the idiomatic empty state for an unselected column. Use it; do not ship a blank pane.

### The compact collapse

Here is the feature that makes `NavigationSplitView` worth the trouble: **at a compact horizontal size class (iPhone portrait), it automatically collapses into a single navigation stack.** The sidebar becomes the root screen; selecting a row pushes the content; selecting a content row pushes the detail. You write the three-column layout once and the framework renders it as a stack on iPhone and as side-by-side columns on iPad/Mac. You do not branch on device.

There are knobs:

- `NavigationSplitView(columnVisibility:)` — a `Binding<NavigationSplitViewVisibility>` to programmatically show/hide the sidebar (`.all`, `.doubleColumn`, `.detailOnly`).
- `.navigationSplitViewColumnWidth(min:ideal:max:)` — per-column width hints on Mac/iPad.
- `preferredCompactColumn` — a `Binding<NavigationSplitViewColumn>` that says which column to show when collapsed. A deep link to a note sets this to `.detail` so the collapsed stack lands on the note, not the sidebar.

The one thing you must keep coherent: **selection survives the collapse.** When the iPhone user is deep in a detail and rotates to landscape on an iPad-class width (or the app moves to a Mac via Continuity), the `selectedNote` you owned is still set, so the detail column renders correctly. Because selection is value-typed `@State` you own, this Just Works — the same reason value-typed navigation makes deep links work.

## 1.6 — `TabView` and value-typed selection

Many apps are tab-based at the top level, with a navigation stack *inside* each tab. The post-iOS-16 idiom uses value-typed selection here too.

```swift
enum AppTab: Hashable {
    case notes, search, settings
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .notes
    @State private var notesPath: [Route] = []
    @State private var searchPath: [Route] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Notes", systemImage: "note.text", value: AppTab.notes) {
                NavigationStack(path: $notesPath) {
                    NotesListView(path: $notesPath)
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack(path: $searchPath) {
                    SearchView(path: $searchPath)
                }
            }
            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}
```

Notes:

- The iOS 18 `Tab("…", systemImage:, value:) { … }` API replaces the older `.tabItem { }` + `.tag()` pattern. Each tab carries a `value` of the selection type. `TabView(selection: $selectedTab)` binds to it.
- **Each tab owns an independent navigation path.** The Notes tab being three deep does not affect the Search tab. This is correct and expected — tapping a tab returns you to where you were in that tab.
- The standard "tap the active tab to pop to root" behaviour is something you wire yourself: observe re-selection and reset that tab's path. (We do this in homework.)

The deep-link consequence is the one rule to memorize: **a deep link into a tabbed app must set the selected tab AND that tab's path together, atomically.** `notes://open/<id>` is not just `notesPath = [.note(id)]`; it is *also* `selectedTab = .notes`. Set one without the other and the right screen is built in a tab the user cannot see. The decoder returns both pieces; the handler applies both. Lecture 2 makes this explicit.

## 1.7 — `AppStorage` and `SceneStorage`: making it survive

You now have navigation modelled as state: a `selectedTab`, some `[Route]` paths, a `selectedNote`. The last step is persisting the parts that should survive a relaunch. SwiftUI gives you two property wrappers, and choosing between them correctly is the skill.

### `AppStorage` — app-wide preferences in `UserDefaults`

`@AppStorage("key")` is a typed binding into `UserDefaults.standard`. It is **app-wide** (shared across every scene/window), it persists forever (until overwritten or the app is deleted), and it is meant for *small preferences*: the selected tab, a sidebar layout choice, "open notes in the editor by default."

```swift
struct AppTabView: View {
    @AppStorage("selectedTab") private var selectedTab: AppTab = .notes
    // …
}

// AppStorage requires RawRepresentable with a primitive RawValue (String/Int).
enum AppTab: String, Hashable {
    case notes, search, settings
}
```

`@AppStorage` natively supports `Bool`, `Int`, `Double`, `String`, `URL`, `Data`, and any `RawRepresentable` whose `RawValue` is `Int` or `String`. That last clause is why `AppTab` is `String`-backed — it makes the enum storable as one line with no encoder.

### `SceneStorage` — per-scene state for restoration

`@SceneStorage("key")` is the one built for navigation. It is **per-scene**: each window/scene gets its own copy, automatically scoped by the system. It is **restoration storage** — the system persists it when the scene backgrounds and restores it when the scene relaunches, including after a cold launch where the process was killed. And it is restricted to the same small types as `AppStorage` (`Bool`, `Int`, `Double`, `String`, `Data`).

That restriction is the catch: a `[Route]` is not directly storable. You bridge it through `Codable` → `Data` → store the `Data` (or a base64/`JSON` `String`). The pattern:

```swift
struct NotesListView: View {
    @State private var path: [Route] = []
    @SceneStorage("notes.path") private var serializedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            List { /* … rows … */ }
                .navigationDestination(for: Route.self, destination: destination)
        }
        .onAppear { restore() }                         // restore on (re)launch
        .onChange(of: path) { _, newValue in save(newValue) }  // persist every change
    }

    private func save(_ path: [Route]) {
        serializedPath = try? JSONEncoder().encode(path)
    }

    private func restore() {
        guard let data = serializedPath,
              let decoded = try? JSONDecoder().decode([Route].self, from: data)
        else { return }
        path = decoded
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id): NoteDetailView(noteID: id)
        case .settings:     SettingsView()
        }
    }
}
```

For this to compile, `Route` must be `Codable`:

```swift
enum Route: Hashable, Codable {
    case note(id: UUID)
    case settings
}
```

Swift synthesizes `Codable` for an enum with associated values automatically (since Swift 5.5), so this is a one-word addition. That single word is the entire reason value-typed navigation makes restoration trivial — the path is already data; you only have to spell `Codable`.

### The decision table

| Need | Wrapper | Why |
|------|---------|-----|
| Selected tab, persisted app-wide | `@AppStorage` | App-wide preference, `RawRepresentable` enum, survives forever |
| Sidebar visibility preference | `@AppStorage` | A user setting, not navigation depth |
| The navigation path (depth in a stack) | `@SceneStorage` | Per-scene, restoration-scoped, killed-process-safe |
| Selected note in a split view | `@SceneStorage` | Per-scene; window A and window B can show different notes |
| A theme color or font-size preference | `@AppStorage` | App-wide, not per-window |

The mental model: **`AppStorage` is "the user's preferences." `SceneStorage` is "where this particular window was."** Tab choice is a preference (most apps keep one tab choice app-wide). Navigation depth is a window position (two windows on iPad can be at different depths). Pick by that question every time.

## 1.8 — What a cold launch actually is, and how to prove restoration

A **cold launch** is the process starting from nothing — no in-memory state, every `@State` at its default, `init` running for real. It happens on first launch, after the user force-quits, and — most often — after iOS terminates your backgrounded app to reclaim memory while the user was in another app for ten minutes. The user *perceives* it as "I came back to the app," and they expect to be where they left.

The simulator reproduces a cold launch precisely. To prove restoration:

```bash
# 1. Run the app in the simulator, navigate two screens deep into a note,
#    then send it to the background:
xcrun simctl launch booted com.crunchlabs.HelloNotes
# (use the app, then press Cmd-Shift-H or the home gesture)

# 2. Terminate the process WITHOUT relaunching (this is the cold-launch trigger):
xcrun simctl terminate booted com.crunchlabs.HelloNotes

# 3. Relaunch. A correctly-restored app lands back on the same note, same depth:
xcrun simctl launch booted com.crunchlabs.HelloNotes
```

If step 3 shows the root list, your `SceneStorage` is not wired (or you are saving the path but never restoring it in `onAppear`). If step 3 shows the right note, you have shipped state restoration. This is the "it restores" promise from the README, and it is a behaviour we test, not a vibe.

One subtlety worth knowing: in Xcode, *stopping* the app with the Stop button is a kill but the *next* `Run` is a fresh build+install, which sometimes resets `UserDefaults`-backed storage in ways a real relaunch would not. Prefer the `simctl terminate` + `simctl launch` pair (or background-then-swipe-up-to-quit on a device) when you are specifically testing restoration. Testing restoration through "Stop then Run" in Xcode is a common way to fool yourself into thinking it is broken when it is not, or working when it is not.

## 1.9 — Putting the layer together

A production "Hello, Notes" navigation layer, assembled from the pieces above, looks like this at the top level:

```swift
import SwiftUI

@main
struct HelloNotesApp: App {
    @State private var store = NotesStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        // One layout; the framework collapses the split view on compact width.
        // We keep a single NavigationSplitView and let it adapt rather than
        // branching on sizeClass ourselves — fewer code paths, fewer bugs.
        RootSplitView()
    }
}
```

The deliberate choice here is *not* to branch on `sizeClass`. `NavigationSplitView` already collapses to a stack on iPhone. Branching by hand — "if compact, render a `NavigationStack`; else render a `NavigationSplitView`" — doubles your navigation code and your bugs, and it desynchronizes selection state across the branch. The mini-project enforces the single-layout rule for exactly this reason. You write `NavigationSplitView` once; the framework does the iPhone collapse.

We have deliberately left two things for Lecture 2 and the exercises: the deep-link decoder (`Route.from(url:)`) and the universal-link transport. Lecture 1 gave you the substrate — stack, split view, tab view, the two storage wrappers, and the cold-launch proof. Lecture 2 gives you the argument for *why* this substrate makes deep links fall out almost for free, by building the same deep-link feature on the old model (watch it break) and the new one (watch it not).

## 1.10 — What to take away

- Navigation is **state**. The state is a **path** of `Hashable` values plus some selections. You own it with `@State` at the container.
- `NavigationLink(value:)` + `navigationDestination(for:)` separates *what to navigate to* (data) from *how to render it* (one registry). Links become trivial data; destinations build lazily.
- Programmatic navigation is **array mutation**: append (push), removeLast (pop), removeAll (pop-to-root), assign (replace). Replace is the deep-link primitive.
- `NavigationSplitView` is the iPad/Mac sidebar-detail layout that **collapses to a stack on iPhone automatically**. Write it once; do not branch on size class.
- `TabView(selection:)` gives each tab its own path. A deep link must set the tab **and** that tab's path together.
- `@AppStorage` is app-wide preferences (selected tab, layout choice). `@SceneStorage` is per-scene restoration (the path, the selected note). Both want small `Codable`/primitive values — which value-typed navigation already provides.
- A **cold launch** is the process starting from zero. Prove restoration with `simctl terminate` then `simctl launch`, not with Xcode's Stop/Run.

Next: why all of this makes deep links correct by construction.
