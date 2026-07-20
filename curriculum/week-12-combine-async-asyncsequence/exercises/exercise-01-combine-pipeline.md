# Exercise 1 — A Combine pipeline you can read in your sleep

**Goal.** Build the canonical Combine search pipeline — `debounce` → `removeDuplicates` → `map` → `sink` — drive it from a `PassthroughSubject`, store the `AnyCancellable` correctly, and *prove to yourself* what happens when you forget to store it. You will read this exact shape in every Combine codebase you ever open; this exercise makes it muscle memory.

**Estimated time.** 45 minutes.

**Prerequisites.** Xcode 16+. Combine ships with the SDK — no package needed. This drops into a SwiftUI app target, a command-line tool, or a test target.

---

## Step 1 — The pieces

Create a small class that owns a query subject and runs a debounced pipeline off it:

```swift
import Combine
import Foundation

final class SearchPipeline {
    // The imperative input: we'll `.send(_:)` keystrokes into this.
    let queryInput = PassthroughSubject<String, Never>()

    // Where results land. In a real app this would be @Published / @Observable;
    // here it's a plain array plus a callback so the exercise needs no UI.
    private(set) var lastQueryRun: String?
    var onSearch: ((String) -> Void)?

    // THE RULE: subscriptions live exactly as long as this set.
    private var cancellables = Set<AnyCancellable>()

    init() {
        queryInput
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)  // wait for a quiet gap
            .removeDuplicates()                                          // skip "sw" -> "sw"
            .map { $0.trimmingCharacters(in: .whitespaces) }            // normalise
            .filter { !$0.isEmpty }                                      // don't search empty
            .sink { [weak self] query in
                self?.lastQueryRun = query
                self?.onSearch?(query)                                   // "run the search"
            }
            .store(in: &cancellables)   // <- the line everyone forgets once
    }
}
```

Read the pipeline top to bottom and narrate it: "take each query, wait until the user stops typing for 300 ms, drop it if it's the same as the last one, trim and skip-if-empty, then run the search." That sentence *is* the pipeline. Combine's value is that the code reads like the sentence.

## Step 2 — Drive it and watch the debounce work

In a quick harness (a test, a `main.swift`, or a button), simulate a fast typist:

```swift
let pipeline = SearchPipeline()
var searchesRun: [String] = []
pipeline.onSearch = { searchesRun.append($0) }

// Simulate typing "swift" one character at a time, faster than 300ms apart.
for fragment in ["s", "sw", "swi", "swif", "swift"] {
    pipeline.queryInput.send(fragment)
}

// Let the run loop spin past the debounce window, then inspect.
RunLoop.main.run(until: Date().addingTimeInterval(0.5))
print("searches run: \(searchesRun)")   // expect EXACTLY ["swift"], not 5 searches
```

The whole point: five keystroke `.send`s, but **one** search. `debounce` collapsed the burst into the final value. If you saw five searches, the debounce isn't wired (check the scheduler and that you `.send` faster than 300 ms apart in the simulation).

## Step 3 — Break the retain rule on purpose

Now feel the most common Combine bug. Make a version that *discards* the cancellable:

```swift
final class LeakySearchPipeline {
    let queryInput = PassthroughSubject<String, Never>()
    var onSearch: ((String) -> Void)?

    func start() {
        queryInput
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] q in self?.onSearch?(q) }
        // ☠️ no .store(in:) — the returned AnyCancellable is discarded here,
        //    the subscription is cancelled immediately, and NOTHING fires.
    }
}
```

Run the same harness against `LeakySearchPipeline`. You will get **zero** searches: the subscription tore down the instant `start()` returned because nothing retained the cancellable. This is the bug that makes a Combine newcomer stare at a pipeline that "does nothing." Now you have *seen* it, so you will recognise it in the wild in five seconds instead of an hour.

## Step 4 — Add `combineLatest` (the compose pattern)

Extend the pipeline so the search depends on *both* the query and a "favorites only" toggle — the Combine way to compose two sources:

```swift
final class ComposedPipeline {
    let queryInput = PassthroughSubject<String, Never>()
    let favoritesOnly = CurrentValueSubject<Bool, Never>(false)
    var onSearch: ((String, Bool) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // combineLatest holds the latest of EACH and re-emits when either changes.
        queryInput
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .combineLatest(favoritesOnly.removeDuplicates())
            .sink { [weak self] query, favs in
                self?.onSearch?(query, favs)
            }
            .store(in: &cancellables)
    }
}
```

Toggle `favoritesOnly` and the search re-runs with the *current* query; type a new query and it re-runs with the *current* favorites flag. That is `combineLatest`: "the latest of each, whenever either moves." You implemented this composition by hand in Week 11; here it is one operator.

---

## Acceptance criteria

- [ ] A `SearchPipeline` with `debounce` → `removeDuplicates` → `map`/`filter` → `sink`, the cancellable stored in a `Set<AnyCancellable>`.
- [ ] A harness proving that typing "s","sw","swi","swif","swift" fast runs **exactly one** search ("swift").
- [ ] A `LeakySearchPipeline` demonstrating that *not* storing the cancellable runs **zero** searches — and you can explain why in one sentence.
- [ ] A `ComposedPipeline` using `combineLatest` to make the search depend on both a query and a toggle.
- [ ] Build with **0 warnings, 0 errors**.

## What you just proved

You can read and write the canonical Combine pipeline, you know the `AnyCancellable` retain rule because you *broke* it and watched it fail, and you can compose two sources with `combineLatest`. This is the Combine fluency the matrix (lecture 2, §6) assumes when it says "for a complex multi-source chain, Combine still reads well." You also now have the *exact* shape — `$query.debounce.removeDuplicates.sink` — that lecture 2 re-implements with `AsyncStream` so you can compare. Hold this pipeline in your head for exercise 2.

---

## Hints (read only if stuck > 10 min)

- **The debounce never fires.** You used `DispatchQueue.main` as the scheduler in a context with no run loop, or your harness exits before the debounce window. Use `RunLoop.main` and keep the run loop alive with `RunLoop.main.run(until:)` long enough (≥ debounce interval).
- **`removeDuplicates()` won't compile.** It requires the `Output` to be `Equatable`. `String` is, so check you didn't `map` to a non-`Equatable` type before it.
- **In a test, the run loop trick is awkward.** For a Swift Testing async test, prefer a `confirmation` or `await Task.sleep(for: .milliseconds(500))` after sending, then assert. Combine's `RunLoop` scheduler and Swift Testing's async model can be reconciled, but a small sleep is the pragmatic choice for this drill.
- **`[weak self]` warning about unused capture.** If your `sink` closure doesn't actually use `self`, drop the capture list. Keep `[weak self]` only where you reference `self` to avoid a retain cycle.
