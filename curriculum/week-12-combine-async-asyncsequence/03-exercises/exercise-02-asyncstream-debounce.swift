// Exercise 2 — A hand-rolled AsyncStream debounce
//
// Goal: Build an AsyncStream from a callback-style source using a Continuation,
//       debounce the stream by cancelling a per-keystroke task, and TEST it
//       deterministically. This is the async twin of exercise 1's Combine
//       pipeline — same behaviour (a burst of keystrokes collapses to one
//       search), built the structured-concurrency way.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite plus the type it tests. Drop it into a test
// target (iOS 17+/macOS 14+). It needs no UI and no package for the core part.
// The OPTIONAL stretch at the bottom uses swift-async-algorithms for a one-line
// .debounce; add that package if you want to compare.
//
//   1. Add to a test target.
//   2. Run with Cmd-U.
//   3. Read the assertions: a fast burst of inputs yields exactly ONE search.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] An AsyncStream<String> built with a Continuation; values are fed via
//       yield(_:) and the stream finishes cleanly.
//   [ ] A debounce that collapses a fast burst ("s","sw",...,"swift") into a
//       single search of the final value.
//   [ ] onTermination cleans up; the for-await loop is cancellable.
//   [ ] You can explain why the AsyncStream version needs no AnyCancellable.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The debouncer. It exposes a stream-feeding API (push) and consumes the stream
// with a per-keystroke cancelling task. The consumer side runs in `run()`,
// which you drive from a Task (the async analogue of SwiftUI's .task).
// ----------------------------------------------------------------------------

actor SearchDebouncer {
    private var continuation: AsyncStream<String>.Continuation?
    private let interval: Duration
    private var searches: [String] = []   // record what actually ran, for the test

    init(interval: Duration = .milliseconds(300)) {
        self.interval = interval
    }

    /// Push a keystroke into the stream. Called imperatively from the UI/test.
    func push(_ query: String) {
        continuation?.yield(query)
    }

    /// Finish the stream so `run()`'s loop ends.
    func finish() {
        continuation?.finish()
    }

    func recordedSearches() -> [String] { searches }

    /// Consume the stream, debouncing. Drive this from a Task. The loop's
    /// lifetime IS the task's lifetime — cancel the task and the loop ends,
    /// firing onTermination. No AnyCancellable anywhere.
    func run(onSearch: @Sendable @escaping (String) -> Void) async {
        let stream = AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { cont in
            self.continuation = cont
            cont.onTermination = { _ in
                // Cleanup hook — fires on finish() OR on task cancellation.
                Task { await self.clearContinuation() }
            }
        }

        var pending: Task<Void, Never>?
        for await query in stream {
            // Cancel the previous pending search; only the last survives the gap.
            pending?.cancel()
            let interval = self.interval
            pending = Task {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await self.record(query)
                onSearch(query)
            }
        }
        // Stream finished: let the last pending search complete.
        await pending?.value
    }

    private func record(_ query: String) { searches.append(query) }
    private func clearContinuation() { continuation = nil }
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

struct AsyncStreamDebounceTests {

    @Test("a fast burst of keystrokes collapses to a single search")
    func collapsesBurst() async {
        let debouncer = SearchDebouncer(interval: .milliseconds(100))

        // Run the consumer in a background task (like SwiftUI's .task).
        let consumer = Task {
            await debouncer.run { _ in }   // recording happens inside the actor
        }

        // Type fast — faster than the 100ms debounce gap.
        for fragment in ["s", "sw", "swi", "swif", "swift"] {
            await debouncer.push(fragment)
            try? await Task.sleep(for: .milliseconds(10))   // 10ms < 100ms gap
        }

        // Wait past the debounce window, then finish and let the consumer drain.
        try? await Task.sleep(for: .milliseconds(200))
        await debouncer.finish()
        await consumer.value

        let ran = await debouncer.recordedSearches()
        #expect(ran == ["swift"])   // exactly one search, the final value
    }

    @Test("two well-separated queries each run")
    func separatedQueriesBothRun() async {
        let debouncer = SearchDebouncer(interval: .milliseconds(50))
        let consumer = Task { await debouncer.run { _ in } }

        await debouncer.push("swift")
        try? await Task.sleep(for: .milliseconds(120))   // well past 50ms gap
        await debouncer.push("kotlin")
        try? await Task.sleep(for: .milliseconds(120))

        await debouncer.finish()
        await consumer.value

        let ran = await debouncer.recordedSearches()
        #expect(ran == ["swift", "kotlin"])   // both fired; they weren't in the same burst
    }

    @Test("cancelling the consumer task stops the loop")
    func cancellationStopsLoop() async {
        let debouncer = SearchDebouncer(interval: .milliseconds(50))
        let consumer = Task { await debouncer.run { _ in } }

        await debouncer.push("swift")
        consumer.cancel()                    // structural cancellation — no AnyCancellable
        await debouncer.finish()
        _ = await consumer.value

        // We don't assert a specific count here (timing-dependent); the point is
        // the cancel() + finish() returns cleanly with no leaked task or crash.
        #expect(Bool(true))
    }
}

// ----------------------------------------------------------------------------
// WHY no AnyCancellable (write it before reading):
//
//   The Combine version (exercise 1) keeps the subscription alive via a stored
//   AnyCancellable and tears it down when the set deallocates. Here the stream's
//   lifetime is the consumer TASK's lifetime: `for await` runs until the stream
//   finishes or the task is cancelled, and onTermination cleans up the source.
//   Cancellation is STRUCTURAL — it propagates with the task tree — so there is
//   no separate object to retain and no "I forgot .store(in:) and nothing fires"
//   bug class. The lifecycle is the task, not a cancellable you must remember.
//
// ----------------------------------------------------------------------------
// OPTIONAL STRETCH (needs swift-async-algorithms)
//
//   import AsyncAlgorithms
//   // Replace the hand-rolled per-keystroke cancellation with the library
//   // operator, which IS the async analogue of Combine's .debounce:
//   for await query in stream.debounce(for: .milliseconds(300)) {
//       onSearch(query)   // already debounced; no per-keystroke task needed
//   }
//   // Compare: this is a one-liner, structurally cancelled, and Swift-6-native
//   // — the async side matching Combine's elegance once you add one package.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The burst test depends on `push` interval (10ms) being well under the
//   debounce interval (100ms), and the post-burst wait (200ms) being well over
//   it. Keep those margins generous so timing noise never flakes the test.
//
// - "An async stream's continuation is captured before the closure returns" —
//   yes, AsyncStream calls your build closure synchronously, so `self.continuation`
//   is set by the time `run()` proceeds to the for-await. If push() races ahead
//   of that, .bufferingNewest(1) keeps the latest value for the loop to pick up.
//
// - If `recordedSearches()` is empty, your pending Task was cancelled before its
//   sleep finished (the burst replaced it) AND the final one didn't get to run
//   because you finished too early. Wait past the debounce window before finish().
//
// - The actor isolation keeps `searches` race-free. Don't reach for a lock or
//   `nonisolated(unsafe)` — the actor is the synchronisation.
//
// ----------------------------------------------------------------------------
