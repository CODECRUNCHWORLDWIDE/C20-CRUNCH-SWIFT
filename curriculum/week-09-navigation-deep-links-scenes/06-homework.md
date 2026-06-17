# Week 9 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours**. Work in your Week 9 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Deliverables** — exactly what to commit.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

---

## Problem 1 — Read the SwiftUI navigation API surface

**Problem statement.** Open Apple's SwiftUI Navigation collection: <https://developer.apple.com/documentation/swiftui/navigation>. List *every* initializer of `NavigationStack` and `NavigationSplitView`. For each, write one sentence on when you would use it. Then write a 150-word note on the one design decision you find most surprising about the post-iOS-16 model.

**Deliverables.** A `notes/navigation-api-surface.md` file.

**Acceptance criteria.**

- Lists all `NavigationStack` initializers (root-only, `path:`, and the `NavigationPath` variant) and all `NavigationSplitView` initializers (two-column, three-column, with `columnVisibility`, with `preferredCompactColumn`).
- Each initializer has a one-sentence "use when…".
- The 150-word note names a real design decision (e.g. "destinations key on type, not on link," or "the split view collapses rather than re-laying-out").
- File committed.

**Hint.** Quick Help in Xcode (Option-click `NavigationStack`) lists the initializers faster than scrolling the web page.

**Estimated time.** 30 minutes.

---

## Problem 2 — `[Route]` vs `NavigationPath`, in code

**Problem statement.** Implement the same two-screen navigation twice: once with `@State var path: [Route]` (typed array) and once with `@State var path = NavigationPath()` (type-erased). Push a `Note.ID` and then a `Tag.ID` in both. For the `NavigationPath` version, serialize and restore it with `NavigationPath.CodableRepresentation`. Then write a 200-word comparison: when is each the right tool?

**Deliverables.** A `RoutingComparison.swift` with both implementations and a `notes/path-vs-navigationpath.md` comparison.

**Acceptance criteria.**

- Both versions compile and push two screens.
- The `NavigationPath` version round-trips through `codable` (encode, decode, restore).
- The note correctly states the rule: typed array for a closed route set you control (default); `NavigationPath` only when the path must mix types you cannot unify into one enum.
- Build: 0 warnings, 0 errors.

**Hint.** `NavigationPath` exposes a `codable` property of type `NavigationPath.CodableRepresentation?` (non-nil only if every value in the path is `Codable`). Encode *that* with `JSONEncoder`.

**Estimated time.** 50 minutes.

---

## Problem 3 — Tap-active-tab-to-pop-to-root

**Problem statement.** In a `TabView(selection:)` app, implement the standard iOS behaviour: tapping the *already-selected* tab pops that tab's navigation stack to root. (Tapping a different tab just switches.) You will need to detect re-selection of the active tab and reset that tab's `path`.

**Deliverables.** A `TabReselection.swift` demonstrating it for a two-tab app.

**Acceptance criteria.**

- Tapping the active tab when it is deep pops it to root.
- Tapping the active tab when already at root does nothing jarring.
- Tapping a different tab switches without resetting the previous tab's path.
- Build: 0 warnings, 0 errors.

**Hint.** Bind `TabView(selection:)` to a custom `Binding<AppTab>` whose `set` compares the new value to the current value; if they are equal, reset that tab's path before (or instead of) assigning.

**Estimated time.** 45 minutes.

---

## Problem 4 — Harden the deep-link decoder

**Problem statement.** Extend the Week 9 `DeepLink.path(for:)` decoder to handle three forms and reject everything else, fully tested:

1. `notes://open/<uuid>` → `[.note(id:)]`
2. `notes://open/<uuid>/tag/<tagUUID>` → `[.note(id:), .tag(id:)]`
3. `https://notes.example.com/open/<uuid>` → `[.note(id:)]` (reject any other host)

**Deliverables.** A `DeepLink.swift` and a `DeepLinkTests.swift` (Swift Testing) with at least 8 cases including malformed UUIDs, wrong hosts, wrong schemes, and the two-level form.

**Acceptance criteria.**

- All three valid forms decode correctly.
- Garbage (bad UUID, foreign host, unknown verb like `delete`) returns `nil`.
- `DeepLink` has no `import SwiftUI` — it is pure.
- Tests pass with `swift test` (or the Xcode test runner); no simulator required to run them.

**Hint.** Normalize both transports to a `[String]` segment list first (`["open", id]` or `["open", id, "tag", tagID]`), then pattern-match the segments. One matcher, two transports.

**Estimated time.** 50 minutes.

---

## Problem 5 — Prove restoration with a transcript

**Problem statement.** Take your Exercise 2 (or mini-project) app, navigate two screens deep, switch tabs, then reproduce a cold launch with `simctl` and confirm restoration. Capture the full terminal transcript and annotate what restored.

**Deliverables.** A `notes/restoration-proof.md` with the transcript and a short explanation.

**Acceptance criteria.**

- The transcript shows `xcrun simctl terminate booted <bundleID>` followed by `xcrun simctl launch booted <bundleID>`.
- The annotation states what restored (tab via `@AppStorage`, path via `@SceneStorage`) and confirms the relaunch landed on the same screen.
- One sentence explains why testing this with Xcode's Stop/Run instead of `simctl` can mislead you (see Lecture 1 §1.8).

**Hint.** `xcrun simctl launch` prints the new process PID, which differs from the pre-terminate PID — include both lines so the transcript proves it was genuinely a fresh process.

**Estimated time.** 35 minutes.

---

## Problem 6 — Write the code-review comment

**Problem statement.** A teammate opens a PR that adds navigation using `NavigationView`, `NavigationLink(destination:)`, and a pair of `@State` `isActive` booleans to handle a deep link. Write the code-review comment that asks them to switch to the value-typed model. It must be *concrete* — name the specific failure modes the `isActive` model ships, not just "the new API is better."

**Deliverables.** A `notes/code-review-comment.md` (200–300 words).

**Acceptance criteria.**

- Names at least three specific failure modes: no arbitrary depth (the next feature needs two levels), warm-link animation glitches from non-atomic boolean flips, and no serializable/testable navigation value for restoration.
- Proposes the concrete replacement (`[Route]` path + `navigationDestination` + a pure decoder).
- Is the tone of a senior reviewer: specific, kind, and backed by a reproducible problem, not by taste.

**Hint.** Lecture 2 §2.8 gives the shape of the comment. Make it yours — reference *this PR's* feature, not the generic example.

**Estimated time.** 30 minutes.

---

## Submitting

Commit all deliverables to your Week 9 repository under the paths named above. Each problem should be at least one commit. In your PR description, paste the restoration transcript from Problem 5 and the code-review comment from Problem 6 — those two are the ones a reviewer will read first, because they prove you can both *demonstrate* and *defend* the week's discipline: navigation is state, the state is value-typed, and value-typed state restores and deep-links by construction.
