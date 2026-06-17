// Exercise 3 — Bridge a Combine publisher into async, consume it in a .task
//
// Goal: Take a framework-style Combine publisher and consume it the ASYNC way
//       via `for await publisher.values`, prove the loop is cancelled
//       STRUCTURALLY when its task is cancelled, and (the other direction) wrap
//       async work in a Future when a Combine API demands a publisher. This is
//       lecture 2, §4 — the two-way bridge — made concrete and tested.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// Swift Testing suite. Drop into a test target (iOS 17+/macOS 14+). Combine and
// the concurrency runtime ship with the SDK — no package needed.
//
//   1. Add to a test target.
//   2. Run with Cmd-U.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] A Combine publisher consumed via `for await publisher.values`.
//   [ ] A test proving the for-await loop ends when its Task is cancelled (no
//       AnyCancellable involved).
//   [ ] A `Future` wrapping async work, consumed by a Combine `.sink`, in a test
//       that proves the value arrives.
//   [ ] You can explain why `.values` frees you from framework-Combine forcing
//       app-Combine.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Combine
import Foundation
import Testing

// ----------------------------------------------------------------------------
// Part A — Combine -> async. Consume a publisher's `.values` AsyncSequence.
// ----------------------------------------------------------------------------

@MainActor
struct CombineToAsyncBridgeTests {

    @Test("a PassthroughSubject is consumed via for-await publisher.values")
    func consumeValues() async {
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []

        // Consume the publisher the ASYNC way. The loop runs in this task.
        let consumer = Task {
            for await value in subject.values {
                received.append(value)
                if value == 3 { break }   // stop after we've seen 3
            }
        }

        // Give the consumer a tick to subscribe, then emit.
        try? await Task.sleep(for: .milliseconds(20))
        subject.send(1)
        subject.send(2)
        subject.send(3)

        await consumer.value
        #expect(received == [1, 2, 3])
    }

    @Test("cancelling the consuming task ends the for-await loop structurally")
    func cancellationEndsLoop() async {
        let subject = PassthroughSubject<Int, Never>()
        let finished = expectationBox()

        let consumer = Task {
            for await _ in subject.values {
                // keep consuming until cancelled
            }
            await finished.fulfill()   // reached only when the loop ends
        }

        try? await Task.sleep(for: .milliseconds(20))
        subject.send(42)
        try? await Task.sleep(for: .milliseconds(20))

        // Structural cancellation: cancel the TASK, the for-await loop ends.
        // No AnyCancellable, no .store(in:), no manual teardown.
        consumer.cancel()
        await consumer.value

        #expect(await finished.wasFulfilled)
    }
}

/// A tiny actor to record "did the loop finish" without a shared mutable race.
actor expectationBox {
    private(set) var wasFulfilled = false
    func fulfill() { wasFulfilled = true }
}

// ----------------------------------------------------------------------------
// Part B — async -> Combine. Wrap async work in a Future for a Combine API.
// ----------------------------------------------------------------------------

/// Pretend async work (e.g. a fetch). In real code this is `await fetchUser()`.
func asyncDouble(_ n: Int) async throws -> Int {
    try await Task.sleep(for: .milliseconds(10))
    return n * 2
}

/// Adapt the async function into a publisher, for a Combine-shaped consumer.
func doublePublisher(_ n: Int) -> AnyPublisher<Int, Error> {
    Future { promise in
        Task {
            do { promise(.success(try await asyncDouble(n))) }
            catch { promise(.failure(error)) }
        }
    }
    .eraseToAnyPublisher()
}

struct AsyncToCombineBridgeTests {

    @Test("a Future wraps async work and delivers via sink")
    func futureDelivers() async {
        var cancellables = Set<AnyCancellable>()
        let result = ResultBox()

        doublePublisher(21)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in Task { await result.set(value) } }
            )
            .store(in: &cancellables)

        // Wait for the async work + delivery.
        try? await Task.sleep(for: .milliseconds(60))
        #expect(await result.value == 42)
    }
}

actor ResultBox {
    private(set) var value: Int?
    func set(_ v: Int) { value = v }
}

// ----------------------------------------------------------------------------
// WHY `.values` matters (write it before reading):
//
//   Framework APIs hand you Combine publishers — Timer.publish,
//   NotificationCenter.publisher, URLSession.dataTaskPublisher, @Published. You
//   used to be forced to consume them WITH Combine (sink + AnyCancellable),
//   which dragged Combine's lifecycle into your code. `publisher.values` exposes
//   ANY publisher as an AsyncSequence, so you consume the framework's Combine
//   API inside a `for await` loop with structural cancellation and zero
//   AnyCancellable. "Combine in the SDK" no longer means "Combine in your app."
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `subject.values` only yields values sent AFTER the for-await loop has begun
//   iterating (a PassthroughSubject has no replay). That's why the tests sleep
//   ~20ms before `send` — to let the consumer task subscribe first.
//
// - In Part A's cancellation test, the loop body never breaks on its own; only
//   `consumer.cancel()` ends it. If the test hangs, you forgot the cancel() or
//   awaited `consumer.value` before cancelling.
//
// - `Future`'s closure runs ONCE and must call `promise` exactly once. Calling
//   it twice or never is a bug; the `do/catch` ensures exactly one call.
//
// - Strict-concurrency warnings about mutable captures in the sink closure are
//   why we funnel results through an `actor` (ResultBox / expectationBox)
//   instead of a `var` captured by reference. Don't reach for nonisolated(unsafe).
//
// ----------------------------------------------------------------------------
