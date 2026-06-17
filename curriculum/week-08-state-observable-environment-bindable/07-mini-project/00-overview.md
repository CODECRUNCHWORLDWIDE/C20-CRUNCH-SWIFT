# Mini-Project — Hello, Notes: CRUD Edition

> Take the static **Hello, Notes** app you built in Week 7 and give it a real, mutable data layer. Model an `@Observable` `NotesStore`, inject it through `@Environment` so the whole app shares one source of truth, and add full **C**reate / **R**ead / **U**pdate / **D**elete. Edit a note in a sheet using a draft-and-commit flow, and prove with a render counter and `onChange(of:)` that the list updates **exactly once** on save and **never** on cancel.

This mini-project **compounds on Week 7.** You start from the "Hello, Notes" repo you pushed last week — the single-screen app that lists hard-coded notes with light/dark mode and Dynamic Type support. This week the notes stop being hard-coded literals and become state the user owns and changes. By the end you have an app that adds, edits, and deletes notes, persists nothing yet (Week 10 adds SwiftData), and renders surgically — and you can *prove* the surgical part with the console.

**Estimated time:** ~11 hours (split across Thursday, Friday, and Saturday in the suggested schedule).

---

## What you will build

The Week 7 app shows a list of notes. This week it becomes a real notes app:

- **Create.** A "+" toolbar button opens an edit sheet seeded with a blank draft. Saving inserts a new note at the top of the list.
- **Read.** The list shows every note's title and a one-line body preview, newest first.
- **Update.** Tapping a note opens the same edit sheet seeded with that note's current values. Saving commits the edits. Cancelling discards them.
- **Delete.** Swipe-to-delete on a row, plus an Edit-mode multi-select delete.
- **Search.** A search field filters the list by title/body as you type — without storming.

Architecturally:

- A single `@Observable final class NotesStore` is the **one source of truth** for the notes array. It is created once at the app root with `@State` and injected into the environment with `.environment(_:)`. Every view that needs notes reads the store from `@Environment(NotesStore.self)` — no prop-drilling.
- The edit sheet uses the **draft-and-commit** pattern from the challenge: it edits a separate draft object and only writes back to the store on Save.
- The acceptance bar — the thing a senior reviewer checks — is that **a save re-renders exactly the changed cell, exactly once, and a cancel re-renders nothing.** You prove it with a `RenderCounter` and `onChange(of:)`.

---

## Rules

- **You may** read Apple's developer documentation, the lecture notes, the resources list, and the WWDC sessions.
- **You may NOT** add SwiftData, Core Data, a network layer, or any persistence this week. The `NotesStore` is **in-memory**. (Week 10 swaps it for SwiftData; the clean ownership boundary you draw this week is *why* that swap will be trivial.)
- **You may NOT** use `ObservableObject` / `@Published` / `@StateObject` / `@ObservedObject` / `@EnvironmentObject` anywhere. This is the modern-Observation week; the legacy trio is for reading old code, not writing new code.
- **You must** keep the Week 7 polish: light/dark mode, Dynamic Type to `.accessibility5`, and correct rendering on iPhone SE (3rd gen) and iPad Pro 13-inch.
- Target: iOS 17+ deployment, Xcode 16+, **strict concurrency** with zero warnings.

---

## Acceptance criteria

- [ ] The repo is your **Hello, Notes** repo from Week 7, extended on a new branch or commit series (keep the history — the app grows every week).
- [ ] `NotesStore` is an `@Observable final class` holding `var notes: [Note]`, created once with `@State` at the app root and injected with `.environment(store)`.
- [ ] At least three different views read the store via `@Environment(NotesStore.self)` — including one that is *not* a direct child of the injecting view (no prop-drilling).
- [ ] **Create** works: the "+" button opens a sheet with a blank draft; Save inserts a new note at index 0; Cancel inserts nothing.
- [ ] **Update** works: tapping a note opens the sheet seeded with its values; Save commits; Cancel discards.
- [ ] **Delete** works: swipe-to-delete removes a single note; Edit-mode multi-select deletes several.
- [ ] **Search** filters the list as you type and does **not** storm (verified with `Self._printChanges()` — typing does not re-render unchanged rows).
- [ ] The edit sheet uses **draft-and-commit** with `@Bindable` binding the `TextField`s to the draft.
- [ ] **Render-count proof, pasted into the README:**
  - On **Save** of an edit: the edited cell re-renders **exactly once**; no other cell re-renders.
  - On **Cancel**: **zero** cells re-render.
  - On **Create**: the new cell renders exactly once on insertion.
  - On **Delete**: the deleted cell goes away; remaining cells do not re-render their content.
- [ ] Builds with **zero warnings** under strict concurrency.
- [ ] Renders correctly on **iPhone SE (3rd gen)** and **iPad Pro 13-inch**, in **light and dark**, at Dynamic Type **`.accessibility5`** — no clipping, no truncation (the Week 7 promise still holds).
- [ ] `README.md` updated with: the new feature list, the render-count proof, and a "Things I learned" section with at least 3 specific items.

---

## Suggested order of operations

Build incrementally. Each phase compiles and runs before you move on.

### Phase 0 — Branch from Week 7 (~10 min)

1. Open your Week 7 "Hello, Notes" project.
2. Create a branch: `git checkout -b week-08-crud`.
3. Confirm the Week 7 app still builds and runs. You are extending it, not rewriting it.

Commit: `Start Week 8 CRUD from Week 7 baseline`.

### Phase 1 — The model and the store (~1h)

Replace the hard-coded note literals with `@Observable` types. The `Note` becomes a reference type so per-property tracking works at the cell level.

```swift
import Foundation
import Observation

@Observable
final class Note: Identifiable {
    let id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, body: String = "", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }
}

@Observable
final class NotesStore {
    var notes: [Note]

    init(notes: [Note] = NotesStore.seed) { self.notes = notes }

    func add(title: String, body: String) {
        notes.insert(Note(title: title, body: body), at: 0)
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    func delete(at offsets: IndexSet, in visible: [Note]) {
        let ids = offsets.map { visible[$0].id }
        notes.removeAll { ids.contains($0.id) }
    }

    func filtered(by query: String) -> [Note] {
        guard !query.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    static let seed: [Note] = [
        Note(title: "Welcome to Hello, Notes",
             body: "This list is now mutable. Add, edit, and delete me."),
        Note(title: "State ownership",
             body: "The store owns the notes. Views observe it."),
        Note(title: "Renders exactly once",
             body: "Editing this note should re-render exactly this cell, once."),
    ]
}
```

Commit: `@Observable Note and NotesStore`.

### Phase 2 — Own the store and inject it (~30 min)

At the app root, create the store with `@State` (the creation point) and inject it for the whole tree.

```swift
import SwiftUI

@main
struct HelloNotesApp: App {
    @State private var store = NotesStore()

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(store)
        }
    }
}
```

Update your Week 7 list view to read the store from the environment instead of a hard-coded array:

```swift
struct NotesListView: View {
    @Environment(NotesStore.self) private var store
    @State private var searchText = ""
    // ... (presentation state added in later phases)
}
```

Commit: `Inject NotesStore via environment; list reads it`.

### Phase 3 — Read + search, without storming (~1.5h)

Render the filtered list. Extract the row into its own view that reads only its own note. Add a `RenderCounter` so you can prove the no-storm claim from the start.

```swift
final class RenderCounter {
    private var counts: [UUID: Int] = [:]
    func tick(_ id: UUID) {
        counts[id, default: 0] += 1
        print("[cell \(id.uuidString.prefix(4))] render #\(counts[id]!)")
    }
}

struct NoteRow: View {
    let note: Note            // reads only its own note's fields
    let counter: RenderCounter

    var body: some View {
        let _ = counter.tick(note.id)
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(.headline)
            if !note.body.isEmpty {
                Text(note.body).font(.subheadline)
                    .foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .onChange(of: note.title) { old, new in
            print("[onChange title \(note.id.uuidString.prefix(4))] '\(old)' -> '\(new)'")
        }
    }
}
```

Wire the list with `.searchable` (or a plain extracted `SearchField`) and confirm that typing does not re-render unchanged rows. Hold the counter at the list level: `@State private var counter = RenderCounter()`.

Commit: `List + search + render counter (no storm)`.

### Phase 4 — The edit sheet (Create + Update) (~2.5h)

This is the heart of the week. One sheet handles both "add" and "edit" via a draft-and-commit flow. Use `.sheet(item:)` driven by an enum or optional that distinguishes the two modes.

```swift
@Observable
final class NoteDraft {
    var title: String
    var body: String
    init(title: String = "", body: String = "") {
        self.title = title; self.body = body
    }
    init(from note: Note) { title = note.title; body = note.body }
}

enum EditTarget: Identifiable {
    case new
    case existing(Note)
    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let n): return n.id.uuidString
        }
    }
}

struct EditNoteSheet: View {
    let target: EditTarget
    @Environment(NotesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NoteDraft

    init(target: EditTarget) {
        self.target = target
        switch target {
        case .new: _draft = State(initialValue: NoteDraft())
        case .existing(let note): _draft = State(initialValue: NoteDraft(from: note))
        }
    }

    var body: some View {
        @Bindable var draft = draft
        NavigationStack {
            Form {
                TextField("Title", text: $draft.title)
                TextField("Body", text: $draft.body, axis: .vertical).lineLimit(4...10)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit(); dismiss() }
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var title: String {
        switch target { case .new: "New Note"; case .existing: "Edit Note" }
    }

    private func commit() {
        switch target {
        case .new:
            store.add(title: draft.title, body: draft.body)
        case .existing(let note):
            if note.title != draft.title { note.title = draft.title }
            if note.body != draft.body { note.body = draft.body }
            note.updatedAt = .now
        }
    }
}
```

Present it from the list:

```swift
struct NotesListView: View {
    @Environment(NotesStore.self) private var store
    @State private var searchText = ""
    @State private var editTarget: EditTarget?
    @State private var counter = RenderCounter()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.filtered(by: searchText)) { note in
                    NoteRow(note: note, counter: counter)
                        .contentShape(Rectangle())
                        .onTapGesture { editTarget = .existing(note) }
                }
                .onDelete { offsets in
                    store.delete(at: offsets, in: store.filtered(by: searchText))
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editTarget = .new } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .sheet(item: $editTarget) { target in
            EditNoteSheet(target: target)
        }
    }
}
```

Commit: `Edit sheet: create + update with draft-and-commit`.

### Phase 5 — Delete (~1h)

Swipe-to-delete is wired above via `.onDelete`. Add the Edit-mode multi-select (the `EditButton` toolbar item above enables it; `.onDelete` already handles the removal). Confirm:

- Swiping a row left reveals Delete; tapping it removes that note.
- Tapping "Edit" enters selection mode; selecting several and deleting removes all of them.
- Deleting does not re-render the *content* of surviving rows (the counter for surviving rows does not climb — only their position may change).

Commit: `Swipe + multi-select delete`.

### Phase 6 — Prove "exactly once" (~1.5h)

Run in the simulator with the console open. Capture and paste into the README:

1. **Save (update):** edit the third note's title, tap Save. Expect exactly one `[cell <id>] render #N` for that note and one `[onChange title <id>]` line. No other cell prints.
2. **Cancel:** open a note, change the title, tap Cancel. Expect **zero** list output.
3. **Create:** tap "+", type a title, tap Save. Expect the new cell to render once on insertion.
4. **Delete:** swipe-delete a note. Expect the deleted cell to disappear with no content re-render of survivors.

If any of these storms, walk the Lecture 2 §2.8 checklist: check for an unstable `.id`, an over-broad row input, or the search field sharing a body with the list.

Commit: `Render-count proof in README`.

### Phase 7 — Polish + multi-device (~1h)

- Re-verify the Week 7 promise: iPhone SE (3rd gen) and iPad Pro 13-inch, light and dark, Dynamic Type `.accessibility5`. The edit sheet's `Form` must not clip at the largest text size.
- Add an empty state: when `store.notes.isEmpty`, show a `ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Tap + to add one."))`.
- Run `Self._printChanges()` once more on a keystroke to confirm no storm crept in.
- Push the branch and open a PR against your own `main` (practice the PR flow — Week 8's code-review participation requirement).

Commit: `Polish: empty state, multi-device, dark mode verify`.

---

## Example expected console output

On a **save** that changes the title of the note whose id starts `3f9a`:

```
[cell 3f9a] render #2
[onChange title 3f9a] 'Renders exactly once' -> 'Renders exactly once — proven'
```

On a **cancel** (after editing text then cancelling):

```
(no output)
```

On **create** of a new note whose id starts `b1c2`:

```
[cell b1c2] render #1
```

If you see more than one render for the edited cell, or any output at all on cancel, you have a bug — fix it before submitting. "It feels fast" is not the deliverable; this output is.

---

## Rubric

| Criterion | Weight | What "great" looks like |
|----------|-------:|-------------------------|
| Builds and runs | 20% | Zero warnings under strict concurrency; runs on iPhone + iPad simulators |
| State ownership | 25% | One `@Observable` store, owned with `@State`, injected via `@Environment`; no prop-drilling; no legacy wrappers |
| Edit flow correctness | 20% | Draft-and-commit; Save commits, Cancel discards; `@Bindable` binds the draft |
| Renders exactly once | 20% | Console proof: save = one cell once, cancel = zero, pasted in README |
| Multi-device + a11y | 10% | iPhone SE + iPad Pro, light/dark, Dynamic Type `.accessibility5`, no clipping |
| README quality | 5% | Feature list, proof output, "Things I learned" (3+ specific items) |

---

## Stretch (optional)

- **Sort control.** Add a `var sortNewestFirst: Bool` to the store and a toolbar toggle. Bind it with the `@Bindable var store = store` environment idiom. Prove that toggling sort re-renders the list once and does not touch the search field.
- **Undo delete.** When a note is deleted, show a transient banner with an "Undo" button that re-inserts it at its prior index. (Hint: capture the note and its index before removal.)
- **Discard confirmation.** If the draft differs from the original when Cancel is tapped, present a `.confirmationDialog` before dismissing.
- **Extract the store into a Swift package.** Move `Note`, `NotesStore`, and `NoteDraft` into a local SwiftPM `NotesCore` package (the Week 6 shared-types pattern). This sets up Week 13, when the same models gain a networking layer.

---

## What this prepares you for

- **Week 9 (Navigation)** turns the tap-to-edit into value-typed navigation and adds a `notes://open/:id` deep link. The deep link is just a *write* to navigation state from outside — which only makes sense because this week you internalised "navigation/presentation is state."
- **Week 10 (SwiftData)** swaps the in-memory `NotesStore` for a SwiftData `@Model` + `ModelContext`. Because you drew the ownership boundary correctly this week — store owns the data, views observe it — the swap touches the store and almost nothing else. That is the payoff for getting state ownership right.
- **Week 12 (Phase II integration)** turns this into "Notes v1," the portfolio app, with debounced `AsyncStream` search, tag filtering, and state restoration. Everything compounds; keep the repo clean.

---

## Submission

When done:

1. Push your `week-08-crud` branch to your Hello, Notes GitHub repo.
2. Make sure `README.md` includes the new feature list, the render-count proof output (save, cancel, create, delete), and the "Things I learned" section.
3. Confirm a fresh clone builds with zero warnings and runs on both the iPhone SE and iPad Pro simulators.
4. Open a PR against your own `main` and post the PR URL in your cohort tracker. You did real work; show it — and the render-count proof is the part to be proud of.
