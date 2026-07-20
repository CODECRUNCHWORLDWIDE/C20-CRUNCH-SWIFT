# Week 8 — Quiz

Twelve questions on state ownership, the Observation framework, `@Bindable`, `@Environment`, view identity, and the re-render storm. Take it with your lecture notes closed. Aim for 9/12 before moving to Week 9. Answer key at the bottom — don't peek.

---

**Q1.** Which statement best captures the one rule of SwiftUI state ownership?

- A) Every view should hold its own copy of any state it displays.
- B) Every piece of mutable state has exactly one owner; other views read a copy, a write-through binding, or observe a shared model.
- C) All shared state must live in a global singleton injected into the environment.
- D) State should be duplicated between parent and child so each can update independently.

---

**Q2.** You write `@State private var count = 0` in a view. Why does `count` *not* reset to `0` every time `body` re-evaluates?

- A) Because `@State` is `private`, which makes Swift cache the value.
- B) Because `body` is only called once per view.
- C) Because `@State`'s storage is managed by SwiftUI keyed to the view's identity, separate from the disposable view struct.
- D) Because the `= 0` initialiser is only legal on `let`, so the compiler keeps the value constant.

---

**Q3.** A child view only *displays* a string its parent owns; it never changes it. What should the child's property be?

- A) `@Binding var text: String`
- B) `@State private var text: String`
- C) `let text: String`
- D) `@Environment(\.text) var text: String`

---

**Q4.** What is the headline behavioural difference between an `@Observable` model and a legacy `ObservableObject` with `@Published` properties, with respect to view re-rendering?

- A) `@Observable` re-renders every observing view on any change; `ObservableObject` re-renders only readers of the changed property.
- B) `@Observable` re-renders only views that read the specific property that changed; `ObservableObject` re-renders every view holding the object on any `@Published` change.
- C) They are identical; `@Observable` is only a syntax change.
- D) `@Observable` never re-renders views; you must call `objectWillChange.send()` manually.

---

**Q5.** You hold a shared `@Observable` model at the view that creates it. Which is correct?

- A) `let store = NotesStore()`
- B) `@StateObject private var store = NotesStore()`
- C) `@ObservedObject var store = NotesStore()`
- D) `@State private var store = NotesStore()`

---

**Q6.** Inside a view you read a model from the environment with `@Environment(NotesStore.self) private var store`. You now need a `Binding` to `store.sortNewestFirst` for a `Toggle`. What is the idiomatic line to add inside `body`?

- A) `let binding = Binding($store.sortNewestFirst)`
- B) `@Bindable var store = store`  (then use `$store.sortNewestFirst`)
- C) `@State var store = store`
- D) `let store = store.binding()`

---

**Q7.** A view contains `SomeChildView().id(UUID())`. What happens, and is it correct?

- A) Nothing special; `.id(UUID())` is a no-op and is fine.
- B) SwiftUI gives the child a new identity every render, destroying and recreating it (and its `@State`) each time — this is a bug.
- C) It caches the child so it never re-renders — a performance optimisation.
- D) It makes the child observe the `UUID` and re-render only when the UUID changes — which it never does, so the child never updates.

---

**Q8.** Which is the correct use of `onChange(of:)` according to the data-flow story?

- A) To derive a stored `@State` value `b` from another value `a` by writing `onChange(of: a) { b = f($1) }`.
- B) To trigger a side effect (kick off a search, log analytics) in response to a value changing.
- C) To replace `body` so the view does not recompute.
- D) To create a two-way binding between two `@State` properties.

---

**Q9.** A detail view shows a note based on `let noteID: UUID`, loading it asynchronously. The same view is reused (same structural position) for different notes as the user navigates. Which modifier ensures the load re-runs when `noteID` changes?

- A) `.onAppear { load() }`
- B) `.task { load() }`
- C) `.task(id: noteID) { await load() }`
- D) `.onChange(of: noteID) { }` with an empty closure

---

**Q10.** In the legacy model, a view writes `@ObservedObject private var store = LegacyStore()` (creating the store itself). What is the bug?

- A) `@ObservedObject` cannot be `private`, so it will not compile.
- B) `@ObservedObject` does not own the object's lifetime, so the store is re-created on every parent re-render, wiping its state and restarting any in-flight work.
- C) `@ObservedObject` re-renders too rarely, so the view shows stale data.
- D) There is no bug; this is the correct legacy pattern for a self-owned store.

---

**Q11.** You add `let _ = Self._printChanges()` to a row's `body` and, on a single keystroke in an unrelated search field, you see the row print `@identity changed`. What does that message most likely indicate?

- A) The row's data changed by value — an expected, healthy re-render.
- B) The row's identity changed — SwiftUI tore it down and rebuilt it, likely due to an unstable `.id` or structural-identity churn. This is a bug.
- C) The row read a new environment value.
- D) The row's `@State` was modified during the view update.

---

**Q12.** In a draft-and-commit edit sheet, why do you bind the `TextField`s to a *draft* object rather than directly to the live model via `@Bindable`?

- A) Because `@Bindable` cannot bind a `TextField`.
- B) Because binding directly to the live model would mutate it on every keystroke, making the list storm and making "Cancel" impossible to honour.
- C) Because a draft is faster to allocate than a live model.
- D) Because the live model is a value type and cannot be bound.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — The one rule from Lecture 1 §1.1. There is no "two owners" configuration in correct SwiftUI; A and D are the duplicated-state bug, C is the over-eager-singleton anti-pattern.

2. **C** — `@State` storage lives in SwiftUI-managed storage keyed by the view's identity, not in the disposable view struct, so it survives `body` re-evaluation. `private` is a style/encapsulation requirement, not the mechanism (A); `body` is called many times (B); D is nonsense.

3. **C** — Take the least powerful tool that works. Read-only display needs a plain `let`. `@Binding` (A) implies the child writes back, which it does not; `@State` (B) would make the child own a copy, decoupling it from the parent; D misuses the environment for a one-level pass-down.

4. **B** — Per-property tracking is the Observation framework's headline win. `ObservableObject` invalidation is object-level (any `@Published` change re-renders every observer); `@Observable` re-renders only views that read the changed property.

5. **D** — `@State private var store = NotesStore()` is the modern creation/ownership form. B is the legacy equivalent (correct in pre-iOS-17 code but not what we write now); A re-creates the store every render (a bug); C is the "restarts every render" footgun.

6. **B** — `@Bindable var store = store` inside `body` re-binds the environment model locally so you get `$`-projectable bindings (`$store.sortNewestFirst`). This is the §1.5 idiom. The others are invented syntax.

7. **B** — `.id(UUID())` generates a new identity every render, so SwiftUI destroys and recreates the child each time, resetting its `@State` and restarting its `.task`. `.id` must be a stable, meaningful value or omitted entirely.

8. **B** — `onChange(of:)` is for side effects, not state derivation. A is the classic "keep two states manually in sync" bug — `b` should be a computed property. C and D misdescribe the modifier.

9. **C** — `.task(id:)` cancels and re-runs the async work when the `id` value changes, exactly the reused-detail-view case. Plain `.task` (B) and `.onAppear` (A) run once and would keep showing the first note; D detects the change but does no loading.

10. **B** — `@ObservedObject` observes but does not own; SwiftUI re-runs the property initialiser on every parent re-render, constructing a fresh `LegacyStore()` each time and wiping its state. The fix is `@StateObject` for the creating view. (Modern equivalent: use `@State`.)

11. **B** — `@identity changed` means a teardown/rebuild, almost always a bug — typically an unstable `.id` or a structural-identity change. A healthy data re-render prints `@self changed` or `_property changed`; D prints a runtime "Modifying state during view update" warning, not `@identity changed`.

12. **B** — Binding directly to the live model mutates it on every keystroke, which storms the list and makes "Cancel" a lie (there is nothing to discard — the change already happened). The draft gives you an explicit commit boundary: Save copies back, Cancel drops the draft. `@Bindable` *can* bind a `TextField` (A is false); the draft choice is about the commit boundary, not allocation speed.

</details>

---

If you scored under 9, re-read the lectures for the questions you missed — especially Q4 (per-property tracking), Q6 (the `@Bindable var x = x` idiom), and Q12 (draft-and-commit), which are the load-bearing ideas of the week. If you scored 11 or 12, you're ready for the [homework](./homework.md) and the mini-project.
