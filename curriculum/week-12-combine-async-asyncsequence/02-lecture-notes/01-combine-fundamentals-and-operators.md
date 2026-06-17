# Lecture 1 — Combine fundamentals, operators, and where it still earns its keep

> "Combine is not the future. But it is in your codebase, in the SDK, and in the interview, so you will read it whether you write it or not. Learn it well enough to maintain it and bridge it — and learn `async`/`await` well enough to replace it."

This is the honest Combine lecture. We teach it because you cannot escape it — `NotificationCenter.publisher`, `Timer.publish`, `@Published`, `URLSession.dataTaskPublisher`, and a decade of shipping code are all Combine — but we teach it with the 2026 frame: Apple's reactive investment moved to structured concurrency in 2021, so Combine is a *read-and-bridge* skill for new code and a *maintain* skill for old code. By the end of this lecture you can read any Combine pipeline, write a competent one, and explain the demand/back-pressure model that makes Combine Combine. Lecture 2 gives you the async side and the matrix that chooses.

---

## 1. The shape of a stream — and why "one value" isn't enough

You already have a tool for "a value that arrives later": `async`/`await`. `let user = try await fetchUser()` suspends, then resumes with *one* value. That is the whole story for a single asynchronous result, and for that case `async`/`await` is perfect and Combine is overkill.

But a huge class of problems is not "one value later." It is *many values over time*:

- Every character the user types into a search field.
- Every `NSNotification` posted to `NotificationCenter`.
- Every tick of a timer.
- Every byte of progress in a download.
- Every event a WebSocket pushes.

These are **streams**: a producer emits values across a span, possibly forever, possibly failing, and a consumer reacts to each. You cannot model "the keystroke stream" as a single `await` — there is no single value to wait for. You need a vocabulary for *sequences over time*. Combine was Apple's first such vocabulary (2019); `AsyncSequence` is the second (2021). This lecture is the first; lecture 2 is the second.

---

## 2. Publisher, Subscriber, Subscription — the three roles

Combine has exactly three roles, and every pipeline is wiring them together.

- **`Publisher`** — the *producer*. It declares two associated types: `Output` (what it emits) and `Failure: Error` (how it can fail; `Never` if it cannot). A publisher does *nothing* until subscribed — it is a recipe, not a running process. This laziness matters.
- **`Subscriber`** — the *consumer*. It declares matching `Input` and `Failure` types and three callbacks: `receive(subscription:)`, `receive(_ input:)` (per value), and `receive(completion:)` (success or failure, once).
- **`Subscription`** — the *connection*, created when a subscriber subscribes to a publisher. It is the back-pressure channel: the subscriber tells the subscription **how many** values it is ready for via `request(_ demand:)`, and the publisher must not exceed that demand. This is the part people skip and the part that distinguishes Combine from a naive callback.

```text
   Publisher  ──subscribe──►  creates Subscription  ──►  Subscriber
       │                            ▲   │                     │
       │   emits ≤ demanded values  │   │  request(demand)    │
       └────────────────────────────┘   └─────────────────────┘
                                     back-pressure: the subscriber
                                     pulls; the publisher respects it
```

The everyday consequence: a `Publisher` is inert until you attach a subscriber, and the canonical subscriber you attach is `sink` or `assign`, both of which hand you an `AnyCancellable` you must keep alive. Lose the cancellable and the subscription tears down. We will hit that rule hard in §5.

### Back-pressure, concretely

**Back-pressure** is the system's answer to "what if the producer is faster than the consumer?" In Combine, the subscriber *requests* a demand (a count, or `.unlimited`), and the publisher must respect it. A slow consumer can request one-at-a-time and the publisher will not flood it. Most operators forward `.unlimited` demand (so you rarely see it), but the model is there, and it is the thing async streams handle *differently* (lecture 2, §1) — `AsyncStream` buffers and the consumer pulls via `for await`, rather than the consumer pre-declaring a numeric demand. Hold "Combine: subscriber pre-requests a count; async: consumer pulls one at a time" as the back-pressure contrast; the matrix uses it.

---

## 3. Subjects — imperatively feeding a stream

A bare `Publisher` is declarative. Often you have an *imperative* source — a delegate callback, a button tap, a value you want to push — and you need to *send into* a stream from outside. That is a **`Subject`**, a publisher you can feed:

```swift
import Combine

// PassthroughSubject: emits values as they're sent; has no "current value".
let taps = PassthroughSubject<Void, Never>()
taps.send(())          // emit a tap
taps.send(())

// CurrentValueSubject: holds a current value, replays it to new subscribers.
let query = CurrentValueSubject<String, Never>("")
query.send("sw")
print(query.value)     // "sw"  — you can read the current value synchronously
```

- **`PassthroughSubject`** is "an event bus." It has no stored value; a subscriber sees only values sent *after* it subscribes. Use it for events (taps, notifications-you-relay).
- **`CurrentValueSubject`** is "an observable variable." It stores a current value (readable via `.value`), replays it to new subscribers, and emits on every change. It is, not coincidentally, exactly the shape `@Published` wraps.

Subjects are the bridge *into* Combine from the imperative world, the same role `AsyncStream.Continuation` plays for async sequences (lecture 2, §2). When you must convert "a callback fires" into "a stream emits," you reach for a subject (Combine) or a continuation (async).

---

## 4. The operator catalogue — what you'll actually use

Operators are the reason anyone tolerates Combine: they are a rich, chainable vocabulary for transforming streams, and several have no one-liner async equivalent without a helper package. Each operator is itself a publisher that subscribes to the upstream and re-publishes. The ones you must know:

### Transforming

```swift
publisher
    .map { $0 * 2 }                          // transform each value
    .tryMap { try parse($0) }                // transform, may throw (Failure becomes Error)
    .scan(0) { sum, next in sum + next }     // running accumulation, emits each step
    .compactMap { Int($0) }                  // transform + drop nils
```

### Filtering

```swift
publisher
    .filter { $0 > 0 }                       // keep matching values
    .removeDuplicates()                      // drop consecutive equal values
    .replaceNil(with: 0)                     // substitute for nils
    .replaceError(with: [])                  // recover from failure with a fallback
```

`removeDuplicates()` is the unsung hero of search: if the user types "sw", deletes, retypes "sw", you do not want to re-run the same search. It drops *consecutive* equal values, so the pipeline stays quiet when nothing actually changed.

### Time — the operators Combine was born for

```swift
publisher
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)   // wait for a quiet gap
    .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)  // at most one per window
    .delay(for: .seconds(0.5), scheduler: RunLoop.main)          // shift everything later
```

`debounce` is *the* operator for search-as-you-type: it emits a value only after the upstream has been *quiet* for the specified interval. Type "swift" fast and `debounce(300ms)` emits exactly once, 300 ms after the last keystroke — not five times. This is the operator the whole week's worked example revolves around, and the one async sequences need a helper (`swift-async-algorithms`) to match. `throttle`, by contrast, emits at most once per window regardless of quiet (good for scroll position, GPS). Know the difference: **debounce waits for silence; throttle rate-limits.**

### Combining

```swift
Publishers.CombineLatest(queryPublisher, filterPublisher)   // latest of each, emits on either change
    .map { query, filter in /* both current values */ }

Publishers.Merge(streamA, streamB)    // interleave two streams of the same type
queryPublisher.zip(idPublisher)       // pair the Nth of each (waits for both)
```

`combineLatest` is how you build "search depends on *both* the query *and* the selected tag" — it holds the latest of each and re-emits whenever either changes. (You built exactly this composition by hand in Week 11's filter; here it is one operator.)

### Flattening

```swift
queryPublisher
    .map { query in searchPublisher(for: query) }   // now a publisher-of-publishers
    .switchToLatest()                               // subscribe to the newest inner, cancel the old
```

`flatMap` flattens a publisher-of-publishers into a single stream; `switchToLatest` does so while *cancelling the previous inner publisher* when a new one arrives — which is precisely the "cancel the in-flight search when the user types again" behaviour. `debounce` + `removeDuplicates` + `map` + `switchToLatest` is the classic Combine search pipeline, and it is genuinely elegant. Hold it up; lecture 2 builds the same thing with `AsyncStream` and you compare.

### Terminal — where the pipeline runs

Nothing happens until you attach a *terminal subscriber*:

```swift
let cancellable = publisher
    .sink(
        receiveCompletion: { completion in /* .finished or .failure */ },
        receiveValue: { value in /* each value */ }
    )

// or, for a Never-failure publisher, the one-arg form:
let c2 = publisher.sink { value in print(value) }

// or assign straight into a property:
let c3 = publisher.assign(to: \.title, on: someObject)
```

`sink` and `assign` are the two terminals. Both return an `AnyCancellable`. The pipeline runs only while that cancellable lives — which is the single most common Combine bug, next.

---

## 5. `AnyCancellable` — the retain rule that bites everyone

This is the Combine footgun, and it is worth a section because every Combine newcomer ships it once.

**The rule: a subscription lives exactly as long as its `AnyCancellable`.** When the cancellable deallocates, the subscription is cancelled and the pipeline stops. So:

```swift
// ☠️ BUG: the cancellable is a local, deallocated at the end of the function.
//    The subscription tears down immediately and you receive nothing.
func startListening() {
    somePublisher.sink { print($0) }   // returned AnyCancellable is discarded!
}

// ✅ FIX: store the cancellable so it outlives the function.
final class Listener {
    private var cancellables = Set<AnyCancellable>()
    func startListening() {
        somePublisher
            .sink { print($0) }
            .store(in: &cancellables)   // kept alive by `self`
    }
}
```

The idiom is a `Set<AnyCancellable>` property and `.store(in: &cancellables)` on every pipeline. When the owning object deallocates, the set deallocates, every subscription is cancelled — clean teardown, no leaks. Forget `.store(in:)` and your pipeline silently does nothing; *over*-retain (store a cancellable that captures `self` strongly in a closure) and you leak. The async-await world sidesteps this entirely: a `for await` loop's lifetime *is* the enclosing task's lifetime, cancelled structurally when the task is — no manual cancellable bookkeeping. That ergonomic difference is a real point in async's favour (matrix, lecture 2).

---

## 5b. Schedulers, threading, and error handling — the two things that break in production

Two Combine details bite in production and deserve their own section, because the happy-path tutorials skip them and then your UI updates on the wrong thread or your pipeline dies silently on the first error.

### Schedulers — where does each operator run?

A **`Scheduler`** in Combine answers "on what thread/queue does this work execute, and with what timing?" Two operators control it:

```swift
publisher
    .subscribe(on: DispatchQueue.global(qos: .userInitiated))   // where the SUBSCRIPTION/upstream work runs
    .map { expensiveTransform($0) }                              // ...runs on the global queue
    .receive(on: RunLoop.main)                                    // where DOWNSTREAM delivery runs
    .sink { updateUI($0) }                                        // ...runs on the main thread
```

- **`subscribe(on:)`** controls where the *upstream* (the subscription setup and the publisher's work) runs. Use it to push expensive producing work off the main thread.
- **`receive(on:)`** controls where everything *downstream of it* is delivered. This is the one you almost always need: **UI updates must happen on the main thread**, so a pipeline that ends in a SwiftUI update needs `.receive(on: RunLoop.main)` (or `DispatchQueue.main`) before the `sink`/`assign`. Forget it and you mutate UI state from a background queue — a crash or a "Publishing changes from background threads is not allowed" warning.

The async/await world makes this *structural* instead of operator-based: a `@MainActor` view model's methods run on the main actor by construction, and `await` hops are explicit in the type system. Combine's scheduling is a runtime concern you wire per pipeline; async's is a compile-time isolation the compiler checks. That difference — "I must remember `.receive(on:)`" versus "the compiler enforces `@MainActor`" — is another quiet point in async's favour, and a frequent source of Combine bugs in mixed codebases.

`RunLoop.main` versus `DispatchQueue.main` matters subtly: `RunLoop.main` defers delivery until the run loop is free (so it can coalesce and can be *delayed* during scrolling), while `DispatchQueue.main` schedules immediately on the main queue. For `debounce`/`throttle` schedulers, `RunLoop.main` is conventional; for a plain `receive(on:)` before a UI update, `DispatchQueue.main` is often the safer "deliver promptly" choice. Know that the choice exists; most bugs are "I forgot to schedule on main at all," not "I picked the wrong main scheduler."

### Error handling — the `Failure` type and the silent-death trap

A Combine publisher's second associated type is `Failure: Error`. When a publisher *fails*, it sends a `.failure(error)` completion and **the subscription terminates — permanently.** No more values, ever. This is the trap: a search pipeline that fails once (a decode error, a network blip) is *dead*, and the search field silently stops working with no crash to tell you why.

```swift
// ☠️ THE TRAP: one failure kills the pipeline forever.
queryPublisher
    .tryMap { try riskyParse($0) }     // if this throws once, the pipeline completes with .failure
    .sink(
        receiveCompletion: { completion in
            if case .failure = completion { /* pipeline is now DEAD */ } },
        receiveValue: { use($0) }
    )

// ✅ THE FIX: recover from the error and keep the pipeline alive.
queryPublisher
    .tryMap { try riskyParse($0) }
    .catch { error in Just(fallbackValue) }   // replace the failed stream with a recovery stream
    // or: .replaceError(with: fallbackValue)  // simpler: substitute a value on failure
    .sink { use($0) }
```

The operators for keeping a pipeline alive across errors: **`replaceError(with:)`** (substitute a value and *complete* — note this still ends the stream after the substitution), **`catch { }`** (replace the failed stream with a whole new publisher, so the *outer* stream survives if the new one does), and **`retry(n)`** (resubscribe up to `n` times on failure — useful for transient network errors, and the conceptual ancestor of the retry-with-backoff you build properly in Week 13). For a *long-lived* pipeline like search-off-`$query`, you typically `catch` the inner search publisher (inside a `flatMap`/`switchToLatest`) so a single failed search doesn't kill the whole keystroke stream — the failure is contained to one inner publisher, not the outer one.

The async world handles this with ordinary `do`/`catch` inside the `for await` loop: a thrown error from one iteration is caught and the loop *continues* to the next element if you want it to. There is no "the stream is permanently dead after one error" trap unless you `break` or let the error propagate out of the loop. That is a genuinely simpler error model, and the second reason (after cancellation) that async streams are less bug-prone than Combine for everyday work.

---

## 6. `@Published` and `ObservableObject` — the legacy SwiftUI bridge

Before the Observation framework (`@Observable`, Week 8), SwiftUI's reactivity ran on Combine:

```swift
import Combine

final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [String] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // $query is a Publisher<String, Never> for the property's changes.
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] q in self?.search(q) }
            .store(in: &cancellables)
    }

    private func search(_ q: String) { /* ... */ }
}

struct SearchView: View {
    @StateObject private var model = SearchModel()
    var body: some View {
        List(model.results, id: \.self) { Text($0) }
            .searchable(text: $model.query)
    }
}
```

Three things to internalise:

- **`@Published var query`** synthesises a publisher `$query` (note the `$`) that emits on every change. This is `CurrentValueSubject` in property-wrapper clothing. It is the single most common place Combine appears in app code — a debounced search wired off `$query`.
- **`ObservableObject` + `@StateObject`/`@ObservedObject`** is the *pre-Observation* SwiftUI binding mechanism. The whole class re-publishes via `objectWillChange`, and SwiftUI re-renders. This is exactly what `@Observable` replaced in 2023 (Week 8) — and `@Observable` re-renders *only the views that read the changed property*, where `ObservableObject` re-renders everything observing the object. That granularity is why Apple moved on.
- **`$query`-debounce-sink is the canonical Combine-in-SwiftUI pattern**, and it is *also* the thing you will most often migrate to `@Observable` + an `AsyncStream` debounce (lecture 2). When you see a `@Published` debounced into a `sink`, you are looking at the legacy version of this week's worked example.

The practical 2026 guidance: **new view models use `@Observable`, not `ObservableObject`** (Week 8 settled this). But you will *read* `@Published`/`ObservableObject` constantly — every codebase older than 2023 is built on it — so you must be fluent in this pattern even though you write its successor.

---

## 7. `.onReceive` — Combine in the SwiftUI view

When you have a publisher (often a framework one) and want a view to react to it, `.onReceive` is the bridge:

```swift
struct ClockView: View {
    @State private var now = Date()
    // Timer.publish is a framework Combine API — you can't avoid Combine here.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(now, format: .dateTime.hour().minute().second())
            .onReceive(timer) { now = $0 }   // run a closure on each emission
    }
}
```

`.onReceive(publisher) { value in ... }` subscribes to the publisher for the lifetime of the view and runs the closure on each value. It is the *view-level* terminal subscriber — SwiftUI manages the `AnyCancellable` for you, so you do not write `.store(in:)` here.

The crucial contrast with `.task` (lecture 2, §4): **`.onReceive` is not tied to a value identity and does not auto-restart.** `.task(id:)` cancels and restarts its async work when the `id` changes; `.onReceive` just keeps the same subscription. For framework Combine publishers (`Timer.publish`, `NotificationCenter.publisher`) `.onReceive` is the right and only ergonomic tool. For your own async streams, `.task` is usually better. Knowing which view modifier matches which producer is part of "place reactivity correctly."

---

## 8. Where Combine still earns its keep in 2026

Lecture 2 makes the full case that new code defaults async-first. But fairness demands naming where Combine is still the better or only tool, because "always use async" is as wrong as "always use Combine":

1. **Framework APIs that *are* Combine.** `NotificationCenter.publisher(for:)`, `Timer.publish`, `@Published`, `URLSession.dataTaskPublisher`, `NSObject.publisher(for:)` (KVO). These hand you a publisher; the most ergonomic consumption is often `.onReceive` or a short Combine chain. (You *can* bridge each to async via `.values` — lecture 2 — but sometimes the Combine path is shorter.)
2. **Rich operator chains with no one-liner async equivalent.** `combineLatest` of four sources, each `debounce`d and `removeDuplicates`d, merged and `switchToLatest`'d — Combine expresses this in a readable chain. The async equivalent needs `swift-async-algorithms` and is more verbose. For a *complex* multi-source reactive pipeline, a mature Combine chain can still read better.
3. **An existing Combine codebase.** The cheapest correct architecture is often "match the code that's there." Dropping one `async` island into a 50-file Combine app creates two paradigms to maintain; consistency has value (the Week 11 ADR lesson applies).

But for the *typical* new feature — a debounced search, a stream of events, a download's progress — `async`/`await` + `AsyncSequence` is simpler, has structural cancellation, sidesteps the `AnyCancellable` retain dance, and is where Apple invests. That is the default, and lecture 2 builds it.

---

## 8b. A worked example — relaying `NotificationCenter` into a debounced state update

To make the whole catalogue concrete, here is a small but realistic pipeline that ties together a *framework Combine API* (the kind you cannot avoid), a subject, two operators, and the retain rule. The scenario: another part of the system posts a `.notesDidChange` notification whenever the store mutates, and you want a "last synced" label that updates at most once per second no matter how chatty the notifications are.

```swift
import Combine
import Foundation

extension Notification.Name {
    static let notesDidChange = Notification.Name("notesDidChange")
}

final class SyncStatusModel: ObservableObject {
    @Published private(set) var lastChangeText = "No changes yet"
    private var cancellables = Set<AnyCancellable>()
    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .medium; return f
    }()

    init() {
        // NotificationCenter.publisher(for:) is a FRAMEWORK Combine API — you
        // consume it with Combine (or bridge it via .values, lecture 2).
        NotificationCenter.default.publisher(for: .notesDidChange)
            .map { _ in Date() }                                   // map each notification to "now"
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)  // at most one/sec
            .receive(on: RunLoop.main)                             // deliver on main for UI
            .map { [formatter] date in "Last change: \(formatter.string(from: date))" }
            .sink { [weak self] text in self?.lastChangeText = text }
            .store(in: &cancellables)                              // the retain rule
    }
}
```

Walk it: a framework publisher emits a `Notification` per post; `map` discards the notification and stamps the time; `throttle(latest:)` rate-limits to one update per second (we use `throttle`, not `debounce`, because we want *steady* updates during a burst, not silence-then-one); `receive(on: RunLoop.main)` guarantees the `@Published` mutation happens on the main thread; the final `map` formats; `sink` assigns and is *stored*. Five posts in 800 ms produce one label update. Every concept from this lecture — framework Combine API, operators, the scheduler rule (§5b), `@Published`, and the cancellable retain rule — appears in eight lines. This is the shape you will read in production Combine code, and you can now narrate every line of it.

In lecture 2 you will see this exact relay rewritten with `for await NotificationCenter.default.publisher(for: .notesDidChange).values` inside a `.task`, debounced with `swift-async-algorithms` — same behaviour, structural cancellation, no `AnyCancellable`. Hold this version up against that one when you get there.

---

## 9. Recap — and the bridge to lecture 2

You now have Combine well enough to read it, write it, and not ship the retain bug:

- A **stream** is many-values-over-time; `async`/`await` handles one value, Combine (and `AsyncSequence`) handle streams.
- **Publisher / Subscriber / Subscription** are the three roles; the subscription carries **back-pressure** (the subscriber pre-requests a demand the publisher respects).
- **Subjects** (`PassthroughSubject`, `CurrentValueSubject`) feed a stream imperatively; they are the Combine analogue of an `AsyncStream` continuation.
- The **operator catalogue** — `map`/`filter`/`removeDuplicates`/`debounce`/`combineLatest`/`flatMap`/`switchToLatest`/`sink`/`assign` — is Combine's reason to exist; `debounce` + `removeDuplicates` + `switchToLatest` is the canonical search pipeline.
- **`AnyCancellable`** must be *stored* (`.store(in: &cancellables)`) or the subscription tears down; this manual lifecycle is exactly what `async`'s structural cancellation removes.
- **`@Published`/`ObservableObject`** is the legacy SwiftUI bridge (replaced by `@Observable`); **`.onReceive`** is the view-level subscriber for framework publishers.
- Combine **still earns its keep** for framework Combine APIs, rich operator chains, and existing Combine codebases — but new code defaults async-first.

Lecture 2 builds the other half: `AsyncSequence` and `AsyncStream`, the two-way bridge between Combine and async (`publisher.values` and friends), the search debounce *re-implemented* with `AsyncStream` so you can compare it line-for-line with the Combine version, where to place reactivity in SwiftUI (`.task` vs `.onReceive`), and the decision matrix that — given any streaming problem — tells you which of these three tools to reach for. Bring the Combine search pipeline (`$query.debounce.removeDuplicates.switchToLatest`) with you; we are about to build its async twin and weigh them.
