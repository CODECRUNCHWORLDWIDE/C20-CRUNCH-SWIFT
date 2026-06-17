# Week 16 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones. The audit work runs in the Simulator with the Accessibility Inspector; the VoiceOver experience is best on a real device.

## Index

1. **[Exercise 1 — Audit a screen and fix every label](./exercise-01-audit-and-label.md)** — run the Accessibility Inspector audit on a deliberately broken screen, find the unlabeled buttons, the decorative-image noise, and the missing traits, and fix every reported issue to zero. The audit-find-fix loop, in one exercise. (~40 min)
2. **[Exercise 2 — A Dynamic-Type-safe cell](./exercise-02-dynamic-type-safe-cell.swift)** — build a list cell that renders correctly from the default size up to AX5 using text styles, `@ScaledMetric`, and a reflow-to-vertical layout, with previews pinned to AX5 proving it doesn't clip. (~50 min)
3. **[Exercise 3 — Reduce-motion and haptics](./exercise-03-reduce-motion-and-haptics.swift)** — read `accessibilityReduceMotion` to swap a slide animation for a fade, and add `.sensoryFeedback` / `UIImpactFeedbackGenerator` confirmation on a deliberate action — respecting the user's settings. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills.
- **Audit with the Accessibility Inspector** (Xcode ▸ Open Developer Tool ▸ Accessibility Inspector) and, where you can, **test with VoiceOver on a real device** with the screen curtain on (three-finger triple-tap). The Inspector finds missing labels; only real VoiceOver reveals confusing flow.
- For Dynamic Type, **pin previews to `.accessibility5`** and look — the AX5 clip is the most common accessibility bug and the easiest to see if you glance at it.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. The bar for accessibility is *measurable*: the audit reports zero issues, and the cell doesn't clip at AX5.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-16` to compare.
