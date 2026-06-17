# Week 12 — Resources

Every primary resource on this page is **free**. Apple's developer documentation and WWDC sessions are free without a paid membership. The community writing is public. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **Combine — framework landing page.** The publisher/subscriber model, the operator index, and the API reference root:
  <https://developer.apple.com/documentation/combine>
- **"Processing published elements with Combine."** Apple's canonical pipeline article — read this before you write a `.sink`:
  <https://developer.apple.com/documentation/combine/processing-published-elements-with-subscribers>
- **`AsyncSequence` — the protocol reference.** The `for await` model and the standard-library async sequences:
  <https://developer.apple.com/documentation/swift/asyncsequence>
- **`AsyncStream` / `AsyncThrowingStream`.** Building a stream from a callback world with a `Continuation`:
  <https://developer.apple.com/documentation/swift/asyncstream>
  <https://developer.apple.com/documentation/swift/asyncthrowingstream>
- **"Migrating to Swift Concurrency" / the concurrency book chapter on async sequences.** The async-first mental model that frames the whole week:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>

## The types and operators (reference, skim don't memorize)

- **`Publisher`:** <https://developer.apple.com/documentation/combine/publisher>
- **`Subscriber` / `Subscription` / `Subscribers.Demand`** (the back-pressure model): <https://developer.apple.com/documentation/combine/subscribers>
- **`AnyCancellable`:** <https://developer.apple.com/documentation/combine/anycancellable>
- **`PassthroughSubject` / `CurrentValueSubject`:** <https://developer.apple.com/documentation/combine/passthroughsubject>
- **`@Published` and `ObservableObject`** (the legacy SwiftUI bridge): <https://developer.apple.com/documentation/combine/published>
- **`debounce` / `throttle` / `removeDuplicates` / `combineLatest` / `flatMap`:** all under the operator index at <https://developer.apple.com/documentation/combine/publishers>
- **`Publisher.values`** (a publisher as an `AsyncSequence` — the bridge): <https://developer.apple.com/documentation/combine/publisher/values-1dm9r>
- **`AsyncStream.Continuation` and buffering policies:** <https://developer.apple.com/documentation/swift/asyncstream/continuation>

## WWDC sessions (free, watch in this order)

- **"Introducing Combine"** (WWDC19) — the original framework introduction; publishers, subscribers, operators:
  <https://developer.apple.com/videos/play/wwdc2019/722/>
- **"Combine in Practice"** (WWDC19) — building real pipelines, the SwiftUI bridge:
  <https://developer.apple.com/videos/play/wwdc2019/721/>
- **"Meet AsyncSequence"** / **"Meet async/await in Swift"** (WWDC21) — the async-streams model that supersedes most Combine use:
  <https://developer.apple.com/videos/play/wwdc2021/10058/>
  <https://developer.apple.com/videos/play/wwdc2021/10132/>
- **"Explore structured concurrency in Swift"** (WWDC21) — cancellation and task trees, which `.task` and `AsyncStream` rely on:
  <https://developer.apple.com/videos/play/wwdc2021/10134/>
- **"Beyond the basics of structured concurrency"** (WWDC23) — `onTermination`, cancellation handlers, the lifecycle details an `AsyncStream` needs:
  <https://developer.apple.com/videos/play/wwdc2023/10170/>
- **"Discover concurrency in SwiftUI"** (WWDC21) — `.task`, `.task(id:)`, and where reactivity belongs in a view:
  <https://developer.apple.com/videos/play/wwdc2021/10019/>

## The Combine-vs-async lineage (why this matters)

Combine arrived in 2019 as Apple's first-party reactive framework (a Rx-shaped answer); `async`/`await` and `AsyncSequence` arrived in 2021 and absorbed most of what Combine was used for. Understanding the timeline is the "when each" answer.

- **Combine release context** — it has seen little evolution since 2021; Apple's concurrency investment is structured concurrency. This is why new code defaults async-first.
- **The `@Published`/`ObservableObject` → `@Observable` migration** (Week 8) is the same story at the state layer: the Observation framework replaced Combine's SwiftUI bridge. Re-read Apple's migration guide with that lens:
  <https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — Combine and Concurrency guides.** Paul Hudson's free, current references for both `debounce` pipelines and `AsyncStream`:
  <https://www.hackingwithswift.com/quick-start/concurrency>
- **Donny Wals — "Practical Combine" and the async-sequences series.** The most production-focused writing on bridging and back-pressure:
  <https://www.donnywals.com/category/swift/>
- **Swift by Sundell — the Combine and concurrency articles.** Clear, measured comparisons of the two worlds:
  <https://www.swiftbysundell.com/>
- **Point-Free — "Concurrency" collection.** Deep, opinionated material on `AsyncStream`, back-pressure, and where the two models differ (some free episodes):
  <https://www.pointfree.co/collections/concurrency>
- **Matt Massicotte — concurrency blog.** The clearest current writing on Swift 6 strict concurrency as it touches streams and actors:
  <https://www.massicotte.org/>

## Testing references (for the integration project)

- **XCUITest — UI testing reference.** The integration project is UI-tested with XCUITest:
  <https://developer.apple.com/documentation/xctest/user-interface-tests>
- **"Testing asynchronous code" with Swift Testing** — confirmations and `async` test functions for the stream tests:
  <https://developer.apple.com/documentation/testing/>
- **`Clock` / `ContinuousClock` / `SuspendingClock`** — controllable time for debounce tests (and TCA's `TestClock` from Week 11):
  <https://developer.apple.com/documentation/swift/clock>

## Open-source projects to read this week

You learn more from one hour reading a real reactive pipeline than from three hours of tutorials. Pick one and trace a single stream end to end:

- **`apple/swift-async-algorithms`** — Apple's package of async sequence operators (`debounce`, `throttle`, `combineLatest`, `merge`) — the `AsyncSequence` analogue of Combine's operators, and the *idiomatic* way to debounce an async stream in 2026. Read how `debounce` is implemented:
  <https://github.com/apple/swift-async-algorithms>
- **`CombineCommunity/CombineExt`** — community operators that fill gaps in Combine; instructive for understanding the operator model even if you write async code:
  <https://github.com/CombineCommunity/CombineExt>
- **Apple's "Fruta" / "Food Truck" sample apps** — show `.task`, `.onReceive`, and the modern reactive placement in a real SwiftUI app:
  <https://developer.apple.com/documentation/swiftui/>

## Tools you'll use this week

- **Xcode 16+** — Combine and the concurrency runtime ship with the SDK; no package needed for the core week.
- **`swift-async-algorithms`** (optional but recommended) — add via **File ▸ Add Package Dependencies ▸ `https://github.com/apple/swift-async-algorithms`** to get a production-grade async `debounce` for the challenge's stretch.
- **XCUITest** — built into Xcode; the integration project records a UI test that types into the search field and asserts the debounced result.
- **Instruments — "Swift Concurrency" template** — visualises tasks, continuations, and `await` suspensions; use it to *see* the debounce drop intermediate work.

## Free reading (chapter-level, not whole books)

- **The Swift Programming Language — "Concurrency" chapter** (linked above) covers `async`/`await`, tasks, and async sequences end to end, free.
- **Apple's Combine article group** (the "Processing published elements" and "Controlling publishing with connectable publishers" articles) is effectively a free Combine primer.

## Paid books (optional, clearly marked)

- **"Practical Combine" — Donny Wals** (paid). The most production-focused Combine book; worth it if you maintain a Combine codebase.
- **"Combine: Asynchronous Programming with Swift" — Kodeco/raywenderlich** (paid). Thorough operator-by-operator coverage; dated on the async side but still the clearest Combine deep dive in print.

---

*If a link 404s, please open an issue so we can replace it.*
