# Week 8 — State: `@State`, `@Observable`, `@Environment`, `@Bindable`

Welcome to Week 8 of **C20 · Crunch Swift**. Last week you learned that a SwiftUI view is a function from state to a view tree, and that `body` is re-invoked and diffed whenever that state changes. This week we answer the question that decides whether your app is a joy or a misery to work on: *who owns the state, and how does it flow?*

This is the single most consequential topic in the entire SwiftUI half of the track. Get state ownership right and your views are small, your data flows in one direction, your previews work, and your re-renders are surgical. Get it wrong and you ship a re-render storm — a view that recomputes its `body` dozens of times per keystroke, drops frames in Instruments, and corrupts a half-finished edit because two views think they each own the same value. Every SwiftUI bug that is not a layout bug is, at bottom, a state-ownership bug. By Friday you will be able to look at any piece of state in a SwiftUI app and name, without hesitation, which primitive owns it: `@State`, `@Binding`, `@Environment`, `@Bindable`, or a plain `let`. And you will be able to *defend that choice in a code review* — which is the actual skill this week earns.

The big change you are walking into is the **Observation framework**. Before iOS 17 (2023), SwiftUI's observation story was `ObservableObject`, `@Published`, `@StateObject`, and `@ObservedObject` — a Combine-based system that worked but had a fatal performance characteristic: *any* `@Published` change on an object invalidated *every* view that held a reference to it, whether or not that view read the property that changed. The Observation framework (`@Observable`, `@Bindable`) fixed this at the language level. A view now re-renders only when a property it *actually reads* changes. This is not a small optimisation; it is a different model, and it is the model you will write for the rest of this track and your career. We teach the modern model as the default and cover the legacy `@StateObject`/`@ObservedObject` distinction so you can read the millions of lines of pre-2023 SwiftUI you will inevitably inherit — but we do not write it from scratch unless we have a reason.

The mental shift this week is from "I store data in views" to "views *observe* data they do not own." A `@State` is a view's private scratchpad — it owns the value, it is the source of truth, and it survives `body` re-evaluation. A `@Binding` is a *write-through reference* to a `@State` someone else owns — the classic example is a `TextField` that edits a parent's string. `@Environment` is dependency injection done the SwiftUI way — you put a value at the top of a view tree and any descendant reads it without anyone in between passing it down (the cure for "prop-drilling"). `@Observable` is how a reference-type model announces its changes. `@Bindable` is the bridge that lets you make two-way bindings *into* an `@Observable` model's properties. Five primitives. The whole week is learning the boundaries between them and the bug that lives on each side of each boundary.

We end the week by adding full CRUD to the **Hello, Notes** app you built in Week 7. You will model an `@Observable` `NotesStore`, inject it through `@Environment` so the whole app shares one source of truth, edit a note in a sheet, and — this is the acceptance bar — prove with `onChange(of:)` and a render counter that the list updates *exactly once* when you save and *never* when you cancel. That last sentence is the difference between a hobbyist's SwiftUI app and a senior engineer's.

## Learning objectives

By the end of this week, you will be able to:

- **Name** the owner of any piece of SwiftUI state and pick the correct primitive — `@State`, `@Binding`, `@Environment`, `@Bindable`, or a plain `let` — for a given ownership scenario, and defend the choice in a code review.
- **Explain** how `@State` makes a view the source of truth for a value, why it must be `private`, and how SwiftUI keeps it alive across `body` re-evaluations using view identity.
- **Wire** a two-way `@Binding` from a parent's `@State` down into a child control, and recognise the three ways to create a binding (`$value`, `Binding(get:set:)`, and a derived/projected binding).
- **Adopt** the Observation framework: annotate a reference-type model with `@Observable`, hold it with `@State` at its owning view, and understand why a reading view re-renders *only* when a property it reads changes.
- **Inject** an `@Observable` model into the environment with `.environment(_:)` and read it in a deep descendant with `@Environment(MyModel.self)`, eliminating prop-drilling.
- **Use** `@Bindable` to produce two-way bindings into an `@Observable` model's properties — the modern replacement for `ObservableObject` + `@Binding` plumbing.
- **Distinguish** the legacy `@StateObject` (owns/creates) from `@ObservedObject` (observes/does-not-own) and explain the bug class of using `@ObservedObject` where `@StateObject` was required.
- **Reason** about view identity — structural identity vs explicit `.id(_:)` — and predict when a state-holding view is destroyed and recreated (losing its `@State`).
- **Apply** `onChange(of:)` and `task { }` correctly, including the `initial:` parameter, the two-value closure, and `task(id:)` for re-running async work when an identity changes.
- **Diagnose** a re-render storm with a render counter, identify its cause (misplaced `@State`, a coarse `ObservableObject`, an unstable `.id`, or an over-broad environment read), and fix it.

## Prerequisites

This week assumes you have completed **C20 weeks 1–7**, or have equivalent fluency. Specifically:

- You can read and write idiomatic Swift — value vs reference types, `let` vs `var`, optionals, closures — Weeks 1–2. State ownership *is* the value-vs-reference distinction wearing a SwiftUI hat; if `struct` vs `class` is still fuzzy, re-read Week 1 first.
- You understand `Sendable`, `@MainActor`, and actor isolation — Week 4. SwiftUI views and `@Observable` models are `@MainActor`-isolated in practice; the compiler will hold you to it.
- You can build and run a SwiftUI app in Xcode 16+, structure a view hierarchy, and reason about modifier order — Week 7. You have the **Hello, Notes** app from Week 7 checked into Git; this week's mini-project compounds on it.
- You are comfortable with the iOS Simulator, Xcode previews, and the View debugger.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. Everything this week runs in the Simulator — no device, no Apple Developer membership. The Observation framework requires iOS 17 / macOS 14 as the deployment minimum; we target iOS 17+ for the whole Phase II.

## Topics covered

- **State ownership** as the organising principle: every piece of mutable state has exactly one owner, and every other view either receives a read-only copy, a write-through binding, or observes a shared model.
- **`@State`**: a view-owned source of truth for a value type (or, with `@Observable`, the *creation* point of a reference-type model). Why it is `private`, how it survives `body` re-evaluation, and how view identity keeps it alive.
- **`@Binding`**: a write-through reference to state owned elsewhere. The `$` projection, `Binding(get:set:)`, derived bindings, constant bindings for previews, and `Binding` to optional/collection elements.
- **The Observation framework**: the `@Observable` macro, what it generates (`ObservationRegistrar`, per-property tracking), and the headline win — a view re-renders only when a property it *reads in `body`* changes.
- **`@Bindable`**: deriving two-way bindings into an `@Observable` model's properties; when you need it (editing model fields in a control) and when you do not (read-only display).
- **`@Environment`**: SwiftUI's dependency-injection channel. System values (`\.dismiss`, `\.colorScheme`, `\.modelContext`) and custom `@Observable` objects via `.environment(_:)` / `@Environment(Type.self)`. The prop-drilling problem it solves.
- **`@EnvironmentObject` (legacy)**: the `ObservableObject`-era environment injection, why it crashed at runtime when you forgot to inject it, and why the typed `@Environment(Type.self)` is strictly better.
- **`@StateObject` vs `@ObservedObject` (legacy)**: `@StateObject` creates and owns (initialised once, survives re-render); `@ObservedObject` observes a reference passed in (does not own, can be recreated). The classic bug: a timer/network task that restarts on every parent re-render because someone used `@ObservedObject` where `@StateObject` was required.
- **View identity**: structural identity (position in the view tree) vs explicit identity (`.id(_:)`). How identity decides whether SwiftUI *updates* a view or *destroys and recreates* it — and what that does to `@State`.
- **The `.id(_:)` modifier**: forcing a new identity to reset a subtree's state on purpose, and the foot-gun of an unstable `.id` that resets state by accident.
- **`onChange(of:)`**: the modern two-parameter form `(oldValue, newValue)`, the `initial:` flag, and where it belongs in the data-flow story (side effects, not state derivation).
- **`task { }` and `task(id:)`**: attaching async work to a view's lifetime, automatic cancellation when the view disappears, and re-running on an identity change.
- **The re-render storm**: what it is, the four common causes, how to *see* it with a render counter (`let _ = Self._printChanges()` and an explicit counter), and how to fix each cause.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                       | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|-------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | State ownership; `@State`, `@Binding`, view identity        |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Observation framework; `@Observable`, `@Bindable`           |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | `@Environment`; legacy `@StateObject`/`@ObservedObject`     |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | The re-render storm; `onChange(of:)`, `task {}`; challenge   |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — CRUD on Hello, Notes; sheet edit flow         |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; render-count verification           |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                  |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                             | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's Observation docs, the WWDC "Discover Observation" session, the SwiftUI data-flow guide, and the canonical community writing on state ownership |
| [lecture-notes/01-state-ownership-who-owns-what.md](./02-lecture-notes/01-state-ownership-who-owns-what.md) | State ownership end to end: the five primitives, the ownership decision table, view identity, and the bug class of getting each one wrong |
| [lecture-notes/02-the-re-render-storm-walkthrough.md](./02-lecture-notes/02-the-re-render-storm-walkthrough.md) | A line-by-line walkthrough of a re-render storm: how to see it, the four causes, and the fix for each — with `Self._printChanges()` and a render counter |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-environment-injection-no-prop-drilling.md](./03-exercises/exercise-01-environment-injection-no-prop-drilling.md) | Build an `@Observable` model, inject it via `@Environment`, read it from a deep child without prop-drilling |
| [exercises/exercise-02-bindable-sheet-edit.swift](./03-exercises/exercise-02-bindable-sheet-edit.swift) | Use `@Bindable` to two-way bind a sheet's fields to a model and confirm edits propagate exactly once |
| [exercises/exercise-03-reproduce-and-fix-a-render-storm.swift](./03-exercises/exercise-03-reproduce-and-fix-a-render-storm.swift) | Reproduce a render storm caused by misplaced `@State`, fix it, and verify with a render counter |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-edit-in-sheet-cancel-discards-save-commits.md](./04-challenges/challenge-01-edit-in-sheet-cancel-discards-save-commits.md) | An edit-in-a-sheet flow where cancel discards and save commits, proven with `onChange(of:)` to update the list exactly once on save and never on cancel |
| [quiz.md](./05-quiz.md) | 12 questions on ownership, Observation, `@Bindable`, `@Environment`, identity, and the render storm |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for "Hello, Notes — CRUD edition": an `@Observable` `NotesStore` injected via `@Environment`, edit-in-a-sheet, list updates exactly once |

## The "renders exactly once" promise

Week 7 gave you the contract that a SwiftUI view's `body` is a pure function of state. Week 8 adds the second contract, the one a senior reviewer actually checks:

> **A user action should re-render the minimum set of views, the minimum number of times.** Tapping "Save" in an edit sheet should re-render the list cell that changed — once. It should not re-render the whole list, it should not re-render the cell three times, and it should not re-render anything at all when the user taps "Cancel."

You will *prove* this with a render counter this week, not assert it. "It feels fast enough" is not an engineering statement. "The list cell rendered exactly once on save and zero times on cancel — here is the counter output" is.

## A note on what's not here

Week 8 is the *state* week. It deliberately does **not** cover:

- **Navigation state** (`NavigationStack`, `NavigationPath`, `navigationDestination`, deep links). Navigation is state, and we treat it as state — but the full treatment is Week 9. This week we keep navigation to `.sheet(isPresented:)` and `.sheet(item:)` so the focus stays on ownership.
- **Persistence** (`SwiftData`, `@Model`, `@Query`, `ModelContext`). The `NotesStore` this week is in-memory. Week 10 swaps it for SwiftData, and you will see how cleanly the swap goes *because* the ownership boundary was drawn correctly this week.
- **Combine** (`@Published`, `ObservableObject` as a primary tool, operators). We cover the *legacy* `ObservableObject`/`@StateObject`/`@ObservedObject` trio so you can read old code, but Combine proper is Week 12, where we compare it to `async/await` and `AsyncSequence`.
- **App architecture** (MVVM-as-discipline, TCA). The "plain SwiftUI + `@Observable`" approach you learn this week *is* an architecture — the one Apple ships and the one we default to. The architecture comparison (MVVM, TCA, the case against VIPER) is Week 11.

The point of Week 8 is narrow and deep: five state primitives, the boundary between each pair, the bug on each boundary, and the discipline to render exactly once.

## Up next

Continue to **Week 9 — Navigation, deep links, scenes** once you have shipped this week's mini-project with the render-count verification. Week 9 treats navigation as just another kind of state — `NavigationPath` is a `@State` you mutate, a deep link is a write to that state from outside — which only makes sense once this week's ownership model is reflexive. The notes app keeps growing: Week 9 adds a sidebar-detail layout and a `notes://open/:id` deep link, Week 10 adds SwiftData, and by Week 12 it is a polished multi-platform app. Every one of those weeks assumes you can name the owner of any piece of state on sight. Earn that this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
