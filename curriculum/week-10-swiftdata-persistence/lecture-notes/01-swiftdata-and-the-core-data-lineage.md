# Lecture 1 — SwiftData and the Core Data lineage: what it solves, and what it still hides

> "SwiftData isn't a new database. It's a new way to talk to a database you've already been shipping for fifteen years."

This is the lecture that decides whether SwiftData feels like magic or like a leaky abstraction you can reason about. The framing for the whole week is one sentence: **SwiftData is a Swift-macro front end over Core Data.** Hold that, and every surprise this week — why a fetch is slow, why a relationship loads lazily, why a background write doesn't appear on the main thread, why a migration fails — has a one-layer-down explanation. Lose it, and you are cargo-culting `@Model` annotations and praying.

We are going to build the mental model bottom-up: the engine (Core Data / SQLite), then the front end (the macros), then the runtime objects (`ModelContainer`, `ModelContext`), then the read path (`@Query`, `#Predicate`). By the end you should be able to draw the stack on a whiteboard and point to which layer is responsible for any given behaviour.

---

## 1. The stack, drawn once so we never have to argue about it again

Here is the full stack under a SwiftData app, top to bottom:

```text
┌─────────────────────────────────────────────────────────────┐
│  Your SwiftUI views                                          │
│    @Query var notes: [Note]        <- a read, auto-updating  │
│    @Environment(\.modelContext)    <- the unit of work       │
├─────────────────────────────────────────────────────────────┤
│  SwiftData (the macros + thin runtime)                       │
│    @Model / @Attribute / @Relationship  -> Schema            │
│    ModelContainer / ModelContext / FetchDescriptor           │
│    #Predicate -> Foundation Predicate                        │
├─────────────────────────────────────────────────────────────┤
│  Core Data (the engine — present, just not spelled out)      │
│    NSManagedObjectModel    (the compiled schema)             │
│    NSManagedObjectContext  (what ModelContext wraps)         │
│    NSPersistentStoreCoordinator                              │
│    NSPredicate / NSFetchRequest                              │
├─────────────────────────────────────────────────────────────┤
│  SQLite                                                       │
│    a .store file on disk: ZNOTE, ZTAG, Z_2TAGS join tables   │
└─────────────────────────────────────────────────────────────┘
```

You never type a single Core Data symbol in a SwiftData app. But every one of them is *there*, running your `insert`, evaluating your `#Predicate`, faulting your relationships. When you open the `.store` file with `sqlite3` (do this — it is on the resources page) you will see tables named `ZNOTE` and `ZTAG` and a join table `Z_2TAGS`, with a `Z_PK` primary key column and `Z_ENT` entity discriminator. That `Z` prefix is Core Data's, untouched since 2009. SwiftData wrote those tables through Core Data.

**Why does this matter for you, the engineer?** Because the moment something is slow or wrong, the docs for SwiftData are thin, but the docs and fifteen years of Stack Overflow for Core Data are deep. "SwiftData relationship not loading" returns three blog posts. "Core Data faulting" returns the entire history of iOS development. Knowing the lineage doubles the surface area of help available to you.

---

## 2. What SwiftData actually solves

Core Data is powerful and *miserable* to set up. The pre-2023 ritual was:

- A `.xcdatamodeld` file edited in a visual editor that did not diff well in Git and that nobody on the team could review in a PR.
- `NSManagedObject` subclasses that were either hand-written and error-prone, or codegen'd and untouchable.
- Stringly-typed key paths (`object.value(forKey: "title")`) or fragile `@NSManaged` properties.
- `NSFetchRequest<NSFetchRequestResult>` with `NSPredicate(format: "title CONTAINS %@", query)` — a string mini-language with no compiler checking. A typo in the predicate format string crashed at runtime, not compile time.
- Boilerplate to stand up the `NSPersistentContainer`, and `@FetchRequest` in SwiftUI that still leaned on the model file.

SwiftData replaces all of it with Swift you can review in a PR:

```swift
import SwiftData

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date

    init(title: String, body: String, createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
```

That single declaration replaces a `.xcdatamodeld` entity, a generated `NSManagedObject` subclass, and the `@NSManaged` plumbing. The schema is now **code**. It diffs in Git. It is type-checked. It autocompletes. This is the headline win, and it is a real one — for greenfield on-device storage in 2026, SwiftData is the correct default precisely because it makes the schema reviewable and the queries type-checked.

The second thing it solves is the SwiftUI integration. The old `@FetchRequest` worked but was awkward to make dynamic. `@Query` is genuinely clean:

```swift
struct NotesList: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    var body: some View {
        List(notes) { note in
            Text(note.title)
        }
    }
}
```

`@Query` fetches on appear, observes the context, and re-runs automatically when the store changes — including changes made on another context that gets merged in. You write a property; SwiftData wires the reactivity.

The third thing: **type-checked predicates.** `#Predicate` is a macro that takes a Swift closure and compiles it into a `Foundation.Predicate`, which SwiftData lowers to an `NSPredicate` the store evaluates. The closure is real Swift the compiler checks:

```swift
let query = "swift"
let descriptor = FetchDescriptor<Note>(
    predicate: #Predicate { note in
        note.title.localizedStandardContains(query)
    },
    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
)
```

If you misspell `title` here, it is a compile error. In the old `NSPredicate(format:)` world it was a crash in front of a user. That alone justifies the framework.

---

## 3. `@Model` — what the macro generates, and why it's a class

`@Model` is the centre of SwiftData. Expand it (Xcode: right-click the macro, "Expand Macro") and you will see it does a lot:

- Conforms the type to **`PersistentModel`** and **`Observable`** (the same Observation framework you learned in Week 8 — a `@Model` is observable, so `@Query`-fetched objects drive SwiftUI re-renders just like an `@Observable` model).
- Adds a **`PersistentIdentifier`** (`persistentModelID`) — the stable, store-wide identity of the row. This is *not* your `id`; it is SwiftData's internal handle, and it is what you pass across context/thread boundaries because the object itself is not `Sendable`.
- Rewrites every stored property into a **computed property backed by the persistent store** — reads go through `getValue(forKey:)`, writes through `setValue(forKey:)`. Your `var title: String` is not a plain field anymore; it is a faulting accessor onto SQLite.
- Generates a `schemaMetadata` description SwiftData uses to build the `Schema`.

The single most important consequence: **a `@Model` is a `class`, a reference type.** It must be. The whole point is identity — two references to "the note with `persistentModelID` X" must be the *same* object, with the same change tracking, so that editing it in a detail view updates the same row the list view shows. A struct has value semantics; a copy is a different value. Persistence needs identity, so `@Model` is a class. (Mark it `final` — there is no reason to subclass a model, and `final` helps the compiler.)

This is why Week 1's `struct` vs `class` lecture was load-bearing. Your `Note` is the first place in this track where you *want* reference semantics and the framework enforces it.

### `@Attribute` — tuning how a property is stored

Plain properties just work. `@Attribute` is for when you need to tell the store something:

```swift
@Model
final class Note {
    @Attribute(.unique) var slug: String          // upsert key; one row per slug
    var title: String
    var body: String
    @Attribute(.externalStorage) var coverImage: Data?  // big blob -> separate file, not inline in SQLite
    @Attribute(.preserveValueOnDeletion) var auditID: UUID
    var createdAt: Date

    init(slug: String, title: String, body: String,
         coverImage: Data? = nil, auditID: UUID = UUID(), createdAt: Date = .now) {
        self.slug = slug
        self.title = title
        self.body = body
        self.coverImage = coverImage
        self.auditID = auditID
        self.createdAt = createdAt
    }
}
```

The options you will actually use:

- **`.unique`** — declares a uniqueness constraint. The footgun: inserting a second object with a colliding unique value does **not** error and does **not** create a duplicate. It performs an **upsert** — the existing row is updated with the new object's values. This surprises everyone the first time. If you expected a "duplicate" error, you got a silent overwrite. Know this cold.
- **`.externalStorage`** — store large `Data` blobs as files alongside the database rather than inline in SQLite. Use it for images and attachments; inline blobs bloat the database and slow every fetch that touches the row.
- **`.preserveValueOnDeletion`** — keep the value available in the history API (WWDC24) even after the row is deleted, for sync/audit.
- **`.spotlight`** — index for Core Spotlight search.
- **`originalName:`** — the rename escape hatch; covered in lecture 02 under migrations.

A property whose type is `Codable` (a struct, an enum, an array of structs) is stored automatically — SwiftData encodes it into the row. Cheap and convenient, but not queryable with a predicate (SQLite sees an opaque blob), so do not store something you need to filter on as a `Codable` blob.

### `@Relationship` — the object graph

Relationships are where SwiftData earns its keep and where the footguns hide. Here is the many-to-many you will build in the mini-project:

```swift
@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date

    // A note has many tags. The inverse is Tag.notes.
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag]

    init(title: String, body: String, createdAt: Date = .now, tags: [Tag] = []) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.tags = tags
    }
}

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var notes: [Note]      // the other side of the many-to-many

    init(name: String, notes: [Note] = []) {
        self.name = name
        self.notes = notes
    }
}
```

Two rules to internalise:

1. **Declare the `inverse:` on exactly one side.** A relationship has two ends. If you let SwiftData infer the inverse it usually gets it right for simple cases, but for many-to-many — and any time you have two relationships between the same pair of types — you *must* be explicit, or SwiftData will guess wrong and you will get phantom extra relationships. Convention: declare `inverse:` on the "owned" side and leave the other a plain array. SwiftData materialises the join table (`Z_2TAGS` in the SQLite dump) for you.

2. **Choose the `deleteRule:` deliberately.** When you delete an object, what happens to the objects it points at?
   - **`.nullify`** (the default for optional/to-many) — set the reference to nil / remove from the array, but keep the related objects. Deleting a `Note` should *not* delete its `Tag`s (other notes use them), so `.nullify` is correct here.
   - **`.cascade`** — delete the related objects too. Correct when the children are *owned* — a `Project` with `Task`s where tasks have no life outside the project.
   - **`.deny`** — refuse the delete if relationships exist. For referential-integrity-critical data.
   - **`.noAction`** — leave dangling references; you promise to fix them yourself. Almost never what you want.

Picking `.cascade` where you meant `.nullify` is how you delete a tag and silently wipe every note that used it. The delete rule is not a detail; it is a data-loss decision.

### Faulting and the N+1 problem (inherited straight from Core Data)

When `@Query` hands you `[Note]`, the notes' **relationships are not loaded yet.** `note.tags` is a *fault* — a placeholder that triggers a SQLite query the first time you touch it. This is Core Data faulting, inherited wholesale. It is good (you do not pay to load tags you never read) and it is a trap:

```swift
// N+1: one query for notes, then one query PER note to fault its tags.
List(notes) { note in
    Text("\(note.title) — \(note.tags.count) tags")  // .tags faults here, per row
}
```

If `notes` has 500 rows, scrolling the list fires up to 500 extra queries, one per visible row's first `tags` access. The fix is to tell the fetch to **prefetch** the relationship so SwiftData batches it:

```swift
var descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
descriptor.relationshipKeyPathsForPrefetching = [\Note.tags]
let notes = try context.fetch(descriptor)
// now note.tags is already populated; no per-row query
```

We measure this in lecture 02 and the exercises. For now, know the words: **faulting** (lazy load on access) and **N+1** (one query per row instead of one query for all rows). They are Core Data concepts you inherited the day you typed `@Model`.

---

## 4. `ModelContainer` — the database

The `ModelContainer` owns three things: the **schema** (compiled from your `@Model` types), the **store** (the SQLite file on disk), and the **configuration** (how to open it). In a SwiftUI app you usually never construct one by hand; you hand the model types to a scene modifier and let SwiftData build it:

```swift
import SwiftUI
import SwiftData

@main
struct HelloNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Note.self, Tag.self])
    }
}
```

`.modelContainer(for:)` builds the container, picks the default on-disk location (`Application Support/default.store`), installs a `mainContext` into the environment under `\.modelContext`, and makes `@Query` work in any descendant. That one line is the whole setup that used to be forty lines of `NSPersistentContainer` boilerplate.

When you need control — tests, an in-memory store, a custom URL, CloudKit — build a `ModelConfiguration`:

```swift
// In-memory container for tests and previews: fast, ephemeral, no file on disk.
@MainActor
func makePreviewContainer() throws -> ModelContainer {
    let schema = Schema([Note.self, Tag.self])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true   // <- nothing touches disk; perfect for tests
    )
    let container = try ModelContainer(for: schema, configurations: [config])
    return container
}
```

`isStoredInMemoryOnly: true` is the single most useful configuration option in the framework. Use it for every unit test and every Xcode preview — it gives you a real, fully functional store that lives only in RAM, so tests are fast and isolated and previews never pollute your simulator's database. (To turn on CloudKit sync you would pass `cloudKitDatabase: .private("iCloud.com.example.notes")` instead — but that is Phase IV, with its own schema constraints.)

---

## 5. `ModelContext` — the unit of work

If the container is the database, the **context is your scratchpad of pending changes.** It tracks objects you insert, modify, and delete, and nothing touches disk until it **saves.** This is the Unit of Work pattern, and it is `NSManagedObjectContext` with a Swifty face.

```swift
@Environment(\.modelContext) private var context

func addNote() {
    let note = Note(title: "New", body: "")
    context.insert(note)        // staged in the context; not yet on disk
    // ...edit note.title, note.body...
    try? context.save()         // flush all pending changes to SQLite atomically
}

func delete(_ note: Note) {
    context.delete(note)        // staged delete
    try? context.save()
}
```

Things to know about contexts:

- **Autosave.** The `mainContext` from `.modelContainer(for:)` has autosave **on** by default — it saves periodically and when the app backgrounds, so you can often skip the explicit `save()`. But "often" is not "always," and relying on autosave timing for a save the user expects to be durable *now* is a bug. Save explicitly when correctness depends on it.
- **`hasChanges` / `rollback`.** `context.hasChanges` tells you if there are unsaved edits; `context.rollback()` discards them and reverts inserted/modified/deleted objects. This is exactly how you implement "Cancel" in an edit sheet without persisting — you can edit a model object directly and `rollback()` if the user cancels.
- **A context is NOT `Sendable`.** This is the concurrency rule the Swift 6 compiler enforces. A `ModelContext` belongs to the thread/actor that created it. You may **not** create a note on the main context, hand the *object* to a background task, and use it there. The model objects are not `Sendable` either. To do work on a background thread you create a **new** context for that thread (or use `@ModelActor`, lecture 02) and pass **`PersistentIdentifier`s** across the boundary, then re-fetch in the destination context.

```swift
// WRONG under strict concurrency — context and model are not Sendable.
Task.detached {
    context.insert(note)   // compiler error: capturing non-Sendable
}

// RIGHT — a dedicated context per actor; pass the identifier, re-fetch.
@ModelActor
actor NoteImporter {
    func importTitles(_ titles: [String]) throws {
        for title in titles {
            modelContext.insert(Note(title: title, body: ""))
        }
        try modelContext.save()
    }
}
```

`@ModelActor` (lecture 02 covers it properly) is the supported way to get a background context: it synthesises an actor with its own `modelContext`, isolated to that actor, so the compiler is satisfied and you do not corrupt the main context from another thread.

---

## 6. `@Query` and `#Predicate` — the read path

`@Query` is a SwiftUI property wrapper; it only works inside a `View` and it reads the `\.modelContext` from the environment. Three increasingly real forms:

```swift
// 1. Everything, sorted.
@Query(sort: \Note.createdAt, order: .reverse) var notes: [Note]

// 2. Filtered with a static predicate + multiple sort keys.
@Query(
    filter: #Predicate<Note> { !$0.body.isEmpty },
    sort: [SortDescriptor(\Note.createdAt, order: .reverse),
           SortDescriptor(\Note.title)]
) var nonEmptyNotes: [Note]

// 3. DYNAMIC — the predicate depends on a runtime value.
//    @Query's parameters are fixed at init, so you re-init it in the View's init.
struct TaggedNotesList: View {
    @Query private var notes: [Note]

    init(tagName: String) {
        _notes = Query(
            filter: #Predicate<Note> { note in
                note.tags.contains { $0.name == tagName }
            },
            sort: [SortDescriptor(\Note.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List(notes) { Text($0.title) }
    }
}
```

Form 3 is the one people fumble. `@Query`'s filter is captured when the property wrapper is initialised, so you cannot just mutate a `@State` and expect the query to change. You drive the dynamic query by **re-initialising the `Query`** in the view's `init`, using the synthesised `_notes` backing property. When the parent passes a new `tagName`, SwiftUI re-creates the view, the `init` runs again with the new predicate, and `@Query` re-fetches. (If `tagName` is itself view state, hold it in the parent and pass it down — this is exactly the value-typed-navigation pattern from Week 9 doing double duty.)

### What `#Predicate` accepts — and why it matters for performance

This is the crux of the whole week. `#Predicate` does **not** accept arbitrary Swift. It accepts a restricted subset that SwiftData can translate into SQL the store runs **in the database.** Supported: comparisons, boolean logic, a curated set of `String` methods (`localizedStandardContains`, `starts(with:)`, `==`), `contains` on a to-many relationship, optional handling, arithmetic. **Not** supported: calling your own functions, most computed properties, anything the translator can't lower to SQL. If you write something it can't translate, you get a compile error or, worse, a runtime failure.

The reason this restriction exists is the entire performance story:

```swift
// IN SQLITE: the predicate is translated to a WHERE clause. SQLite filters
// 100,000 rows using an index and returns the 12 that match. Memory: ~12 rows.
let matched = try context.fetch(
    FetchDescriptor<Note>(predicate: #Predicate { $0.title.localizedStandardContains("swift") })
)

// IN MEMORY: fetch ALL 100,000 Note objects into RAM (faulting each one),
// then run a Swift closure to keep 12. Memory: 100,000 rows. Time: brutal.
let allNotes = try context.fetch(FetchDescriptor<Note>())
let matchedSlow = allNotes.filter { $0.title.localizedStandardContains("swift") }
```

These two snippets return the *same answer* and have *wildly* different cost. The first asks SQLite to do the filtering where the data lives. The second drags the entire table across the Core Data faulting layer into Swift objects, then throws almost all of them away. On a large store the difference is milliseconds versus seconds, and a smooth scroll versus a memory warning. **A `#Predicate` runs in SQLite; a `.filter` runs in memory.** Tattoo it. This is the footgun you plant and fix in Wednesday's challenge.

### `FetchDescriptor` — the imperative read

`@Query` is for views. When you need to fetch outside a view (a service, a background import, a count) use `FetchDescriptor` against a context directly:

```swift
// Bounded fetch — never fetch unbounded into a List you can.
var descriptor = FetchDescriptor<Note>(
    predicate: #Predicate { $0.tags.contains { $0.name == "swift" } },
    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
)
descriptor.fetchLimit = 50
descriptor.relationshipKeyPathsForPrefetching = [\Note.tags]
let page = try context.fetch(descriptor)

// Count without materialising objects — cheap, stays in SQLite.
let total = try context.fetchCount(FetchDescriptor<Note>())
```

`fetchCount` is the one to reach for when you only need a number — it runs `SELECT COUNT(*)` in SQLite and never builds a single Swift object. Calling `context.fetch(...).count` to get the same number is the footgun's cousin.

---

## 7. What SwiftData still hides — the leaks to know about

SwiftData is a good abstraction, which means it leaks in predictable places. Senior engineers know where:

1. **The query plan.** You write a `#Predicate`; you do not see the generated SQL or whether it used an index. The fix is to look — Instruments' SwiftData/Core Data template shows the actual SQL and timing. If a query is slow, profile it; do not guess.
2. **Faulting.** Relationships and even attributes load lazily. A loop that touches `note.tags` looks like array access but is a database query each time. The N+1 problem (§3) is the canonical bite.
3. **Concurrency.** The "context is not `Sendable`" rule is non-negotiable under Swift 6. SwiftData hides the threading model right up until the compiler refuses your background write. `@ModelActor` is the supported answer; lecture 02 builds one.
4. **Migrations.** Additive schema changes "just work" — until they don't, and a property rename or a type change silently drops data or crashes on launch. SwiftData hides migration entirely until you need a non-trivial one, at which point you must hand-write a `SchemaMigrationPlan`. Lecture 02 is largely about this.
5. **Batch operations.** There is no SwiftData `NSBatchDeleteRequest` equivalent that deletes a million rows without loading them. For heavy batch work you drop to raw Core Data (lecture 02's co-existence pattern) — the underlying coordinator is the same store, so you can.

None of these are reasons to avoid SwiftData. They are the things you keep in your peripheral vision so that when the abstraction leaks, you recognise the puddle instead of staring at it.

---

## 8. The decision table

When does SwiftData win, and when do you reach past it to Core Data? Memorise the shape:

| Situation | Reach for |
|-----------|-----------|
| New on-device storage in a SwiftUI app | **SwiftData** — the default in 2026 |
| Schema you want reviewable in PRs, type-checked queries | **SwiftData** |
| Quick prototype, tests with `isStoredInMemoryOnly` | **SwiftData** |
| Existing large Core Data app | Keep **Core Data**; adopt SwiftData incrementally (lecture 02) |
| Batch delete/update of huge row counts | **Core Data** `NSBatch*Request` over the shared store |
| Complex multi-stage data migration | **Core Data** migration, or a custom `SchemaMigrationPlan` |
| Fine-grained fetch control, derived attributes, sectioned fetch | **Core Data** `NSFetchedResultsController` |
| Non-Apple platform (Linux Vapor service) | **Neither** — Fluent / Postgres; SwiftData is Apple-platform only |

That last row matters for this track specifically: your Vapor server from Phase I does **not** use SwiftData. SwiftData is an Apple-platform, on-device framework over Core Data, which does not exist on Linux. The server persists with Fluent and Postgres; the client persists with SwiftData; and the *shared codable types* from Week 6 are the bridge between them. Do not try to run `@Model` on the server.

---

## 9. Recap — the one-layer-down habit

You will write SwiftData all week. The discipline that turns you from someone who *uses* SwiftData into someone who can *debug* it is the reflex to ask, on every surprise, "what is the layer below doing?"

- Fetch is slow → is the predicate running in SQLite or am I filtering in memory? (Instruments shows the SQL.)
- Relationship is empty / slow → is it a fault I'm triggering N+1 times? (Prefetch it.)
- Background write won't compile → context isn't `Sendable`; make an actor with its own context.
- Migration crashed on launch → which schema version did the store actually have, and is my change additive? (Lecture 02.)
- `.unique` didn't error on a duplicate → it upserted; that's the documented semantic, not a bug.

SwiftData solved the setup misery and the stringly-typed predicate. It did not repeal the laws of the engine underneath. Learn the engine well enough to read it, write the front end every day, and you have the skill this week earns: model a schema with relationships and query it efficiently — *and know why it's efficient.*

In lecture 02 we go down into the co-existence pattern (running SwiftData and Core Data over the same store), the migration machinery (`VersionedSchema`, `SchemaMigrationPlan`), and the performance footguns with measured before/after numbers. Bring this stack diagram with you; we are about to use every layer of it.
