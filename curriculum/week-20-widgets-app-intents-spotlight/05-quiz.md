# Week 20 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 21. Answer key with explanations at the bottom — don't peek.

---

**Q1.** A widget shows fake placeholder content forever and never your real notes. What is the most likely single cause?

- A) The `TimelineReloadPolicy` is wrong.
- B) The widget extension can't see the app's store — the App Group is missing or the store URL isn't shared between the two targets.
- C) The widget view has a layout bug.
- D) `supportedFamilies` is empty.

---

**Q2.** Why does an App Intent's `perform()` need to construct its own store access rather than reading `AppState.shared.modelContext`?

- A) Singletons are bad style.
- B) `perform()` runs off-process, possibly while the app is fully terminated, so app-process singletons may not exist — it must reach shared storage directly.
- C) `modelContext` is deprecated in intents.
- D) Intents can't import SwiftData.

---

**Q3.** Which `TimelineProvider` callback must be **instant and data-free**?

- A) `getTimeline`
- B) `getSnapshot`
- C) `placeholder(in:)`
- D) All three must fetch data.

---

**Q4.** Your notes widget's content only changes when the user adds or edits a note — never on a clock. Which reload policy fits, and how does the widget actually update?

- A) `.atEnd`, and it polls every minute.
- B) `.after(date:)` set one minute ahead, looping forever.
- C) `.never`, and the app calls `WidgetCenter.shared.reloadTimelines(ofKind:)` whenever data changes.
- D) There is no way to update an event-driven widget.

---

**Q5.** What does an **App Shortcut** give you that a plain registered `AppIntent` does not?

- A) Nothing; they're identical.
- B) A Siri phrase that works with **zero user setup** the moment the app is installed.
- C) The ability to take parameters.
- D) Off-process execution.

---

**Q6.** Why must every App Shortcut phrase contain `\(.applicationName)`?

- A) For localization only.
- B) It's the anchor token Siri uses to route the spoken request to your app; a phrase without it is ambiguous and ignored.
- C) It sets the shortcut's icon.
- D) It's required only on watchOS.

---

**Q7.** Inside a WidgetKit view, which controls can run an App Intent interactively (no app launch)?

- A) Any `TapGesture`.
- B) `Button(intent:)` and `Toggle(isOn:intent:)` only.
- C) `NavigationLink`.
- D) `onTapGesture` on any view.

---

**Q8.** You pass a note into an interactive widget intent so it knows which note to act on. Why is a `UUID` a better key than the SwiftData `persistentModelID`?

- A) `persistentModelID` is slower.
- B) A `UUID` is a stable, `Sendable` value that round-trips cleanly across the process boundary; a `persistentModelID` is not a reliable cross-process key.
- C) `UUID`s are smaller.
- D) `persistentModelID` can't be put in a predicate.

---

**Q9.** A Lock Screen `.accessoryCircular` widget you designed with full colour and three lines of text renders as a blank-ish tinted blob. Why?

- A) The data is missing.
- B) Accessory widgets are rendered monochrome/vibrant and are tiny — colour is mostly ignored and there's room for roughly one number or glyph, not paragraphs.
- C) `.accessoryCircular` isn't a real family.
- D) You forgot `.containerBackground`.

---

**Q10.** A user taps your note in Spotlight, the app opens, but lands on the list instead of the note. What's wrong?

- A) The note wasn't indexed.
- B) The `onContinueUserActivity(CSSearchableItemActionType)` continuation isn't handled, or the `uniqueIdentifier` doesn't resolve to a note to route to.
- C) Spotlight is disabled.
- D) The widget timeline is stale.

---

**Q11.** A note you deleted still appears in Spotlight and taps to nothing. What did you forget?

- A) To call `reloadTimelines`.
- B) To de-index it with `deleteSearchableItems(withIdentifiers:)` when it was deleted.
- C) To set a `domainIdentifier`.
- D) To save the context.

---

**Q12.** Which statement about the modern App Intents framework vs the legacy `.intentdefinition` world is correct?

- A) App Intents still require a visual `.intentdefinition` editor.
- B) App Intents are pure Swift `structs` — diffable, reviewable, type-checked — and one intent feeds Siri, Shortcuts, interactive widgets, and Spotlight; the legacy world used code-gen and a separate extension.
- C) `.intentdefinition` is the new, preferred approach.
- D) App Intents only work with Siri, not Shortcuts.

---

**Q13.** Your widget reads the store in `getTimeline`. To stay within the extension's tight time/memory budget, how should it fetch the single most-recent note and the total count?

- A) `context.fetch(FetchDescriptor<Note>())` then `.first` and `.count`.
- B) `FetchDescriptor` with `fetchLimit = 1` and a sort for the recent note, and `fetchCount` for the total — never materialise the whole table.
- C) Load every note into a `@Query`.
- D) Fetch all notes twice, once per value.

---

## Answer key

**Q1 — B.** The widget runs in a separate process and can't read the app's default store. The shared App Group container, with both targets pointed at the same store URL, is the fix. The number-one widget bug. (Lecture 2, §1; §6.)

**Q2 — B.** `perform()` runs off-process, often with the app terminated (Siri, interactive widget). App singletons may be nil. Construct store access against the shared App Group URL and return `Sendable` values. (Lecture 1, §2; §7.)

**Q3 — C.** `placeholder(in:)` draws the skeleton/gallery state and must be instant and synchronous — no data fetch. `getSnapshot`/`getTimeline` may fetch. (Lecture 2, §2.)

**Q4 — C.** For content that changes on user action, use `.never` and reload explicitly with `WidgetCenter.shared.reloadTimelines` from the app (and from your intents) on every write. Refreshes are budgeted; you cannot poll. (Lecture 2, §2.)

**Q5 — B.** An App Shortcut pre-packages an intent with a phrase so it works in Siri with no user configuration. A plain intent requires the user to build a shortcut first. (Lecture 1, §3.)

**Q6 — B.** `\(.applicationName)` is the routing anchor; Siri uses it to know the request is yours. A phrase without it is ignored. (Lecture 1, §3.)

**Q7 — B.** Only `Button(intent:)` and `Toggle(isOn:intent:)` are interactive inside a widget (iOS 17+). Arbitrary gestures are not. (Lecture 2, §4.)

**Q8 — B.** The intent runs off-process and can't take a live model object (not `Sendable`); it needs a stable, `Sendable` key. A `UUID` round-trips across the process boundary cleanly; a `persistentModelID` is not a reliable cross-process key. (Lecture 2, §4; challenge.)

**Q9 — B.** Lock Screen accessory widgets are rendered monochrome/vibrant and are watch-complication-sized. Design for one number or glyph (a `Gauge`/`Text`), not colour and paragraphs. (Lecture 2, §3.)

**Q10 — B.** You must handle `onContinueUserActivity(CSSearchableItemActionType)`, pull the `uniqueIdentifier`, resolve it to a note, and `path.append` it into the nav stack. Without the continuation, the app opens but doesn't route. (Lecture 2, §5.)

**Q11 — B.** The index must stay in sync with the store. Every delete path must `deleteSearchableItems(withIdentifiers:)`, or you get a ghost result that taps to a note that no longer exists. (Lecture 2, §5; §6.)

**Q12 — B.** App Intents are pure Swift, reviewable and type-checked, with one declaration feeding every system surface; the legacy `.intentdefinition` world used a visual editor, code-gen, and a separate Intents Extension. (Lecture 1, §5.)

**Q13 — B.** A widget runs on a tight budget. Use `fetchLimit = 1` + sort for the recent note and `fetchCount` for the total — never fetch the whole table and `.first`/`.count` it. The Week 10 footguns apply doubly here. (Lecture 2, §2; mini-project Milestone 2.)

---

*Score 11+? On to Week 21. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — the App-Group-shares-the-store idea and the off-process `perform()` are the two ideas this week is graded on.*
