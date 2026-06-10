# Week 11 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 12. Answer key with explanations at the bottom — don't peek.

---

**Q1.** In one sentence, what does "moving right" on the architecture axis (plain SwiftUI → MVVM → TCA) buy you, and what does it cost?

- A) It buys nothing and costs nothing; the patterns are interchangeable.
- B) It buys testability, predictability, and team-scaling; it costs indirection, boilerplate, and sometimes build time.
- C) It buys runtime performance; it costs memory.
- D) It buys smaller binaries; it costs readability.

---

**Q2.** Which three questions best decide where a feature belongs on the architecture axis?

- A) Which pattern is trending; what the senior engineer prefers; what the docs recommend.
- B) How much logic needs testing in isolation; how many people touch it over how long; how bad a wrong state transition is.
- C) How many views it has; how much state it holds; how many colors it uses.
- D) Whether it's iPhone or iPad; whether it uses SwiftData; whether it has navigation.

---

**Q3.** Why does modern "MVVM in SwiftUI" not require a reactive library (RxSwift/ReactiveCocoa)?

- A) SwiftUI forbids reactive libraries.
- B) The Observation framework (`@Observable`) provides the model-to-view binding that MVVM used to need a reactive library to create.
- C) MVVM never needed binding.
- D) Reactive libraries are now built into the kernel.

---

**Q4.** A view model reaches for `URLSession.shared` directly inside one of its methods. Why is this a problem?

- A) It's a memory leak.
- B) It's a *hidden dependency* — there's no seam to inject a fake, so the method can't be tested without hitting the real network.
- C) `URLSession.shared` is deprecated.
- D) It violates `Sendable`.

---

**Q5.** In MVVM, which statement about the view is correct?

- A) The view owns the business logic and the model renders it.
- B) The view is dumb: it renders the model's state and forwards user intent (method calls) to the model; it holds no business logic.
- C) The view performs the network calls and the model formats them.
- D) The view and model are the same type.

---

**Q6.** What is "unidirectional data flow"?

- A) State flows down into the view; intent (actions/method calls) flows up out of it; the model mutates state and the loop repeats — one direction.
- B) Data only ever flows from the network to the database.
- C) The view mutates the model directly and the model mutates the view directly.
- D) A pattern where data flows in a circle with no entry point.

---

**Q7.** In TCA, what is an `Effect`?

- A) A SwiftUI view modifier.
- B) A *description* of side work (a network call, a timer) that the reducer returns and the store runs and cancels — the reducer describes it but does not perform it.
- C) The feature's state.
- D) A synonym for `Action`.

---

**Q8.** Why is TCA's `State` a value type (`struct`/`enum`), and what does that enable in testing?

- A) Value types are faster; it enables nothing special.
- B) A value-type state is one inspectable, `Equatable`, copyable value, so a `TestStore` can assert the *entire* state before and after each action exhaustively.
- C) SwiftUI requires reference types, so this is a workaround.
- D) Value types can't hold logic, which simplifies tests.

---

**Q9.** In TCA, why is the default `testValue` of a dependency often `unimplemented(...)`?

- A) To make the app crash in production.
- B) So that an *unexpected* call to that dependency in a test fails loudly, forcing you to explicitly override the dependencies a feature actually uses.
- C) Because the live value isn't written yet.
- D) To disable the dependency entirely.

---

**Q10.** How does a TCA test make a 300 ms debounce deterministic and instant?

- A) It actually sleeps 300 ms of wall-clock time.
- B) It injects a `TestClock` via `@Dependency(\.continuousClock)` and calls `await clock.advance(by: .milliseconds(300))`, which fires scheduled work immediately and exactly.
- C) It removes the debounce in tests.
- D) It uses `Thread.sleep`.

---

**Q11.** What problem did VIPER's **Presenter** solve in 2014 UIKit, and why is it largely redundant in SwiftUI?

- A) It solved navigation; SwiftUI still needs it.
- B) It pushed formatted data into a view that couldn't observe a model; SwiftUI's `@Observable`/`@ObservableState` makes the view observe the model directly, so the Presenter becomes a pass-through with no job.
- C) It solved threading; actors replace it.
- D) It solved persistence; SwiftData replaces it.

---

**Q12.** Which is the *correct* architecture for a settings screen that is one `@AppStorage`-backed `Bool` toggle owned by one engineer?

- A) TCA, for exhaustive coverage.
- B) VIPER, for separation of concerns.
- C) Plain SwiftUI + `@State`/`@AppStorage` — adding a view model or reducer is structure that buys nothing here.
- D) MVVM with a `SettingsToggleViewModel`.

---

**Q13.** What is the actual senior deliverable of an architecture decision, beyond the code?

- A) A benchmark.
- B) An architectural decision record (ADR): a short document stating the decision, context, options considered, and consequences — making the *reasoning* legible later.
- C) A UML diagram.
- D) A Slack message.

---

## Answer key

**Q1 — B.** The axis is structure. Moving right buys testability, predictability, and team-scaling; it costs indirection, boilerplate, and sometimes build time. There is no globally correct point — only the right one for a feature's stakes. (Lecture 1, §1.)

**Q2 — B.** Testability need, team-and-longevity, and blast radius are the three questions. All low → no architecture; any high → climb the axis. (Lecture 1, §1; lecture 2, §5.)

**Q3 — B.** The Observation framework provides the binding (model mutation → view re-render) that MVVM historically needed a reactive library to create. That's why "MVVM in SwiftUI" is just `@Observable` plus discipline, not an imported framework. (Lecture 1, §2–3.)

**Q4 — B.** A hidden dependency has no injection seam, so the method can't be tested without the live world. The fix is to make the dependency a parameter (protocol or struct-of-closures) injected through `init`. (Lecture 1, §5.)

**Q5 — B.** The dumb view renders state and forwards intent; the view model owns the logic. If you deleted every view and kept the models, the app's behaviour would still be fully described. (Lecture 1, §3.)

**Q6 — A.** State down, intent up, model mutates, loop repeats. The clean unidirectional half of MVVM; the bidirectional `@Binding` for form input is the idiomatic exception. (Lecture 1, §4.)

**Q7 — B.** An `Effect` is a *description* of side work the reducer returns; the store runs and cancels it. The reducer describes, the store performs — which is what makes effects testable and cancellable. (Lecture 2, §1.)

**Q8 — B.** Value-type state is one inspectable, `Equatable` value, so a `TestStore` can assert the whole state exhaustively before/after each action — no "some field also changed and I didn't notice" bug class. (Lecture 2, §1, §3.)

**Q9 — B.** An `unimplemented` `testValue` fails the test if called, so a test only passes when you explicitly override the dependencies the feature uses — surfacing unexpected side effects instead of silently passing. (Lecture 2, §2.)

**Q10 — B.** Inject a `TestClock` and `advance(by:)`. Scheduled work fires immediately and exactly; no wall-clock sleep, no flake. (Lecture 2, §2–3.)

**Q11 — B.** The Presenter pushed formatted data into a non-observing view; the Observation framework makes the view observe the model directly, leaving the Presenter jobless. Each VIPER component solved a UIKit problem SwiftUI eliminated. (Lecture 2, §4.)

**Q12 — C.** Plain SwiftUI. Run the three questions: testability need, team size, blast radius — all low. A view model or reducer here is structure buying nothing. Resisting needless structure is the same judgment as adding needed structure. (Lecture 2, §5.)

**Q13 — B.** The ADR records the decision, context, rejected options, and consequences — making the *why* legible later. Anyone can choose; the senior deliverable is the half-page that defends the choice. (Lecture 2, §6.)

---

*Score 11+? On to Week 12. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — the dependency-injection seam (what makes a view model testable) and the exhaustive `TestStore` (what TCA's structure buys) are the two ideas this week is graded on.*
