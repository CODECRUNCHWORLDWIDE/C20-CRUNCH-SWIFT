// Exercise 3 — TCA dependency injection, time, and determinism
//
// Goal: Register a real @Dependency with liveValue / testValue / previewValue,
//       use TWO library-provided dependencies (continuousClock and uuid) inside
//       a reducer's effect, and override all of them in a TestStore so an effect
//       that involves a network call, a 500 ms debounce, and a random UUID
//       becomes fully deterministic and provable. This is lecture 2, §2 and §3.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// 1. Requires the swift-composable-architecture package (added in exercise 2).
// 2. Swift Testing suite + the feature it tests. Drop into a test target that
//    links ComposableArchitecture, or split feature/app and tests/test target.
// 3. Run with Cmd-U.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] A custom @Dependency (TodoClient) with liveValue, an UNIMPLEMENTED
//       testValue, and a previewValue.
//   [ ] The reducer uses @Dependency(\.continuousClock) for a debounce and
//       @Dependency(\.uuid) to stamp new items.
//   [ ] A TestStore test uses TestClock to advance past the debounce and an
//       incrementing UUID so the asserted ids are deterministic.
//   [ ] You can explain why injecting the clock and uuid is what makes the test
//       NOT flaky (no real sleep, no random id).
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import ComposableArchitecture
import Foundation
import Testing

// ----------------------------------------------------------------------------
// A small todo feature: type a title (debounced), and "save" creates a Todo
// with a fresh UUID via a client. Three dependencies in play:
//   - continuousClock : library-provided, for the debounce
//   - uuid            : library-provided, for the new item's id
//   - todoClient      : OUR dependency, for the save side effect
// ----------------------------------------------------------------------------

struct Todo: Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
}

@Reducer
struct TodoFeature {
    @ObservableState
    struct State: Equatable {
        var draft = ""
        var todos: [Todo] = []
        var isSaving = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case draftSettled
        case saveTapped
        case saveResponse(Todo)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid
    @Dependency(\.todoClient) var todoClient

    private enum CancelID { case debounce }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.draft):
                // Debounce 500 ms after the last keystroke before "settling".
                return .run { send in
                    try await clock.sleep(for: .milliseconds(500))
                    await send(.draftSettled)
                }
                .cancellable(id: CancelID.debounce, cancelInFlight: true)

            case .binding:
                return .none

            case .draftSettled:
                // (In a real app you might validate here; we just leave a hook.)
                return .none

            case .saveTapped:
                guard !state.draft.isEmpty else { return .none }
                state.isSaving = true
                let todo = Todo(id: uuid(), title: state.draft)   // injected uuid
                return .run { send in
                    let saved = try await todoClient.save(todo)
                    await send(.saveResponse(saved))
                }

            case let .saveResponse(todo):
                state.isSaving = false
                state.todos.append(todo)
                state.draft = ""
                return .none
            }
        }
    }
}

// ----------------------------------------------------------------------------
// Our custom dependency, with all three canonical values.
// ----------------------------------------------------------------------------

struct TodoClient: Sendable {
    var save: @Sendable (_ todo: Todo) async throws -> Todo
}

extension TodoClient: DependencyKey {
    // Production: would POST to the backend and return the server's copy.
    static let liveValue = Self(
        save: { todo in
            // Real implementation would call URLSession (Week 13). Echo for now.
            todo
        }
    )

    // Tests: unimplemented, so a forgotten override fails loudly.
    static let testValue = Self(
        save: unimplemented("TodoClient.save", placeholder: Todo(id: UUID(), title: ""))
    )

    // Previews: cheap fake so SwiftUI previews "work" without a backend.
    static let previewValue = Self(
        save: { $0 }
    )
}

extension DependencyValues {
    var todoClient: TodoClient {
        get { self[TodoClient.self] }
        set { self[TodoClient.self] = newValue }
    }
}

// ----------------------------------------------------------------------------
// The deterministic test: TestClock + incrementing UUID + stubbed client.
// ----------------------------------------------------------------------------

@MainActor
struct TodoFeatureTests {

    @Test("typing debounces exactly 500 ms before settling")
    func debounce() async {
        let clock = TestClock()
        let store = TestStore(initialState: TodoFeature.State()) {
            TodoFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .incrementing
        }

        // Type three characters quickly. Each schedules a debounce effect and
        // cancels the previous (cancelInFlight: true), so only the LAST settles.
        await store.send(\.binding.draft, "b") { $0.draft = "b" }
        await store.send(\.binding.draft, "bu") { $0.draft = "bu" }
        await store.send(\.binding.draft, "buy") { $0.draft = "buy" }

        // Nothing has settled yet — the 500 ms hasn't elapsed. Advance time.
        await clock.advance(by: .milliseconds(500))

        // Exactly one settle fires (the others were cancelled). No state change.
        await store.receive(\.draftSettled)
    }

    @Test("saving stamps a deterministic UUID and appends the todo")
    func save() async {
        let store = TestStore(initialState: TodoFeature.State(draft: "Milk")) {
            TodoFeature()
        } withDependencies: {
            $0.uuid = .incrementing           // 0000...0000, 0000...0001, ...
            $0.todoClient.save = { todo in
                // The client echoes; assert it received the right todo.
                #expect(todo.title == "Milk")
                return todo
            }
        }

        // .incrementing produces this exact UUID for the first call:
        let expectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(\.saveResponse) {
            $0.isSaving = false
            $0.todos = [Todo(id: expectedID, title: "Milk")]
            $0.draft = ""
        }
    }

    @Test("an empty draft does not save")
    func emptyDraftNoOp() async {
        let store = TestStore(initialState: TodoFeature.State(draft: "")) {
            TodoFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            // NOTE: we deliberately do NOT override todoClient.save. If the
            // reducer wrongly tried to save an empty draft, the unimplemented
            // testValue would fail the test — proving the guard works.
        }

        await store.send(.saveTapped)   // no state change, no effect, no save call
    }
}

// ----------------------------------------------------------------------------
// WHY injection makes this non-flaky (write it before reading):
//
//   With the REAL clock, the debounce test would have to actually wait 500 ms of
//   wall time and could flake under load. With TestClock, "advance by 500 ms" is
//   instantaneous and exact. With the REAL UUID() the saved id would be random
//   and un-assertable; with `.incrementing` it is 0000...0000 every run, so the
//   assertion is stable. And because todoClient's testValue is `unimplemented`,
//   the empty-draft test PROVES no save happens — a real save call would fail
//   the test. Determinism in tests comes from injecting time, identity, and I/O.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `$0.uuid = .incrementing` is a library-provided generator that yields
//   sequential UUIDs starting at all-zeros. `UUID(0)` is a shorthand the library
//   also offers in some versions; the uuidString form above is always valid.
//
// - `await clock.advance(by:)` must be `await`ed; it lets scheduled clock work
//   run. Forgetting the advance leaves the debounce effect pending and the test
//   fails with "an effect is still in flight."
//
// - The empty-draft test passing WITHOUT overriding todoClient.save is the
//   point: the guard returns `.none` before any effect, so save is never called.
//   If you remove the `guard`, the test fails on the unimplemented save.
//
// - `BindableAction` + `BindingReducer()` are what turn `$store.draft` edits
//   into `.binding(\.draft)` actions. Without `BindingReducer()` in the body,
//   the binding action never updates state.
//
// ----------------------------------------------------------------------------
