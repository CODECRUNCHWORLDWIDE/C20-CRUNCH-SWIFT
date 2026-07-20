# Mini-Project — "Hello, Notes" grows a navigation layer

> Take the "Hello, Notes" CRUD app you built in Week 8 and give it a real navigation layer: a sidebar-content-detail `NavigationSplitView` for iPad and Mac, the same code collapsing to a `NavigationStack` on iPhone, navigation state that survives a cold launch, and a `notes://open/:id` deep link that opens any note from a cold launch. By the end you have an app that behaves the way users expect a multi-screen app to behave — it remembers where you were, it adapts to the device, and a tapped link lands you on the right note whether the app was running or killed.

This mini-project **compounds directly on Week 8.** You are not starting over. You keep the `@Observable NotesStore` and the CRUD sheet from last week and add the navigation layer *on top* of an already-working data layer. Next week (Week 10), you will swap the in-memory store for SwiftData *underneath* this navigation layer without touching the navigation — because you modelled navigation as value-typed routes keyed on a note's stable `id`, not on an object reference. That is the whole point of doing navigation this week and persistence next: each layer is independently replaceable.

**Estimated time:** ~8.5 hours (split across Friday, Saturday, and the unstructured project time in the schedule).

---

## Prerequisites from Week 8

You need the Week 8 deliverable in your working tree:

- An `@Observable final class NotesStore` holding `var notes: [Note]` with `create`, `update`, and `delete` methods.
- A `Note` model: `struct Note: Identifiable, Hashable, Codable { let id: UUID; var title: String; var body: String; var tagIDs: [UUID] }`.
- A create/edit sheet driven by `@Bindable` and presented with `.sheet(item:)` or `.sheet(isPresented:)`.

If you skipped Week 8, build the minimum surface first — the store and the model above, with three sample notes. This mini-project is about navigation, not CRUD; the CRUD just has to exist so navigation has something to navigate to.

For this week, add a `Tag` model and a tags collection to the store so the sidebar has something to show:

```swift
struct Tag: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
}
```

`NotesStore` gains `var tags: [Tag]` and a `notes(in tagID: Tag.ID?) -> [Note]` helper that returns all notes when `tagID` is `nil` (the "All Notes" pseudo-tag) and the tagged subset otherwise.

---

## What you will build

A single SwiftUI app, **HelloNotes**, with one codebase that renders correctly on iPhone, iPad, and Mac:

1. **A three-column `NavigationSplitView`** on iPad and Mac:
   - **Sidebar:** a list of tags (plus an "All Notes" row at the top). Selection drives the content column.
   - **Content:** the notes in the selected tag, as a `List(selection:)`. Selection drives the detail column.
   - **Detail:** the selected note's editor, wrapped in a `NavigationStack` so a note can push further (to a linked tag's note list, or to Settings).
2. **The same layout collapsing to a `NavigationStack` on iPhone** — you do *not* write a separate iPhone layout. `NavigationSplitView` collapses to a stack at compact width automatically. The rule is enforced in the rubric: one layout, no `if sizeClass == .compact` branch.
3. **State restoration across a cold launch:**
   - The selected tag and the selected note persist via `@SceneStorage` so a relaunch lands on the same note.
   - The preferred sidebar visibility and a "default to All Notes" toggle persist via `@AppStorage`.
4. **A `notes://open/:id` deep link** that opens any note from a cold launch, routed through a pure `DeepLink.path(for:)` decoder and applied atomically.
5. **(Carry-over from Week 8)** full CRUD: create a note, edit it in a sheet, delete it. Navigation and CRUD must coexist — deleting the note you are viewing must pop the detail gracefully, not crash.

You ship **one Xcode project** with this structure:

```
HelloNotes/
  HelloNotesApp.swift            // @main, WindowGroup, environment injection
  Models/
    Note.swift                   // Note (Identifiable, Hashable, Codable)
    Tag.swift                    // Tag
    Route.swift                  // enum Route: Hashable, Codable
    NotesStore.swift             // @Observable store (from Week 8 + tags)
  Navigation/
    RootSplitView.swift          // the NavigationSplitView, the single layout
    DeepLink.swift               // pure URL -> [Route]? decoder (no SwiftUI import)
  Screens/
    NoteDetailView.swift         // detail/editor, pushes within the detail stack
    SettingsView.swift
  HelloNotesTests/
    DeepLinkTests.swift          // Swift Testing, no simulator
    RestorationTests.swift       // encode/decode round-trip of [Route]
```

---

## Rules

- **You may** read Apple's documentation, the lecture notes, your Week 9 exercises, and the open-source repos in `resources.md`.
- **You may NOT** add any third-party navigation library (no `swift-navigation`, no TCA, no Coordinator framework). The point of this week is to do it with plain SwiftUI state so you understand the substrate. Routers come in Week 11.
- **You may NOT** write a separate iPhone layout. One `NavigationSplitView`, collapsing automatically. A `#if os(...)` or a `horizontalSizeClass` branch around the *whole* navigation layout is an automatic rubric deduction (a `#if os(macOS)` for a Mac-only menu command is fine).
- **You may NOT** use `NavigationView` or `NavigationLink(destination:)` or any `isActive:` binding. Value-typed only.
- **Navigation state must be value-typed and `Codable`.** The `Route` enum and the selections must round-trip through JSON, proven by `RestorationTests`.

---

## The `Route` model

Define the closed set of routes once. This is the navigation contract for the whole app:

```swift
import Foundation

enum Route: Hashable, Codable {
    case note(id: UUID)     // a note's detail/editor
    case tag(id: UUID)      // a tag's note list, pushed within the detail
    case settings
}
```

Everything keys on `id`, never on a `Note` value or reference. That is deliberate: when Week 10 replaces the store with SwiftData, the `id` is still the stable identity, so the navigation layer does not change. Keying navigation on object references is the bug that makes navigation break the moment persistence changes underneath it.

---

## Build order (suggested)

Do it in this sequence; each step is independently testable.

### Step 1 — The split view, hard-coded selection (≈1.5h)

Build `RootSplitView` with the three columns and the sidebar/content/detail wiring from Lecture 1 §1.5. Hard-code the initial selection to the first tag and first note. Run on the iPad Pro 13" simulator and confirm three columns. Run on the iPhone 16 simulator and confirm it collapses to a stack you can drill into and back out of. **Do not branch on size class** — confirm the collapse is automatic.

### Step 2 — Selection state + the detail stack (≈1.5h)

Replace the hard-coded selection with `@State` selections bound through `List(selection:)`:

```swift
@State private var selectedTagID: Tag.ID?
@State private var selectedNoteID: Note.ID?
@State private var detailPath: [Route] = []
```

The detail column wraps a `NavigationStack(path: $detailPath)` so a note can push a linked tag or Settings. Use `ContentUnavailableView` for the "no note selected" state. Confirm selecting a tag filters the content column and selecting a note shows it in the detail.

### Step 3 — Restoration (≈1.5h)

Persist `selectedTagID`, `selectedNoteID`, and `detailPath` with `@SceneStorage` (encode the path to `Data`; store the optional UUIDs as their `uuidString`). Persist a "default to All Notes on launch" toggle and the preferred sidebar visibility with `@AppStorage`. Then prove restoration:

```bash
xcrun simctl terminate booted com.crunchlabs.HelloNotes
xcrun simctl launch    booted com.crunchlabs.HelloNotes
```

You must land on the same tag, same note, same depth. This is the README's "it restores" contract.

### Step 4 — The deep-link decoder + transport (≈1.5h)

Write `DeepLink.swift` as a pure `static func path(for url: URL) -> [Route]?` (no SwiftUI import) that decodes `notes://open/<uuid>`. Register the `notes` URL scheme in the target. Wire `.onOpenURL` on the root to apply the decoded path — and because the split view collapses, applying a deep link must set `selectedNoteID` (so the detail column shows it on iPad/Mac) *and* the `detailPath`/`preferredCompactColumn` (so the collapsed iPhone stack lands on it). Test:

```bash
xcrun simctl openurl booted notes://open/22222222-2222-2222-2222-222222222222
```

Then prove the cold path: terminate, fire the link, confirm cold launch lands on the note.

### Step 5 — CRUD coexistence + polish (≈1.5h)

Wire the Week 8 create/edit sheet back in. Handle the delete-while-viewing case: deleting the selected note sets `selectedNoteID = nil` and pops the detail to `ContentUnavailableView` rather than crashing on a dangling id. Add a "+" toolbar button to create a note and select it. Confirm the whole thing on all three simulators.

### Step 6 — Tests (≈1h)

- `DeepLinkTests`: valid URL → `[.note(id:)]`; garbage → `nil`; wrong scheme → `nil`. Pure, no simulator.
- `RestorationTests`: encode a `[Route]` of mixed cases to JSON, decode it back, assert equality. This proves the restoration storage will round-trip.

---

## Acceptance criteria

Functional:

- [ ] Three columns (sidebar/content/detail) on iPad 13" and Mac.
- [ ] The *same code* collapses to a navigation stack on iPhone, with no size-class branch in your navigation layout.
- [ ] Selecting a sidebar tag filters the content list; selecting a content note shows it in the detail.
- [ ] A note can push a linked tag and Settings within the detail stack; Back is coherent at every depth.
- [ ] Selected tag, selected note, and detail depth all survive a cold launch (`simctl terminate` + `launch`).
- [ ] `notes://open/<id>` opens the correct note both warm and cold.
- [ ] Deleting the currently-viewed note pops the detail gracefully (no crash, no dangling id).
- [ ] Create and edit (the Week 8 sheet) still work alongside navigation.

Engineering:

- [ ] `Route` is `Hashable, Codable`; navigation keys on `id`, never on a `Note` reference.
- [ ] `DeepLink.path(for:)` is pure (no SwiftUI import) and unit-tested without a simulator.
- [ ] No `NavigationView`, no `NavigationLink(destination:)`, no `isActive:` anywhere.
- [ ] No third-party navigation dependency.
- [ ] Build succeeds with **0 warnings, 0 errors** on iPhone, iPad, and Mac destinations.

---

## Scoring rubric (0–4 each; 20 total)

| Criterion | 0 | 2 | 4 |
|---|---|---|---|
| **Adaptive layout** | Separate iPhone/iPad layouts or a size-class branch | One `NavigationSplitView`, collapses but selection desyncs on collapse | One layout, collapses cleanly, selection coherent across the collapse |
| **Navigation modelling** | `isActive`/booleans or object-keyed routes | Value-typed `Route` but not `Codable`, or some imperative leftovers | `Route: Hashable, Codable`, keyed on `id`, all navigation is path mutation |
| **State restoration** | None; cold launch shows root | Selected note restores but depth or tag does not | Tag, note, and depth all restore; proven with a `simctl` transcript |
| **Deep links** | None, or works warm but not cold | Works warm and cold but decoder is impure or untested | Pure tested decoder, works warm and cold, sets tab/column atomically |
| **Robustness & coexistence** | Crashes on delete-while-viewing or on a bad deep link | Handles one but not both edge cases | Delete-while-viewing pops gracefully; bad/garbage links do nothing |

A score of **14/20** passes. Below that, revise and resubmit.

---

## What to submit

- The `HelloNotes` Xcode project (committed to your Week 9 branch).
- A `PROOF.md` in the project root with:
  - The cold-launch restoration transcript (`simctl terminate` + `launch`, plus a sentence describing what restored).
  - The warm and cold deep-link transcripts (`simctl openurl`).
  - One short paragraph: *why does the navigation layer not change when Week 10 swaps in SwiftData?* (Answer in terms of routes keyed on `id`.)
- Screenshots: the three-column layout on iPad, the collapsed stack on iPhone, and the detail open after a cold-launch deep link.

---

## Why this is the right mini-project for Week 9

Every later week leans on this. Week 10's SwiftData drop-in only works cleanly because navigation keys on `id`. Week 12's reactive search adds a Search tab whose results deep-link into the same `Route` set. Phase III's push notifications carry a `notes://open/<id>` payload that lands on this exact handler. Phase IV's widgets tap into the same deep link. You are not building a throwaway demo; you are building the navigation spine of the app you will carry through the rest of the course. Build it like you mean it: value-typed, `Codable`, restored across a cold launch, and proven with a terminal transcript rather than a claim.
