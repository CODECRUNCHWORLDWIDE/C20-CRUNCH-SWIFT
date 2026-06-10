// Exercise 2 — A TCA reducer and an exhaustive TestStore
//
// Goal: Write a small but real TCA feature — a counter with a "load fact"
//       effect — as a @Reducer with value-type State, an Action enum, a Reduce
//       body, and an Effect. Then prove the ENTIRE flow with a TestStore that
//       asserts every state change and receives every effect. Exhaustivity is
//       the point: if you forget a field or an effect, the test fails.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// 1. Add the package: File ▸ Add Package Dependencies ▸
//    https://github.com/pointfreeco/swift-composable-architecture  (1.x line).
// 2. This file is a SWIFT TESTING suite plus the feature it tests. Drop it into
//    a test target that links ComposableArchitecture, or split the feature into
//    the app target and the tests into the test target — either builds.
// 3. Run with Cmd-U. Read the TestStore failures carefully: TCA prints a diff of
//    expected-vs-actual state, which is the best teaching tool in the framework.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] The reducer has value-type State, an Action enum, and at least one
//       Effect returned from .run.
//   [ ] All TestStore tests pass, and each asserts the FULL state change for
//       every action it sends or receives (exhaustive — no un-asserted field).
//   [ ] You can explain, in one sentence, why the test FAILS if you delete one
//       of the `$0.count = ...` mutations from an assertion.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import ComposableArchitecture
import Foundation
import Testing

// ----------------------------------------------------------------------------
// The feature under test: a counter that can also fetch a "number fact".
// ----------------------------------------------------------------------------

@Reducer
struct CounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
        var fact: String?
        var isLoadingFact = false
    }

    enum Action: Equatable {
        case incrementTapped
        case decrementTapped
        case factButtonTapped
        case factResponse(String)
    }

    // A small injected dependency so the effect is deterministic in tests.
    // (Exercise 3 goes deep on dependencies; here we use a simple client.)
    @Dependency(\.factClient) var factClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .incrementTapped:
                state.count += 1
                return .none

            case .decrementTapped:
                state.count -= 1
                return .none

            case .factButtonTapped:
                state.isLoadingFact = true
                state.fact = nil
                let number = state.count
                return .run { send in
                    let fact = try await factClient.fact(for: number)
                    await send(.factResponse(fact))
                }

            case let .factResponse(fact):
                state.isLoadingFact = false
                state.fact = fact
                return .none
            }
        }
    }
}

// ----------------------------------------------------------------------------
// The dependency the effect calls. Registered as a TCA @Dependency so a test
// can override it. (Exercise 3 explains live/test/preview values in full.)
// ----------------------------------------------------------------------------

struct FactClient: Sendable {
    var fact: @Sendable (_ number: Int) async throws -> String
}

extension FactClient: DependencyKey {
    // The live value would hit a real "numbers" API; here it's a local stub so
    // the exercise needs no network. Exercise 3 swaps this for a real call shape.
    static let liveValue = Self(
        fact: { number in "\(number) is a number with interesting properties." }
    )
    // Unimplemented by default: an unexpected call in a test fails loudly.
    static let testValue = Self(
        fact: unimplemented("FactClient.fact", placeholder: "")
    )
}

extension DependencyValues {
    var factClient: FactClient {
        get { self[FactClient.self] }
        set { self[FactClient.self] = newValue }
    }
}

// ----------------------------------------------------------------------------
// The exhaustive TestStore suite.
// ----------------------------------------------------------------------------

@MainActor
struct CounterFeatureTests {

    @Test("incrementing and decrementing mutate count exactly")
    func incrementDecrement() async {
        let store = TestStore(initialState: CounterFeature.State()) {
            CounterFeature()
        }

        // Each send declares the EXACT state change. If count didn't become 1,
        // or some other field changed unexpectedly, this fails with a diff.
        await store.send(.incrementTapped) { $0.count = 1 }
        await store.send(.incrementTapped) { $0.count = 2 }
        await store.send(.decrementTapped) { $0.count = 1 }
    }

    @Test("tapping fact loads, then receives the response")
    func loadFact() async {
        let store = TestStore(initialState: CounterFeature.State(count: 7)) {
            CounterFeature()
        } withDependencies: {
            // Override the (unimplemented) testValue with a deterministic stub.
            $0.factClient.fact = { number in
                #expect(number == 7)               // the effect was called with the right input
                return "7 is the response."
            }
        }

        // The tap sets the loading flag and clears any old fact, AND schedules
        // an effect. We assert the immediate state change here.
        await store.send(.factButtonTapped) {
            $0.isLoadingFact = true
            $0.fact = nil
        }

        // The effect completed and sent .factResponse back. We MUST receive it
        // (or the store fails with "an effect is still in flight") and declare
        // the state change it causes.
        await store.receive(\.factResponse) {
            $0.isLoadingFact = false
            $0.fact = "7 is the response."
        }
    }

    @Test("count is captured at tap time, not response time")
    func countCapturedAtTap() async {
        let store = TestStore(initialState: CounterFeature.State(count: 3)) {
            CounterFeature()
        } withDependencies: {
            $0.factClient.fact = { number in "fact for \(number)" }
        }

        await store.send(.factButtonTapped) {
            $0.isLoadingFact = true
            $0.fact = nil
        }
        // Even if the user incremented after tapping, the effect used the count
        // captured at tap (3), because the reducer read `state.count` into a
        // local `let number` before returning the effect.
        await store.receive(\.factResponse) {
            $0.isLoadingFact = false
            $0.fact = "fact for 3"
        }
    }
}

// ----------------------------------------------------------------------------
// WHY exhaustivity matters (write it before reading):
//
//   A TestStore assertion must account for the WHOLE state change of each
//   action. If you delete `$0.count = 1` from the first send, the test fails:
//   "expected count to stay 0 but it became 1." You cannot accidentally leave a
//   state change un-asserted, and every effect you fire must be `receive`d or
//   the store fails with "an effect is still in flight." The test is a complete,
//   executable specification — there is no "some other field also changed and I
//   didn't notice" bug class.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `store.send(\.binding...)` is for bound fields; plain actions use
//   `store.send(.incrementTapped)`. The `\.factResponse` in `receive` is a
//   case-path key path to the enum case (the @Reducer macro generates these).
//
// - "An effect is still in flight" at the end of a test means you fired an
//   effect (a `.run`) and didn't `await store.receive(...)` the action it sent
//   back. Add the matching receive.
//
// - If `receive` reports a different value than you asserted, TCA prints a diff.
//   The actual value is what the effect produced; fix your assertion to match,
//   or fix the reducer/stub if the value is genuinely wrong.
//
// - The whole suite is `@MainActor` because Store/TestStore are main-actor
//   bound. Don't `Task.detached` inside a test.
//
// - `unimplemented(...)` as the testValue is deliberate: if a test forgets to
//   override `factClient`, the test fails the instant the effect calls it —
//   surfacing an unexpected dependency instead of silently passing.
//
// ----------------------------------------------------------------------------
