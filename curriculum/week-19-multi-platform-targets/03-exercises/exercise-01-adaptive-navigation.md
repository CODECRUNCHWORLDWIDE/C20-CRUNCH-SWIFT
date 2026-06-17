# Exercise 1 — One adaptive navigation, three platforms

**Goal.** Build a single `NavigationSplitView` with value-typed selection and prove — with **zero** platform branches — that it renders as a sidebar-detail layout on Mac and iPad and collapses to a navigation stack on iPhone. This is the share-via-adaptivity idea distilled to one screen: the same code, adapting, because you modeled navigation as state.

**Estimated time.** 45 minutes.

**Prerequisites.** Xcode 16+ with the iOS Simulator, an iPad Simulator, and the ability to run the Mac destination (runs natively on your Mac). You do *not* need the Notes Pro app for this drill — we build a throwaway `MultiScratch` app so the focus stays on the adaptive container. The value-typed navigation is the Week 9 pattern; if it's rusty, glance back at it.

---

## Step 1 — Scaffold a multiplatform SwiftUI app

In Xcode: **File ▸ New ▸ Project ▸ Multiplatform ▸ App.** Name it `MultiScratch`. The Multiplatform template gives you one app target with iOS, iPadOS, and macOS destinations out of the box — confirm under the target's **Supported Destinations** that iPhone, iPad, and Mac are all listed. This single target is what proves the point: one `@main`, three platforms.

Confirm it builds and runs on the iOS Simulator *and* on "My Mac" before you touch anything.

## Step 2 — A trivial shared model

Create `Item.swift`:

```swift
import Foundation

struct Section: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let items: [Item]
}

struct Item: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

// A little sample data so there's something to navigate.
let sampleSections: [Section] = [
    Section(name: "Inbox", items: [Item(title: "Buy milk"), Item(title: "Call Alex")]),
    Section(name: "Work",  items: [Item(title: "Ship Notes Pro"), Item(title: "Review PR")]),
    Section(name: "Ideas", items: [Item(title: "Watch complication"), Item(title: "Vision window")]),
]
```

## Step 3 — One `NavigationSplitView`, value-typed selection

Replace `ContentView.swift` entirely. The whole exercise is that this has **no `#if os`**:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: Section?
    @State private var selectedItem: Item?

    var body: some View {
        NavigationSplitView {
            // Column 1 (sidebar). On iPhone this becomes the stack's root.
            List(sampleSections, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.name, systemImage: "folder")
                }
            }
            .navigationTitle("Sections")
        } content: {
            // Column 2 (items in the selected section). On iPhone, pushed.
            if let section = selectedSection {
                List(section.items, selection: $selectedItem) { item in
                    NavigationLink(value: item) { Text(item.title) }
                }
                .navigationTitle(section.name)
            } else {
                ContentUnavailableView("Pick a section", systemImage: "folder")
            }
        } detail: {
            // Column 3 (the selected item). On iPhone, pushed again.
            if let item = selectedItem {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.largeTitle)
                    Text(item.title).font(.title)
                }
                .navigationTitle("Detail")
            } else {
                ContentUnavailableView("Pick an item", systemImage: "doc.text")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview { ContentView() }
```

## Step 4 — Run it on three platforms and SEE it adapt

Run the *same build* on each destination and watch the layout change with zero code changes:

- **Mac (My Mac):** a three-column window — sections, items, detail, side by side. Resize the window narrow and watch columns drop.
- **iPad Pro:** sidebar + detail in landscape; a slide-over sidebar in portrait. The `.balanced` style splits the columns.
- **iPhone:** a **navigation stack** — tap a section to push the items, tap an item to push the detail, swipe back. No columns; SwiftUI collapsed the split view into a stack *automatically*.

The exact same `NavigationSplitView` is a productivity three-pane on the Mac and a push-pop stack on the iPhone. You wrote no platform branches. That's the share-via-adaptivity claim, proven by your own eyes.

## Step 5 — Add a semantic toolbar action (still no `#if os`)

Add a toolbar button with a *semantic* placement and a free keyboard shortcut:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {     // trailing on iOS, toolbar on Mac — adapts
        Button("New", systemImage: "plus") { /* add */ }
            .keyboardShortcut("n", modifiers: .command)   // ⌘N on Mac; inert elsewhere, no #if os
    }
}
```

Run again. On the Mac the button is in the window toolbar and **⌘N** works. On the iPhone it's in the navigation bar's trailing position and the shortcut is simply inert. One declaration, correct on both — because `.primaryAction` is semantic and `.keyboardShortcut` is a no-op where there's no keyboard.

---

## Acceptance criteria

- [ ] A single Multiplatform target with iPhone, iPad, and Mac destinations.
- [ ] One `NavigationSplitView` with value-typed selection (`$selectedSection`, `$selectedItem`) and **zero `#if os`**.
- [ ] It renders as **three columns on Mac**, **sidebar-detail on iPad**, and a **navigation stack on iPhone** — verified by running all three.
- [ ] A `.primaryAction` toolbar button with a `.keyboardShortcut` that works on Mac and is inert on iPhone, with no platform branch.
- [ ] Build with **0 warnings, 0 errors** on all three destinations.

## What you just proved

You proved lecture 1's central claim: `NavigationSplitView` with value-typed selection is *adaptive by construction*. The same code is a three-pane Mac app and a push-pop iPhone app because you modeled navigation as state (the Week 9 pattern), and SwiftUI chooses the right presentation per platform. You also used semantic toolbar placement and a free keyboard shortcut to adapt *without* forking. This is the iPhone/iPad/Mac trio coming "nearly for free" — the foundation the mini-project builds the Watch and Vision shells onto.

---

## Hints (read only if stuck > 10 min)

- **The iPhone shows columns / looks broken.** You probably nested a `NavigationStack` inside the `NavigationSplitView`, or didn't use the split view's own column closures. `NavigationSplitView` collapses on its own — don't wrap it.
- **Selection doesn't drive the columns.** The `List(selection:)` binding and the `NavigationLink(value:)` must use the *same* type, and the `@State` selection must match. `selection: $selectedSection` + `NavigationLink(value: section)` where both are `Section`.
- **The Mac destination won't run.** Confirm "My Mac" (or "Mac (Designed for iPad)" — but prefer native "My Mac") is in Supported Destinations and selected in the scheme. If only "Mac (Designed for iPad)" appears, you're on the Catalyst path; add the native macOS destination.
- **⌘N does nothing on Mac.** The `.keyboardShortcut` must be on a focusable control in the window; if the button is in a placement the Mac hides, move it to `.primaryAction`. Also confirm the window has focus.
- **`ContentUnavailableView` not found.** It's iOS 17+/macOS 14+. Raise your deployment target if needed.
