// Exercise 3 — Retry with exponential backoff and full jitter
//
// Goal: Implement a retry loop that retries only RETRYABLE failures, backs off
//       exponentially with FULL JITTER, stops at an attempt cap, and respects
//       cancellation. Prove each property with deterministic tests — including
//       that jitter actually spreads the delays (so a thundering herd doesn't
//       form) and that a non-retryable error fails immediately.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Swift Testing suite. Drop into a test target (iOS 17+/macOS 14+). No package,
// no server — we drive the retry loop with an injected operation that fails a
// scripted number of times, so tests are deterministic and fast.
//
//   1. Add to a test target.
//   2. Run with Cmd-U.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] A RetryPolicy with exponential backoff and FULL jitter (random in
//       [0, capped ceiling]).
//   [ ] retry() retries a retryable error up to the cap, returns on first
//       success, and rethrows a non-retryable error IMMEDIATELY (no retries).
//   [ ] A test shows jitter produces a SPREAD of delays (not all identical).
//   [ ] A test shows cancellation stops the retry loop.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The error space (trimmed) + retryability.
// ----------------------------------------------------------------------------

enum NetworkError: Error, Equatable {
    case offline, cancelled, timedOut, transport, http(status: Int), decoding

    var isRetryable: Bool {
        switch self {
        case .timedOut, .transport:       return true
        case .http(let status):           return status == 429 || (500...599).contains(status)
        case .offline, .cancelled, .decoding: return false
        }
    }
}

// ----------------------------------------------------------------------------
// The retry policy: exponential backoff with full jitter.
// ----------------------------------------------------------------------------

struct RetryPolicy: Sendable {
    var maxAttempts = 4
    var baseDelay: Duration = .milliseconds(20)   // small so tests run fast
    var maxDelay: Duration = .milliseconds(320)

    /// Full jitter: a uniformly random delay in [0, min(maxDelay, base * 2^attempt)].
    func delay(forAttempt attempt: Int, rng: inout some RandomNumberGenerator) -> Duration {
        let ceiling = min(baseDelay * (1 << attempt), maxDelay)
        let ceilingSeconds = Double(ceiling.components.seconds)
            + Double(ceiling.components.attoseconds) / 1e18
        let jittered = Double.random(in: 0...ceilingSeconds, using: &rng)
        return .seconds(jittered)
    }
}

// ----------------------------------------------------------------------------
// The retry loop. The operation is injected so tests are deterministic.
// ----------------------------------------------------------------------------

func retry<T: Sendable>(
    policy: RetryPolicy = RetryPolicy(),
    sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 0
    var rng = SystemRandomNumberGenerator()
    while true {
        do {
            return try await operation()
        } catch let error as NetworkError {
            attempt += 1
            // Stop if not retryable OR we've used our last attempt.
            guard error.isRetryable, attempt < policy.maxAttempts else { throw error }
            let delay = policy.delay(forAttempt: attempt - 1, rng: &rng)
            try await sleep(delay)   // throws CancellationError if the task is cancelled
        }
    }
}

// ----------------------------------------------------------------------------
// A scriptable operation: fails N times, then succeeds (or always fails).
// ----------------------------------------------------------------------------

actor ScriptedOperation {
    private var calls = 0
    private let failuresBeforeSuccess: Int
    private let error: NetworkError

    init(failsTimes: Int, with error: NetworkError = .transport) {
        self.failuresBeforeSuccess = failsTimes
        self.error = error
    }

    func callCount() -> Int { calls }

    func run() async throws -> String {
        calls += 1
        if calls <= failuresBeforeSuccess { throw error }
        return "ok"
    }
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

struct RetryTests {

    @Test("succeeds after transient failures, within the cap")
    func succeedsAfterRetries() async throws {
        let op = ScriptedOperation(failsTimes: 2, with: .transport)   // fail twice, then succeed
        // No real sleeping in tests — inject a no-op sleep.
        let result = try await retry(sleep: { _ in }) { try await op.run() }
        #expect(result == "ok")
        #expect(await op.callCount() == 3)   // 2 failures + 1 success
    }

    @Test("a non-retryable error fails immediately with no retries")
    func nonRetryableFailsFast() async {
        let op = ScriptedOperation(failsTimes: 99, with: .http(status: 400))  // 400 is NOT retryable
        await #expect(throws: NetworkError.http(status: 400)) {
            try await retry(sleep: { _ in }) { try await op.run() }
        }
        #expect(await op.callCount() == 1)   // tried exactly once — no retries
    }

    @Test("gives up after maxAttempts on a persistent retryable error")
    func capsAttempts() async {
        let op = ScriptedOperation(failsTimes: 99, with: .http(status: 503))  // always 503
        let policy = RetryPolicy(maxAttempts: 4)
        await #expect(throws: NetworkError.http(status: 503)) {
            try await retry(policy: policy, sleep: { _ in }) { try await op.run() }
        }
        #expect(await op.callCount() == 4)   // exactly maxAttempts tries
    }

    @Test("full jitter spreads delays — they are not all identical")
    func jitterSpreads() {
        let policy = RetryPolicy()
        var rng = SystemRandomNumberGenerator()
        // Compute many delays for the SAME attempt; with jitter they should differ.
        let delays = (0..<50).map { _ in policy.delay(forAttempt: 2, rng: &rng) }
        let unique = Set(delays.map { $0.components.attoseconds })
        #expect(unique.count > 1)   // not all identical => jitter is working
        // And every delay is within [0, ceiling].
        let ceiling = min(policy.baseDelay * 4, policy.maxDelay)
        #expect(delays.allSatisfy { $0 <= ceiling })
    }

    @Test("cancellation stops the retry loop")
    func cancellationStops() async {
        let op = ScriptedOperation(failsTimes: 99, with: .transport)
        let task = Task {
            // A real sleep so there's a suspension point to cancel at.
            try await retry(policy: RetryPolicy(maxAttempts: 10, baseDelay: .milliseconds(50))) {
                try await op.run()
            }
        }
        try? await Task.sleep(for: .milliseconds(30))
        task.cancel()
        let result = await task.result
        // The loop should have thrown (CancellationError surfaced through sleep),
        // not run all 10 attempts.
        if case .success = result { Issue.record("expected cancellation to throw") }
        #expect(await op.callCount() < 10)
    }
}

// ----------------------------------------------------------------------------
// WHY full jitter matters (write it before reading):
//
//   With pure exponential backoff (no jitter), every client that failed at the
//   same instant retries at the SAME instant — a synchronized wave that
//   re-overwhelms a recovering server (the "thundering herd"). Full jitter picks
//   a random delay in [0, ceiling], smearing the retries across the window so the
//   server sees a trickle instead of a wave and can actually recover. The
//   jitterSpreads test proves the delays differ; at scale, that difference is the
//   difference between a server that recovers and one that keeps getting knocked
//   down.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Inject `sleep: { _ in }` (a no-op) in the timing tests so they don't
//   actually wait — you're testing retry COUNTS and error handling, not real
//   delays. Use a real sleep only in the cancellation test, where you need a
//   suspension point to cancel at.
//
// - `baseDelay * (1 << attempt)` is `base * 2^attempt`. `1 << 0 == 1`,
//   `1 << 1 == 2`, etc. Cap with `min(..., maxDelay)` before jittering.
//
// - The cap test asserts callCount == maxAttempts: attempt starts at 0, becomes
//   1..maxAttempts-1 on failures, and the guard `attempt < maxAttempts` throws
//   on the maxAttempts-th. Trace it on paper if the count is off by one.
//
// - Cancellation works because `Task.sleep(for:)` throws CancellationError when
//   the task is cancelled, which propagates out of the retry loop. If you swap
//   in a non-throwing sleep, you lose this — keep the sleep `throws`.
//
// ----------------------------------------------------------------------------
