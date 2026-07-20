# Week 7 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours**. Work in your Week 7 Git repository (the `hello-notes` repo is fine) so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

---

## Problem 1 — Read "Demystify SwiftUI" and write the loop in your own words

**Problem statement.** Watch the WWDC21 session "Demystify SwiftUI" (<https://developer.apple.com/videos/play/wwdc2021/10022/>). Then, *without rewatching*, write a 250-word note at `notes/demystify.md` that explains, in your own words: (1) what SwiftUI compares when it diffs, (2) what "identity" means for a view and why it matters, and (3) the difference between *structural* identity and *explicit* (`.id(...)`) identity. Include the state-change loop as a five-step list (state changes → … → minimal mutation).

**Acceptance criteria.**

- `notes/demystify.md` exists, is 220–280 words.
- It correctly distinguishes structural identity (position in the tree) from explicit identity (`.id(...)` / `ForEach(id:)`).
- It lists the five-step loop in order.
- File is committed.

**Hint.** The session's three pillars are **Identity, Lifetime, Dependencies**. Your note should touch all three. Identity decides whether a change is a *mutation* or a *remove + insert*.

**Estimated time.** 45 minutes.

---

## Problem 2 — Prove the modifier-order rule with a screenshot pair

**Problem statement.** In a fresh SwiftUI view, render the same `Text("Modifier order")` twice: once as `.padding().background(.tint).clipShape(.rect(cornerRadius: 12))` and once as `.background(.tint).padding().clipShape(.rect(cornerRadius: 12))`. Put both in a `VStack` so they appear together. Capture a screenshot. Save it as `notes/modifier-order.png` and write a 120-word explanation at `notes/modifier-order.md` of why the two differ, using the phrase "wraps the result of."

**Acceptance criteria.**

- A single view shows both orderings stacked, visibly different.
- `notes/modifier-order.png` is the screenshot, `notes/modifier-order.md` is the 120-word writeup.
- The writeup correctly explains that `.background` paints behind whatever view it wraps, and that order is composition order.
- `Build Succeeded`, zero warnings.

**Hint.** The first ordering's tint includes the padding; the second's tint hugs the glyphs with transparent padding outside, and the `clipShape` rounds different bounds in each case.

**Estimated time.** 30 minutes.

---

## Problem 3 — Write a custom `Layout`

**Problem statement.** Implement a `Layout` conformance called `EqualWidthHStack` that lays its subviews left-to-right, giving each exactly `1/N` of the available width with a configurable `spacing`. Use it to lay out three equal-width buttons. (Lecture 02 gives a working reference — implement it yourself first, then compare.) Add a short comment over `sizeThatFits` and `placeSubviews` saying which of "propose / choose / place" each method corresponds to.

**Acceptance criteria.**

- `EqualWidthHStack: Layout` implements both `sizeThatFits(proposal:subviews:cache:)` and `placeSubviews(in:proposal:subviews:cache:)`.
- Three buttons render with visibly equal widths that re-divide when you resize (rotate the simulator or use the iPad).
- A comment maps `sizeThatFits` → "child chooses" and `placeSubviews` → "parent places."
- `Build Succeeded`, zero warnings.

**Hint.** In `placeSubviews`, compute `cellWidth = (bounds.width - totalSpacing) / count`, then *propose* exactly `cellWidth` to each subview and `place` it; give the buttons `.frame(maxWidth: .infinity)` so they choose to fill the proposed cell.

**Estimated time.** 60 minutes.

---

## Problem 4 — Survive `.accessibility5`

**Problem statement.** Take the `NoteCard` you built (challenge or mini-project) and make it survive `.accessibility5` if it does not already. Add a `#Preview` with `.environment(\.dynamicTypeSize, .accessibility5)`. Document, in `notes/dynamic-type.md` (100 words), the specific reflow you applied (e.g. "badge drops below the text," "header switches from `HStack` to `VStack`," "used `ViewThatFits`") and why a `.lineLimit(1)` on the title would have been wrong.

**Acceptance criteria.**

- The card renders at `.accessibility5` with no clipping and no title/badge truncation, in both light and dark.
- A `#Preview` proves it in the Canvas.
- `notes/dynamic-type.md` (90–120 words) names the reflow strategy and explains the `.lineLimit(1)` pitfall.
- Uses `@ScaledMetric` for at least one metric (icon size or spacing).

**Hint.** `@Environment(\.dynamicTypeSize)` exposes `.isAccessibilitySize`; branch your header layout on it, or wrap the header in `ViewThatFits(in: .horizontal) { horizontal; vertical }`.

**Estimated time.** 45 minutes.

---

## Problem 5 — Audit a view hierarchy for purity

**Problem statement.** Find (or write, if you don't have one) a SwiftUI view whose `body` does something it shouldn't: allocates a formatter every call, fires a side effect, performs an O(n) computation over a large array, or reads `Date()` directly. Refactor it so `body` is a pure function of the view's stored properties. Write the before/after at `notes/body-purity.md` with a one-paragraph explanation of *what* SwiftUI's calling pattern made the original a bug.

**Acceptance criteria.**

- `notes/body-purity.md` shows a "before" `body` with a purity violation and an "after" that fixes it.
- The fix moves work to the right place: a hoisted constant/static, an `.onAppear`/`.task`, or a precomputed stored property.
- The explanation correctly states that `body` may be invoked many times per state change, so any per-call cost or side effect is multiplied unpredictably.
- File is committed.

**Hint.** A `static let formatter = DateFormatter()` shared across instances, or a value computed once and stored, removes the per-`body` allocation. Side effects belong in `.task { }` or `.onAppear { }`, not in `body`.

**Estimated time.** 45 minutes.

---

## Problem 6 — Schemes, configurations, and a `DEBUG`-only badge

**Problem statement.** In an Xcode project, confirm you can name your scheme, your target, and your two build configurations (Debug, Release) — write them at the top of `notes/build.md`. Then add a small `#if DEBUG` overlay to your app's main view that shows a "DEBUG" badge in the corner, present in Debug builds and absent in Release. Build once in Debug (badge appears) and once in Release (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ set Build Configuration to Release; badge gone). Note the result.

**Acceptance criteria.**

- `notes/build.md` correctly names the scheme, the app target, and lists `Debug` and `Release` as the two configurations.
- A `#if DEBUG ... #endif` overlay shows a "DEBUG" badge in Debug builds only.
- The note records that the badge appears in Debug and disappears when Run is switched to the Release configuration.
- `Build Succeeded`, zero warnings, in both configurations.

**Hint.** `.overlay(alignment: .topTrailing) { ... }` is a clean place for the badge. The `#if DEBUG` condition is defined automatically by the Debug configuration (`SWIFT_ACTIVE_COMPILATION_CONDITIONS` includes `DEBUG`), and stripped from Release.

**Estimated time.** 30 minutes.

---

## Submission

Push the entire `notes/` directory and any sample code to your Week 7 Git repository. The instructor reviews by:

1. Reading each note in `notes/`.
2. Opening the sample code in Xcode 16 and confirming it builds warning-free and the screenshots/claims match what renders.
3. Spot-checking the modifier-order and accessibility5 claims in the Canvas.

A submission whose `notes/` are present, whose code builds clean, and whose screenshots match the claims is a pass. The most common review-fail is "the note claims the card survives accessibility5 but the preview clips" — run the preview before you submit.

If anything is unclear, post the question in the Week 7 channel before the homework deadline.

---

## Rubric

| Criterion | Weight | What "full marks" looks like |
| --- | --- | --- |
| **Correctness** | 40% | All six problems' code builds warning-free; claims match what renders; the custom `Layout` divides width equally and reflows. |
| **Mental model** | 30% | Notes correctly articulate the state→view loop, identity, modifier-order composition, and `body` purity — in the learner's own words, not copied. |
| **The matrix** | 20% | The `NoteCard` survives `.accessibility5` in light and dark with a deliberate, explained reflow. |
| **Hygiene** | 10% | `notes/` is complete and committed; screenshots present; both Debug and Release build clean. |

Pass mark for the homework: **70%**. Anything below 70% should be reworked before the mini-project review.

---

**References**

- "Demystify SwiftUI" (WWDC21): <https://developer.apple.com/videos/play/wwdc2021/10022/>
- `Layout` protocol: <https://developer.apple.com/documentation/swiftui/layout>
- `DynamicTypeSize`: <https://developer.apple.com/documentation/swiftui/dynamictypesize>
- `@ScaledMetric`: <https://developer.apple.com/documentation/swiftui/scaledmetric>
- "Customizing the build schemes for a project": <https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project>
