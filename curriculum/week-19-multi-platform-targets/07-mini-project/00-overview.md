# Mini-Project — Notes Pro v1, on five platforms

This week the notes app stops being an iOS app and becomes a *product*. You will take **Notes Pro v1** from Week 18 — the SwiftUI app with SwiftData, a `NotesClient`, a subscription gate, and push — and add three new surfaces: a **macOS-native target**, a **watchOS companion** that shows the three most recent notes (with a complication), and a **visionOS window**. All three share the SwiftData models, the `NotesClient`, and the domain logic through a `NotesCore` package, and by the end you demonstrate **all four running side by side in their simulators**.

This is a *compounding* project, and it's the most architecturally satisfying of the track: you don't write much *new* code, you *share* the code you already have and add thin shells on top. The point of the week is to feel how *little* changes when the share/adapt line was drawn right — the model, the network, the persistence, and the subscription gate are all reused unchanged; each platform adds only the presentation it wants. The discipline throughout is the README's promise: **every line lives on one side of the share/adapt line, and you can say which and why.**

---

## Where you're starting from

Your Notes Pro v1 (Week 18) has, roughly:

- A SwiftUI iOS app (iPhone + iPad) with SwiftData persistence and adaptive `NavigationSplitView`/`NavigationStack` navigation.
- A `NotesClient` actor (pinned, request-signing — Weeks 13, 17).
- A `notes_pro_monthly` StoreKit 2 subscription gate (Week 18).
- Push + a Notification Service Extension (Week 18).

If you don't have a clean checkpoint, build the minimal version first; the platform work is the same.

## What you're building toward

By the end you have:

- A **`NotesCore` SwiftPM package** holding the models, `NotesClient`, persistence, and domain logic — compiling for iOS, macOS, watchOS, and visionOS.
- A **macOS-native target** (SwiftUI on macOS, not Catalyst) with a real menu bar, window toolbar, and ⌘N — the adaptive `NavigationSplitView` as a three-pane Mac app.
- A **watchOS companion** showing the three most recent notes, with a **complication** showing the note count.
- A **visionOS window** rendering the same notes app as a floating panel in the Shared Space.
- A **subscription gate that works on every platform** (the Pro feature is gated everywhere, reading `currentEntitlements`).
- A **parity demonstration**: iPhone, Mac, Watch, and Vision running side by side, the same core, four shells.

---

## Milestone 1 — Extract the shared core (≈ 2 h)

Move everything shared into a `NotesCore` package (lecture 2, §4; exercise 3). This is the foundation everything else stands on, and the constraint — it must compile for all four platforms — is what enforces the share/adapt line.

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotesCore",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11), .visionOS(.v2)],
    products: [.library(name: "NotesCore", targets: ["NotesCore"])],
    targets: [
        .target(name: "NotesCore"),
        .testTarget(name: "NotesCoreTests", dependencies: ["NotesCore"]),
    ]
)
```

Into the package go: the `@Model` types (`Note`, `Tag`), the `NotesClient`, the SwiftData container setup, the subscription `Store` logic, and the domain functions (search, recent, summary). Out stays: anything that imports UIKit/AppKit — that's shell.

Decisions to defend in review:

- **`public` what crosses the boundary.** The model, its init, and every domain/store function a shell calls must be `public`. The compiler tells you what you missed.
- **No UIKit/AppKit in the core.** If something needs `UIColor` or `NSView`, it's a shell concern — push it out. The package physically can't hold it (it won't compile for watchOS), which is the boundary doing its job.
- **The subscription `Store` is core.** "Does this user have Pro?" has the same answer on every platform, derived from `currentEntitlements` — so the gate logic is shared, and each shell just *reads* `store.hasProAccess`.

Update the iOS app to `import NotesCore` and confirm it still builds and runs unchanged. The iOS app is now a thin shell on the core.

## Milestone 2 — The macOS-native target (≈ 2 h)

Add macOS as a **destination of your existing SwiftUI app target** (target ▸ Supported Destinations ▸ add Mac), choosing **"My Mac" (native)**, not "Mac (Designed for iPad)" / Catalyst (lecture 1, §3). The adaptive `NavigationSplitView` becomes a three-pane Mac window for free.

Add the Mac-native affordances, each a small adaptation:

```swift
// In the shared shell — semantic placements and free shortcuts adapt without #if os.
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("New Note", systemImage: "plus", action: addNote)
            .keyboardShortcut("n", modifiers: .command)   // ⌘N on Mac, inert on iOS
    }
}
.commands {                                                // a Mac menu-bar command group
    CommandGroup(after: .newItem) {
        Button("New Note") { addNote() }.keyboardShortcut("n", modifiers: .command)
    }
}
```

Decisions to defend:

- **Native SwiftUI, not Catalyst** — for a SwiftUI app this is the right choice (lecture 1, §3); you get a real menu bar and native controls with the shared code.
- **The `Paywall` works on Mac** — StoreKit 2 runs on macOS; the subscription gate is the same. Confirm the paywall renders and the gate flips.
- **Window sizing is the one `#if os`** — `.frame(minWidth:)` is macOS-only, isolated in a named modifier (exercise 2), not smeared through the body.

**Prove it:** run on "My Mac" and confirm a three-pane window, a working menu bar, ⌘N, and the subscription gate — all from the shared core.

## Milestone 3 — The watchOS companion + complication (≈ 2.5 h)

Add a **watchOS app target** (its own `@main`) that imports `NotesCore` and shows a glance (lecture 2, §1–2).

```swift
import SwiftUI
import SwiftData
import NotesCore

@main
struct NotesWatchApp: App {
    var body: some Scene {
        WindowGroup { RecentNotesView() }
            .modelContainer(NotesCore.sharedContainer)
    }
}

struct RecentNotesView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    var body: some View {
        NavigationStack {                          // a stack, not a split view
            List(notes.prefix(3)) { note in        // glanceable: three most recent
                NavigationLink(value: note) {
                    Text(note.title).font(.headline).lineLimit(1)
                }
            }
            .navigationTitle("Recent")
            .navigationDestination(for: Note.self) { note in
                ScrollView { Text(note.body).padding() }   // read-only on the wrist
            }
        }
    }
}
```

Then add a **complication** as a WidgetKit extension (lecture 2, §2; challenge 1) showing the note count via the shared `NotesDomain.summary`.

Decisions to defend:

- **A glance, not a tiny iPhone** — three notes, read-only detail, a `NavigationStack`. The density adapts; the data is shared.
- **The complication reads the shared core** — the count comes from `NotesCore`, so the wrist and the phone can't disagree.
- **The Pro gate still applies** — if a feature is Pro-gated, the watch respects it (reading the same `Store`).

**Prove it:** run the watchOS simulator, see the three recent notes, add the complication to a watch face, and confirm the count shows.

## Milestone 4 — The visionOS window (≈ 1.5 h)

Add visionOS — either as a destination of the iOS target or its own target — rendering the same app as a window (lecture 2, §3). Resist immersion; a window is correct.

```swift
import SwiftUI
import NotesCore

@main
struct NotesVisionApp: App {
    var body: some Scene {
        WindowGroup {
            NotesRootView()        // the SAME adaptive root as iOS/Mac
        }
        .windowStyle(.plain)        // a flat panel in the Shared Space
        .modelContainer(NotesCore.sharedContainer)
    }
}
```

Decisions to defend:

- **A window, not an `ImmersiveSpace`** — a notes app is a window (lecture 2, §3). Note in a comment *where* immersion would fit (a 3D mind-map, a focus mode) and why you didn't build it.
- **The same `NotesRootView`** — visionOS renders your existing adaptive layout with glass, depth, and eye focus for free. The only "adaptation" is `.windowStyle(.plain)`.

**Prove it:** run the visionOS simulator and confirm the notes app floats as a window, navigable by look-and-pinch.

## Milestone 5 — Parity demonstration (≈ 1.5 h)

The acceptance bar for the week. Boot the iPhone, Mac (native), Watch, and Vision simulators **at once** (Apple Silicon makes this feasible) and demonstrate the same feature on each:

1. Create a note on the iPhone. Confirm it appears on the Mac, the Watch (in recent), and the Vision window — same data, same order, because it's the same shared store/sync.
2. Confirm the **Pro gate** behaves identically: lock a feature, and it's locked on every platform that surfaces it.
3. Confirm each **shell fits its platform**: three-pane on Mac, glance on Watch, window on Vision, stack on iPhone.
4. Produce a **parity matrix** (challenge 1) in the repo README: feature × platform, with a "Behavior shared?" column citing the `NotesCore` path, and honest "absent by design" cells for the watch (no long-note composition).

Record this side-by-side run as a clip or screenshots — four simulators, one codebase. "Same core, four shells, proven side by side" is the deliverable.

---

## How the data is shared across the targets

One thing to wire deliberately (lecture 2, §6): the iOS app, the macOS app, the watch app, the complication, and the Notification Service Extension are **separate processes**, so they can't share an in-memory store. Place the SwiftData store in an **App Group container** so every same-device target reads the same notes:

```swift
public extension NotesCore {
    static var sharedContainer: ModelContainer {
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.crunch.notes")!
            .appending(path: "Notes.store")
        return try! ModelContainer(for: Note.self, Tag.self,
                                   configurations: ModelConfiguration(url: url))
    }
}
```

Enable the **App Group** capability on every target (app, watch app, complication, NSE) and point each `.modelContainer(NotesCore.sharedContainer)` at it. For the *watch as a separate device*, rely on CloudKit sync (the `cloudKitDatabase:` config) if the watch is paired to the same iCloud account, or a `WCSession` handoff for live phone→watch updates — the transport adapts to the topology, but the schema and query code stay shared. Document which transport you used and why in your README.

## Acceptance criteria

- [ ] A **`NotesCore` SwiftPM package** holds the models, `NotesClient`, persistence, store/gate, and domain logic, compiling for iOS/macOS/watchOS/visionOS with **no UIKit/AppKit imports** and **no `#if os` in the core**.
- [ ] The SwiftData store lives in a shared **App Group container** so the app, watch, complication, and extension (same-device processes) read the same notes.
- [ ] A **macOS-native target** (SwiftUI, not Catalyst) renders the adaptive `NavigationSplitView` as a three-pane window with a menu bar, a window toolbar, and ⌘N.
- [ ] A **watchOS companion** shows the three most recent notes (a glance, read-only detail) and a **complication** showing the note count from the shared core.
- [ ] A **visionOS window** renders the same `NotesRootView` as a floating panel (a window, not an immersion), with a comment on where immersion would fit.
- [ ] The **subscription gate works on every platform**, reading the shared `Store`/`currentEntitlements`.
- [ ] A **parity matrix** in the README citing the shared `NotesCore` path per feature and honestly marking what each platform should/shouldn't do.
- [ ] **All four new surfaces demonstrated running side by side** (clip or screenshots).
- [ ] Build with **0 warnings, 0 errors** on every target, including Swift 6 strict-concurrency.

## Stretch goals

- **A Mac-specific menu bar** with full File/Edit menus and ⌘-shortcuts via `.commands`, so the Mac app feels native, not ported.
- **Watch Connectivity / CloudKit sync** so the watch shows live phone data (rather than its own store) — a preview of the capstone's CloudKit sync.
- **A visionOS ornament** — a bottom ornament with the note count or quick actions, the one visionOS-specific affordance that earns its keep for a window app.
- **Digital Crown scrolling** on the watch's note list, the one watch-exclusive input that fits a glance.
- **Shared snapshot tests** on the `NotesCore` domain, run once, proving the logic identical across platforms.

## What this milestone earns you

You can now ship one SwiftUI codebase to four Apple platforms — the literal "skill earned" line for the week. More than that: you extracted a shared core that the compiler keeps platform-agnostic, added three thin shells that each fit their surface, and proved parity by running them side by side. That "share the core, adapt the shell, draw the line deliberately" discipline is worth 15 points on the capstone rubric (multi-platform parity), and it's the foundation Phase IV builds every feature on — the Widget (Week 20), the Live Activity (Week 21), and the capstone all stand on this shared core. Notes Pro v1 is now an *ecosystem*. Phase IV has begun.
