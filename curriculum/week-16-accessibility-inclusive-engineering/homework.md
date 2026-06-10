# Week 16 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 16 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. The accessibility bar is *measurable*: the audit reports zero issues, and cells don't clip at AX5.

---

## Problem 1 — Label and trait a toolbar

**Problem statement.** Take a toolbar with five icon-only buttons (add, search, sort, share, delete). Give each a purposeful `accessibilityLabel`, mark any toggle's state with `accessibilityValue`, and run the Accessibility Inspector audit to confirm zero label issues. Write the labels you chose into `notes/labels.md` with a one-line justification each (purpose, not icon).

**Acceptance criteria.**

- Five icon buttons, each with a purpose label (not the SF Symbol name, not "X button").
- Any toggle carries an `accessibilityValue` for its state.
- The audit reports zero label issues.
- `notes/labels.md` documents the choices. Committed.

**Hint.** "Add note", not "plus" and not "Add button". Let VoiceOver supply "button" from the trait. A toggle: label "Favorite", value "On"/"Off".

**Estimated time.** 30 minutes.

---

## Problem 2 — Merge a custom cell into one element

**Problem statement.** Build a custom cell with an avatar image, a name, a subtitle, and an unread badge. By default it generates four VoiceOver stops. Use `accessibilityElement(children:)` and a custom label so it reads as one sensible sentence (e.g. "Alex Kim, 3 unread, Product team"). Hide the decorative avatar from the tree. Verify the reading with the Inspector's VoiceOver simulation.

**Acceptance criteria.**

- The cell is one accessibility element with a clear, sentence-like label.
- The decorative avatar is `accessibilityHidden(true)` (or contributes only meaningfully).
- Verified via the Inspector or device VoiceOver. 0 warnings. Committed.

**Hint.** `accessibilityElement(children: .ignore)` + an explicit `accessibilityLabel` gives you full control of the announced string, vs `.combine` which concatenates. Pick whichever reads better.

**Estimated time.** 40 minutes.

---

## Problem 3 — A Dynamic-Type-safe cell, tested at AX5

**Problem statement.** Build (or take from exercise 2) a list cell and make it render correctly at AX5: text styles, `@ScaledMetric` for icon/spacing, reflow to vertical at accessibility sizes, no fixed height. Add `#Preview`s pinned to default and `.accessibility5`. In `notes/dynamic-type.md`, paste a screenshot of both previews and confirm no clipping at AX5.

**Acceptance criteria.**

- The cell uses text styles and `@ScaledMetric`, reflows at AX sizes, no hard-coded height.
- Default and AX5 previews exist; the AX5 one shows no clipping/truncation.
- `notes/dynamic-type.md` has both screenshots. 0 warnings. Committed.

**Hint.** `.environment(\.dynamicTypeSize, .accessibility5)` on the preview. If it clips, you left a `lineLimit` or a fixed frame somewhere — drop limits at AX sizes, use padding not height.

**Estimated time.** 45 minutes.

---

## Problem 4 — Reduce-motion-aware animation

**Problem statement.** Build a view with a non-trivial animation (a card flip, a slide-up sheet, a parallax). Read `\.accessibilityReduceMotion` and provide a calm alternative (a fade, or no animation) when it's on. Add a `#Preview` with reduce-motion forced on. In `notes/reduce-motion.md`, explain why honoring the setting matters.

**Acceptance criteria.**

- The animation is full-motion normally and calm/faded when `accessibilityReduceMotion` is true.
- A `#Preview` with `.environment(\.accessibilityReduceMotion, true)`.
- `notes/reduce-motion.md` explains the why (explicit user preference, vestibular reasons).
- 0 warnings. Committed.

**Hint.** `.transition(reduceMotion ? .opacity : <fancy>)`, with the insertion inside `withAnimation`. The preview environment override lets you see the calm path without changing Settings.

**Estimated time.** 40 minutes.

---

## Problem 5 — Color-blind-safe status indicators

**Problem statement.** Take a screen that signals state with color alone (a list of items each with a red/yellow/green status dot). Refactor so every state carries a *distinct shape/icon* AND an `accessibilityLabel`, so the signal survives color blindness and no sight. Test with Settings ▸ Accessibility ▸ Color Filters (simulate color blindness) and with VoiceOver. Document in `notes/contrast.md`.

**Acceptance criteria.**

- Each status uses a distinct icon/shape (not just color) plus an `accessibilityLabel`.
- Verified under a color-blindness filter (the states are still distinguishable) and under VoiceOver (each announces its state).
- `notes/contrast.md` documents the before/after. 0 warnings. Committed.

**Hint.** `checkmark.circle.fill` / `exclamationmark.triangle.fill` / `xmark.circle.fill` differ by *shape*, so they survive color blindness; add `.accessibilityLabel("Healthy" / "Warning" / "Error")` for VoiceOver. Color becomes an enhancement, not the only carrier.

**Estimated time.** 40 minutes.

---

## Problem 6 — An accessibility UI test in CI

**Problem statement.** Add an XCUITest that (a) finds a button by `accessibilityIdentifier` and asserts its `accessibilityLabel`, and (b) runs `app.performAccessibilityAudit()` so an accessibility regression fails the test. Confirm the test passes, then deliberately remove a label and confirm the test fails — proving it actually guards accessibility.

**Acceptance criteria.**

- A UI test asserting a button's label via its identifier.
- A test calling `performAccessibilityAudit()` (Xcode 15+).
- You demonstrated the test FAILS when a label is removed (paste the failure), then restored it. 0 warnings. Committed.

**Hint.** `app.buttons["addNote"].label == "Add note"`. `try app.performAccessibilityAudit()` throws on findings. The "remove a label, watch it fail" step is what proves the test has teeth — a green test that never fails guards nothing.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic, the audit/AX5/VoiceOver verification was actually done, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor issue (a slightly verbose label, a missing screenshot). |
| 3 | Works, but misses one criterion (cell still clips at AX5, color-only signal not fully fixed, audit not re-run). |
| 2 | Compiles and partially works; a core idea is wrong (label is the icon name, reduce-motion ignored, fixed point sizes left in). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for a fixed point size (`.font(.system(size:))`) where a text style was required; **−2** for color-only state signaling; **−2** for an animation that ignores reduce-motion; **−1** for a label that's the SF Symbol name or includes the redundant control type ("X button").

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the accessibility tree (labels/traits/combine, problems 1, 2) and Dynamic-Type-safe layout (problem 3) — so re-run exercises 01 and 02 before resubmitting.
