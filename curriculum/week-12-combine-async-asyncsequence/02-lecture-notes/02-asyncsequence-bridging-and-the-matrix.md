# Lecture 2 — AsyncSequence, AsyncStream, the bridge, and the decision matrix

Lecture 1 gave you Combine — the read-and-bridge skill. This lecture gives you the other side: `AsyncSequence` and `AsyncStream`, the structured-concurrency way to model streams, the one Apple invests in and the one new code defaults to. We build the search debounce a *second* way so you can compare it line-for-line with the Combine version, learn the two-way bridge between the worlds, settle where reactivity belongs in a SwiftUI view, and end on the decision matrix that turns "which tool?" from a vibe into a lookup.

---

## 1. `AsyncSequence` — a `for` loop over time

Here is the whole idea: an **`AsyncSequence`** is a sequence whose elements arrive *asynchronously*, and you consume it with `for await`, which is just a loop that *suspends* between elements instead of blocking.

```swift
// A function that returns an AsyncSequence of lines from a URL.
for try await line in url.lines {        // url.lines is an AsyncSequence<String>
    print(line)                          // each iteration may suspend until the next line arrives
}
print("stream finished")                 // reached when the sequence completes
```

Compare to a synchronous `for x in array`. The only difference is the `await`: each step may suspend, letting other work run, then resume when the next element is ready. The compiler desugars `for await` into calls on an *async iterator* (`makeAsyncIterator()`, then `await iterator.next()` returning `nil` at the end) — exactly the iterator protocol you learned in Week 2, with `async` bolted on.

What makes this so pleasant compared to Combine:

- **Cancellation is structural.** The `for await` loop runs inside a `Task`. Cancel the task (or let it go out of scope) and the loop stops at the next suspension point — no `AnyCancellable`, no `.store(in:)`, no manual teardown. The stream's lifetime *is* the task's lifetime. This is the single biggest ergonomic win over Combine.
- **Errors are `try`, not a `Failure` type.** `for try await` throws like any other Swift error; you `catch` it with normal `do`/`catch`. No `.replaceError`, no `Failure == Never` gymnastics.
- **Back-pressure is "pull."** The consumer asks for the next element (`await next()`) when it is ready for one. There is no pre-declared numeric demand; the producer simply does not produce the next element until the consumer pulls. This is a *simpler* back-pressure model than Combine's demand counting, and for most app problems it is the one you want.

The standard library gives you the operators you expect — `.map`, `.filter`, `.compactMap`, `.first(where:)`, `.reduce`, `.prefix` — as async sequence transforms. What it does *not* ship in the stdlib is `debounce`/`throttle`/`combineLatest`; those live in Apple's **`swift-async-algorithms`** package (resources), which is the async analogue of Combine's time and combining operators.

---

## 2. `AsyncStream` — building a stream from the callback world

`AsyncSequence` is the protocol; you rarely conform to it by hand. The everyday tool for *producing* a stream — especially from an imperative, callback, or delegate source — is **`AsyncStream`**, built with a **`Continuation`** you feed:

```swift
// Turn a callback-based source into an AsyncStream.
func locationStream(_ manager: LocationManager) -> AsyncStream<Location> {
    AsyncStream { continuation in
        manager.onUpdate = { location in
            continuation.yield(location)          // push a value into the stream
        }
        manager.onStop = {
            continuation.finish()                 // complete the stream
        }
        // Clean up the imperative source when the stream is torn down
        // (consumer task cancelled, or `finish()` called).
        continuation.onTermination = { _ in
            manager.onUpdate = nil
            manager.stop()
        }
        manager.start()
    }
}

// Consume it — cancellation-safe, no cancellable bookkeeping.
let task = Task {
    for await location in locationStream(manager) {
        update(location)
    }
}
// task.cancel() stops the loop AND fires onTermination, cleaning up the manager.
```

The pieces:

- **`continuation.yield(_:)`** pushes a value to whoever is `for await`-ing the stream. This is the async analogue of `subject.send(_:)` (lecture 1, §3).
- **`continuation.finish()`** completes the stream; the `for await` loop ends. (`AsyncThrowingStream` adds `finish(throwing:)` to end with an error.)
- **`continuation.onTermination`** is the cleanup hook — it fires when the consumer's task is cancelled *or* when you `finish()`. This is where you detach the callback, stop the manager, close the socket. Forgetting it is the async analogue of leaking a subscription. It is the *one* lifecycle obligation `AsyncStream` keeps that mirrors Combine's `AnyCancellable`, but it is local and explicit rather than a global retain dance.

### Buffering — the back-pressure knob

What if the producer `yield`s faster than the consumer `for await`s? `AsyncStream`'s **buffering policy** decides:

```swift
AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in /* ... */ }
```

- **`.unbounded`** (default) — buffer everything. Simple, but a fast producer with a slow consumer grows memory without limit. Fine for bursty-but-finite sources; dangerous for firehoses.
- **`.bufferingNewest(n)`** — keep only the `n` most recent; drop the oldest when full. Perfect for "I only care about the latest" sources: cursor position, latest search query, latest sensor reading. `.bufferingNewest(1)` is "always the freshest value, never a backlog."
- **`.bufferingOldest(n)`** — keep the first `n`, drop new ones when full. For "process in order, don't skip" sources where the early values matter most.

Choosing the buffering policy *is* choosing the back-pressure behaviour, and it is the explicit answer to lecture 1's Combine demand model. For search-as-you-type you want `.bufferingNewest(1)` (only the latest keystroke matters) — which is half of why the `AsyncStream` debounce works the way it does, next.

---

## 3. The search debounce — the same feature, the async way

Lecture 1 showed the canonical Combine search pipeline: `$query.debounce(300ms).removeDuplicates().sink`. Here is the *same behaviour* with `AsyncStream`, so you can hold them side by side.

```swift
@Observable
@MainActor
final class AsyncSearchModel {
    var query = "" {
        didSet { continuation?.yield(query) }   // feed each keystroke into the stream
    }
    private(set) var results: [String] = []

    private var continuation: AsyncStream<String>.Continuation?
    private let client: SearchClient

    init(client: SearchClient) {
        self.client = client
    }

    /// Drive this from .task in the view. The loop's lifetime is the view's.
    func observeQueries() async {
        // Build the stream and capture its continuation so `didSet` can yield.
        let stream = AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { cont in
            self.continuation = cont
            cont.onTermination = { _ in self.continuation = nil }
        }

        var lastSearched: String?
        for await q in stream {
            // Debounce by hand: wait 300ms; if a newer query arrived, this task
            // was replaced (see below), so we never run a stale search.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            guard q != lastSearched else { continue }   // removeDuplicates, by hand
            lastSearched = q
            results = (try? await client.search(q)) ?? []
        }
    }
}
```

Wait — the loop above debounces *each* element, which is not quite right (it delays every query rather than collapsing a burst). The honest, production-correct hand-rolled debounce restarts a timer per keystroke and only fires after silence. The clean way to express that is a per-keystroke task that cancels its predecessor:

```swift
func observeQueries() async {
    let stream = AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { cont in
        self.continuation = cont
        cont.onTermination = { _ in self.continuation = nil }
    }

    var debounceTask: Task<Void, Never>?
    for await q in stream {
        debounceTask?.cancel()                    // cancel the previous pending search
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            let hits = (try? await self.client.search(q)) ?? []
            await MainActor.run { self.results = hits }
        }
    }
}
```

Now read the two implementations together. **Combine:** `.debounce(for:scheduler:)` — one operator, the cancellation of the in-flight search is implicit in `switchToLatest`, the lifecycle is an `AnyCancellable` you store. **`AsyncStream`:** you build the stream, feed it from `didSet`, and express the debounce as "cancel the previous task, sleep, then search" — more explicit, more lines, but *every step is visible*, cancellation is structural (the `for await` loop and the inner task both die with the view's `.task`), and there is no `AnyCancellable` to leak.

The honest verdict, which goes straight into the matrix:

- For *this exact operator* (a textbook debounce), Combine's one-liner is genuinely more elegant, **and** `swift-async-algorithms` offers an async `.debounce(for:)` that matches it (so the async side can be a one-liner too, with one package).
- For *cancellation lifecycle and Swift-6-nativeness*, the `AsyncStream`/`Task` version wins — it is structurally cancelled, has no retain dance, and reads as ordinary Swift control flow.
- The mini-project uses the **`AsyncStream`** version, because "Notes v1" is new code, the lifecycle wins matter, and building it by hand once teaches the model. But you should be able to write the Combine version in your sleep, because you will read it everywhere.

---

## 3b. Async sequence operators, and `swift-async-algorithms`

Combine's reason to exist is its operator catalogue (lecture 1, §4). The async world has operators too — some in the standard library, the time-and-combining ones in Apple's `swift-async-algorithms` package — and you should know what's where so you don't reinvent them.

**In the standard library**, an `AsyncSequence` gets the transforms you'd expect, lazily:

```swift
let titles = notes.async                      // any Sequence -> AsyncSequence
    .filter { !$0.isArchived }                // AsyncFilterSequence
    .map(\.title)                             // AsyncMapSequence
    .prefix(20)                               // AsyncPrefixSequence

for await title in titles { print(title) }    // nothing runs until you iterate

// Terminal-style reductions also exist:
let total = try await numbers.reduce(0, +)
let firstSwift = try await titles.first { $0.contains("Swift") }
let allShort = try await titles.allSatisfy { $0.count < 50 }
```

These are *lazy and async*: `map`/`filter` build a wrapper sequence and do their work only as you `for await` through it, suspending where the upstream suspends. They are the direct analogues of Combine's `map`/`filter`/`compactMap`/`first(where:)`.

**What the standard library does *not* ship** — and what you reach for `swift-async-algorithms` to get — are the *time* and *multi-source* operators that were Combine's headline:

```swift
import AsyncAlgorithms

// debounce — wait for a quiet gap, then emit the latest. The async .debounce.
for await query in keystrokes.debounce(for: .milliseconds(300)) {
    await search(query)
}

// throttle — at most one per interval (rate limit).
for await position in scrollPositions.throttle(for: .milliseconds(100)) { update(position) }

// combineLatest — the latest of each, re-emitting when either changes.
for await (query, tag) in combineLatest(queryStream, tagStream) { search(query, tag) }

// merge — interleave streams of the same element type.
for await event in merge(networkEvents, localEvents) { handle(event) }

// chunked / collect — batch elements by count or time, e.g. for bulk writes.
for await batch in inserts.chunked(by: .repeating(every: .seconds(1))) { try await save(batch) }
```

This is the key fact for the matrix: **`swift-async-algorithms` closes most of the operator gap.** The common reason people say "Combine is more powerful" is the operator vocabulary — but `debounce`, `throttle`, `combineLatest`, `merge`, `zip`, `chunked` all exist on the async side once you add this one package. So the *operator-ergonomics* argument for Combine shrinks to "a genuinely complex multi-source chain" and "it's already there in the SDK." For the everyday debounced search, the async side is now a one-liner too — `keystrokes.debounce(for:)` — and it carries the structural-cancellation win for free. The mini-project's hand-rolled debounce (§3) is a *teaching* exercise; in real new code, `swift-async-algorithms`' `.debounce` is what you'd ship.

One caveat worth knowing: these async operators consume their upstream by iteration, so they live inside a `Task`/`for await` and are cancelled structurally — but a `combineLatest` of two streams keeps *both* upstreams alive until both finish or the task is cancelled. The lifecycle is the task, as always; just be aware that multi-source operators hold multiple producers open. That is the async equivalent of remembering that a Combine `CombineLatest` retains both upstream subscriptions.

---

## 4. Bridging Combine ⇄ async — both directions

You will constantly be in one world needing the other. The bridges:

### Combine → async (the common direction)

Every `Publisher` exposes `.values`, which *is* an `AsyncSequence`:

```swift
// A framework Combine API consumed the async way:
for await note in NotificationCenter.default.publisher(for: .myEvent).values {
    handle(note)
}

// A @Published property consumed without a sink/cancellable:
for await q in model.$query.values {
    search(q)
}
```

`publisher.values` lets you consume *any* Combine publisher — including the framework ones (`Timer.publish`, `NotificationCenter.publisher`, `dataTaskPublisher`) — inside a `for await` loop, getting structural cancellation for free and dropping the `AnyCancellable`. This is the single most useful bridge: it means "Combine in the SDK" no longer forces "Combine in your code." Consume the framework publisher's `.values` in a `.task`.

### async → Combine (the rarer direction)

When a Combine-shaped API *demands* a publisher and you have async work, wrap it in a `Future`:

```swift
func fetchPublisher() -> AnyPublisher<User, Error> {
    Future { promise in
        Task {
            do { promise(.success(try await fetchUser())) }
            catch { promise(.failure(error)) }
        }
    }
    .eraseToAnyPublisher()
}
```

`Future` runs its closure once and publishes a single value or failure — the publisher shape over a single async result. You need this only when feeding async work *into* an existing Combine pipeline; in new code you would not.

**The rule across the bridge:** do not leak. A `.values` loop is cancelled with its task (clean). A `Future`-wrapped task should be cancelled if the publisher's subscription is cancelled (tie the inner `Task` to the subscription's lifetime if it matters). Crossing the bridge sloppily re-introduces exactly the leak each model was trying to avoid.

---

## 5. Placing reactivity in SwiftUI — `.task` vs `.onReceive` vs `@Observable`

Three view-level tools, three jobs. Getting this right is "place reactivity correctly":

- **`@Observable` (plain state).** For state that changes *synchronously* in response to user action — a toggle, a text field, a computed property. No stream, no async. The view reads the property; the framework re-renders. This is most of your UI. (Week 8.)
- **`.task { }` / `.task(id:)`.** For *consuming an `AsyncSequence` or running async work tied to the view's lifetime.* `.task` starts when the view appears and is **automatically cancelled when the view disappears** — so a `for await` loop inside it cleans up structurally. `.task(id: someValue)` additionally **cancels and restarts** when `someValue` changes, which is the idiomatic way to re-run a search when a parameter changes. This is where your `AsyncStream` consumption lives:

```swift
.task { await model.observeQueries() }          // runs for the view's lifetime
.task(id: selectedTag) { await model.reload() } // restarts when the tag changes
```

- **`.onReceive(publisher)`.** For *framework Combine publishers* (`Timer.publish`, `NotificationCenter.publisher`) where you want a closure per emission and SwiftUI to manage the cancellable. It does **not** auto-restart on an id and is the right tool only when the producer is genuinely a Combine publisher you are not bridging. (Lecture 1, §7.)

The decision within SwiftUI: **synchronous state → `@Observable`; your async stream → `.task`; a framework Combine publisher → `.onReceive` (or bridge it with `.values` and use `.task`).** The single most common mistake is using `.onReceive` for everything (because it is familiar) when `.task` would give you free cancellation, or doing async work in `onAppear { Task { } }` (which is *not* cancelled on disappear) when `.task` would cancel it for you. Prefer `.task`; it is the structurally-correct default.

---

## 6. The decision matrix — which tool, and why

Here it is, the deliverable of the week. Given a streaming problem, this table picks the tool. Read the *reasons*, not just the cells — the reasons are what you say in code review.

| Situation | Reach for | Why |
|-----------|-----------|-----|
| A single async result (`fetchUser()`) | **`async`/`await`** | Not a stream; one `await`. Combine is overkill. |
| Your own stream of events in new code (keystrokes, custom events) | **`AsyncStream`** | Structural cancellation, no `AnyCancellable`, Swift-6-native. |
| Search-as-you-type debounce, new code | **`AsyncStream` + `swift-async-algorithms` `.debounce`** | One-liner debounce *and* structural cancellation. |
| Consuming a framework Combine API (`Timer.publish`, `NotificationCenter`) | **`.values` bridge → `.task`**, or `.onReceive` | Bridge to async for free cancellation; `.onReceive` if a tiny closure suffices. |
| A *complex* multi-source reactive chain (4 sources, combineLatest, switchToLatest) | **Combine** (or async-algorithms) | Combine's operator vocabulary still expresses this most readably. |
| Maintaining / extending an existing Combine codebase | **Combine** | Consistency beats mixing paradigms (the Week 11 ADR lesson). |
| SwiftUI view reacting to synchronous state | **`@Observable`** | No stream needed; plain state and re-render. |
| Driving a view-lifetime async loop | **`.task` / `.task(id:)`** | Auto-cancel on disappear, auto-restart on id change. |
| Rate-limiting (at most one per second) | **`throttle`** (Combine) or async-algorithms `throttle` | "Rate limit," not "wait for silence" — different from debounce. |

The 2026 default, stated plainly: **new code is async-first.** Reach for `async`/`await`, `AsyncSequence`, `AsyncStream`, and `swift-async-algorithms`. Drop to Combine when the API hands you a publisher, when a genuinely complex operator chain reads better, or when you are matching an existing Combine codebase. Apple has invested in structured concurrency since 2021 and not meaningfully in Combine since; betting on the platform's direction is the safe long-term call. But "async-first" is not "async-only" — the matrix's Combine rows are real, and a senior engineer uses the right tool, not the fashionable one.

---

## 7. Back-pressure, finally compared

We have touched back-pressure in both lectures; here is the consolidated picture, because it is the deepest distinction and an interview favourite:

- **Combine: demand-based pull.** The subscriber pre-requests a numeric demand (`request(.max(n))` or `.unlimited`); the publisher must not exceed it. Most operators forward `.unlimited`, so you rarely tune it, but the model can express "give me one at a time." It is *push within a demand budget*.
- **`AsyncSequence`: suspension-based pull.** The consumer's `for await` calls `next()` only when ready; the producer's next element is not produced (or, for `AsyncStream`, is *buffered per the policy*) until then. There is no numeric demand; the consumer's *speed* is the back-pressure. It is *pull by suspension*.
- **`AsyncStream` buffering** is where you *choose* the overflow behaviour: `.unbounded` (never drop, risk memory), `.bufferingNewest(n)` (drop old, keep fresh), `.bufferingOldest(n)` (keep early, drop new). This is the explicit knob Combine hides behind demand.

The practical upshot for search: you want to *drop* intermediate keystrokes (only the latest query matters), so `.bufferingNewest(1)` plus a debounce is correct, and a naive `.unbounded` buffer that fires a search per buffered keystroke is the footgun the challenge measures. Back-pressure is not academic — it is "did your search fire five times or once."

---

## 7b. The firehose — a worked back-pressure failure and fix

Back-pressure is abstract until a firehose melts your app, so here is the concrete failure and the one-line fix. The scenario: a sensor (or a WebSocket, or a tight progress callback) `yield`s a value every millisecond, and you render each one. The consumer — a SwiftUI update — can realistically handle maybe one update per frame (16.67 ms, Week 7's budget). Producer: 1000/sec. Consumer: 60/sec. That is a 16× mismatch, and the buffering policy decides whether it is fine or fatal.

```swift
// ☠️ THE FAILURE: .unbounded buffers every value the fast producer emits.
let stream = AsyncStream<Reading>(bufferingPolicy: .unbounded) { cont in
    sensor.onReading = { cont.yield($0) }   // 1000/sec
}
for await reading in stream {
    await render(reading)                    // ~60/sec; the buffer grows ~940 items/sec
}
// The buffer grows without bound. Memory climbs, latency between "sensor read"
// and "rendered" grows to seconds, and eventually you get a memory warning.
// Every rendered value is also STALE — you're rendering readings from minutes ago.
```

The buffer is not just a memory problem; it is a *latency and correctness* problem. By the time a buffered reading reaches `render`, the world has moved on — you are drawing the past. For a "show the latest" source, every buffered intermediate value is waste you will throw away after rendering it once.

```swift
// ✅ THE FIX: .bufferingNewest(1) keeps only the freshest reading.
let stream = AsyncStream<Reading>(bufferingPolicy: .bufferingNewest(1)) { cont in
    sensor.onReading = { cont.yield($0) }
}
for await reading in stream {
    await render(reading)   // always the LATEST reading; intermediate ones dropped
}
// Memory is bounded (one item). Latency is one frame. You render current data.
// The 940 dropped readings/sec are exactly the ones you didn't want anyway.
```

`.bufferingNewest(1)` *intentionally drops* the values the consumer cannot keep up with, keeping only the most recent — which is precisely right for "latest value matters" sources (cursor, sensor, latest search query, scroll position). For an "every value matters, in order" source (a log you must not lose lines from), you would instead slow the *producer* or use `.bufferingOldest(n)` with a large `n` and accept the memory, because dropping is not acceptable there. The policy *is* the back-pressure decision, and choosing it is the difference between an app that handles a firehose and one that drowns in it.

This is the exact shape of the search footgun, scaled up: a search that buffers every keystroke and fires a query per buffered character is the firehose; `.bufferingNewest(1)` + debounce is the fix. The challenge measures this directly with a 500-keystroke stress test — the firehose in miniature. Combine's demand model expresses the same idea differently (a subscriber requesting `.max(1)`), but `AsyncStream`'s named buffering policy makes the decision *visible at the call site*, which is why it is easier to get right.

---

## 8. Recap — the whole reactive picture

You now have all three reactive tools and the judgment to choose:

1. **`AsyncSequence`** is a `for` loop over time — `for await`, structural cancellation, `try`-based errors, pull-by-suspension back-pressure. The standard library gives `map`/`filter`/`reduce`; `swift-async-algorithms` gives `debounce`/`throttle`/`combineLatest`.
2. **`AsyncStream`** produces a stream from the callback world via a `Continuation` — `yield`, `finish`, `onTermination` for cleanup, and a *buffering policy* (`.unbounded` / `.bufferingNewest` / `.bufferingOldest`) that is the explicit back-pressure knob.
3. **The bridge** is two-way: `publisher.values` consumes *any* Combine publisher as an `AsyncSequence` (the common direction, freeing you from framework-Combine forcing app-Combine), and `Future` wraps async work back into a publisher (the rare direction). Don't leak across it.
4. **SwiftUI placement** — `@Observable` for synchronous state, `.task`/`.task(id:)` for view-lifetime async streams (auto-cancel, auto-restart), `.onReceive` for framework Combine publishers. Prefer `.task`; it is structurally correct.
5. **The matrix** chooses the tool. New code is **async-first**; Combine is for framework APIs, complex operator chains, and existing Combine codebases. Use the right tool, defend it with the *reason* from the matrix, not with fashion.
6. **Back-pressure** distinguishes them: Combine pulls by numeric demand, async pulls by suspension, and `AsyncStream`'s buffering policy is where you decide what to drop. For search, drop intermediate keystrokes (`.bufferingNewest(1)` + debounce).

The exercises drill each tool — a Combine pipeline, a hand-rolled `AsyncStream` debounce, and the `.values` bridge consumed in a `.task`. The challenge implements the search debounce *both* ways, measures keystroke→search latency and dropped intermediate searches, and writes the decision note. The mini-project is the Phase II gate: "Notes v1," with `AsyncStream`-debounced search wired into the persistent, navigable, architected app you have built all phase. Go make the search feel instant — and be able to say, in one sentence, why you built it the way you did.
