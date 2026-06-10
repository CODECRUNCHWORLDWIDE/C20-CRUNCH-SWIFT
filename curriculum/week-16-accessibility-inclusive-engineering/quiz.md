# Week 16 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 17. Answer key with explanations at the bottom — don't peek.

---

**Q1.** What is the accessibility tree?

- A) The same thing as the SwiftUI view hierarchy.
- B) A parallel structure of accessibility elements (label, value, traits, frame) that assistive technologies like VoiceOver navigate — related to, but not identical to, the visual hierarchy.
- C) A list of the app's screens.
- D) The undo/redo stack.

---

**Q2.** VoiceOver focuses an icon-only `Button { } label: { Image(systemName: "trash") }` with no accessibility modifiers. What does it announce?

- A) "Delete, button."
- B) "trash, button" — the SF Symbol name, which is meaningless to the user.
- C) Nothing.
- D) "Image."

---

**Q3.** What makes a good `accessibilityLabel`?

- A) The control type repeated ("Delete button").
- B) The SF Symbol name.
- C) A concise description of the element's *purpose*, without the control type ("Delete note").
- D) A full sentence explaining everything the button does.

---

**Q4.** Where does an element's *current state* (a toggle's on/off, a rating's value) belong?

- A) In the `accessibilityLabel`.
- B) In the `accessibilityValue`, separate from the label, so VoiceOver re-announces just the value when it changes.
- C) In the `accessibilityHint`.
- D) In the `accessibilityIdentifier`.

---

**Q5.** What's the difference between `accessibilityLabel` and `accessibilityIdentifier`?

- A) They're the same.
- B) The label is read aloud to the user (localized); the identifier is a stable, non-localized string for UI tests and is *not* read aloud.
- C) The identifier is read aloud; the label is for tests.
- D) Both are read aloud.

---

**Q6.** A custom composite cell (title + date + tag count) generates three separate VoiceOver stops. How do you make it read as one element?

- A) `accessibilityHidden(true)`.
- B) `accessibilityElement(children: .combine)` to merge the children into one element.
- C) Remove the date and tag count.
- D) Add `.isButton`.

---

**Q7.** Why is `.font(.system(size: 17))` an accessibility bug?

- A) 17pt is too small.
- B) A fixed point size ignores Dynamic Type entirely — it stays 17pt no matter what text size the user set, so it's unreadable at AX5.
- C) It's slow.
- D) It's not a bug.

---

**Q8.** A horizontal cell with an icon and text clips/truncates badly at AX5. What's the right pattern?

- A) Cap the text length.
- B) Use `dynamicTypeSize.isAccessibilitySize` + `AnyLayout` to reflow to vertical at accessibility sizes, and use padding (not a fixed height).
- C) Hard-code a taller frame.
- D) Disable Dynamic Type for that cell.

---

**Q9.** What does `@ScaledMetric` do?

- A) Scales a numeric value (icon size, padding) with the user's Dynamic Type setting, so non-text dimensions grow with the text.
- B) Measures performance.
- C) Scales the whole view by a fixed factor.
- D) Limits the maximum text size.

---

**Q10.** A user has Reduce Motion on. What should your slide/scale transition do?

- A) Play anyway — it's a nice animation.
- B) Be replaced with a gentle fade (or no animation), because Reduce Motion is an explicit preference often set for vestibular/medical reasons.
- C) Play faster.
- D) Crash.

---

**Q11.** A status indicator is a green dot for "online" and a red dot for "offline". Why is this an accessibility bug, and what's the fix?

- A) Dots are too small. Fix: bigger dots.
- B) Color is the only signal — identical to a red-green color-blind user, and unlabeled for VoiceOver. Fix: add a distinct shape/icon AND an `accessibilityLabel`.
- C) The colors are wrong. Fix: use blue and orange.
- D) It isn't a bug.

---

**Q12.** Why call `prepare()` on a `UIImpactFeedbackGenerator` before the action?

- A) It's required or the haptic won't fire.
- B) Without it, the first haptic after an idle period lags while the Taptic Engine spins up; preparing warms it so the feedback is instant.
- C) It makes the haptic stronger.
- D) It checks for a Taptic Engine.

---

**Q13.** The automated Accessibility Inspector audit reports zero issues. Is the app fully accessible?

- A) Yes — zero issues means done.
- B) No — the automated audit catches mechanical failures (missing labels, small targets, contrast), but only operating the app with VoiceOver and the screen curtain reveals confusing flow, bad reading order, and unreachable actions.
- C) No — the audit is always wrong.
- D) Yes, as long as it also passed in the Simulator.

---

## Answer key

**Q1 — B.** The accessibility tree is the parallel element structure assistive tech navigates, related to but not identical to the visual hierarchy — your app's "second UI." (Lecture 1, §1.)

**Q2 — B.** With no label, VoiceOver falls back to the image name ("trash") — meaningless. You must supply `accessibilityLabel("Delete note")`. (Lecture 1, §1, §3.)

**Q3 — C.** Describe the purpose, concisely, without the control type (VoiceOver adds "button" from the trait). "Delete note." (Lecture 1, §3.)

**Q4 — B.** State goes in the value, separate from the name, so VoiceOver re-announces just the value when it changes. (Lecture 1, §4.)

**Q5 — B.** Label = read aloud, localized, for the user. Identifier = stable, non-localized, for UI tests, not spoken. Keep them distinct. (Lecture 1, §4, §7.6.)

**Q6 — B.** `accessibilityElement(children: .combine)` merges the children into one element that reads as a sentence — one VoiceOver stop per cell. (Lecture 1, §6.)

**Q7 — B.** A fixed point size ignores Dynamic Type; it stays 17pt at AX5, unreadable for users who need large text. Use a text style. (Lecture 2, §1.)

**Q8 — B.** Reflow to vertical at accessibility sizes with `isAccessibilitySize` + `AnyLayout`, and size with padding, not a fixed height. (Lecture 2, §1.)

**Q9 — A.** `@ScaledMetric` scales a numeric value with Dynamic Type, so icons and spacing grow with the text instead of staying fixed. (Lecture 2, §2.)

**Q10 — B.** Honor the preference — swap to a fade. Reduce Motion is often a medical accommodation; overriding it is wrong, like ignoring dark mode. (Lecture 2, §3.)

**Q11 — B.** Color alone is invisible to color-blind users and unlabeled for VoiceOver. Add a distinct shape/icon and an `accessibilityLabel` so the signal carries across color, shape, and speech. (Lecture 2, §4.)

**Q12 — B.** `prepare()` warms the Taptic Engine so the first haptic doesn't lag. It's not required, but without it the first fire after idle is late. (Lecture 2, §5.)

**Q13 — B.** The audit catches mechanical bugs; only VoiceOver + the screen curtain reveals experiential ones (flow, order, reachability). Audit → curtain → audit. (Lecture 1, §7; challenge 1.)

---

*Score 11+? On to Week 17. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — the accessibility tree (labels/traits/combine) and Dynamic-Type-safe layout are the two ideas this week is graded on.*
