# Lecture 1 — The architecture spectrum, and MVVM as a discipline

> "Architecture is the set of constraints you accept on purpose so that change stays cheap. Every pattern is a trade. The skill is knowing which trade to make."

This is the lecture that stops you from cargo-culting an architecture. By the end you should be able to draw a single axis — *amount of structure* — place three patterns on it, and say, for any given feature, which point on that axis is correct and why. We start with the cheapest possible architecture (none), build up to MVVM, and leave TCA for lecture 02. The through-line is one question repeated at every level: **what does this structure buy, and what does it cost?**

---

## 1. The one axis that matters

Forget the acronym soup for a moment. Almost every iOS architecture argument is really an argument about a single dial: **how much structure do you impose between "the user tapped a button" and "the database changed"?**

```text
 less structure                                                      more structure
 cheaper to write                                                    cheaper to change at scale
 ◄──────────────────────────────────────────────────────────────────────────────►
 │                          │                          │                          │
 Plain SwiftUI          MVVM (an              Unidirectional         TCA (a full
 + @Observable          @Observable           data flow             framework: reducers,
 logic in the view      view model)           (state in/actions     effects, dependencies,
                                               out, hand-rolled)     exhaustive tests)
```

Moving right buys you **testability** (logic you can assert without a UI), **predictability** (state changes are explicit and reproducible), and **team-scaling** (a shape everyone follows, so a stranger's feature reads like yours). Moving right costs you **indirection** (more files, more hops to follow a single tap), **boilerplate** (types and glue per feature), and sometimes **build time** (macros and generics are not free).

There is no globally correct point on this axis. There is only the correct point *for a given feature, team, and lifespan.* A settings toggle owned by one engineer for a screen nobody will touch again belongs on the far left. A payment flow touched by six engineers over three years, where a wrong state transition costs real money, belongs further right. The senior move is matching the structure to the stakes — and writing down why.

### The three questions that decide it

When you are genuinely unsure where a feature belongs on the axis, ask these three questions in order. They resolve the vast majority of cases.

1. **How much do I need to test the logic in isolation?** If the logic is "show this sheet, dismiss it," there is nothing to test and no view model earns its keep. If the logic is "compute the renewal price given plan, region, promo, and proration," you want that in something you can hit with a hundred assertions and zero UI. The amount of *testable logic* pulls you right.

2. **How many people will touch this, over how long?** One person for one sprint: keep it simple. Six people for three years: the consistency of a strong pattern (everyone's feature has the same shape) is worth real boilerplate, because the boilerplate is what makes a stranger's code legible. Team size and lifespan pull you right.

3. **How bad is a wrong state transition?** A cosmetic glitch: who cares, stay left. A double charge, a lost draft, a sync that corrupts data: you want unidirectional flow and exhaustive tests so that "the state can never reach this combination" is *proven*, not hoped. Blast radius pulls you right.

If all three answers are "low," the correct architecture is *no architecture* — and choosing that deliberately is not laziness, it is judgment. If any answer is "high," you start climbing the axis. We will keep coming back to these three questions all week.

---

## 2. The far left: plain SwiftUI + `@Observable`

Here is the thing the internet rarely tells SwiftUI newcomers: **the Observation framework you learned in Week 8 already does most of what MVVM was invented to do.** Before SwiftUI, the view (a `UIViewController`) had no way to bind to a model and re-render automatically; you needed a layer — a view model — plus a reactive library (RxSwift, ReactiveCocoa) to push changes into the view. MVVM existed to *create binding where the platform had none.*

SwiftUI has binding built in. `@Observable` makes any class's mutations drive re-renders. So a huge swath of "MVVM" in SwiftUI is just… the language. Watch how little ceremony a real feature needs:

```swift
import SwiftUI

struct CounterScreen: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.largeTitle.monospacedDigit())
            HStack {
                Button("−") { count -= 1 }
                Button("+") { count += 1 }
            }
        }
    }
}
```

There is no view model here, and adding one would be *worse* — pure indirection buying nothing. The logic (`+1`, `−1`) is trivial, untested-able in any meaningful sense, owned by one screen. This is the far-left architecture, and for this feature it is *correct.* The discipline is recognising it.

Now scale up slightly. A small piece of state with a touch of logic, still owned by the view, still fine with no extra layer:

```swift
@Observable
final class FilterModel {
    var query = ""
    var showArchived = false

    func matches(_ note: Note) -> Bool {
        let textOK = query.isEmpty
            || note.title.localizedStandardContains(query)
        let archiveOK = showArchived || !note.isArchived
        return textOK && archiveOK
    }
}

struct NotesScreen: View {
    @State private var filter = FilterModel()
    let notes: [Note]

    var body: some View {
        List(notes.filter(filter.matches)) { Text($0.title) }
            .searchable(text: $filter.query)
            .toolbar {
                Toggle("Archived", isOn: $filter.showArchived)
            }
    }
}
```

Is `FilterModel` a "view model"? Sort of — but notice we did not *call* it one, did not give it a protocol, did not inject anything, did not build a test target. It is a small `@Observable` holding a little state and a pure function. It lives one `@State` declaration away from the view that owns it. This is the grey zone right of "nothing" and left of "MVVM as a discipline," and it is where an enormous amount of healthy SwiftUI code lives. Do not let a process force you to promote this into five files.

**When the far left stops being enough.** You feel it. The `matches` function grows three more flags. The view starts doing network calls in `.task`. A second screen needs the same filtering logic. Someone asks "can we unit-test the filter rules?" and you realise the rules are tangled into a `View` you cannot instantiate without a SwiftUI runtime. *That* is the signal to move right — not a rule that said "always use MVVM," but a felt cost the structure would remove.

---

## 3. MVVM as a discipline (not a library)

MVVM in modern SwiftUI is not a framework you import. It is a *discipline*: you decide that a feature's state and logic live in a dedicated, deliberately-designed `@Observable` class — the **view model** — and the **view** does nothing but render that state and forward user intent back to the model. Three rules define the discipline:

1. **The view model owns the feature's state and logic.** Everything the feature *is* and *does* — the data, the derived values, the actions the user can take — lives in the view model. The view holds a reference to it and nothing else of substance.

2. **The view is dumb.** It reads the model's state to build `body`, and it calls the model's methods in response to taps and edits. It contains no business logic, no network calls, no persistence. If you deleted every `View` and kept the view models, the *behaviour* of the app would be fully described.

3. **Dependencies are injected, never reached for.** The view model does not say `URLSession.shared` or `ModelContext()` inside itself; it receives whatever it needs through its `init`. This is the single rule that makes the difference between a testable view model and an untestable one, and §5 is entirely about it.

Here is the `FilterModel` from §2, promoted to a real view model because the feature grew — it now loads notes, tracks loading state, and reports errors:

```swift
import SwiftUI
import Observation

@Observable
@MainActor
final class NotesListModel {
    // MARK: State the view renders
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    var query = ""

    // MARK: Injected dependencies (see §5)
    private let repository: NotesRepository

    init(repository: NotesRepository) {
        self.repository = repository
    }

    // MARK: Derived state (pure, trivially testable)
    var visibleNotes: [Note] {
        guard !query.isEmpty else { return notes }
        return notes.filter { $0.title.localizedStandardContains(query) }
    }

    // MARK: Intent the view forwards
    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            notes = try await repository.allNotes()
        } catch {
            loadError = "Couldn't load notes: \(error.localizedDescription)"
        }
    }

    func addNote(title: String) async {
        do {
            let note = try await repository.create(title: title)
            notes.insert(note, at: 0)
        } catch {
            loadError = "Couldn't add note: \(error.localizedDescription)"
        }
    }
}
```

And the dumb view that drives it:

```swift
struct NotesListView: View {
    @State private var model: NotesListModel

    init(repository: NotesRepository) {
        _model = State(initialValue: NotesListModel(repository: repository))
    }

    var body: some View {
        List(model.visibleNotes) { note in
            Text(note.title)
        }
        .searchable(text: $model.query)         // two-way binding into the model
        .overlay {
            if model.isLoading { ProgressView() }
        }
        .alert("Error", isPresented: .constant(model.loadError != nil)) {
            Button("OK") { }
        } message: {
            Text(model.loadError ?? "")
        }
        .task { await model.load() }            // forward "view appeared" intent
        .toolbar {
            Button("Add") { Task { await model.addNote(title: "New") } }
        }
    }
}
```

Notice the shape. The view's `body` is a *projection of model state*. The view's interactions are *calls into the model*. There is not one `if` of business logic in the view. You could hand the view to a designer and the view model to a backend engineer and they would barely need to talk.

### Why `@Observable` and `@MainActor`, specifically

- **`@Observable`** (the Week 8 macro) is what makes mutations to `notes`, `isLoading`, `query` re-render the view automatically. It tracks *which* properties the `body` actually read and re-runs `body` only when one of those changes — the precise re-render you learned to reason about in Week 8. This is why modern MVVM needs no reactive library: the binding is in the language.
- **`@MainActor`** on the whole class is the Swift-6-correct way to say "this view model's state is only ever touched on the main thread." The view reads it on the main actor; the `async` methods `await` off-main work (the repository call) and then mutate state back on the main actor. The compiler enforces it. Mark UI-facing view models `@MainActor` and you sidestep a whole category of data races (Week 4) for free.
- **`private(set)`** on the read-only state is a small but real discipline: the view can *read* `notes` but cannot *assign* it. Only the model's own methods mutate it. This keeps the "view is dumb" rule from eroding one convenient `model.notes = []` at a time. The bindable `query` is `var` because `.searchable` needs two-way access.

### The `@State`-owns-the-model pattern

One subtlety that trips people up: the view *owns* its view model via `@State`, not `@StateObject` (that was the `ObservableObject` era) and not a plain `let`. `@State private var model: NotesListModel` means SwiftUI keeps the *same* model instance alive across re-renders of this view — it is created once when the view first appears and persists. If you wrote `let model = NotesListModel(...)` you would get a *fresh* model every time `body` re-ran, losing all state. `@State` is the ownership primitive (Week 8) and a reference-type view model is a legitimate thing to own with it. When a *parent* creates the model and passes it down, the child takes it as `@Bindable var model:` (also Week 8) so it can bind to the model's properties.

---

## 4. Unidirectional vs bidirectional data flow

MVVM as shown above is *mostly* unidirectional but cheats in one place, and understanding the cheat is the bridge to TCA.

**Unidirectional** means: state flows *down* into the view (the view reads it to render), and intent flows *up* out of the view (the view calls methods; the model changes state; the new state flows down again). One direction, one loop. State is never mutated by the view directly — the view *asks*, the model *decides*.

```text
        ┌──────────────────────────────────────────┐
        │                                           │
        ▼                                           │
   ┌─────────┐   reads state    ┌──────────┐        │
   │  View   │ ◄─────────────── │  Model   │        │
   │ (dumb)  │ ──────────────►  │ (logic)  │ ───────┘
   └─────────┘  sends intent    └──────────┘   mutates state,
                (method call)                  loop repeats
```

Our `addNote` and `load` are unidirectional: the view says "add" / "appeared," the model does the work and updates state, the view re-renders. Clean.

**The cheat is `$model.query`.** SwiftUI's two-way `@Binding` (`.searchable(text: $model.query)`) lets the *view* write directly into the model's `query`. That is bidirectional — the view mutated model state without going through a method. For a search field this is fine and idiomatic; SwiftUI's bindings are *built* for exactly this, and fighting them is silly. But notice the asymmetry: the part of MVVM that is "pure" unidirectional flow is the *logic* (loading, adding), and the part that is bidirectional is the *form input* (text fields, toggles). Most MVVM is this hybrid, and it works well.

**TCA's whole proposition (lecture 02) is making even the form input unidirectional** — a text edit becomes an `Action` (`.queryChanged("sw")`) that flows through the reducer like everything else, so *every* state change in the entire feature is a single, observable, replayable event. That is more structure (every binding becomes an action) buying more predictability (you can record the action stream and replay the exact session). Whether that trade is worth it is the central question of the week — and the answer is "sometimes." Hold the asymmetry in mind; it is the seam where MVVM ends and TCA begins.

---

## 5. Dependency injection — the rule that makes a view model testable

This is the most important section in the lecture, because it is the difference between a view model you can test and one you cannot, and testability is the main thing the architecture axis buys.

**The anti-pattern:** a view model that reaches out and grabs its dependencies.

```swift
@Observable @MainActor
final class BadModel {
    private(set) var notes: [Note] = []

    func load() async {
        // ☠️ reaches for the live world directly.
        let url = URL(string: "https://api.example.com/notes")!
        let (data, _) = try! await URLSession.shared.data(from: url)   // hidden dependency
        notes = try! JSONDecoder().decode([Note].self, from: data)
    }
}
```

You cannot test `BadModel.load()` without hitting the real network. There is no seam to insert a fake. A test would be slow, flaky, and dependent on a server being up. The dependency on `URLSession.shared` is *hidden* — it is not visible in the type's signature, so nothing forces you to confront it. Hidden dependencies are the root cause of untestable code.

**The fix:** make the dependency a *parameter*. Define an abstraction (a protocol, or just a struct of closures) and inject a conforming value through `init`.

```swift
// 1. The abstraction. A protocol is the classic choice; a struct-of-closures
//    (the "witness" style TCA favours) also works. Either gives you a seam.
protocol NotesRepository: Sendable {
    func allNotes() async throws -> [Note]
    func create(title: String) async throws -> Note
}

// 2. The live implementation — the real network/persistence.
struct LiveNotesRepository: NotesRepository {
    let session: URLSession
    func allNotes() async throws -> [Note] {
        let url = URL(string: "https://api.example.com/notes")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([Note].self, from: data)
    }
    func create(title: String) async throws -> Note {
        // ...POST and decode the created note...
        Note(title: title)
    }
}

// 3. The view model takes the abstraction, not the concretion.
@Observable @MainActor
final class NotesListModel {
    private let repository: NotesRepository
    init(repository: NotesRepository) { self.repository = repository }
    // ...as in §3...
}
```

Now there is a *seam*. In production you inject `LiveNotesRepository`. In a test you inject a stub:

```swift
import Testing

struct StubRepository: NotesRepository {
    var notes: [Note]
    var createError: Error?
    func allNotes() async throws -> [Note] { notes }
    func create(title: String) async throws -> Note {
        if let createError { throw createError }
        return Note(title: title)
    }
}

@MainActor
struct NotesListModelTests {
    @Test("load populates notes from the repository")
    func loadPopulates() async {
        let stub = StubRepository(notes: [Note(title: "A"), Note(title: "B")])
        let model = NotesListModel(repository: stub)

        await model.load()

        #expect(model.notes.count == 2)
        #expect(model.isLoading == false)
        #expect(model.loadError == nil)
    }

    @Test("load surfaces an error when the repository throws")
    func loadSurfacesError() async {
        struct Boom: Error {}
        let failing = StubRepository(notes: [], createError: Boom())
        // Make allNotes throw too for this test:
        var stub = failing
        stub.notes = []
        let model = NotesListModel(repository: ThrowingRepository())

        await model.load()

        #expect(model.notes.isEmpty)
        #expect(model.loadError != nil)
    }

    @Test("visibleNotes filters by query")
    func filtering() {
        let model = NotesListModel(repository: StubRepository(notes: []))
        model.notes = []   // (test-only seam, or expose a setter for tests)
        model.query = "swift"
        #expect(model.visibleNotes.allSatisfy { $0.title.localizedStandardContains("swift") })
    }
}

struct ThrowingRepository: NotesRepository {
    struct Boom: Error {}
    func allNotes() async throws -> [Note] { throw Boom() }
    func create(title: String) async throws -> Note { throw Boom() }
}
```

These tests are fast (no network), deterministic (the stub returns exactly what you say), and they exercise the *logic* — loading, error handling, filtering — with no SwiftUI runtime at all. That is the payoff of MVVM-as-a-discipline: **the behaviour of the app is in a class you can instantiate and assert against.** The far-left "logic in the view" architecture could not give you this, because you cannot instantiate a `View`'s logic in isolation. The structure bought testability. That is the trade, made visible.

### Two flavours of the abstraction: protocol vs struct-of-closures

You will see both. A **protocol** (`protocol NotesRepository`) is the familiar object-oriented seam. A **struct of closures** — the "witness" pattern Point-Free popularised and TCA's dependency system uses — looks like this:

```swift
struct NotesRepositoryClient: Sendable {
    var allNotes: @Sendable () async throws -> [Note]
    var create: @Sendable (_ title: String) async throws -> Note
}

extension NotesRepositoryClient {
    static let live = Self(
        allNotes: { /* real network */ [] },
        create: { title in Note(title: title) }
    )
    static func stub(_ notes: [Note]) -> Self {
        Self(allNotes: { notes }, create: { Note(title: $0) })
    }
}
```

The struct-of-closures style avoids a proliferation of one-method protocols and conforming types; you build a value with the behaviours you want, including per-test stubs, inline. It composes beautifully with TCA's `@Dependency` (lecture 02). For now, know that *both* are valid ways to create the seam, and the seam — not the syntax — is the point. A hidden `URLSession.shared` has no seam; a parameter has one.

---

## 6. The MVVM smells to watch for

MVVM done badly is worse than no architecture — it adds indirection without adding the testability that justified the indirection. The code-review smells:

- **The Massive View Model.** You fled the Massive View Controller of UIKit and recreated it as a 600-line view model that does networking, persistence, formatting, navigation, and analytics. The fix is the same as always: split by responsibility. A view model should own *one feature's* state and intent, not the whole screen's universe.
- **Logic that leaked back into the view.** An `if note.dueDate < .now && !note.isDone { ... }` inside `body`. That is business logic in the dumb view; move it to the model as a derived property (`note.isOverdue`) and let the view render the boolean.
- **The view model that reaches for the live world.** `URLSession.shared`, `ModelContext()`, `Date()`, `UUID()` *inside* the model. Every one is a hidden dependency that makes a test non-deterministic. Inject them. (Even `Date.now` and `UUID()` are dependencies — a test that asserts a timestamp needs a controllable clock; lecture 02's TCA `@Dependency(\.date)` and `@Dependency(\.uuid)` exist precisely for this.)
- **A view model for a view that has no logic.** A `SettingsToggleViewModel` wrapping a single `Bool`. This is structure buying nothing. Delete it; use `@State`. Resisting needless structure is as much the discipline as adding needed structure.
- **Bidirectional bindings into computed state.** Trying to make `.searchable(text: $model.visibleNotesQuery)` bind to something that is *derived* rather than *stored*. Bindings need a real stored property to write to. Bind to `query`; compute `visibleNotes` from it.

---

## 7. Where we are, and where lecture 02 goes

You now have the left half of the architecture axis cold:

- **Plain SwiftUI + `@Observable`** is the correct architecture for trivial, single-owner, untested-able features — and choosing it is judgment, not laziness.
- **MVVM as a discipline** extracts an `@Observable`, `@MainActor` view model that owns the feature's state and logic, keeps the view dumb, injects its dependencies, and is therefore testable with fast, deterministic Swift Testing suites and zero UI.
- **Dependency injection** — making dependencies parameters, not hidden global reaches — is the single rule that converts an untestable view model into a testable one. Protocol or struct-of-closures; the seam is the point.
- **Unidirectional data flow** (state down, intent up) is the clean half of MVVM; the bidirectional `@Binding` for form input is the idiomatic hybrid; and making *even form input* unidirectional is exactly what TCA does next.

Lecture 02 climbs the right half of the axis: **The Composable Architecture**, where state is a value, every change is an `Action`, every side effect is a *described* `Effect` the store runs and cancels for you, dependencies are a first-class system, and the whole feature is exhaustively testable with a `TestStore`. Then we make the concrete case against **VIPER** — what it solved in 2014, and why SwiftUI plus everything in *this* lecture make its ceremony redundant — and we learn to write the **ADR** that records which point on the axis a feature chose, and why. Bring the three questions (testability, team size, blast radius) with you; they are how we decide whether TCA's extra structure is worth its cost.
