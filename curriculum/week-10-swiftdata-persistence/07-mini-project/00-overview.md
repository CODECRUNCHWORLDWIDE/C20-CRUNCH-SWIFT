# Mini-Project — Hello, Notes: SwiftData edition

This week the notes app stops forgetting. You will migrate **Hello, Notes** off the in-memory `@Observable` `NotesStore` you built in Week 8 and grew in Week 9, and onto a real SwiftData store on disk. Along the way you add a `Tag` model with a **many-to-many** relationship to `Note`, query notes by tag with a `#Predicate`, and prove the whole thing survives a force-quit cold launch.

This is a *compounding* project. It is not a new app. You start from the Week 9 codebase — the one with the `NavigationStack`/`NavigationSplitView` sidebar-detail layout and the `notes://open/:id` deep link — and you swap the storage layer underneath it. The point of the week is to feel how *cleanly* that swap goes **because** you drew the state-ownership boundary correctly in Week 8. The navigation stays. The views barely change. The store changes completely.

---

## Where you're starting from

Your Week 9 app has, roughly:

- An `@Observable final class NotesStore` holding `var notes: [Note]` in memory, injected via `@Environment`.
- A `struct Note: Identifiable` (a **value type** — that's about to change).
- A `NavigationSplitView` (iPad/Mac) / `NavigationStack` (iPhone) layout with a list and a detail editor.
- A `notes://open/:id` deep link handled in `onOpenURL` that pushes a note onto the navigation path.
- CRUD: add, edit-in-detail, delete — all mutating the in-memory array.

If you don't have a clean Week 9 checkpoint, build the minimal version first; the SwiftData work is the same either way.

## What you're building toward

By the end you have:

- A `@Model final class Note` (now a **reference type**) persisted in SwiftData.
- A `@Model final class Tag` with `@Attribute(.unique) var name`.
- A **many-to-many** `Note ↔ Tag` relationship with an explicit `inverse:` and a deliberate `deleteRule:`.
- A `ModelContainer` on the app scene; the views read via `@Query` and write via `\.modelContext`.
- A **tag filter**: pick a tag, and the list shows only notes carrying it, via a dynamic `#Predicate`.
- A passing **relaunch test**: create a note, tag it, force-quit, relaunch cold, and it's all still there.
- A `VersionedSchema` + `SchemaMigrationPlan` registered, so you're ready to ship v2.

---

## Milestone 1 — Model the schema (≈ 1.5 h)

Convert `Note` from a struct to a `@Model` class, and add `Tag`.

```swift
import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    // Many-to-many. Inverse lives here; Tag.notes is the other end.
    // .nullify: deleting a note must NOT delete its tags (other notes use them).
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag]

    init(title: String, body: String = "", createdAt: Date = .now,
         updatedAt: Date = .now, tags: [Tag] = []) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }
}

@Model
final class Tag {
    @Attribute(.unique) var name: String   // one row per tag name; insert-with-same-name UPSERTS
    var notes: [Note]

    init(name: String, notes: [Note] = []) {
        self.name = name
        self.notes = notes
    }
}
```

Decisions you must be able to defend in review:

- **Why `.nullify` and not `.cascade`?** A tag is shared across notes. Deleting one note must not vaporise the "swift" tag that ten other notes use. `.cascade` here would be a data-loss bug. (If you instead wanted "delete a note, delete tags *only this note* had," that's app logic after the delete, not a delete rule.)
- **Why `inverse:` on `Note.tags` and a plain array on `Tag.notes`?** Many-to-many *requires* an explicit inverse on one side or SwiftData guesses wrong and you get phantom relationships. Pick one side, declare it, leave the other plain. SwiftData materialises the `Z_2TAGS` join table.
- **Why `@Attribute(.unique)` on `Tag.name`?** You want exactly one "swift" tag, not one per note that uses it. Unique gives you upsert: inserting a `Tag(name: "swift")` when one exists updates the existing row instead of duplicating. (Know the upsert semantic — it's the documented behaviour, not a "duplicate" error.)

## Milestone 2 — Wire the container, retire the store (≈ 1.5 h)

Delete the in-memory `NotesStore`. Replace its injection with a `ModelContainer`.

```swift
import SwiftUI
import SwiftData

@main
struct HelloNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Note.self, Tag.self])   // replaces .environment(NotesStore())
    }
}
```

Now update the views. The state-ownership work from Week 8 pays off here: anywhere you previously read `store.notes`, you now use `@Query`; anywhere you previously called `store.add(_:)` / `store.delete(_:)`, you now use the `\.modelContext`.

```swift
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    var body: some View {
        List {
            ForEach(notes) { note in
                NavigationLink(value: note) {     // value-typed nav from Week 9 — Note is now a @Model
                    NoteRow(note: note)
                }
            }
            .onDelete { offsets in
                offsets.map { notes[$0] }.forEach(context.delete)
                try? context.save()
            }
        }
        .navigationTitle("Notes")
        .toolbar { Button("Add", systemImage: "plus", action: addNote) }
    }

    private func addNote() {
        let note = Note(title: "New Note")
        context.insert(note)
        try? context.save()
    }
}
```

Because `Note` is now a `@Model` (and therefore `Identifiable` and `Hashable` via `persistentModelID`), your Week 9 `NavigationLink(value: note)` and `navigationDestination(for: Note.self)` keep working with **no changes** to the navigation layer. That's the compounding payoff — value-typed navigation didn't care whether `Note` was a struct or a managed object; it only cared that it was `Hashable`.

The detail editor edits the model object directly — and because `@Model` is observable, SwiftUI re-renders the list cell when you change a field. Use `@Bindable` (Week 8) to bind the text fields:

```swift
struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            TextField("Title", text: $note.title)
            TextField("Body", text: $note.body, axis: .vertical)
            TagEditor(note: note)
        }
        .onChange(of: note.title) { note.updatedAt = .now }
        .onChange(of: note.body)  { note.updatedAt = .now }
    }
}
```

## Milestone 3 — The tag editor and the many-to-many (≈ 2 h)

Add and remove tags on a note. The subtlety: you must **reuse** existing tags by name (so the unique constraint does its job), not create a new `Tag` per note.

```swift
struct TagEditor: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var newTagName = ""

    var body: some View {
        Section("Tags") {
            ForEach(note.tags.sorted { $0.name < $1.name }) { tag in
                HStack {
                    Text(tag.name)
                    Spacer()
                    Button("Remove", systemImage: "minus.circle", role: .destructive) {
                        note.tags.removeAll { $0.persistentModelID == tag.persistentModelID }
                    }
                    .labelStyle(.iconOnly)
                }
            }
            HStack {
                TextField("Add tag", text: $newTagName)
                Button("Add", action: addTag).disabled(newTagName.isEmpty)
            }
        }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        // Reuse an existing tag if one exists; only create when truly new.
        let existing = allTags.first { $0.name == name }
        let tag = existing ?? Tag(name: name)
        if existing == nil { context.insert(tag) }
        if !note.tags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
            note.tags.append(tag)
        }
        try? context.save()
        newTagName = ""
    }
}
```

Adding a tag to `note.tags` automatically populates `tag.notes` on the inverse — that's what the `inverse:` declaration buys you. You set one side; SwiftData maintains the other.

## Milestone 4 — Query notes by tag with a `#Predicate` (≈ 1.5 h)

Add a tag-filter screen: pick a tag, see only its notes. This is the dynamic-`@Query` pattern from lecture 1, §6 — the filter depends on a runtime value, so you re-init the `Query` in the view's `init`.

```swift
struct TaggedNotesView: View {
    let tagName: String
    @Query private var notes: [Note]

    init(tagName: String) {
        self.tagName = tagName
        _notes = Query(
            filter: #Predicate<Note> { note in
                note.tags.contains { $0.name == tagName }
            },
            sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
        )
    }

    var body: some View {
        List(notes) { note in
            NavigationLink(value: note) { NoteRow(note: note) }
        }
        .navigationTitle("#\(tagName)")
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView("No notes with #\(tagName)", systemImage: "tag")
            }
        }
    }
}
```

The `#Predicate` with `contains` runs the membership test **in SQLite over the join table**, not by loading every note and checking its tags in Swift. That's the efficient query the week's "skill earned" line demands. Wire a `TagSidebar` (or a tag picker in the toolbar) that pushes `TaggedNotesView(tagName:)` via value-typed navigation — extend the Week 9 `NavigationSplitView` so the sidebar lists tags and the content column shows the filtered notes.

## Milestone 5 — Schema versioning (≈ 1 h)

Wrap your current schema in a `VersionedSchema` and register a `SchemaMigrationPlan` on the container, even though there's only one version today. This is the "ready for v2" discipline from lecture 2 — it costs ten minutes now and saves a data-loss incident later. (See exercise 03 for the exact shape.) Then, to *prove* it works, add a small field (e.g. `var isPinned: Bool = false`) as a V2 with a lightweight stage, and run the migration test from exercise 03 adapted to your `Note`.

## Milestone 6 — The relaunch test (≈ 0.5 h)

The acceptance bar for the whole week.

1. Launch the app. Create two notes. Tag one of them with `#swift` and `#ideas`, the other with `#swift`.
2. Open the tag filter for `#swift` — both notes appear. For `#ideas` — one appears.
3. **Force-quit the process:** `xcrun simctl terminate booted <your.bundle.id>` (or swipe the app card away in the App Switcher).
4. Relaunch cold: `xcrun simctl launch booted <your.bundle.id>` (or tap the icon).
5. Both notes are still there. Both tags are still there. The `#swift` filter still returns both notes. Nothing was lost.

Record this as a short clip or a sequence of screenshots in your repo's README. "It survived a cold launch" is the deliverable.

---

## Acceptance criteria

- [ ] `Note` and `Tag` are `@Model final class` types; the in-memory `NotesStore` is **deleted**.
- [ ] A many-to-many `Note ↔ Tag` relationship with an explicit `inverse:` and a justified `deleteRule:` (`.nullify`).
- [ ] `Tag.name` is `@Attribute(.unique)` and tags are **reused by name**, not duplicated per note.
- [ ] `.modelContainer(for: [Note.self, Tag.self])` on the app scene; views read via `@Query`, write via `\.modelContext`, edit via `@Bindable`.
- [ ] A tag filter that uses a **dynamic `#Predicate`** (`note.tags.contains { $0.name == tagName }`) — the membership test runs in SQLite, not in a Swift `.filter`.
- [ ] The Week 9 navigation (`NavigationSplitView`/`NavigationStack`, value-typed links, the `notes://open/:id` deep link) **still works** unchanged.
- [ ] A `VersionedSchema` + `SchemaMigrationPlan` is registered, and a V1→V2 lightweight migration is demonstrated with a test.
- [ ] **The relaunch test passes:** create + tag, force-quit (process killed, not backgrounded), relaunch cold, data intact.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict-concurrency.

## Stretch goals

- **Tag chips with counts.** Show each tag in the sidebar with a count of its notes — use `tag.notes.count`, but prefetch the relationship (`relationshipKeyPathsForPrefetching = [\Tag.notes]`) so you don't N+1.
- **Bulk seed + the footgun.** Seed 50k notes and wire the challenge's naive-vs-predicate search into the toolbar. Carry the `PERF.md` over.
- **Background import via `@ModelActor`.** Import notes from a JSON file on a background actor (lecture 2, §3) and watch `@Query` pick up the merged changes on the main thread automatically.
- **CloudKit-ready check.** Flip the model to satisfy CloudKit's constraints (all relationships optional, no `.unique`) behind a feature flag, and note what you had to change. (Don't enable sync — that's Phase IV — just see the constraints.)

## What this milestone earns you

You can now model a SwiftData schema with relationships and query it efficiently — the literal "skill earned" line for the week. More than that: you migrated a real app's storage layer with the navigation and UI almost untouched, which is the senior move. The clean swap was *earned* in Week 8 when you got state ownership right; this week you collected the dividend. Week 11 puts an architecture (MVVM / TCA) around the store you just built; you'll be glad the data layer is solid before you start arguing about where it should live.
