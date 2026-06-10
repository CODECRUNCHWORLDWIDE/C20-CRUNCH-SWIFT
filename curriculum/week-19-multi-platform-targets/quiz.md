# Week 19 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 20. Answer key with explanations at the bottom — don't peek.

---

**Q1.** What is the "share/adapt line"?

- A) A rule that all code must be shared across platforms.
- B) The deliberate boundary between layers that are identical on every platform (model, networking, persistence, domain — shared) and layers that depend on the device (navigation, input, window, density — adapted).
- C) A SwiftUI modifier.
- D) The line between iOS and iPadOS.

---

**Q2.** Which of these is a **smell** that the share/adapt line is in the wrong place?

- A) The model layer is in a shared package.
- B) Business logic contains `#if os(...)` branches — the platform leaked into the core, which should be platform-agnostic.
- C) Navigation uses `NavigationSplitView`.
- D) The Mac app has a menu bar.

---

**Q3.** For a **SwiftUI** app new in 2026, which way onto the Mac is the default?

- A) Mac Catalyst "Scale to fit iPad."
- B) Mac Catalyst "Optimize for Mac."
- C) SwiftUI multiplatform (native, AppKit-backed) — add macOS as a destination of the SwiftUI target.
- D) A separate Objective-C target.

---

**Q4.** When is **Mac Catalyst** still the right choice?

- A) For all new SwiftUI apps.
- B) When you have a large existing **UIKit** app you can't rewrite in SwiftUI and want it on the Mac with native chrome.
- C) Never.
- D) Only for games.

---

**Q5.** A single `NavigationSplitView` with value-typed selection renders how, across platforms?

- A) Identically everywhere — always three columns.
- B) Three/two columns (sidebar-detail) on Mac/iPad, and it **collapses to a `NavigationStack`** (push/pop) on iPhone — automatically, with no platform branches.
- C) It only works on the Mac.
- D) You must write a separate version per platform.

---

**Q6.** Why does `.keyboardShortcut("n", modifiers: .command)` need **no** `#if os`?

- A) It's iOS-only.
- B) It's a no-op where there's no keyboard, so it adds the Mac affordance (⌘N) and is simply inert on iPhone — an adaptation that costs nothing on platforms that don't use it.
- C) It throws on iOS.
- D) It requires a keyboard on every platform.

---

**Q7.** Where should a genuinely platform-specific touch (e.g. a macOS-only `.frame(minWidth:)`) go?

- A) In the middle of the view's `body`, branched with `#if os`.
- B) Isolated in a named `ViewModifier` or helper, so the fork is small and localized and the `body` reads clean on every platform.
- C) In the shared `NotesCore` package.
- D) In `UserDefaults`.

---

**Q8.** A watchOS app should be designed as:

- A) A literal port of the iPhone app.
- B) A glance — the few most recent items, a simpler `NavigationStack`, read-mostly — onto the *same* shared data, with density adapted for seconds-long, wrist-sized use.
- C) An immersive experience.
- D) A web view.

---

**Q9.** In modern watchOS, a complication is:

- A) A separate, bespoke complication API unrelated to widgets.
- B) A **WidgetKit widget** (a `Widget` with a `TimelineProvider`) rendered in the watch-face accessory families (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`).
- C) A `UIView`.
- D) Not supported anymore.

---

**Q10.** For a notes app on visionOS, the right scene type is:

- A) An `ImmersiveSpace` that takes over the room.
- B) A `WindowGroup` window (`.windowStyle(.plain)`) — a floating panel in the Shared Space; the existing adaptive layout renders with glass, depth, and eye focus for free.
- C) A volumetric box.
- D) A full-screen game scene.

---

**Q11.** Why does putting the shared core in a SwiftPM package declared for all four platforms *enforce* the share/adapt line?

- A) It doesn't; it's just organization.
- B) Because the package must compile for iOS/macOS/watchOS/visionOS, the compiler refuses any platform-specific UI import (UIKit/AppKit) in it — the line becomes a build-enforced boundary, not a convention.
- C) Packages are faster.
- D) It hides the code from the app targets.

---

**Q12.** You wrote and tested `NotesDomain.recent(_:limit:)` in the shared `NotesCore`. How many times must you test it per platform?

- A) Once per platform — five times.
- B) **Once** — it's the same compiled code on every platform, so testing it once covers all of them.
- C) Never; domain logic doesn't need tests.
- D) Twice — iOS and macOS only.

---

**Q13.** In a parity matrix, a feature is honestly marked "absent by design" on the Watch (e.g. composing a long note). This is:

- A) A bug to fix.
- B) The correct senior judgment — cramming a long-form editor onto a wrist makes a worse app; the honest gap is the right call, not a missing feature.
- C) A sign the core isn't shared.
- D) A reason to fork the app.

---

## Answer key

**Q1 — B.** The share/adapt line is the deliberate boundary: model/network/persistence/domain are shared (same answer everywhere); navigation/input/window/density adapt (depend on the device). Drawing it deliberately is the week's whole skill. (Lecture 1, §1.)

**Q2 — B.** `#if os` in business logic means the platform leaked into the core, which must be platform-agnostic. The fix is to push the branch up into the shell. (Lecture 1, §1, §4.)

**Q3 — C.** For a SwiftUI app, native SwiftUI multiplatform (macOS as a destination) is the default — native controls, shared code, least effort. (Lecture 1, §3.)

**Q4 — B.** Catalyst is the pragmatic bridge for a large existing UIKit app you can't rewrite. New SwiftUI work skips it. (Lecture 1, §3.)

**Q5 — B.** `NavigationSplitView` is adaptive: columns on Mac/iPad, an automatic collapse to a `NavigationStack` on iPhone — no branches, because navigation is modeled as state (Week 9). (Lecture 1, §5.)

**Q6 — B.** `.keyboardShortcut` is inert where there's no keyboard, so it adds the Mac affordance for free and needs no platform branch — the ideal adaptation. (Lecture 1, §5.)

**Q7 — B.** Isolate the fork in a named modifier/helper so it's small and localized and the `body` stays clean. Never in the shared core. (Lecture 1, §4; exercise 2.)

**Q8 — B.** A watch app is a glance onto the same shared data — fewer items, a stack, read-mostly — with density adapted, not a port of the phone. (Lecture 2, §1.)

**Q9 — B.** Modern complications *are* WidgetKit widgets rendered in the accessory families. (Lecture 2, §2.)

**Q10 — B.** A notes app is a window; the existing adaptive layout renders spatially with glass/depth/eye focus for free. Immersion is for experiences, not a productivity window. (Lecture 2, §3.)

**Q11 — B.** A package declared for every platform can't compile a UIKit/AppKit-only file, so the compiler enforces the platform-agnostic core — the line becomes a build boundary, not just a convention. (Lecture 2, §4.)

**Q12 — B.** It's the same compiled code on every platform, so a single test in `NotesCoreTests` covers all of them. (Lecture 2, §5.)

**Q13 — B.** Honestly marking a feature absent-by-design (long-note composition on a watch) is the right judgment; forcing it would make a worse app. The gap is a decision, not a defect. (Lecture 2, §5; challenge 1.)

---

*Score 11+? On to Week 20. Below 9? Re-read both lecture notes and re-run exercises 1 and 3 — the navigation-adapts-for-free idea and the package-enforces-the-line idea are the two clusters this week is graded on.*
