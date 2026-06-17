# Week 12 — Quiz

Fourteen questions. Take it with your lecture notes closed. Aim for 11/14 before moving to Week 13. Answer key with explanations at the bottom — don't peek.

---

**Q1.** When is `async`/`await` (not Combine, not `AsyncSequence`) the right tool?

- A) For a stream of many values over time.
- B) For a *single* asynchronous result (`let user = try await fetchUser()`) — not a stream, one `await`.
- C) For debouncing user input.
- D) Never; always prefer Combine.

---

**Q2.** What does a Combine `Publisher` do before it is subscribed to?

- A) It immediately starts emitting values.
- B) Nothing — a publisher is a lazy recipe; it does no work until a subscriber attaches.
- C) It buffers values until memory runs out.
- D) It throws an error.

---

**Q3.** What is the most common Combine bug, and its fix?

- A) Using too many operators; fix: use fewer.
- B) Discarding the `AnyCancellable` returned by `sink`/`assign` — the subscription tears down immediately and nothing fires. Fix: `.store(in: &cancellables)`.
- C) Using `RunLoop.main`; fix: use `DispatchQueue`.
- D) Subscribing twice; fix: subscribe once.

---

**Q4.** What does `.debounce(for: .milliseconds(300), scheduler:)` do, and how does it differ from `.throttle`?

- A) They are identical.
- B) `debounce` emits a value after the upstream has been *quiet* for the interval (wait for silence); `throttle` emits at most one value per window (rate limit).
- C) `debounce` rate-limits; `throttle` waits for silence.
- D) Both emit every value unchanged.

---

**Q5.** In `@Published var query`, what is `$query`?

- A) A binding.
- B) A `Publisher<String, Never>` that emits on every change to `query` — `CurrentValueSubject` in property-wrapper clothing.
- C) The current value of `query`.
- D) A `Task`.

---

**Q6.** Why did `@Observable` replace `ObservableObject`/`@Published` for SwiftUI view models?

- A) `@Observable` is faster to type.
- B) `@Observable` re-renders only the views that read the changed property; `ObservableObject` re-renders everything observing the object — `@Observable`'s granularity is the win.
- C) Combine was removed from the SDK.
- D) They are identical; it was a rename.

---

**Q7.** How do you consume an `AsyncSequence`, and how is cancellation handled?

- A) With `.sink`; cancellation needs an `AnyCancellable`.
- B) With `for await` (or `for try await`); cancellation is *structural* — the loop runs inside a `Task` and stops when the task is cancelled, no `AnyCancellable`.
- C) With a delegate callback; cancellation is manual.
- D) You cannot cancel an `AsyncSequence`.

---

**Q8.** You're building an `AsyncStream` from a delegate callback. What is `continuation.onTermination` for?

- A) To emit the final value.
- B) The cleanup hook — it fires when the consumer's task is cancelled *or* you call `finish()`, so you can detach the callback / stop the source.
- C) To restart the stream.
- D) To set the buffer size.

---

**Q9.** For search-as-you-type, which `AsyncStream` buffering policy is correct, and why?

- A) `.unbounded`, to never miss a keystroke.
- B) `.bufferingOldest(1)`, to keep the first keystroke.
- C) `.bufferingNewest(1)`, because only the *latest* query matters — drop the stale intermediate keystrokes.
- D) Buffering policy doesn't matter for search.

---

**Q10.** How do you consume a framework Combine publisher (e.g. `NotificationCenter.publisher`) the async way?

- A) You can't; framework publishers force Combine in your code.
- B) Via `publisher.values`, which exposes any publisher as an `AsyncSequence` you can `for await` over — freeing you from `AnyCancellable`.
- C) By rewriting the framework.
- D) With `.sink` only.

---

**Q11.** When a Combine API *demands* a publisher but you have async work, what wraps it?

- A) `PassthroughSubject`.
- B) A `Future { promise in Task { ... } }` that publishes a single value or failure — the publisher shape over one async result.
- C) `@Published`.
- D) `for await`.

---

**Q12.** What is the difference between `.task` and `.onReceive` in SwiftUI?

- A) None.
- B) `.task` runs async work for the view's lifetime and is *auto-cancelled on disappear* (and `.task(id:)` restarts on id change); `.onReceive` subscribes to a Combine publisher for the view's lifetime and does *not* auto-restart on an id.
- C) `.onReceive` is async; `.task` is for publishers.
- D) `.task` is deprecated.

---

**Q13.** What is the 2026 default for *new* reactive code, and the main exceptions?

- A) Combine for everything.
- B) Async-first (`async`/`await`, `AsyncSequence`, `AsyncStream`, `swift-async-algorithms`); exceptions are framework Combine APIs, genuinely complex operator chains, and matching an existing Combine codebase.
- C) RxSwift.
- D) There is no default; pick randomly.

---

**Q14.** How does back-pressure differ between Combine and `AsyncSequence`?

- A) Neither has back-pressure.
- B) Combine pulls by a pre-declared *numeric demand* the publisher respects; `AsyncSequence` pulls by *suspension* (the consumer's `for await` requests the next element when ready), and `AsyncStream`'s buffering policy decides overflow behaviour.
- C) Combine has none; only async does.
- D) They are identical.

---

## Answer key

**Q1 — B.** A single async result is one `await`; it is not a stream, so Combine and `AsyncSequence` are overkill. Streams (many values over time) are where the reactive tools earn their place. (Lecture 1, §1; lecture 2, §1.)

**Q2 — B.** A publisher is a lazy recipe; it does nothing until a subscriber attaches. This laziness is why you must attach a terminal (`sink`/`assign`) and keep the cancellable. (Lecture 1, §2.)

**Q3 — B.** Discarding the `AnyCancellable` tears down the subscription instantly, so the pipeline silently does nothing. Store it in a `Set<AnyCancellable>` via `.store(in:)`. (Lecture 1, §5.)

**Q4 — B.** `debounce` waits for *silence* (emits after a quiet gap) — the search operator; `throttle` rate-limits (at most one per window). They are not the same. (Lecture 1, §4.)

**Q5 — B.** `$query` is a publisher emitting on every change — `CurrentValueSubject` in disguise. It is the most common place Combine appears in app code (the debounced-search pattern). (Lecture 1, §6.)

**Q6 — B.** `@Observable` re-renders only views that read the changed property; `ObservableObject` re-renders everything observing the object. The granularity is the win. (Lecture 1, §6; Week 8.)

**Q7 — B.** `for await` consumes an `AsyncSequence`; cancellation is structural — the loop dies with its task, no `AnyCancellable`. This is the biggest ergonomic win over Combine. (Lecture 2, §1.)

**Q8 — B.** `onTermination` is the cleanup hook, firing on task cancellation or `finish()`. Forgetting it is the async analogue of leaking a subscription. (Lecture 2, §2.)

**Q9 — C.** `.bufferingNewest(1)` — only the latest query matters, so drop the stale intermediate keystrokes. With a debounce, this fires one search per burst. `.unbounded` is the footgun that can fire a search per keystroke. (Lecture 2, §2, §7.)

**Q10 — B.** `publisher.values` exposes any publisher as an `AsyncSequence`. This frees you from framework-Combine forcing app-Combine — consume it in a `.task` with structural cancellation. (Lecture 2, §4.)

**Q11 — B.** A `Future` runs its closure once and publishes a single value/failure — the publisher shape over one async result. The rarer bridge direction (async → Combine). (Lecture 2, §4.)

**Q12 — B.** `.task` is async, view-lifetime, auto-cancelled on disappear, and `.task(id:)` restarts on id change; `.onReceive` is the Combine-publisher subscriber and does not auto-restart. Prefer `.task` for your async streams. (Lecture 1, §7; lecture 2, §5.)

**Q13 — B.** New code is async-first; Combine remains for framework APIs, complex operator chains, and existing Combine codebases. Use the right tool, defend with the matrix's reason. (Lecture 2, §6.)

**Q14 — B.** Combine pulls by numeric demand; `AsyncSequence` pulls by suspension; `AsyncStream`'s buffering policy decides overflow. For search you drop intermediate keystrokes via `.bufferingNewest(1)`. (Lecture 1, §2; lecture 2, §7.)

---

*Score 11+? On to Week 13 and Phase III. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the `AsyncStream` debounce (structural cancellation, buffering) and the `.values` bridge (consuming framework Combine the async way) are the two ideas this week is graded on.*
