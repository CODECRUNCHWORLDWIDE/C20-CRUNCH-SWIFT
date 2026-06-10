# Lecture 1 — App Intents: the new contract between your app and the rest of iOS

> "An App Intent is a verb your app exposes to the operating system. Once you declare it, Siri, Shortcuts, the action button, Spotlight, and your own widgets can all invoke it — and your app does not have to be running for them to do so."

This is the lecture that reframes what an app *is*. For nineteen weeks you have built an app as a place: a process the user launches, a window it draws, a set of screens they tap through. This week the app becomes a *service* the system can call into. The framing for the whole week is one sentence: **the rest of iOS becomes a client of your app's actions and data.** Hold that, and the otherwise-strange design of App Intents — why `perform()` is `async` and runs off-process, why parameters are so heavily typed, why you write a phrase string for Siri — all follows. Lose it, and you will keep treating an intent like a method call and be confused when it runs while your UI is asleep.

We are going to build the mental model top-down: the system-as-client idea first, then the `AppIntent` itself, then how it reaches Siri (App Shortcuts), then how it models your app's *nouns* (App Entities), and finally how all of it replaced the old `.intentdefinition` world. By the end you should be able to draw the surfaces an intent feeds — Shortcuts, Siri, the widget, Spotlight — and point at the one `struct` that feeds them all.

---

## 1. The system-as-client model, drawn once

Here is the shape of an App-Intents-era app, with the surfaces that invoke it:

```text
                         ┌──────────────────────────────────────┐
   "Hey Siri, add a      │           iOS system surfaces        │
    note saying ..."  ──▶│  Siri    Shortcuts    Action Button  │
                         │  Spotlight   Interactive Widgets     │
                         └───────────────────┬──────────────────┘
                                             │ invokes
                                             ▼
                         ┌──────────────────────────────────────┐
                         │   struct AddNote: AppIntent          │
                         │     @Parameter var text: String      │
                         │     func perform() async throws ...  │   <- runs OFF your app's
                         └───────────────────┬──────────────────┘      main process, on the
                                             │ mutates                  system's schedule
                                             ▼
                         ┌──────────────────────────────────────┐
                         │   Shared SwiftData store (App Group)  │
                         │   ZNOTE / ZTAG in group container     │
                         └──────────────────────────────────────┘
```

The single most important fact on that diagram is the comment on the right: **`perform()` runs outside your app's normal process, on the system's schedule.** When Siri invokes `AddNote`, your app may be fully terminated. iOS spins up a lightweight execution context, runs your `perform()`, and tears it down. Your `@MainActor` UI is not there. Your app's in-memory singletons are not there. The only thing that *is* there is whatever you can reach from the intent itself — which is why the shared store at the bottom of the diagram matters so much, and why the App Group from lecture 2 is load-bearing.

**Why does this matter for you, the engineer?** Because the bug you will write this week is "the intent worked when I tested it with the app open, then failed in the field." It failed because in the field the app was *not* open, your convenient `AppState.shared` was nil, and the intent tried to reach into a process that did not exist. Design every intent as if the app is dead — because, often, it is.

---

## 2. The `AppIntent` itself

An App Intent is a `struct` conforming to `AppIntent`. The minimum viable intent has a title and a `perform()`:

```swift
import AppIntents

struct ShowNoteCount: AppIntent {
    static let title: LocalizedStringResource = "Show note count"
    static let description = IntentDescription("Tells you how many notes you have.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = try await NotesStore.shared.totalCount()
        return .result(dialog: "You have \(count) notes.")
    }
}
```

Several things in that small block are deliberate and worth naming:

- **`static let title`** is a `LocalizedStringResource`. This is the name the user sees in Shortcuts and the Siri suggestion. It is required. Make it a clean imperative verb phrase: "Add note," "Show note count," "Pin note" — not "noteAdder" or "NoteIntent."
- **`description`** is the longer text in the Shortcuts gallery. Optional but you should write it; it is what a user reads when deciding whether to use your action.
- **`perform()` is `async throws`** and returns `some IntentResult`. The return type is a composition: `IntentResult` is the base; you add capabilities with `&`. `ProvidesDialog` means "I can speak/show a sentence back." `ReturnsValue<T>` means "I hand a typed value to the next Shortcuts step." `OpensIntent` chains to another intent. You compose the protocols you need.
- The async-ness is not decoration. `perform()` runs on the system's schedule and is expected to do real work — a database write, a network call — without blocking. Swift Concurrency is the model; there is no completion-handler form.

### Parameters — typed inputs the system collects for you

Most useful intents take input. You declare it with `@Parameter`, and the framework handles *collecting* it — from a Shortcuts UI field, from a Siri follow-up question, from a value piped in by a previous action:

```swift
struct AddNote: AppIntent {
    static let title: LocalizedStringResource = "Add note"
    static let description = IntentDescription("Creates a new note with the given text.")

    // The text to put in the note. `requestValueDialog` is what Siri asks if it's missing.
    @Parameter(title: "Text", requestValueDialog: "What should the note say?")
    var text: String

    // Optional, with a default — Shortcuts shows it but doesn't force it.
    @Parameter(title: "Pinned", default: false)
    var pinned: Bool

    // The one-line summary shown for this action in the Shortcuts editor.
    static var parameterSummary: some ParameterSummary {
        Summary("Add note saying \(\.$text)") {
            \.$pinned
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        let note = store.add(text: text, pinned: pinned)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
        return .result(dialog: "Added a note: \(note.title).")
    }
}
```

Read the parameter machinery carefully — it is where App Intents earns its keep:

- **`@Parameter(title:)`** names the input in every UI that collects it. **`requestValueDialog`** is the sentence Siri *speaks* if the user invokes the intent without supplying the value ("What should the note say?"). The framework drives the whole back-and-forth; you just declare the prompt.
- **Types do real work.** A `String` parameter gets a text field; a `Bool` gets a toggle; an `Int` gets a number pad; a `Date` gets a date picker; an `AppEnum` gets a menu of cases; an `AppEntity` (§4) gets a *searchable picker of your app's objects*. You do not build any of those UIs. You declare the type and the system builds the right collector.
- **`parameterSummary`** controls the human-readable one-liner in the Shortcuts editor — "Add note saying [Text]" with the parameters inlined. Get this right and your action reads like a sentence; skip it and it reads like a form.

### `perform()` and the off-process reality

Note that `perform()` above is marked `@MainActor` *only because* it touches a `NotesStore` we have decided is main-actor-isolated, and even then we construct a **fresh** store pointed at the App Group, not a captured singleton. Under Swift 6 strict concurrency the compiler will not let you capture non-`Sendable` state across the boundary, and that is a feature: it forces you to acknowledge that the intent runs somewhere your app's normal state does not exist. The discipline:

- **Construct your data access inside `perform()`**, pointed at shared storage, rather than reaching for `App.shared.modelContext`.
- **Return only `Sendable` results** — a dialog string, a value, an entity — never a live model object.
- **Reload the widget at the end** (`WidgetCenter.shared.reloadTimelines`) so the surface the user is looking at reflects the change you just made.

This is the same lesson as Week 10's `@ModelActor`: the store and its objects are not `Sendable`, so you create access local to where the work runs and pass values across boundaries.

---

## 3. App Shortcuts — giving an intent a Siri phrase with zero user setup

Declaring an `AppIntent` makes it available in the **Shortcuts app** — the user can find it and build a shortcut. But that requires the user to go set it up. **App Shortcuts** are intents you pre-package with a phrase so they work in Siri *immediately*, with no configuration. You register them with an `AppShortcutsProvider`:

```swift
import AppIntents

struct NotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNote(),
            phrases: [
                "Add a note in \(.applicationName)",
                "Make a note in \(.applicationName)",
                "New \(.applicationName) note"
            ],
            shortTitle: "Add Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: ShowNoteCount(),
            phrases: [
                "How many notes do I have in \(.applicationName)",
                "\(.applicationName) note count"
            ],
            shortTitle: "Note Count",
            systemImageName: "number"
        )
    }
}
```

The rules that decide whether Siri actually recognises your phrase:

1. **Every phrase must contain `\(.applicationName)`.** Siri uses your app name as the anchor token that routes the request to you. "Add a note" with no app name is ambiguous across every notes app on the device; "Add a note in Hello Notes" is yours. This is not optional — a phrase without the app-name token is ignored.
2. **List several natural phrasings.** Users do not say the one phrase you imagined. Give the obvious synonyms ("add," "make," "new"). Siri matches loosely within a phrase but not across phrases you did not write.
3. **App Shortcuts need no user setup.** This is the headline difference from a plain intent. The moment your app is installed and `AppShortcutsProvider` is registered, the phrases work in Siri and the actions appear in the Shortcuts gallery's "from this app" section. There is no "enable in Settings" step.
4. **Keep the count small.** Apple recommends roughly ten App Shortcuts max — these are your app's *headline* actions, not its entire API surface. Expose "add note," not "set the third paragraph's font."

To test without speaking: open the **Shortcuts app**, find your app's section, and run the shortcut by tapping it. Voice invocation ("Hey Siri, …") is device-only and needs the physical device from Phase III; the tap path works in the Simulator and exercises the exact same `perform()`.

---

## 4. App Entities — modelling your app's *nouns*

Intents are verbs; **App Entities** are the nouns those verbs act on. When an intent needs to refer to "a note" — "pin *which* note?", "show *this* note" — you model the note as an `AppEntity` so the system can present a searchable picker, pipe one between Shortcuts steps, and (with Spotlight, lecture 2) index it.

```swift
import AppIntents

struct NoteEntity: AppEntity {
    let id: UUID                                  // stable identity the system stores
    @Property(title: "Title") var title: String
    @Property(title: "Created") var createdAt: Date

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)",
                              subtitle: "\(createdAt.formatted(date: .abbreviated, time: .shortened))")
    }

    static let defaultQuery = NoteQuery()
}

// How the system finds entities: by id (for piping) and by string (for a picker search).
struct NoteQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        return store.notes(withIDs: identifiers).map(NoteEntity.init)
    }

    func suggestedEntities() async throws -> [NoteEntity] {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        return store.recentNotes(limit: 5).map(NoteEntity.init)
    }
}

// A query that supports free-text search powers an Entity picker in Shortcuts.
extension NoteQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [NoteEntity] {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        return store.search(string).map(NoteEntity.init)
    }
}
```

What each piece buys you:

- **`id`** is the stable handle the system stores when a user puts "this note" into a shortcut. Later, to re-resolve it, the system calls `entities(for:)` with that id. Use your model's real identifier (a `UUID`, or a SwiftData `PersistentModelID`-derived value) so it survives across launches.
- **`displayRepresentation`** is how the entity renders in a picker or a Siri response — a title and optional subtitle and image. This is the entity's face.
- **`defaultQuery`** / `EntityQuery` is how the system *finds* entities: `entities(for:)` resolves ids (for piping a value between steps), `suggestedEntities()` provides the default picker list, and conforming to `EntityStringQuery` adds free-text search so a user can type to filter your notes in the Shortcuts entity picker.

Now an intent can take a `NoteEntity` parameter and the system presents your notes in a searchable picker, for free:

```swift
struct PinNote: AppIntent {
    static let title: LocalizedStringResource = "Pin note"

    @Parameter(title: "Note")
    var note: NoteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        store.setPinned(true, forNoteID: note.id)
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
        return .result()
    }
}
```

The user building this shortcut gets a "Note" parameter that opens a searchable list of their notes — and you wrote none of that UI. That is the leverage of modelling your nouns as entities.

### `AppEnum` — a fixed menu of choices

Not every parameter is free-form text or an entity. When the input is one of a *fixed* set — a sort order, a note colour, a priority — model it as an `AppEnum` and the system renders a menu:

```swift
enum NoteSort: String, AppEnum {
    case newest, oldest, alphabetical

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sort order")
    static let caseDisplayRepresentations: [NoteSort: DisplayRepresentation] = [
        .newest: "Newest first",
        .oldest: "Oldest first",
        .alphabetical: "Alphabetical"
    ]
}

struct ListNotes: AppIntent {
    static let title: LocalizedStringResource = "List notes"

    @Parameter(title: "Sort", default: .newest)
    var sort: NoteSort

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> {
        let store = try NotesStore(forGroup: AppGroup.identifier)
        let notes = store.allNotes(sortedBy: sort).map(NoteEntity.init)
        return .result(value: notes)
    }
}
```

The `caseDisplayRepresentations` map is what turns the raw cases into human-readable menu items in Shortcuts and Siri. An `AppEnum` is the right model whenever the answer is "one of these N options" — it gives the user a picker, validates the input for free, and reads naturally in the Shortcuts sentence. Reach for it instead of a `String` parameter the moment the valid values are a closed set; a stringly-typed "sort" parameter that the user can fat-finger is a worse experience and a class of bug an enum eliminates at the type level (the same Week 1 lesson — model the closed set as an enum — applied to the intent surface).

### Chaining and returning values

The `ListNotes` intent above returns `ReturnsValue<[NoteEntity]>` — which means its output can be *piped into the next Shortcuts step.* This is the composition that makes App Intents powerful: a user (or you, in an App Shortcut) can build "List notes sorted newest → take the first → pin it" by chaining intents, each consuming the previous one's typed output. You enable it by composing the right result protocols:

- **`ReturnsValue<T>`** — hands a typed value to the next step (an entity, a number, a string, an array).
- **`ProvidesDialog`** — speaks/shows a sentence to the user (closing the loop when there's no UI).
- **`OpensIntent`** — chains directly to another intent, so one action triggers the next.
- **`ShowsSnippetView`** — returns a small SwiftUI snippet the system renders inline (a richer confirmation than a dialog).

You compose what the action needs: a pure mutation returns bare `IntentResult`; a query returns `ReturnsValue`; a Siri-facing action adds `ProvidesDialog` so the user hears confirmation. The composition is the action's *contract* with the rest of the system — what it gives back, and to whom.

---

## 5. Why this replaced `.intentdefinition` entirely

If you read older iOS material you will see `SiriKit`, `INIntent`, `.intentdefinition` files, and an "Intents Extension" target. That is the **previous** generation, and App Intents replaced it for new work. The reasons are worth knowing because they explain why the new framework looks the way it does:

| Old world (`.intentdefinition` / SiriKit) | New world (App Intents) |
|-------------------------------------------|--------------------------|
| A visual `.intentdefinition` editor that did not diff in Git or review in a PR | Pure Swift `structs` — diffable, reviewable, type-checked |
| Code generation produced `INIntent` subclasses you imported but couldn't read | No code-gen; the intent *is* the source you wrote |
| A separate **Intents Extension** target with its own lifecycle | The intent compiles into your app (and any extension that needs it); no separate target required |
| Parameters were loosely typed and resolution was a delegate dance | `@Parameter` with real Swift types; the framework drives resolution and follow-up questions |
| Siri, Shortcuts, and widgets each integrated differently | One intent feeds Siri, Shortcuts, the action button, interactive widgets, and Spotlight |
| Predefined SiriKit *domains* (messaging, payments, …) you had to fit into | Your *own* domain — any verb your app supports, no Apple-blessed category required |

The throughline: App Intents made your app's actions **first-class Swift, with one declaration feeding every system surface.** When the syllabus says "App Intents (the framework, not the legacy `IntentDefinition`)," this table is why. You will not write a `.intentdefinition` file this week, or ever, for new code.

---

## 6. The shape of a good intent surface

A senior reviewer looks at your App Intents and asks: *are these the right verbs, modelled cleanly?* The heuristics:

- **Expose actions, not your whole API.** "Add note," "show count," "pin note" are user-meaningful. "Reload the cache," "sync now," "set sort order" are plumbing — keep them in the app. The intent surface is your app's *headline capabilities*, the things a user would reasonably ask Siri or build a shortcut around.
- **Make every parameter recoverable.** If a parameter can be missing, give it a `requestValueDialog` so Siri can ask, or a `default` so it is optional. An intent that fails because a value wasn't supplied and couldn't be asked for is a dead end.
- **Return something.** A `ProvidesDialog` confirmation ("Added a note") closes the loop so the user knows it worked — vital when there's no UI to look at. A `ReturnsValue` lets the action compose into a larger shortcut.
- **Assume the app is terminated.** Construct data access inside `perform()`, reach shared storage, return `Sendable` values, reload the widget. Never depend on app-process singletons.
- **Reload the surfaces you changed.** A mutation that doesn't `reloadTimelines` leaves the widget showing yesterday's state. The intent and the widget are two views of the same store; keep them in sync.

### `openAppWhenRun` and `ShowsSnippetView` — when the intent needs the app

Most intents do their work headless and return a dialog. Two escape hatches exist for when that isn't enough:

- **`static var openAppWhenRun = true`** brings the app to the foreground as part of running the intent. Use it sparingly — for an action that *intrinsically* needs the full UI ("open the note for editing"), not for a quick mutation. An intent that needlessly launches the app defeats the point of the headless surface and annoys the user who asked Siri precisely so they wouldn't have to open the app.
- **`ShowsSnippetView`** lets `perform()` return a small SwiftUI view the system renders inline in the Siri/Shortcuts result — a richer confirmation than a spoken sentence (a mini note preview, say). It's the middle ground between "speak a dialog" and "open the whole app."

The decision: headless with a dialog by default; a snippet when a glance helps; `openAppWhenRun` only when the action genuinely is "take me into the app." Reaching for `openAppWhenRun` as a shortcut to avoid building the headless path is the anti-pattern — it turns every Siri request into an app launch, which is exactly what App Intents was built to avoid.

---

## 7. Recap — the verb your app lends to the OS

You will write App Intents all week and lean on them again in the capstone. The discipline that turns "I made an intent that worked in a demo" into "I shipped an intent the platform surfaces reliably" is one habit: **treat `perform()` as code that runs while your app is dead.**

- It runs off-process → construct data access locally, pointed at the shared App Group store.
- It returns to a faceless caller → return a `Sendable` value or dialog, never a live object.
- It changed shared state → reload the widget timelines so the visible surface updates.
- It needs to reach Siri with no setup → register an `AppShortcutsProvider` with `\(.applicationName)` in every phrase.
- It acts on your app's objects → model those objects as `AppEntity` so the system gives you a searchable picker for free.
- Its input is a closed set → model it as an `AppEnum` for a validated menu, not a fat-fingerable `String`.

One last reflex to keep: **the App Group is the foundation under all of it.** Every snippet in this lecture that touches data — `AddNote`, `PinNote`, `NoteQuery`, `ListNotes` — reaches the store via `AppGroup.identifier`, never via an app-process handle. That is not a stylistic choice; it is what makes the intent work when the app is dead, and it is the same shared container the widget and Spotlight index will read in lecture 2. Get the App Group right and every off-process surface this week — intent, widget, Spotlight result — can see the data; get it wrong and none of them can.

App Intents turned your app's actions into Swift the operating system can call. WidgetKit (lecture 2) turns your app's *content* into something the system can render on a timeline, and Core Spotlight turns it into something the system can *find* — and both of them lean on the App Group that lets the off-process surfaces see your store. Bring this diagram with you to lecture 2; we are about to make every surface on it real over the Hello, Notes data.
