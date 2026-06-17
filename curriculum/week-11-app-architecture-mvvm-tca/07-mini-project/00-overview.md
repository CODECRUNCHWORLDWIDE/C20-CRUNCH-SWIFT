# Mini-Project — Search-and-filter, two ways (and the ADR that decides)

This week the notes app gains a real feature — **search-and-filter** — and you build it **twice**: once as plain `@Observable` MVVM, once as a TCA reducer. Then you write the **architectural decision record** that says which one you would actually ship into Hello, Notes, and why. The code is the means; the ADR is the deliverable. The skill the syllabus names for this week is "can implement and critique three architectures; can write an ADR," and this project is where you earn it.

This is a *compounding* project. The persistence layer from Week 10 (the SwiftData `Note`/`Tag` store) stays exactly as it is. You are not rebuilding the app — you are adding one feature on top of a solid data layer, and you are doing it twice so you can *feel* the difference between the two architectures with your own hands instead of reading someone's opinion about them.

---

## Where you're starting from

Your Week 10 app has:

- A SwiftData `@Model final class Note` (and `Tag`) persisted on disk, surviving cold launch.
- A `@Query`-driven notes list inside a `NavigationSplitView`/`NavigationStack` layout.
- A tag filter (`TaggedNotesView`) using a dynamic `#Predicate`.

If you don't have a clean Week 10 checkpoint, the search-and-filter feature works against an in-memory array of `Note` too — the architecture comparison is the same either way. But ideally you wire it to the real SwiftData store so the feature is real.

## What you're building toward

The feature, identical in behaviour across both implementations:

- A **search field** that filters notes by a substring match on title or body, debounced ~300 ms so a fast typist does not fire a search per keystroke.
- A **tag filter** chip row: tap a tag to additionally constrain results to notes carrying it. Search and tag filter compose (both must match).
- A **"favorites only" toggle** that further constrains to favorited notes.
- **Loading and empty states**: a spinner while a (simulated) search runs, and a `ContentUnavailableView` when nothing matches.

You build this:

1. **As MVVM** — an `@Observable @MainActor NotesSearchModel` with an injected search dependency, a dumb view, and a Swift Testing suite.
2. **As TCA** — a `@Reducer NotesSearchFeature` with value-type state, an action enum, a `@Dependency`, a debounce effect, and a `TestStore` suite.
3. **Plus an ADR** — `ADR.md` deciding which to ship into Hello, Notes, referencing what you observed building both.

---

## Milestone 1 — The shared seam (≈ 0.5 h)

Both implementations need the *same* dependency seam so the comparison is fair: a search service abstraction. Define it once, inject it into both.

```swift
import Foundation

struct NoteHit: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let tags: [String]
    var isFavorite: Bool
}

struct NotesSearchClient: Sendable {
    /// Runs a query against the store and returns matching note hits.
    /// In the real app this wraps a SwiftData FetchDescriptor + #Predicate;
    /// for the comparison we keep it abstract so both architectures inject it.
    var search: @Sendable (_ query: String, _ tag: String?, _ favoritesOnly: Bool) async throws -> [NoteHit]
}

extension NotesSearchClient {
    static let live = NotesSearchClient { query, tag, favoritesOnly in
        // Real implementation: build a FetchDescriptor<Note> with a #Predicate
        // combining title/body contains, tag membership, and isFavorite, then
        // fetch against a background ModelContext. (Week 10 §6 + Week 13 will
        // make the async/persistence side production-grade.)
        []   // replace with the real fetch in your app target
    }

    static func stub(_ hits: [NoteHit]) -> NotesSearchClient {
        NotesSearchClient { query, tag, favoritesOnly in
            hits.filter { hit in
                let textOK = query.isEmpty
                    || hit.title.localizedStandardContains(query)
                    || hit.body.localizedStandardContains(query)
                let tagOK = tag.map { hit.tags.contains($0) } ?? true
                let favOK = !favoritesOnly || hit.isFavorite
                return textOK && tagOK && favOK
            }
        }
    }
}
```

The `stub` does the filtering in Swift so your tests are deterministic; the `live` version pushes it into SQLite via a `#Predicate` (Week 10). **Both** implementations take a `NotesSearchClient` — that is the seam, identical for both, exactly as lecture 1, §5 prescribes.

## Milestone 2 — The MVVM implementation (≈ 2.5 h)

An `@Observable @MainActor` view model owns the feature; the view is dumb; the dependency is injected.

```swift
import SwiftUI
import Observation

@Observable
@MainActor
final class NotesSearchModel {
    // Inputs the view binds to
    var query = ""
    var selectedTag: String?
    var favoritesOnly = false

    // State the view renders
    private(set) var results: [NoteHit] = []
    private(set) var isSearching = false
    private(set) var searchError: String?

    private let client: NotesSearchClient
    private var searchTask: Task<Void, Never>?

    init(client: NotesSearchClient) {
        self.client = client
    }

    /// Call when any filter input changes. Debounces, then searches.
    func filtersChanged() {
        searchTask?.cancel()                       // cancel the in-flight debounce
        searchTask = Task { [query, selectedTag, favoritesOnly] in
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            await runSearch(query: query, tag: selectedTag, favoritesOnly: favoritesOnly)
        }
    }

    private func runSearch(query: String, tag: String?, favoritesOnly: Bool) async {
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            results = try await client.search(query, tag, favoritesOnly)
        } catch {
            searchError = "Search failed: \(error.localizedDescription)"
            results = []
        }
    }
}
```

The view binds inputs and calls `filtersChanged()` on each change:

```swift
struct NotesSearchView: View {
    @State private var model: NotesSearchModel
    let allTags: [String]

    init(client: NotesSearchClient, allTags: [String]) {
        _model = State(initialValue: NotesSearchModel(client: client))
        self.allTags = allTags
    }

    var body: some View {
        List(model.results) { hit in
            VStack(alignment: .leading) {
                Text(hit.title).font(.headline)
                if !hit.tags.isEmpty {
                    Text(hit.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $model.query)
        .onChange(of: model.query) { model.filtersChanged() }
        .onChange(of: model.selectedTag) { model.filtersChanged() }
        .onChange(of: model.favoritesOnly) { model.filtersChanged() }
        .safeAreaInset(edge: .top) {
            ScrollView(.horizontal) {
                HStack {
                    Toggle("Favorites", isOn: $model.favoritesOnly).toggleStyle(.button)
                    ForEach(allTags, id: \.self) { tag in
                        Button("#\(tag)") {
                            model.selectedTag = (model.selectedTag == tag) ? nil : tag
                        }
                        .buttonStyle(.bordered)
                        .tint(model.selectedTag == tag ? .accentColor : .secondary)
                    }
                }.padding(.horizontal)
            }
        }
        .overlay {
            if model.isSearching { ProgressView() }
            else if model.results.isEmpty {
                ContentUnavailableView("No matches", systemImage: "magnifyingglass")
            }
        }
        .task { model.filtersChanged() }   // initial load
    }
}
```

Then the test suite — the whole reason you extracted the model:

```swift
import Testing

@MainActor
struct NotesSearchModelTests {
    let sample = [
        NoteHit(id: UUID(), title: "SwiftUI layout", body: "stacks", tags: ["swift"], isFavorite: true),
        NoteHit(id: UUID(), title: "Kotlin flows", body: "coroutines", tags: ["kotlin"], isFavorite: false),
        NoteHit(id: UUID(), title: "Swift actors", body: "isolation", tags: ["swift", "concurrency"], isFavorite: false),
    ]

    @Test("query filters by title/body substring")
    func queryFilters() async {
        let model = NotesSearchModel(client: .stub(sample))
        model.query = "swift"
        await model.runSearchForTest()   // expose runSearch to tests, or call filtersChanged + await
        #expect(model.results.count == 2)
    }

    @Test("tag and favorites compose with the query")
    func compose() async {
        let model = NotesSearchModel(client: .stub(sample))
        model.query = "swift"
        model.favoritesOnly = true
        await model.runSearchForTest()
        #expect(model.results.map(\.title) == ["SwiftUI layout"])
    }

    @Test("a failing client surfaces an error and clears results")
    func error() async {
        struct Boom: Error {}
        let failing = NotesSearchClient { _, _, _ in throw Boom() }
        let model = NotesSearchModel(client: failing)
        await model.runSearchForTest()
        #expect(model.searchError != nil)
        #expect(model.results.isEmpty)
    }
}
```

> Implementation note: to make `runSearch` testable without fighting the debounce timer, add a tiny `func runSearchForTest() async { await runSearch(query: query, tag: selectedTag, favoritesOnly: favoritesOnly) }` guarded by `#if DEBUG`, or make `runSearch` internal. The debounce is a UI concern; the *search logic* is what you test. This is a real MVVM trade-off — the timer is awkward to test, which is itself a data point for your ADR.

## Milestone 3 — The TCA implementation (≈ 3 h)

The same feature as a reducer. Note how the debounce, which was awkward to test in MVVM, becomes trivially testable here with `TestClock`.

```swift
import ComposableArchitecture

@Reducer
struct NotesSearchFeature {
    @ObservableState
    struct State: Equatable {
        var query = ""
        var selectedTag: String?
        var favoritesOnly = false
        var results: [NoteHit] = []
        var isSearching = false
        var searchError: String?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case filtersChangedDebounced
        case searchResponse(Result<[NoteHit], NotesSearchError>)
    }

    @Dependency(\.notesSearchClient) var client
    @Dependency(\.continuousClock) var clock
    private enum CancelID { case search }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return debounceThenSearch()

            case .binding:
                // Any filter input changed (query, tag, favoritesOnly).
                return debounceThenSearch()

            case .filtersChangedDebounced:
                state.isSearching = true
                state.searchError = nil
                let (q, tag, fav) = (state.query, state.selectedTag, state.favoritesOnly)
                return .run { send in
                    await send(.searchResponse(
                        Result { try await client.search(q, tag, fav) }
                            .mapError(NotesSearchError.init)
                    ))
                }

            case let .searchResponse(.success(hits)):
                state.isSearching = false
                state.results = hits
                return .none

            case let .searchResponse(.failure(error)):
                state.isSearching = false
                state.results = []
                state.searchError = error.message
                return .none
            }
        }
    }

    private func debounceThenSearch() -> Effect<Action> {
        .run { send in
            try await clock.sleep(for: .milliseconds(300))
            await send(.filtersChangedDebounced)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

struct NotesSearchError: Error, Equatable {
    var message: String
    init(_ error: Error) { self.message = "Search failed: \(error.localizedDescription)" }
}
```

Register the dependency (lecture 2, §2) and write the `TestStore` suite:

```swift
extension NotesSearchClient: DependencyKey {
    static let liveValue = NotesSearchClient.live
    static let testValue = NotesSearchClient(
        search: unimplemented("NotesSearchClient.search", placeholder: [])
    )
}
extension DependencyValues {
    var notesSearchClient: NotesSearchClient {
        get { self[NotesSearchClient.self] }
        set { self[NotesSearchClient.self] = newValue }
    }
}

@MainActor
struct NotesSearchFeatureTests {
    @Test("typing debounces, searches, and populates results")
    func searchFlow() async {
        let clock = TestClock()
        let store = TestStore(initialState: NotesSearchFeature.State()) {
            NotesSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.notesSearchClient.search = { q, _, _ in
                #expect(q == "swift")
                return [NoteHit(id: UUID(0), title: "SwiftUI", body: "", tags: ["swift"], isFavorite: false)]
            }
        }

        await store.send(\.binding.query, "swift") { $0.query = "swift" }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.filtersChangedDebounced) { $0.isSearching = true }
        await store.receive(\.searchResponse.success) {
            $0.isSearching = false
            $0.results = [NoteHit(id: UUID(0), title: "SwiftUI", body: "", tags: ["swift"], isFavorite: false)]
        }
    }
}
```

Notice: the 300 ms debounce that fought your MVVM test is here an exact, instantaneous `clock.advance(by:)`, and the exhaustive `TestStore` *forces* you to assert `isSearching` flipping on then off — a transition the MVVM suite could silently skip. **Write down that observation; it goes straight into the ADR.**

## Milestone 4 — Wire one of them into the app (≈ 1.5 h)

Pick one implementation and actually wire it into Hello, Notes against the real SwiftData store (implement `NotesSearchClient.live` with a real `FetchDescriptor` + `#Predicate`). The *other* implementation stays as a parallel, tested module you can point at. You ship one; you keep both as evidence.

## Milestone 5 — The ADR (≈ 1 h)

This is the graded deliverable. Write `ADR.md` using the five-section format from lecture 2, §6:

- **Status / deciders / date.**
- **Context** — what Hello, Notes is, its team size (you, for now, but write as if a small team), its longevity (it grows through Phase II and IV), and the blast radius of this feature (low — a wrong search result is cosmetic, not a money bug).
- **Decision** — which architecture you shipped this feature in, stated plainly.
- **Options considered** — plain SwiftUI (rejected: there's real testable logic here — debounce, compose, error), MVVM, and TCA, each with the *observation you made building it* (the debounce was awkward to test in MVVM; TCA's exhaustivity caught a transition you'd skip; TCA was ~Nx the lines).
- **Consequences** — what shipping this choice commits you to (e.g. "if we adopt TCA here we should adopt it for the rest of Notes for consistency, OR document why this one feature differs").

Run the three questions (lecture 1, §1) explicitly in the ADR. For Hello, Notes specifically, the honest answer is debatable — and *that is the point.* A feature with real-but-low-stakes logic is exactly the case where reasonable engineers differ, so your ADR must *argue*, not assert.

---

## Acceptance criteria

- [ ] One `NotesSearchClient` seam, injected identically into **both** implementations.
- [ ] An **MVVM** implementation: `@Observable @MainActor` model, injected client, dumb view, and a Swift Testing suite proving query/tag/favorites compose and that errors surface.
- [ ] A **TCA** implementation: `@Reducer` with value-type state, an action enum, a `@Dependency`, a `.cancellable` debounce effect, and a `TestStore` suite that exhaustively asserts the search flow including the `isSearching` transitions, using a `TestClock` for the debounce.
- [ ] One implementation **wired into the real app** against the SwiftData store via a `#Predicate`-backed `live` client.
- [ ] An **`ADR.md`** in the five-section format that decides which to ship, runs the three questions explicitly, references concrete observations from building both (not vibes), names rejected options, and states consequences.
- [ ] Both implementations build with **0 warnings, 0 errors**, including Swift 6 strict concurrency.

## Stretch goals

- **Make the MVVM debounce testable.** Inject a clock into the MVVM model too (a `ContinuousClock`-shaped dependency) so its debounce becomes as testable as TCA's. Note in the ADR that this *narrows* the gap — MVVM can have controllable time, it just doesn't give it to you for free.
- **Add the tag filter to the reducer's navigation.** Push `TaggedNotesView` (Week 10) from a tag chip using the value-typed `NavigationStack` (Week 9). Keep navigation *out* of the reducer for now (TCA navigation is a Phase IV topic) and note that boundary in the ADR.
- **Property-test the compose logic.** Generate random `(query, tag, favoritesOnly)` triples and assert the MVVM and TCA results agree with a reference filter — proving the two architectures implement the *same* feature, which is the premise of the whole comparison.

## What this milestone earns you

You implemented the same feature in two architectures, felt with your own hands what each cost and bought (the debounce test gap, the exhaustivity, the line count), and wrote the ADR that turns that experience into a defensible, legible decision. That is the literal "skill earned" for the week: implement and critique architectures, and write an ADR. More than that — you now have a concrete, portfolio-grade artifact for the "what architecture do you prefer?" interview question, and the answer is no longer a preference. It is a measured trade for a stated context, written down. Week 12 takes the debounce you built here twice and goes one level deeper: Combine vs `async`/`await` vs `AsyncStream`, the reactive machinery underneath the effects.
