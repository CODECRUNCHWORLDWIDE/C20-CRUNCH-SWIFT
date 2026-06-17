# Week 8 Homework

Six practice problems that revisit the week's topics: state ownership, the Observation framework, `@Bindable`, `@Environment`, view identity, and the re-render storm. The full set should take about **5 hours**. Work in your Week 8 Git repository (the Hello, Notes repo, or a scratch `week-08-homework` repo) so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

Every problem must build with **zero warnings** under Xcode 16+ targeting iOS 17+.

---

## Problem 1 — Pick the primitive (code review on paper)

**Problem statement.** For each of the following eight scenarios, name the correct state primitive (`let`, `@State`, `@Binding`, `@Bindable`, `@Environment`, or "computed property") and write one sentence defending the choice. Put your answers in `notes/p1-pick-the-primitive.md`.

1. A view shows a user's display name and never changes it.
2. A view owns a stepper's integer count.
3. A child `TextField` view edits a string the parent owns.
4. A deeply nested badge needs the app's shared `@Observable` `Account` model.
5. A sheet needs two-way `TextField` bindings into an `@Observable` `Draft` it was handed.
6. The app root creates the shared `@Observable` `NotesStore`.
7. A view needs `formattedTotal` derived from `subtotal` and `taxRate`, both already in state.
8. A view needs to dismiss itself.

**Acceptance criteria.**

- File `notes/p1-pick-the-primitive.md` exists with all eight answers, each with a one-sentence defence.
- Committed.

**Hint.** Walk the decision table from Lecture 1 §1.10 top to bottom for each. Note that #7 is a trick — derived values are computed properties, not stored state; and #8 is a *system* environment value (`\.dismiss`).

**Estimated time.** 30 minutes.

---

## Problem 2 — Migrate an `ObservableObject` to `@Observable`

**Problem statement.** You are given this legacy view model. Migrate it to the Observation framework and update the two views that use it.

```swift
import Combine
import SwiftUI

final class CartViewModel: ObservableObject {
    @Published var items: [String] = []
    @Published var couponCode: String = ""
    var total: Int { items.count }
}

struct CartRoot: View {
    @StateObject private var cart = CartViewModel()
    var body: some View {
        VStack { CartCount(cart: cart); CouponField(cart: cart) }
    }
}

struct CartCount: View {
    @ObservedObject var cart: CartViewModel
    var body: some View { Text("\(cart.total) items") }   // reads items only
}

struct CouponField: View {
    @ObservedObject var cart: CartViewModel
    var body: some View { TextField("Coupon", text: $cart.couponCode) }   // edits couponCode
}
```

Convert `CartViewModel` to `@Observable`, replace `@StateObject` with `@State` at the root, replace the read-only `@ObservedObject` in `CartCount` with a plain `let`, and replace the editing `@ObservedObject` in `CouponField` with `@Bindable`. Add `Self._printChanges()` to `CartCount` and prove that typing in the coupon field no longer re-renders `CartCount`.

**Acceptance criteria.**

- `CartViewModel` is `@Observable` with no `@Published` and no `ObservableObject`.
- `CartRoot` uses `@State`; `CartCount` uses `let`; `CouponField` uses `@Bindable`.
- A short note in the file (or commit message) stating: under the legacy version, did typing the coupon re-render `CartCount`? Under the migrated version, does it? (Answer: legacy yes, migrated no.)
- Build is warning-free. Committed.

**Hint.** The `@Bindable var cart: CartViewModel` in `CouponField` gives you `$cart.couponCode`. Migration cheat-sheet is in Lecture 1 §1.8.

**Estimated time.** 45 minutes.

---

## Problem 3 — Three ways to make a `Binding`

**Problem statement.** In a single SwiftUI file `homework/p3-bindings/Bindings.swift`, build one screen that demonstrates all three ways to create a `Binding` from Lecture 1 §1.3:

1. The `$` projection from a `@State` (a `TextField` editing `@State var name`).
2. A hand-built `Binding(get:set:)` — a `Binding<Bool>` derived from "is `selected` non-nil" that drives a `.sheet(isPresented:)`, and clears `selected` when dismissed.
3. A derived/element binding — a `ForEach($items)` where each row gets a `Binding` to its element and a `Toggle` writes through it.

**Acceptance criteria.**

- All three binding styles appear and work in the running app.
- The `Binding(get:set:)` correctly sets `selected = nil` when the sheet is dismissed.
- Toggling a row's `Toggle` updates exactly that element in the array.
- Build is warning-free. Committed with the running screenshot or a description of the behaviour in the commit.

**Hint.** For #2: `Binding<Bool>(get: { selected != nil }, set: { if !$0 { selected = nil } })`. For #3: `ForEach($items) { $item in Toggle(item.name, isOn: $item.done) }`.

**Estimated time.** 50 minutes.

---

## Problem 4 — Reproduce a storm and document the fix

**Problem statement.** Starting from exercise 3's stormy screen (or write your own), reproduce a re-render storm of your choice (pick at least *two* of the four causes from Lecture 2 §2.8). Instrument it with `Self._printChanges()` and a `RenderCounter`. Capture the console output of the storm. Then fix each cause and capture the console output of the calm version. Write up the before/after in `notes/p4-storm-writeup.md`.

**Acceptance criteria.**

- A buildable project containing both a stormy and a calm version (a `Picker` to switch, like exercise 3, is fine).
- `notes/p4-storm-writeup.md` contains: which two+ causes you used, the *before* console output (rows storming), the *after* console output (calm), and a one-paragraph explanation of each fix.
- The calm version re-renders the minimum set of views the minimum number of times for the action you chose.
- Build is warning-free. Committed.

**Hint.** The four causes: unstable `.id` (D), coarse model (A), over-broad row input (B), high-frequency state sharing a body with an expensive tree (C). The two easiest to combine are B (pass the whole array into a row) and C (search field + list in one body).

**Estimated time.** 1 hour.

---

## Problem 5 — `task(id:)` re-loads on identity change

**Problem statement.** Build a small "random fact" screen: a `Picker` selects one of three topics (`swift`, `cats`, `space`), and the view shows a fact loaded asynchronously for the selected topic. The load is a function `func loadFact(for topic: Topic) async -> String` that you stub with a 300 ms `try? await Task.sleep` and returns a canned string per topic. Use `.task(id:)` so that changing the topic cancels the in-flight load and starts a fresh one. Add a `Self._printChanges()` and a `print` inside the task to prove the task re-runs exactly once per topic change and cancels the previous one.

**Acceptance criteria.**

- Changing the topic re-loads the fact via `.task(id: topic)`.
- The previous load is cancelled when the topic changes mid-load (verify by switching quickly and confirming you do not get a stale fact).
- The view shows a `ProgressView` while loading and the fact when loaded.
- Build is warning-free. Committed.

**Hint.** `.task(id: topic) { fact = nil; fact = await loadFact(for: topic) }`. Setting `fact = nil` first shows the `ProgressView`. The cancellation is automatic — `.task(id:)` cancels the old task when `id` changes; the `Task.sleep` throws `CancellationError` and the stale assignment never happens.

**Estimated time.** 50 minutes.

---

## Problem 6 — Mini reflection essay

**Problem statement.** Write a 300–400 word reflection at `notes/week-08-reflection.md` answering:

1. Before this week, which state wrapper did you reach for by default, and was it the right one? What will you reach for now?
2. The Observation framework's per-property tracking is "free" — you get it by adopting `@Observable`. Was there a moment this week where you *saw* it work (a view that did not re-render when you expected it to)? Describe it.
3. Explain the draft-and-commit pattern to a colleague who just bound a sheet's `TextField` straight to the live model and is confused why "Cancel" does nothing. One paragraph.
4. What is one thing about SwiftUI state you still find confusing that this week did not fully resolve? (Week 9 treats navigation as state, Week 10 adds SwiftData — note if your confusion is about those.)

**Acceptance criteria.**

- File exists, 300–400 words.
- Each numbered question is addressed in its own paragraph.
- File is committed.

**Hint.** This is for *you*, not for a grade. Be honest. Future-you debugging a storm in Week 12 will be grateful you wrote down what clicked this week.

**Estimated time.** 30 minutes.

---

## Time budget recap

| Problem | Estimated time |
|--------:|--------------:|
| 1 | 30 min |
| 2 | 45 min |
| 3 | 50 min |
| 4 | 1 h 0 min |
| 5 | 50 min |
| 6 | 30 min |
| **Total** | **~4 h 25 min** |

When you've finished all six, push your repo and open the [mini-project](./07-mini-project/00-overview.md). The homework problems are deliberately the building blocks of the mini-project: problem 2 is its migration discipline, problem 4 is its no-storm requirement, and problem 1 is the code-review skill the whole week earns.
