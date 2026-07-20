# Week 9 — Quiz

Twelve multiple-choice questions on navigation, scenes, storage, and deep links. Take it with your lecture notes closed. Aim for 10/12 before moving to Week 10. Answer key at the bottom — don't peek.

---

**Q1.** Why did Apple replace `NavigationView` + `NavigationLink(destination:)` with `NavigationStack` in iOS 16?

- A) `NavigationView` was slower to compile.
- B) The old model could not represent navigation as serializable data, so deep links and state restoration were intractable; the new model makes the path a plain array of values.
- C) `NavigationView` only worked on iPhone.
- D) Apple wanted to deprecate `List` along with it.

---

**Q2.** In `NavigationStack(path: $path)`, what is the type and meaning of `path`?

- A) A `Bool` — whether any screen is pushed.
- B) An ordered collection of `Hashable` values; its count is the navigation depth and its contents are which screens, in order.
- C) A `String` URL of the current screen.
- D) A closure that builds the next view.

---

**Q3.** Where must `.navigationDestination(for: Route.self)` be placed?

- A) Anywhere in the app; SwiftUI finds it globally.
- B) Inside the `NavigationStack`, attached to content that is always present (e.g. the root `List`).
- C) On every `NavigationLink`, once per link.
- D) Outside the `NavigationStack`, as a sibling.

---

**Q4.** You want to deep-link two screens deep: open a note, then push its tag. On the value-typed model, what is the operation?

- A) Flip two `isActive` booleans in the right order.
- B) `path = [.note(id: noteID), .tag(id: tagID)]` — assign the whole path at once.
- C) Call `navigationDestination` twice.
- D) It is not possible without a Coordinator object.

---

**Q5.** Which is the correct mapping of navigation operations to array mutations on a `@State var path: [Route]`?

- A) push = `removeLast`, pop = `append`.
- B) push = `append`, pop = `removeLast`, pop-to-root = `removeAll`, replace = assignment.
- C) push = assignment, pop-to-root = `append`.
- D) All four operations require a separate API; arrays are not involved.

---

**Q6.** On iPhone in portrait, how does a three-column `NavigationSplitView` render?

- A) It crashes; three columns require a regular size class.
- B) It shows all three columns squeezed side by side.
- C) It automatically collapses into a single navigation stack: sidebar is root, selecting pushes content, selecting pushes detail.
- D) It shows only the detail column and hides the rest permanently.

---

**Q7.** In a tab-based app, a deep link should open a note that lives in the Notes tab. What must the handler do?

- A) Only set the Notes tab's path; the tab switches itself.
- B) Only switch to the Notes tab; the path restores itself.
- C) Set the selected tab to `.notes` AND set the Notes tab's path together, atomically — otherwise the right screen is built in a tab the user can't see.
- D) Present the note modally regardless of tab.

---

**Q8.** What is the difference between `@AppStorage` and `@SceneStorage`?

- A) They are identical; `SceneStorage` is just the newer name.
- B) `@AppStorage` is app-wide `UserDefaults` (preferences); `@SceneStorage` is per-scene restoration storage that survives a cold launch and is the right choice for a navigation path.
- C) `@SceneStorage` is app-wide; `@AppStorage` is per-scene.
- D) `@SceneStorage` can store any type, including views.

---

**Q9.** A `[Route]` cannot be stored directly in `@SceneStorage`. What is the idiomatic bridge?

- A) Convert it to a `String` description with `String(describing:)`.
- B) Make `Route: Codable` and store `try? JSONEncoder().encode(path)` as `Data`, decoding on restore.
- C) Store each route's index as an `Int`.
- D) You cannot persist a path; restoration is impossible for stacks.

---

**Q10.** Why does `.onOpenURL { }` not need a separate code path for a cold launch?

- A) Cold launches never deliver URLs; only warm launches do.
- B) SwiftUI delivers the URL through `onOpenURL` after the scene connects in *both* warm and cold cases, so one handler covers both.
- C) Cold launches require `application(_:didFinishLaunchingWithOptions:)` instead.
- D) The URL is injected into `@State` defaults at compile time.

---

**Q11.** What does a custom URL scheme (`notes://`) give you that a universal link (`https://…`) does not, and vice versa?

- A) Custom scheme works from a web page; universal link does not.
- B) Custom scheme is trivial to register but can be claimed by any app and doesn't work from web pages; universal link requires an AASA file proving domain ownership, works from Safari/Messages, and cannot be spoofed.
- C) They are interchangeable with identical guarantees.
- D) Universal links work without any server configuration.

---

**Q12.** A universal link opens Safari to your website instead of opening your app. Which is the LEAST likely cause?

- A) The `apple-app-site-association` file is unreachable or served with a redirect.
- B) The `appIDs` Team ID in the AASA is wrong.
- C) The app was installed before the AASA became reachable, so the association never refetched.
- D) The `DeepLink.path(for:)` decoder returned the wrong `Route`.

---

**Q13.** Which statement about a *pure* `DeepLink.path(for url: URL) -> [Route]?` is the senior justification for writing it that way?

- A) It runs faster than an impure version.
- B) It can be unit-tested in milliseconds with no simulator, it is total (returns `nil` for garbage rather than crashing), and it is identical across every transport (custom scheme, universal link, cold launch).
- C) Apple requires deep-link decoders to be pure.
- D) Pure functions are required to be `@MainActor`.

---

**Q14.** On a cold launch, `SceneStorage` restores the path the user left, *and* a deep link arrives. Which should win, and why does the value-typed model get this right?

- A) Restoration should win; deep links are advisory.
- B) The deep link should win because the user explicitly tapped a link; `onOpenURL` for a launch URL fires after `onAppear` restoration, so the link's `path = newPath` is the last writer.
- C) They merge into a concatenated path.
- D) Whichever runs first wins, and the order is undefined.

---

**Q15.** Why does keying navigation on a note's `id` (rather than on a `Note` value or reference) matter for next week's SwiftData migration?

- A) SwiftData forbids storing `Note` values in arrays.
- B) `id` is the stable identity that survives the store swap, so the navigation layer keeps working when the persistence layer changes underneath it; reference-keyed routes break the moment the store changes.
- C) `id` is faster to hash.
- D) It does not matter; you rewrite navigation each week anyway.

---

## Answer key

**Q1 — B.** The old model encoded navigation as a tree of views with `isActive` bindings — code, not data. The new `path` array is plain data that serializes for restoration and decodes from URLs.

**Q2 — B.** The path is an ordered collection of `Hashable` values; `count` is depth, contents are the screens in order.

**Q3 — B.** It must be inside the stack, on always-present content. Placed outside, links do nothing; placed on a conditionally-rendered view, the destination vanishes with the view.

**Q4 — B.** Assign the whole path. Arrays have arbitrary depth; this is exactly the case the `isActive` model cannot express without per-level coordination bugs.

**Q5 — B.** push = `append`, pop = `removeLast`, pop-to-root = `removeAll` (or `= []`), replace = assignment. Replace is the deep-link primitive.

**Q6 — C.** A three-column `NavigationSplitView` collapses to a single stack at compact width automatically — which is why you write one layout, not two.

**Q7 — C.** A deep link must set the selected tab *and* that tab's path atomically. Setting one without the other builds the right screen in an invisible tab.

**Q8 — B.** `@AppStorage` = app-wide `UserDefaults` preferences. `@SceneStorage` = per-scene, cold-launch-surviving restoration storage; the right home for a navigation path or a per-window selection.

**Q9 — B.** Make `Route: Codable` (Swift synthesizes it for enums with associated values) and store the JSON-encoded `Data`. That one word, `Codable`, is the whole reason value-typed navigation makes restoration trivial.

**Q10 — B.** `onOpenURL` is delivered after the scene connects in both lifecycles. One handler covers warm and cold; you never special-case the cold launch.

**Q11 — B.** Custom scheme: trivial, unowned, no web-page support. Universal link: requires an AASA proving domain ownership, works from the web, cannot be spoofed. Use the scheme for plumbing, the universal link for human-tappable links.

**Q12 — D.** A wrong decoder result would open the app to the *wrong* note, not bounce to Safari. Bouncing to Safari means the *association* failed (A, B, or C) — the OS never decided the link belongs to your app.

**Q13 — B.** Purity buys millisecond unit tests with no simulator, totality (nil over crash), and one implementation across every transport. That is the senior justification, not raw speed.

**Q14 — B.** The deep link should win; the user explicitly asked to go somewhere. The launch URL's `onOpenURL` fires after `onAppear` restoration, so the link is the last writer. (If restoration wins, your handler is firing too early — move it to the always-present root.)

**Q15 — B.** Keying on the stable `id` decouples navigation from the data layer. Swap the in-memory store for SwiftData and the routes still resolve; reference-keyed routes would dangle the moment the store changes.
