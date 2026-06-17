# Week 16 — Accessibility and inclusive engineering

Welcome to Week 16 of **C20 · Crunch Swift**. You have a fast app running on a real device. This week you make it usable by everyone — including the user navigating entirely by **VoiceOver** with the screen off, the user reading at the **largest Dynamic Type** size because they can't read the default, the user with **reduce motion** on because animation makes them nauseous, and the user who relies on sufficient **color contrast** to tell a button from its background. Accessibility is not a charity feature you bolt on at the end to be nice. It is engineering — a set of APIs, an audit tool, and a measurable bar — and it is the difference between an app a senior reviewer ships and one they send back.

The lecture title says it plainly: **accessibility is engineering, not charity.** The framing matters because the charity framing is why accessibility gets skipped — it sounds optional, a nice-to-have for "those users." The engineering framing is correct and it's why you'll take it seriously: an inaccessible app is *broken* for a meaningful fraction of users, the same way a crashing app is broken, and you find and fix accessibility breakage with a tool (the **Accessibility Inspector**) exactly as you found and fixed performance breakage with Instruments last week. Same discipline: audit, find the failures, fix them, verify. There's also a hard commercial reality — accessibility is a legal requirement in many markets, a frequent App Review rejection reason, and table stakes for enterprise and government contracts. But the real reason is simpler: you're an engineer, the platform gives you first-class accessibility primitives, and an app that ignores them is unfinished.

The mental shift this week is from "how it looks" to "how it's *perceived and operated* — by sight, by sound, by touch, at any text size, with any motion setting." SwiftUI gives you a strong default: standard controls are accessible out of the box, because `Button`, `Toggle`, `List`, and `NavigationStack` carry their accessibility semantics for free. The work is at the edges — the custom view that VoiceOver reads as "image" instead of "Play button, double-tap to play," the icon-only button with no label, the layout that breaks at the largest Dynamic Type size, the animation that should be suppressed under reduce-motion, the color pair that fails contrast. You'll learn the **accessibility tree** (the parallel representation of your UI that VoiceOver navigates), the modifiers that shape it (`accessibilityLabel`, `accessibilityValue`, `accessibilityHint`, `accessibilityElement`, `accessibilityAddTraits`), Dynamic Type and `@ScaledMetric`, the reduce-motion and contrast environment values, and **haptics** (`UIImpactFeedbackGenerator` and the richer `CHHapticEngine`) as a non-visual feedback channel.

We close the week by running Notes v1 **with VoiceOver enabled** and fixing every failure the Accessibility Inspector surfaces — the audit. You will make every interactive element VoiceOver-navigable with a meaningful label and the right traits, add **haptic feedback** on note creation, and ship a **Dynamic-Type-safe** list cell that renders correctly at the largest accessibility text size (the one where everything overflows if you hard-coded a frame height). The skill this week earns is concrete and senior: audit a SwiftUI app for accessibility and ship *measurable* improvements — "the Accessibility Inspector reported 9 issues; here are the zero that remain, and here's a VoiceOver screen recording of the app being fully operable with the screen curtain on."

## Learning objectives

By the end of this week, you will be able to:

- **Explain** the accessibility tree — the parallel representation VoiceOver and other assistive technologies navigate — and how SwiftUI builds it from your view hierarchy, including what's exposed, merged, hidden, or missing by default.
- **Audit** a SwiftUI app with the **Accessibility Inspector** (audit + inspection + VoiceOver simulation) and with VoiceOver on a real device, and read its reported issues the way you read an Instruments trace.
- **Label** interactive elements correctly with `accessibilityLabel`, describe state with `accessibilityValue`, guide with `accessibilityHint`, and apply `accessibilityAddTraits` (`.isButton`, `.isHeader`, `.updatesFrequently`, …) so VoiceOver announces each element meaningfully.
- **Shape the tree** with `accessibilityElement(children:)`, `accessibilityHidden`, and combining/merging so a custom composite view reads as one sensible element instead of a pile of fragments.
- **Support Dynamic Type** end to end — use text styles, the `@ScaledMetric` property wrapper for spacing/icon sizes that must scale, and build cells that don't truncate or overflow at the largest accessibility size.
- **Respect** the environment accessibility settings — `\.accessibilityReduceMotion` (suppress or simplify animation), `\.accessibilityReduceTransparency`, `\.legibilityWeight`, and color-contrast considerations — and adapt the UI accordingly.
- **Add** haptic feedback as a non-visual channel — `UIImpactFeedbackGenerator` / `.sensoryFeedback` for simple events, and `CHHapticEngine` for custom patterns — used to confirm actions, not as decoration.
- **Verify** accessibility the way you verify performance: run the audit, fix every reported issue, navigate the whole app with VoiceOver and the screen curtain on, and prove operability — a measurable bar, not a vibe.

## Prerequisites

This week assumes you have completed **C20 weeks 1–15**, or have equivalent fluency. Specifically:

- You can build a SwiftUI view and reason about the view hierarchy and when `body` recomputes — Week 8. The accessibility tree is built *from* that hierarchy; you need to know your hierarchy to shape its accessibility representation.
- You can deploy to and operate a **physical device** — Week 15. VoiceOver is best experienced and tested on a real device (the screen curtain, the rotor, the gestures); the Simulator's VoiceOver and the Accessibility Inspector are the audit tools, the device is the truth.
- You understand `@Environment` and environment values — Weeks 8–9. Reduce-motion, reduce-transparency, and the Dynamic Type size all arrive as environment values you read to adapt the UI.
- You have **Notes v1** on your device (Week 15). This week's mini-project audits and fixes *it* — the same app, now made operable by everyone.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), the **Accessibility Inspector** (bundled with Xcode: Xcode ▸ Open Developer Tool ▸ Accessibility Inspector), and a **physical iOS 17+/18 device** for real VoiceOver testing. No paid Apple Developer membership is needed for the *audit* work (the Inspector runs in the Simulator), but you already have the membership from Week 15 and the device experience is where the learning is.

## Topics covered

- **The accessibility tree.** What it is (the parallel UI model assistive tech navigates), how SwiftUI generates it from your views, what each view contributes (label, value, traits, frame), and the difference between the visual hierarchy and the accessibility hierarchy.
- **VoiceOver.** How it works (focus, the rotor, swipe-to-next, double-tap-to-activate, the screen curtain), what it announces for each element (label, then value, then traits, then hint), and how to test with it on a device and via the Accessibility Inspector's VoiceOver simulation.
- **`accessibilityLabel`.** The concise name VoiceOver reads — what makes a good label (the *purpose*, not the icon name), when SwiftUI infers it (text, standard controls) and when you must supply it (icon-only buttons, custom views, decorative-vs-meaningful images).
- **`accessibilityValue` and `accessibilityHint`.** Value for dynamic state ("75 percent", "on"), hint for the non-obvious action ("double-tap to open") — and the rule that hints are last-resort and often better designed away.
- **`accessibilityIdentifier`.** The non-localized, stable id for UI tests (distinct from the user-facing label) — the bridge to the snapshot/UI tests from earlier weeks.
- **Traits.** `accessibilityAddTraits` / `removeTraits` — `.isButton`, `.isHeader`, `.isSelected`, `.isToggle`, `.updatesFrequently`, `.playsSound`, `.isModal` — what each tells VoiceOver about how to treat the element.
- **Shaping the tree.** `accessibilityElement(children: .combine / .ignore / .contain)`, `accessibilityHidden(true)` for decorative views, merging a composite cell into one element, and `accessibilityChildren` for custom containers.
- **Dynamic Type.** Text styles (`.body`, `.headline`, …) that scale automatically, the accessibility text sizes (AX1–AX5), `@ScaledMetric` for non-text dimensions (icon size, padding) that must scale with the text, and building cells that reflow instead of truncating at the largest size.
- **`@ScaledMetric`.** The property wrapper that scales a numeric value with the user's Dynamic Type setting, with an optional `relativeTo:` text style — for the icon and spacing dimensions that must grow with the text.
- **Reduce Motion and friends.** `\.accessibilityReduceMotion` (replace a slide/scale with a cross-fade or no animation), `\.accessibilityReduceTransparency`, `\.accessibilityDifferentiateWithoutColor`, `\.legibilityWeight` — reading the environment and adapting.
- **Color and contrast.** The WCAG contrast ratios, why color-alone signaling fails for color-blind users (`differentiateWithoutColor`), and using SF Symbols + text labels alongside color.
- **Haptics.** `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`, SwiftUI's `.sensoryFeedback`, and `CHHapticEngine` for custom patterns — haptics as a confirmation/feedback channel, prepared before use, respectful of the user's settings.
- **Accessibility footguns.** Icon-only button with no label, a custom control VoiceOver reads as "image", color-only state, a hard-coded frame height that clips at AX5, an animation that ignores reduce-motion, a decorative image announced as noise, and an `accessibilityHint` doing a label's job.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                                | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Accessibility as engineering; the tree; VoiceOver; labels/value/hint  |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | Traits; shaping the tree; the Accessibility Inspector audit           |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Dynamic Type + `@ScaledMetric`; reduce-motion; contrast; footguns     |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Haptics (`UIImpactFeedbackGenerator`, `CHHapticEngine`); challenge    |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — VoiceOver audit + fix Notes v1; haptics; AX-safe cell  |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; screen-curtain operability pass               |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                           |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                      | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's accessibility docs, the HIG accessibility chapter, the WWDC accessibility sessions, the WCAG reference, and the canonical community writing on SwiftUI accessibility |
| [lecture-notes/01-voiceover-and-the-accessibility-tree.md](./02-lecture-notes/01-voiceover-and-the-accessibility-tree.md) | Accessibility as engineering, the accessibility tree, VoiceOver, labels/value/hint/identifier, traits, shaping the tree, and auditing with the Accessibility Inspector |
| [lecture-notes/02-dynamic-type-motion-contrast-and-haptics.md](./02-lecture-notes/02-dynamic-type-motion-contrast-and-haptics.md) | Dynamic Type and `@ScaledMetric`, reduce-motion and contrast environment values, color-blind-safe signaling, and haptics as a non-visual feedback channel — with the footguns measured |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-audit-and-label.md](./03-exercises/exercise-01-audit-and-label.md) | Run the Accessibility Inspector audit on a screen, find the unlabeled and mis-traited elements, and fix every reported issue |
| [exercises/exercise-02-dynamic-type-safe-cell.swift](./03-exercises/exercise-02-dynamic-type-safe-cell.swift) | Build a list cell that renders correctly from the default size up to AX5 using text styles and `@ScaledMetric`, and a test that it doesn't clip |
| [exercises/exercise-03-reduce-motion-and-haptics.swift](./03-exercises/exercise-03-reduce-motion-and-haptics.swift) | Read `accessibilityReduceMotion` to swap an animation for a fade, and add `.sensoryFeedback`/`UIImpactFeedbackGenerator` on a confirmed action |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-voiceover-only-operability.md](./04-challenges/challenge-01-voiceover-only-operability.md) | Operate the entire app with VoiceOver and the screen curtain on, find every spot where you get stuck or confused, fix each, and document the before/after with a screen recording |
| [quiz.md](./05-quiz.md) | 13 questions on the tree, VoiceOver, labels/traits, Dynamic Type, `@ScaledMetric`, reduce-motion, contrast, and haptics |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for "Notes v1 — accessible edition": VoiceOver audit + fix, a Dynamic-Type-safe cell, haptics on note creation, and a screen-curtain operability pass |

## The "operable with the screen off" promise

Week 10 gave you "survives a cold launch." Week 15 gave you "measurably fast." Week 16 adds the inclusivity contract a senior reviewer actually checks:

> **The entire app is operable by a user who cannot see the screen, and readable by a user at the largest text size.** Turn on VoiceOver, enable the **screen curtain** (triple-tap with three fingers — the screen goes black, so you *cannot* cheat by looking), and complete every core task: create a note, edit it, tag it, delete it, filter by tag. If you get stuck — an element VoiceOver won't focus, a button with no label, a control that doesn't announce its state — that's a bug, the same as a crash. Then set Dynamic Type to AX5 and confirm nothing clips or truncates.

You will *prove* it by recording a screen capture of yourself operating Notes v1 end to end with the screen curtain on. "It works if you can see it" is not the test; "it works with the screen black" is.

## A note on what's not here

Week 16 is the *core accessibility* week. It deliberately does **not** cover:

- **Switch Control, Voice Control, and AssistiveTouch** in depth. These are real assistive technologies and a well-built accessibility tree (correct labels, traits, and focus order) serves them too — but the specific tuning for each is beyond one week. We build the foundation they all rely on (the tree) and name them.
- **Audio Graphs and accessible charts.** Making data visualizations accessible (`AXChart`, audio graphs) is a specialized topic for chart-heavy apps. Notes v1 has no charts; we name the API and move on.
- **Localization and internationalization.** Right-to-left layout, translated strings, and locale-aware formatting overlap with accessibility (and matter enormously) but are their own discipline. We use `accessibilityIdentifier` (non-localized) correctly and otherwise leave i18n for its own treatment.

The point of Week 16 is narrow and deep: the accessibility tree, VoiceOver operability, Dynamic Type that doesn't break, motion and contrast respected, and haptics as a real feedback channel — audited with a tool and fixed to a measurable zero-issues bar.

## Up next

Continue to **Week 17 — Security, App Transport Security, CryptoKit, Secure Enclave** once you have shipped this week's mini-project and proven screen-curtain operability. Week 17 returns to the security thread you started in Week 14 (the Keychain) — pinning a certificate, encrypting with CryptoKit, and signing requests with a Secure-Enclave key. Accessibility and security share a discipline you've now practiced twice: both are *audited with a tool and fixed to a measurable bar*, not asserted, and both are non-negotiable for App Review and enterprise. You've made the app fast, then usable by everyone; next you make it secure.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
