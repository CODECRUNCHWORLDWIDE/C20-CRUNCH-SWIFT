# Lecture 2 — The Composable Architecture, the case against VIPER, and the ADR

Lecture 1 took you up the left half of the architecture axis: plain SwiftUI, then MVVM as a discipline, with dependency injection as the rule that makes a view model testable. This lecture climbs the right half. We build **The Composable Architecture (TCA)** from its primitives, feel exactly what its extra structure buys (exhaustive testability, total predictability) and costs (every change is an action, more types, a real dependency on a third-party library). Then we make the concrete, fair **case against VIPER** — not a strawman, a genuine accounting of what it solved and why SwiftUI repealed the problem. And we close on the actual deliverable of the week: the **architectural decision record** that makes your choice legible.

---

## 1. TCA from first principles — state, action, reducer

TCA is a framework by Point-Free that imposes **unidirectional data flow** on the *whole* feature, including the form inputs that MVVM left bidirectional (lecture 1, §4). The core idea is a single function:

```text
(inout State, Action) -> Effect
```

Read it slowly. A **reducer** takes the current `State` (mutable, in-out) and an `Action` (a thing that happened), mutates the state to reflect that action, and returns an **`Effect`** — a *description* of any side work to run (a network call, a timer, a save). The store runs the reducer for every action, applies the state mutation, and runs the returned effect. That is the entire model. Every change to the feature's state goes through this one funnel, which is why TCA features are so predictable: there is exactly one place state changes, and every change is a named action.

Here is a minimal but real feature — a search field that debounces and "loads" results — written in TCA. We will reuse the search-and-filter domain from the mini-project.

```swift
import ComposableArchitecture

@Reducer
struct SearchFeature {
    @ObservableState
    struct State: Equatable {
        var query = ""
        var results: [Note] = []
        var isSearching = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)   // form input becomes an action
        case queryChangedDebounced
        case searchResponse([Note])
    }

    @Dependency(\.notesRepository) var repository
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case search }

    var body: some ReducerOf<Self> {
        BindingReducer()   // turns $store.query edits into .binding actions, updating state

        Reduce { state, action in
            switch action {
            case .binding(\.query):
                // The user typed. Debounce, then fire the search.
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.queryChangedDebounced)
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .binding:
                return .none

            case .queryChangedDebounced:
                let query = state.query
                guard !query.isEmpty else {
                    state.results = []
                    return .none
                }
                state.isSearching = true
                return .run { send in
                    let hits = try await repository.search(query)
                    await send(.searchResponse(hits))
                }

            case let .searchResponse(notes):
                state.isSearching = false
                state.results = notes
                return .none
            }
        }
    }
}
```

There is a lot here; let us name each piece, because each is a deliberate trade.

- **`@Reducer`** is a macro that wires the boilerplate (conformances, the `Action` case-path machinery). It is the modern TCA entry point.
- **`@ObservableState`** on `State` makes the value-type state observable to SwiftUI the same way `@Observable` does for a class — when the store's `query` changes, only views that read `query` re-render. State is a `struct`, a *value*; this is central. The entire feature's state is one inspectable, `Equatable`, copyable value.
- **`Action`** is an `enum`. Every single thing that can happen — a keystroke (via `binding`), a debounce firing, a response arriving — is a case. Reading the `Action` enum tells you the *complete* vocabulary of what this feature can do. That is a real documentation win.
- **`Reduce { state, action in ... }`** is the reducer body: a `switch` over actions that mutates `state` and returns an `Effect`. Note it is *just a switch* — no inheritance, no protocols-per-edge, a plain pure-ish function over a value.
- **`Effect`** is what the closure returns. `.none` means "no side work." `.run { send in ... }` describes async work and gives you a `send` to feed actions *back* into the system when the work completes. Crucially, the effect is *returned as a value* — the reducer describes the work but does not perform it; the store performs it. This is what makes effects testable (§3) and cancellable.
- **`.cancellable(id:cancelInFlight:)`** is TCA's debounce/cancellation: each keystroke cancels the previous in-flight search effect, so only the last one survives the 300 ms. You wrote *zero* `Task` cancellation plumbing; the store manages the effect's lifecycle. (This is the same debounce you will build by hand with `AsyncStream` and Combine next week — here it is one modifier.)

### The store and the view

The reducer is pure logic. The **`Store`** runs it, and the SwiftUI view observes the store:

```swift
import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    var body: some View {
        List(store.results) { note in
            Text(note.title)
        }
        .searchable(text: $store.query)        // two-way binding, but it flows as a .binding action
        .overlay {
            if store.isSearching { ProgressView() }
        }
    }
}

// Construction — at the app entry, you build the store once:
let store = Store(initialState: SearchFeature.State()) {
    SearchFeature()
}
```

Look at `$store.query`. It *looks* like the MVVM `$model.query` from lecture 1 — but underneath, the edit becomes a `.binding(\.query)` action that flows through the reducer. The form input that MVVM left bidirectional is now unidirectional: even a keystroke is a named event in the action stream. That is the structure TCA adds, and §3 is why anyone would want it.

---

## 2. Dependencies — the first-class injection system

Lecture 1 made the case that injected dependencies are what make logic testable. TCA takes that from a discipline to a *system*. You saw `@Dependency(\.notesRepository)` and `@Dependency(\.continuousClock)` above. Here is how you register one:

```swift
import ComposableArchitecture

// 1. The client — a struct of closures (the witness style from lecture 1, §5).
struct NotesRepositoryClient: Sendable {
    var search: @Sendable (_ query: String) async throws -> [Note]
    var create: @Sendable (_ title: String) async throws -> Note
}

// 2. Conform it to DependencyKey with the three canonical values.
extension NotesRepositoryClient: DependencyKey {
    static let liveValue = Self(
        search: { query in /* real network/SwiftData query */ [] },
        create: { title in Note(title: title) }
    )

    // Used in tests by default; deliberately "unimplemented" so an UNEXPECTED
    // call fails the test loudly instead of silently returning junk.
    static let testValue = Self(
        search: unimplemented("NotesRepositoryClient.search", placeholder: []),
        create: unimplemented("NotesRepositoryClient.create", placeholder: Note(title: ""))
    )

    static let previewValue = Self(
        search: { _ in [Note(title: "Preview note")] },
        create: { Note(title: $0) }
    )
}

// 3. Expose it on DependencyValues so @Dependency(\.notesRepository) resolves.
extension DependencyValues {
    var notesRepository: NotesRepositoryClient {
        get { self[NotesRepositoryClient.self] }
        set { self[NotesRepositoryClient.self] = newValue }
    }
}
```

Three things make this worth the ceremony:

1. **`liveValue` / `testValue` / `previewValue`.** TCA automatically uses `liveValue` in the running app, `previewValue` in Xcode previews, and `testValue` in tests. You never wire which-one-where; the context picks. Previews get cheap fake data; tests get a controllable stub; production gets the real thing.
2. **`unimplemented` as the default `testValue`.** This is the sharp idea. The default test dependency *fails the test if it is called.* So a test only "passes" if you explicitly override the dependencies the feature actually uses — an *unexpected* network call in a test you thought was pure becomes a loud failure, not a silent flake. This catches the bug where a refactor adds a side effect you forgot to account for.
3. **`@Dependency(\.continuousClock)`, `@Dependency(\.date)`, `@Dependency(\.uuid)`** ship *with* the library. The "hidden `Date.now`/`UUID()`" smell from lecture 1, §6 is solved out of the box: in tests you inject a `TestClock` and an immediate, incrementing UUID, so time and identity are deterministic. The 300 ms debounce above becomes *instant and exact* in tests because the `TestClock` lets you advance time by hand (§3).

This is the dependency-injection discipline of lecture 1, industrialised. The trade: more setup per dependency, a real coupling to the `swift-dependencies` library — bought with the most testable effect system in the ecosystem.

---

## 3. Testing TCA — exhaustive, and why that matters

Here is the payoff that justifies the whole framework. TCA's `TestStore` asserts the *entire* state and effect flow, exhaustively. You `send` an action, declare exactly how state should change, and `receive` every effect action — and if anything diverges, even a field you forgot, the test fails.

```swift
import ComposableArchitecture
import Testing

@MainActor
struct SearchFeatureTests {
    @Test("typing debounces, searches, and populates results")
    func searchFlow() async {
        let clock = TestClock()
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.notesRepository.search = { query in
                #expect(query == "swift")
                return [Note(title: "SwiftUI"), Note(title: "SwiftData")]
            }
        }

        // 1. The user types. State updates immediately; an effect is scheduled.
        await store.send(\.binding.query, "swift") {
            $0.query = "swift"
        }

        // 2. Advance the TestClock past the 300 ms debounce. The debounced
        //    action fires; we declare the state change it causes.
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangedDebounced) {
            $0.isSearching = true
        }

        // 3. The search effect completes and sends back results.
        await store.receive(\.searchResponse) {
            $0.isSearching = false
            $0.results = [Note(title: "SwiftUI"), Note(title: "SwiftData")]
        }
    }
}
```

Why exhaustivity is the feature, not a chore:

- **You must account for every state change.** If the reducer also set `state.lastSearchedAt = clock.now` and you forgot to assert it, the test *fails* — "state was not as expected." The test is a complete, executable specification of the feature's behaviour. There is no "it changed some other field I didn't notice" bug class.
- **You must account for every effect.** Every `.run` effect that sends an action back must be `receive`d, or the `TestStore` fails at the end with "an effect is still in flight." You cannot accidentally leave a fire-and-forget effect untested.
- **Time is controllable.** The `TestClock` made the 300 ms debounce instant and exact. No `sleep`, no flake, no waiting. The "advance by 300 ms" is a single line and the debounced action fires deterministically. This is the `@Dependency(\.continuousClock)` payoff.
- **The `unimplemented` default caught the unexpected.** Because `testValue` for the repository is `unimplemented`, the test only works because we *explicitly* overrode `search`. If the reducer had also called `create`, the test would have failed with "create was called but not implemented" — surfacing a side effect we didn't model.

This is the far-right of the architecture axis. The trade is now fully visible: you wrote an `Action` enum, a value-type `State`, a reducer, three dependency values, and an exhaustive test — *much* more code than the MVVM version. In return you got a feature whose every state transition and every side effect is proven, whose time is deterministic, and whose unexpected effects fail loudly. For a payment flow or a sync engine, that trade is a bargain. For a settings toggle, it is absurd. **The framework did not change which trade is correct; it just made the high-structure end of the axis very, very good at what it is for.**

---

## 4. The case against VIPER — fair, then final

VIPER was the dominant "serious" iOS architecture from roughly 2014 to 2019. It is still in production codebases and still asked about in interviews, so you must be able to discuss it — and, in 2026, argue against adopting it for new SwiftUI work. Do both fairly.

### What VIPER is

Five components, one per letter, connected by protocols:

- **V — View** (a `UIViewController`): renders, forwards user events to the Presenter. Passive.
- **I — Interactor**: the business logic and data access for the use case.
- **P — Presenter**: the middleman; takes events from the View, asks the Interactor for data, formats it into view-ready models, pushes them back to the View.
- **E — Entity**: the plain model objects.
- **R — Router** (the "wireframe"): owns navigation — which screen comes next, how it is constructed and pushed.

Every edge between these is a **protocol**. The View talks to the Presenter through a `...ViewProtocol` / `...PresenterProtocol` pair; the Presenter talks to the Interactor through `...InteractorInputProtocol` / `...InteractorOutputProtocol`; and so on. A single screen is commonly **five classes and six or more protocols.**

### Why it made sense in 2014

This is the part a fair critique must concede. In 2014, iOS had:

- **No declarative UI.** The View was a `UIViewController`, and `UIViewController` was a tar pit — it owned the view lifecycle, the layout, the data, the networking, and the navigation, and it grew into the infamous **Massive View Controller**. Something had to pull logic *out* of it.
- **No built-in binding or observation.** There was no `@Observable`, no SwiftUI re-render. To get data from a model into a view you wrote it by hand or pulled in a reactive library. The Presenter existed to do this hand-wiring.
- **No value-typed navigation.** Navigation was imperative `pushViewController` calls scattered through controllers. The Router existed to centralise that mess.
- **Weak testability by default.** A `UIViewController` is hard to unit-test. Pushing logic into a protocol-fronted Interactor/Presenter gave you something instantiable to test.

Every VIPER component was a *reasonable answer to a real problem the platform had.* It was not cargo cult in 2014. It was disciplined engineering against a hostile substrate.

### Why it is the wrong answer in 2026

Now go component by component and ask what SwiftUI plus everything in these two lectures already provides:

- **The Massive View Controller problem is gone.** SwiftUI's `View` is a small, declarative `struct` that is *already* "passive render of state." There is no 2000-line controller to break up because SwiftUI never gives you one. The core problem VIPER solved does not occur.
- **The Presenter's binding job is done by `@Observable` / `@ObservableState`.** The entire reason the Presenter existed — to push formatted data into a view that could not observe a model — is replaced by the Observation framework. The view reads the model's state; the framework re-renders. The Presenter is now a pass-through with no job.
- **The Router's navigation job is done by value-typed `NavigationStack` (Week 9).** Navigation as state — `NavigationLink(value:)`, `navigationDestination(for:)`, a `NavigationPath` you can serialise — centralises navigation *by construction*, and it deep-links and state-restores for free. The Router is redundant; SwiftUI navigation is already declarative.
- **The Interactor's testable-logic job is done by an injected view model (MVVM) or a reducer (TCA).** You already have a testable home for business logic that does not require a `UIViewController`. The Interactor's reason to exist — "somewhere instantiable to put logic" — is served better by an `@Observable` model with injected dependencies or a TCA reducer with a `TestStore`.
- **The protocol-per-edge ceremony is pure cost now.** Five classes and six protocols per screen bought testability and decoupling *against UIKit*. Against SwiftUI, where the view is already decoupled and the logic already has a testable home, those protocols are indirection with no payoff — exactly the "structure buying nothing" smell from lecture 1, §6, multiplied per screen.

The verdict is not "VIPER was always bad." It is: **VIPER solved problems SwiftUI eliminated.** Adopting it for new SwiftUI work re-creates the ceremony without the problem that justified it. If you inherit a UIKit VIPER codebase, respect it — it was the right call for its substrate, and rewriting it wholesale is rarely worth it. But for a 2026 greenfield SwiftUI feature, the correct points on the axis are plain SwiftUI, MVVM, or TCA — never VIPER. That is the case, made fairly and made final.

---

## 5. When "no architecture" is the right answer

Having spent two lectures building structure, we owe the counterweight, because over-architecting is at least as common a failure as under-architecting. There are features where adding *any* layer — view model or reducer — buys nothing, and the right call is plain SwiftUI with `@State`:

- **The settings toggle.** One `Bool`, persisted with `@AppStorage`, owned by one screen, no logic. A view model here is pure indirection. `@AppStorage("notifications") var on = true` and a `Toggle` is the whole feature.
- **The one-off confirmation sheet.** "Are you sure?" → yes/no. No state worth testing, no dependency, no longevity. A `@State var isPresented` and a `.confirmationDialog` is correct and complete.
- **The static informational screen.** An "About" page, a licenses list. No state, no logic, no architecture.
- **The throwaway prototype.** You are validating an idea this week and deleting it next week. Structure you will not maintain is a liability, not an asset. Build it on the far left; promote it *if* it survives.

Run the three questions from lecture 1, §1 on each: testability need — none; team-and-longevity — one person, short-lived; blast radius — cosmetic. All low. The axis says: stay far left. **Choosing no architecture for these is the same judgment as choosing TCA for a payment flow — matching structure to stakes.** A senior reviewer is as suspicious of a `SettingsToggleReducer` as of a payment flow with logic crammed in a view. Both are mismatches.

---

## 6. The architectural decision record (ADR)

Here is the actual deliverable of the week — not the code, the *record of the decision.* An ADR is a short, durable document that captures one architectural choice so that, six months later, when someone asks "why is the search feature in TCA but the rest of the app in MVVM?", the answer is written down instead of lost. The format (from Michael Nygard's original, lightly adapted):

```markdown
# ADR-007: Use TCA for the payment flow, MVVM elsewhere

- **Status:** Accepted (2026-06-09)
- **Deciders:** iOS team (3 engineers)

## Context

The payment flow has complex, money-touching state (plan, proration, promo,
billing-retry recovery) that several engineers will maintain for years. A wrong
state transition can double-charge a user. The rest of the app (notes list,
settings, detail editing) is single-feature, low-blast-radius UI owned by one
engineer at a time.

## Decision

Implement the **payment flow in TCA** (exhaustive `TestStore` coverage of every
state transition; `@Dependency` for the StoreKit and backend clients). Implement
**everything else in MVVM** (`@Observable` view models, injected repositories,
Swift Testing). Do **not** adopt TCA app-wide.

## Options considered

1. **TCA everywhere** — rejected: the boilerplate tax on simple screens isn't
   repaid; settings and a static About page gain nothing from a reducer.
2. **MVVM everywhere** — rejected for the payment flow: we want *proven*
   exhaustiveness on money-touching transitions, which `TestStore` gives and a
   view-model test suite does not enforce.
3. **VIPER** — rejected: solves UIKit problems SwiftUI already eliminated; pure
   ceremony here.

## Consequences

- Two architectures in one codebase; the README documents which lives where and
  why. New engineers learn the rule "money/complex → TCA, everything else → MVVM."
- The payment flow carries a third-party dependency (TCA) and a steeper learning
  curve, accepted for the testability guarantee.
- Re-evaluate if a second money-touching flow appears; the threshold for TCA is
  "complex state + high blast radius," documented here.
```

Five sections, half a page, no fluff. Why this is the senior deliverable:

- **It captures the *reasoning*, not just the choice.** Anyone can say "we use TCA here." The ADR says *why*, which is what a future maintainer needs.
- **It records the options you rejected.** "Why not TCA everywhere?" is answered in writing, so the team does not re-litigate it every quarter.
- **It has a status and a date.** Decisions expire. An ADR marked "Superseded by ADR-014" is how an architecture evolves legibly instead of drifting.
- **It is the thing you point at in code review.** When the "defend the architecture" question from this week's promise comes, you do not argue from memory — you link the ADR.

Writing one good ADR is worth more to a team than a perfect reducer, because the reducer documents *what* the code does and the ADR documents *why the code is shaped that way* — and the why is what gets lost.

---

## 7. Recap — the whole axis, and how to choose

You now have the complete architecture axis and the judgment to navigate it:

1. **The axis is structure.** Plain SwiftUI + `@Observable` (least) → MVVM → unidirectional flow → TCA (most). Moving right buys testability, predictability, and team-scaling; it costs indirection, boilerplate, and a library dependency. There is no globally correct point — only the correct point for a feature's testability need, team-and-longevity, and blast radius.

2. **TCA industrialises everything MVVM disciplined.** Value-type `State`, an `Action` enum that documents every possible event, a pure reducer, *described* `Effect`s the store runs and cancels, a first-class `@Dependency` system with live/test/preview values, and an exhaustive `TestStore` that proves every transition and effect. The trade is real code for real guarantees — a bargain for money-touching or complex flows, overkill for simple ones.

3. **VIPER solved problems SwiftUI eliminated.** Its five components and protocol-per-edge ceremony were a sound answer to the Massive View Controller, the lack of binding, and imperative navigation in 2014 UIKit. SwiftUI's declarative view, the Observation framework, and value-typed navigation each repealed one of those problems, leaving VIPER's ceremony as pure cost in new SwiftUI work.

4. **No architecture is sometimes the answer.** Settings, one-off sheets, static screens, throwaway prototypes: structure buys nothing, so don't add it. Resisting needless structure is the same judgment as adding needed structure.

5. **The ADR is the deliverable.** The half-page that records the decision, its context, the rejected options, and its consequences is what makes a team's architecture legible and defensible. Write it; link it in review; supersede it when it expires.

The exercises drill the mechanics: extract a testable view model, write a reducer and prove it with a `TestStore`, register a `@Dependency` and swap it. The challenge implements one feature on all three points of the axis and measures the difference. The mini-project builds the search-and-filter feature twice — MVVM and TCA — and asks you to write the ADR that decides what ships. Go choose, and write down why.
