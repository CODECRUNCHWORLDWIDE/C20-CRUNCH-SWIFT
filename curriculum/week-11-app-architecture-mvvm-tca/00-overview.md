# Week 11 — App architecture: MVVM, TCA, and the case against VIPER

Welcome to Week 11 of **C20 · Crunch Swift**. For four weeks you have been building features. Week 8 taught you state ownership, Week 9 taught you navigation, Week 10 taught you persistence — and at no point did anyone ask "where should this code *live*?" The notes app works because the surface area was small enough that scattering logic through the views was survivable. This week the question stops being avoidable. You add one more real feature — search-and-filter — and you discover that *where* you put the logic that drives it decides whether the app is testable, reviewable, and changeable, or whether it slowly becomes the thing nobody wants to touch.

This is the architecture week, and architecture is the most over-discussed and under-understood topic in iOS. The internet will sell you VIPER, MVVM, MVVM-C, MVP, Clean Architecture, Redux, TCA, "vanilla SwiftUI," and a dozen acronyms with strong opinions and weak evidence. We are going to cut through it with one organising principle: **architecture is the set of constraints you accept on purpose so that change stays cheap.** Every pattern is a trade — more structure buys testability and team-scaling at the cost of indirection and boilerplate. The senior skill is not knowing the patterns. It is knowing *which trade a given project should make*, and being able to defend it in a code review and write it down in an architectural decision record.

We teach three points on the spectrum, in order of increasing structure. **Plain SwiftUI + `@Observable`** — the "use the language" architecture, where the Observation framework you learned in Week 8 *is* your view model and you add no layer at all. **MVVM as a discipline** — extract an `@Observable` view model that owns the feature's state and logic, keep the view dumb, and unit-test the view model with zero UI. And **The Composable Architecture (TCA)** by Point-Free — a full unidirectional-data-flow framework with reducers, effects, and a dependency system, where every state change is a value, every side effect is described before it runs, and the entire feature is exhaustively testable as a sequence of `(state, action) -> state` assertions. You will implement the *same* search-and-filter feature in plain `@Observable` MVVM and in TCA, side by side, and feel exactly what the extra structure costs and buys.

And we make the case against VIPER explicitly — not as a strawman, but as a pattern that solved a real problem (the Massive View Controller of UIKit, 2014) that **SwiftUI already solved a different way.** VIPER's five layers and protocol-per-edge ceremony were a reasonable answer to a question the modern Swift toolchain no longer asks. Understanding *why* it made sense then, and why it does not now, is how you avoid cargo-culting it into a SwiftUI codebase where it is pure overhead.

You close the week by writing an **architectural decision record** — a one-page ADR that states the decision, the context, the options you weighed, and the consequences. The ability to write a crisp ADR is the actual deliverable. Anyone can have an opinion about architecture; a senior engineer can write the half-page that makes the team's decision legible six months later when someone asks "why is it built this way?"

## Learning objectives

By the end of this week, you will be able to:

- **Articulate** the architecture spectrum from "no architecture" (plain SwiftUI + `@Observable`) through MVVM to TCA, and explain what each point on it trades structure *for* — testability, team-scaling, predictability — and *against* — indirection, boilerplate, build time.
- **Implement** a feature three ways: as plain SwiftUI with an `@Observable` model in the view, as MVVM with an extracted, unit-tested `@Observable` view model, and as a TCA `Reducer` with `State`, `Action`, `body`, and `Effect`s.
- **Test** business logic without a UI: a plain Swift Testing suite over an `@Observable` view model, and a `TestStore` exhaustive assertion over a TCA reducer.
- **Design** unidirectional data flow — state in, actions out, effects described not performed — and explain why it makes state changes predictable and reproducible.
- **Inject** dependencies cleanly: via initialiser injection into an `@Observable` view model, and via TCA's `@Dependency` / `DependencyValues` system, and explain why a hidden `URLSession.shared` inside a view model is a testability bug.
- **Critique** VIPER concretely — name the five components, explain the UIKit problem it solved, and articalate why SwiftUI's declarative view layer and the Observation framework make its ceremony redundant in 2026.
- **Recognise** when "no architecture" is the *correct* answer — small feature, single owner, short-lived screen — and resist the urge to add structure that buys nothing.
- **Write** an architectural decision record (ADR): decision, context, options, consequences, status — the half-page that makes a team decision legible later.

## Prerequisites

This week assumes you have completed **C20 weeks 1–10**, or have equivalent fluency. Specifically:

- You can name the owner of any piece of SwiftUI state and reach for `@State`, `@Binding`, `@Environment`, `@Bindable` correctly — Week 8. This week's MVVM lecture is, in one sentence, "what happens when the thing `@Bindable` binds to is a deliberately-designed view model instead of an ad-hoc class."
- You understand the **Observation framework** (`@Observable`, `@Bindable`) and why it replaced `ObservableObject`/`@Published` — Week 8. `@Observable` *is* the MVVM view model in modern SwiftUI; there is no separate "MVVM library."
- You are fluent in Swift value types, protocols, and generics — Weeks 1–2. TCA leans hard on value-type `State`, protocol-driven dependencies, and generics; the `Reducer` macro and `@Dependency` only make sense if `struct`/`enum`/`some`/`any` are second nature.
- You understand structured concurrency and `Sendable` — Weeks 3–4. TCA's `Effect` is built on `async`/`await` and structured tasks; an effect that hits the network is an `async` closure the store runs and cancels for you.
- You have the **Hello, Notes** app from Weeks 7–10, now backed by SwiftData. This week's mini-project adds the search-and-filter feature to it twice (MVVM and TCA) without disturbing the persistence layer you just built.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. TCA is added as a Swift Package dependency (`swift-composable-architecture`, the 1.x line, current in 2026). Everything this week runs in the Simulator — no device, no Apple Developer membership.

## Topics covered

- **The architecture spectrum.** "No architecture" (plain SwiftUI + `@Observable`), MVVM as a discipline, and TCA as a framework — what each is, when each is correct, and the three questions (testability needs, team size, feature longevity) that pick between them.
- **Plain SwiftUI + `@Observable`.** Why the Observation framework removes most of the *reason* MVVM existed; when an `@Observable` model right in the view is genuinely the right call; the cost of doing this past a certain feature size.
- **MVVM as a discipline.** The view model as an `@Observable` class that owns feature state and logic; the dumb view that only renders and forwards intent; initialiser-based dependency injection; unit-testing the view model with Swift Testing and zero UI.
- **Unidirectional data flow.** State flows down, actions flow up, effects are *described* before they run; why this makes a feature reproducible (replay the actions, get the state) and where SwiftUI's two-way `@Binding` fits.
- **The Composable Architecture (TCA).** `@Reducer`, `State`, `Action`, the `body` / `Reduce` closure, `Effect` (the side-effect description), `Store`, the SwiftUI `@Bindable var store` integration, and composition with `Scope` and `forEach`.
- **TCA dependencies.** `@Dependency`, `DependencyValues`, `DependencyKey`, `withDependencies`, and `liveValue` / `testValue` / `previewValue` — the system that makes effects swappable and the reducer exhaustively testable.
- **Testing TCA.** `TestStore`, exhaustive assertions (`await store.send(.action) { $0.field = ... }`), receiving effect actions (`await store.receive(...)`), `TestClock` for time, and why exhaustivity catches the bug you didn't write a test for.
- **The case against VIPER.** The five components (View, Interactor, Presenter, Entity, Router), the UIKit Massive-View-Controller problem it solved in 2014, and why SwiftUI's declarative view + Observation + value-typed navigation make its protocol-per-edge ceremony redundant today.
- **When "no architecture" is correct.** The settings screen, the one-off sheet, the single-owner feature — where adding a view model or a reducer buys nothing and costs indirection. Resisting structure is a skill.
- **Architectural decision records (ADRs).** The five-section format (title/status, context, decision, options considered, consequences) and why writing one is the actual senior deliverable, not the code.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | The spectrum; plain `@Observable`; MVVM as a discipline; DI         |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | MVVM testing; unidirectional flow; intro to TCA reducers/effects    |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | TCA dependencies + `TestStore`; the case against VIPER; challenge   |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | When no-architecture wins; writing an ADR; mini-project kickoff     |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — search-and-filter in MVVM and in TCA                 |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; the ADR; side-by-side comparison            |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                         |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Point-Free's TCA docs and videos, Apple's Observation/architecture guidance, the canonical MVVM and VIPER writing, and the ADR references |
| [lecture-notes/01-the-architecture-spectrum-and-mvvm.md](./02-lecture-notes/01-the-architecture-spectrum-and-mvvm.md) | The spectrum end to end: plain `@Observable`, MVVM as a discipline, dependency injection, unidirectional data flow, and testing a view model with zero UI |
| [lecture-notes/02-tca-and-the-case-against-viper.md](./02-lecture-notes/02-tca-and-the-case-against-viper.md) | TCA in depth — reducers, effects, dependencies, `TestStore` — the concrete case against VIPER, when "no architecture" wins, and how to write an ADR |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-extract-a-view-model.md](./03-exercises/exercise-01-extract-a-view-model.md) | Take a view with logic crammed inside it, extract an `@Observable` view model with injected dependencies, and unit-test it with zero UI |
| [exercises/exercise-02-reducer-and-teststore.swift](./03-exercises/exercise-02-reducer-and-teststore.swift) | Write a small TCA `@Reducer` with `State`/`Action`/`Effect` and prove it with an exhaustive `TestStore` |
| [exercises/exercise-03-dependency-injection.swift](./03-exercises/exercise-03-dependency-injection.swift) | Register a TCA `@Dependency` with live/test/preview values and swap it in a `TestStore` to make an effect deterministic |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-same-feature-three-ways.md](./04-challenges/challenge-01-same-feature-three-ways.md) | Implement one feature in plain SwiftUI, MVVM, and TCA; measure the line count, test coverage, and change cost; write the ADR that picks one |
| [quiz.md](./05-quiz.md) | 13 questions on the spectrum, MVVM, unidirectional flow, TCA, dependencies, VIPER, and ADRs |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for "search-and-filter, two ways": the same feature in `@Observable` MVVM and in TCA, plus the ADR that decides what ships |

## The "defend it in review" promise

Week 8 gave you "renders exactly once." Week 9 gave you "restores from a cold launch." Week 10 gave you "survives the process dying." Week 11 adds the discipline a senior reviewer actually probes for:

> **You can defend the architecture in a code review without saying "best practice."** When a reviewer asks "why is this a view model and not just code in the view?" or "why TCA here and not for the settings screen?", you answer with the trade — testability needs, team size, feature longevity — not with a cargo-culted rule. And you can point at the ADR where you wrote the decision down.

"It's the standard pattern" is not an engineering answer; it is the absence of one. The skill this week earns is having a *reason*, and being able to write the reason in five sentences.

## A note on what's not here

Week 11 is the *architecture* week. It deliberately does **not** cover:

- **Networking.** TCA effects that hit a real server, retries, and offline handling are Week 13. This week's effects are simple `async` calls (a clock tick, a search debounce) so the focus stays on the *shape* of the architecture, not the network.
- **Navigation as architecture.** TCA has a full navigation/stack story (`StackState`, `@Presents`) and so does MVVM-C ("Coordinators"). We use the value-typed `NavigationStack` you already built in Week 9 and keep navigation out of the reducer this week. TCA navigation is flagged and deferred.
- **The "one true architecture."** There isn't one. This week is explicitly about *choosing*, and the mini-project deliverable is an ADR that defends a choice for a *specific* context — not a universal verdict.

The point of Week 11 is narrow and deep: three points on the architecture spectrum, the trade each makes, the same feature built two of those ways, and the ADR that makes the choice legible.

## Up next

Continue to **Week 12 — Combine, async/await, and AsyncSequence** once you have shipped this week's mini-project and written the ADR. Week 12 takes the effects you described in TCA and the async work you did in your view models and asks the reactive question underneath them: when is the right tool Combine, when is it `async`/`await`, and when is it `AsyncStream`? The search-as-you-type debounce you wired this week becomes the worked example — you will implement it with both Combine and `AsyncStream` and compare. Then Week 12 is the Phase II integration project ("Notes v1"), which assumes you can pick an architecture and defend it. Earn that this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
