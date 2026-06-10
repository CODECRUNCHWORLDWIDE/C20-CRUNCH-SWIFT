# Challenge 1 — Debounce two ways, measured (and the decision note)

**Time.** 90–120 minutes.
**Deliverable.** Two debounce implementations in a `DebounceTwoWays` repo, a `MEASURE.md` with the search-count and latency numbers, and a `DECISION.md` that picks one for "Notes v1" with the reason. Committed.

## The premise

"Combine or async/await?" is the most common Apple-platform reactive interview question, and the weak answer is a preference. The strong answer is: *here is the same feature built both ways, here is what each one actually did under load, and here is why I shipped one.* The skill this challenge builds is turning the lecture 2 decision matrix from something you memorised into something you *measured* — because a debounce that fires five searches when it should fire one is a real bug, and proving your implementation fires exactly one is a real test.

You will build search-as-you-type debounce twice, instrument both, and decide.

## The feature (identical across both)

A search input that, for a *burst* of fast keystrokes, runs the search **once** with the final value, ~300 ms after the user stops typing. Both implementations expose the same surface so you can test them identically:

```swift
protocol DebouncedSearch {
    /// Push a keystroke. A burst should collapse to one search.
    func type(_ query: String) async

    /// Stop the input (finish the stream / tear down the pipeline).
    func stop() async

    /// The searches that ACTUALLY ran, in order. The measurement target.
    func searchesRun() async -> [String]
}

/// The "search" both implementations call — records and timestamps each run.
actor SearchRecorder {
    struct Run: Sendable { let query: String; let at: ContinuousClock.Instant }
    private(set) var runs: [Run] = []
    private let clock = ContinuousClock()
    func record(_ query: String) { runs.append(Run(query: query, at: clock.now)) }
}
```

### Implementation A — Combine

A `PassthroughSubject<String, Never>` driven by `type(_:)`, a pipeline of `.debounce(for: .milliseconds(300), scheduler:)` → `.removeDuplicates()` → `.sink { recorder.record($0) }`, with the `AnyCancellable` stored. `stop()` sends `.send(completion: .finished)` or cancels the cancellable.

### Implementation B — AsyncStream

An `AsyncStream<String>` with `.bufferingNewest(1)`, fed via `type(_:)` calling `continuation.yield`, consumed in a `for await` loop that debounces by cancelling a per-keystroke `Task` (exercise 2's pattern) before recording. `stop()` calls `continuation.finish()`.

> Optional third implementation: `swift-async-algorithms`' `.debounce(for:)` as a one-line async debounce, so you can compare the *ergonomics* of the hand-rolled async version against the library one.

## What to measure

Record all of this in `MEASURE.md`.

### 1. Searches fired for a fast burst

Simulate a typist: `type("s")`, `type("sw")`, ..., `type("swift")`, each 20 ms apart (well under the 300 ms debounce). Then wait past the window and `stop()`. Assert:

```swift
let ran = await impl.searchesRun()
#expect(ran == ["swift"])   // EXACTLY one search, not five
```

Do this for **both** implementations. They must agree. A version that fires more than one search for an in-burst typist has a broken debounce — that is the bug the measurement catches.

### 2. Searches fired for separated queries

`type("swift")`, wait 400 ms, `type("kotlin")`, wait 400 ms, `stop()`. Both should run `["swift", "kotlin"]` — two searches, because they were *not* in the same burst. This proves the debounce collapses bursts without swallowing genuinely-distinct queries.

### 3. Keystroke → search latency

Using the `SearchRecorder`'s timestamps, measure the gap between the *last* keystroke of a burst and when the search actually ran. It should be ≈ the debounce interval (300 ms), for both. Record the measured latency for each implementation and note any difference (there usually isn't much; that's a finding too).

### 4. Behaviour under a "stuck finger" (stress)

Send 500 keystrokes 1 ms apart (faster than any human, simulating a paste-into-field or a UI test hammering). Both should still run **one** search at the end. This is the back-pressure test: the `.bufferingNewest(1)` async version drops intermediate keystrokes structurally; the Combine `debounce` collapses them. Confirm neither fires a search per keystroke and neither grows memory unboundedly. Note in `MEASURE.md` which buffering/operator behaviour made this safe.

## The decision note

Write `DECISION.md`. Using your measurements and the lecture 2 matrix, decide which implementation you would ship into "Notes v1" and why. It must:

- State the decision plainly (which one ships).
- Reference the **numbers** (search counts, latency), not vibes.
- Name the *qualitative* trade you observed: Combine's `.debounce` was fewer lines; the `AsyncStream` version had structural cancellation and no `AnyCancellable`; the async-algorithms version (if you did it) matched Combine's brevity.
- Tie it to the 2026 default: new code is async-first, and "Notes v1" is new code. State whether that default decided it, or whether a measurement overrode it.
- Note one context where you'd choose the *other* tool (e.g. "if Notes v1 were an existing Combine codebase, I'd match it").

## Acceptance criteria

- [ ] Two implementations (Combine and `AsyncStream`) conforming to the same `DebouncedSearch` surface, both behaving identically.
- [ ] A test/harness proving each fires **exactly one** search for an in-burst typist and **two** for separated queries.
- [ ] `MEASURE.md` records: burst search count, separated search count, keystroke→search latency for each, and the stress-test (500 keystrokes → one search) result with the back-pressure explanation.
- [ ] `DECISION.md` picks one for "Notes v1", references the numbers, names the qualitative trade, ties to the async-first default, and names a context that would flip the choice.
- [ ] Everything builds with **0 warnings**, including Swift 6 strict concurrency.

## What "great" looks like

A weak submission says "async/await is more modern so I used it." A great submission says:

> Both implementations fired exactly one search for a five-keystroke burst (20 ms apart) and two for queries separated by 400 ms, with keystroke→search latency of 304 ms (Combine) and 301 ms (AsyncStream) — within noise. Under the 500-keystroke 1 ms stress test, both fired one search; the Combine `.debounce` collapsed the burst, and the `AsyncStream(.bufferingNewest(1))` dropped all but the latest queued keystroke, so neither grew memory. The Combine version was 14 production lines; the hand-rolled AsyncStream was 31, but had structural cancellation (the `for await` loop dies with the view's `.task`, no `AnyCancellable` to leak) and read as ordinary control flow. I ship the **AsyncStream** version into Notes v1: it's new code, the async-first default applies, and the structural-cancellation win matters in a SwiftUI view where `.task` should own the loop's lifetime. The latency and correctness were identical, so the tiebreak was lifecycle, not performance. If Notes v1 were an existing Combine codebase, I'd ship the Combine version for consistency — the matrix's "match the code that's there" row.

Quantified, contextual, honest that the numbers were a tie and the lifecycle was the tiebreak. That's the senior answer to "Combine or async/await?"

## Where this reappears

The instinct — build both, measure the thing that actually matters (searches fired, latency, memory under stress), then decide with the matrix — is exactly what Phase III's networking week (Week 13) needs when the search runs *against a server* and you must decide where retries, cancellation, and back-pressure live. The debounce you measured here becomes search-against-a-network, and the cancellation discipline you proved here is what keeps a cancelled search from racing a stale response onto the screen.
