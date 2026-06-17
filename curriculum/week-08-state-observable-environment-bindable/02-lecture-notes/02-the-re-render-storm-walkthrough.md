# Lecture 2 — The SwiftUI Re-Render Storm: A Line-by-Line Walkthrough

> **Reading time:** ~70 minutes. **Hands-on time:** ~75 minutes (you instrument a real storm, watch the counter climb, and fix all four causes).

Lecture 1 was about getting ownership *right*. This lecture is about diagnosing what happens when it goes *wrong*: the **re-render storm**, the single most common SwiftUI performance pathology, and the one a senior reviewer looks for first. A storm is a view (or a tree of views) whose `body` recomputes far more often than the user's action warrants — dozens of times per keystroke, or on every unrelated state change, or repeatedly on appear. Dropped frames, janky scrolling, battery drain, and — worst — *correctness* bugs (a half-finished edit corrupted by an unexpected recompute) all trace back to a storm.

The thesis of this lecture: **"it feels fast enough" is not an engineering statement.** "This cell's `body` ran exactly once when I tapped save, and zero times when I tapped cancel — here is the counter output" *is*. You cannot fix what you cannot see, so we start by making re-renders visible, then catalogue the four causes, then fix each one with the counter proving the fix.

## 2.1 — Making re-renders visible: two instruments

You have two tools for *seeing* a re-render. Use both.

### Tool 1 — `Self._printChanges()`

SwiftUI ships a private-but-stable diagnostic that prints, to the console, *why* a view re-rendered. Call it as the first statement in `body`:

```swift
struct RowView: View {
    let note: Note

    var body: some View {
        let _ = Self._printChanges()
        Text(note.title)
    }
}
```

`let _ = Self._printChanges()` is the idiomatic placement — you assign to `_` because `body` is a `@ViewBuilder` and a bare function call would be interpreted as a view. When this view re-renders, the console prints something like:

```
RowView: @self changed.
RowView: _note changed.
RowView: @identity changed.
```

The three messages mean different things, and reading them correctly is the skill:

- **`@self changed`** — the view *value* itself changed (a stored property like `note` is different by equality). This is a legitimate, expected re-render.
- **`_<propertyName> changed`** — the named `@State`/`@Binding`/observed dependency changed. `_note changed` tells you the `note` input differs.
- **`@identity changed`** — the view's *identity* changed, so SwiftUI tore down and rebuilt it (and its `@State` reset). **This is almost always a bug** — usually an unstable `.id` or a structural-identity change (§2.4). When you see `@identity changed` on a view you expected to merely update, stop and investigate.

`_printChanges()` is for *Debug* builds only. It is a diagnostic, not telemetry. Strip it (or `#if DEBUG` it) before you ship.

### Tool 2 — an explicit render counter

`_printChanges()` tells you *why*; a counter tells you *how many times*. Build a tiny reference-type counter and increment it in `body`:

```swift
import SwiftUI

final class RenderCounter {
    private(set) var count = 0
    let label: String
    init(_ label: String) { self.label = label }
    func tick() {
        count += 1
        print("[\(label)] render #\(count)")
    }
}
```

Hold one per view you are auditing and tick it at the top of `body`:

```swift
struct AuditedRow: View {
    let note: Note
    let counter: RenderCounter

    var body: some View {
        let _ = counter.tick()       // prints "[Row 3] render #1", "#2", ...
        Text(note.title)
    }
}
```

Now you can make *exact* claims: "Tapping save produced `[Row 3] render #1` and nothing else — the changed cell rendered once, the other cells did not render at all." That is the acceptance bar for this week's mini-project and challenge. We are not estimating; we are counting.

A subtlety: the counter must be a *reference type* you pass in, not `@State`, because mutating `@State` from inside `body` would itself trigger a re-render (an infinite loop, which SwiftUI will warn about with "Modifying state during view update"). A plain `class` you mutate as a side effect of rendering is the correct shape for measurement — it is deliberately *outside* SwiftUI's dependency graph.

## 2.2 — Anatomy of a storm: the demo we will fix

Here is a deliberately broken notes screen. It compiles, it runs, it *looks* fine — and it storms. Read it, then we instrument it.

```swift
import SwiftUI

struct Note: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var done: Bool = false
}

struct StormyListView: View {
    // CAUSE A (preview): a coarse model — every change invalidates the whole view.
    @State private var notes: [Note] = (1...50).map { Note(title: "Note \($0)") }
    @State private var searchText: String = ""

    var body: some View {
        VStack {
            // CAUSE C: a TextField bound to @State at the TOP of a big tree.
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List {
                ForEach(filtered) { note in
                    // CAUSE B: the row reads the whole array via a closure, not a value.
                    StormyRow(note: note, allNotes: notes)
                        // CAUSE D: an unstable id resets identity every render.
                        .id(UUID())
                }
            }
        }
    }

    var filtered: [Note] {
        searchText.isEmpty ? notes
            : notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

struct StormyRow: View {
    let note: Note
    let allNotes: [Note]     // the whole array, just to show a count — a mistake

    var body: some View {
        let _ = Self._printChanges()
        HStack {
            Text(note.title)
            Spacer()
            Text("\(allNotes.count)").foregroundStyle(.secondary)
        }
    }
}
```

Run this, type one character into the search field, and watch the console. You will see all fifty rows print `_printChanges` output — for a *single keystroke*. That is the storm. Four distinct causes conspire here; we will name and kill each.

## 2.3 — Cause A: a coarse model invalidates everything

The deepest version of this cause shows up with the *legacy* `ObservableObject`, so understand it there first, then see why `@Observable` fixes it.

With `ObservableObject`:

```swift
final class CoarseStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""   // unrelated to the list rows
}

struct CoarseList: View {
    @ObservedObject var store: CoarseStore

    var body: some View {
        let _ = Self._printChanges()
        List(store.notes) { Text($0.title) }   // reads notes, NOT searchText
    }
}
```

Type into a *search field elsewhere* that mutates `store.searchText`, and `CoarseList` re-renders anyway — even though it only reads `store.notes`. Why? Because `@Published` invalidation is **object-level**: any `@Published` change publishes `objectWillChange`, and *every* view observing the object re-renders, regardless of which property changed. The list does not read `searchText`, but it pays for `searchText`'s churn.

**The fix is the Observation framework.** Convert the model:

```swift
import Observation

@Observable
final class FineStore {
    var notes: [Note] = []
    var searchText: String = ""
}

struct FineList: View {
    let store: FineStore        // plain let; @Observable tracks reads, not the holder

    var body: some View {
        let _ = Self._printChanges()
        List(store.notes) { Text($0.title) }   // subscribes to `notes` only
    }
}
```

Now `FineList` reads `store.notes` during `body`, so the Observation registrar subscribes it to the `notes` key path *only*. Mutating `store.searchText` does not touch `notes`, so `FineList` does **not** re-render. This is the headline win of `@Observable`: per-property tracking turns object-level storms into surgical updates, for free, just by adopting the macro.

In the `StormyListView` demo, `notes` and `searchText` are both `@State` on the *same view*, so the whole `StormyListView.body` recomputes whenever either changes — that is the value-type analogue of cause A. The fix there is structural: extract the search field and the list into separate views so a `searchText` change does not force the *list-building* code to re-run. We do that in §2.7.

## 2.4 — Cause D: unstable `.id` destroys and rebuilds (start here — it is the worst)

We jump to cause D out of order because it is the most destructive and the easiest to spot once you know the signature.

```swift
ForEach(filtered) { note in
    StormyRow(note: note, allNotes: notes)
        .id(UUID())     // BUG
}
```

`.id(UUID())` assigns a brand-new identity to every row on every render. From SwiftUI's perspective, the rows you rendered last frame and the rows this frame are *entirely different views*. So instead of *updating* fifty rows in place, SwiftUI **destroys all fifty and creates fifty new ones** — every render. The `_printChanges` output shows `@identity changed` on every row, the giveaway.

The damage is not just performance. Because identity reset destroys `@State`, any row that held `@State` (an expansion toggle, a swipe offset, an in-progress edit) *loses it* every render. Animations restart. `.task` work cancels and re-launches. This is the cause behind "my list flickers" and "my row's local state keeps resetting."

**The fix:** delete the `.id(UUID())`. `ForEach` already derives a stable identity from `Note.id` (because `Note` is `Identifiable`). You only add `.id` when you *want* a replacement, with a *stable* value:

```swift
ForEach(filtered) { note in
    StormyRow(note: note)        // identity comes from note.id — stable, correct
}
```

The rule from Lecture 1, restated as a storm fix: **`.id` must be stable across renders. A value that changes every render (`UUID()`, `Date()`, an index in a reordering list) is always a bug.**

## 2.5 — Cause B: passing the whole collection into a row

```swift
StormyRow(note: note, allNotes: notes)   // the row takes the ENTIRE array
```

`StormyRow` only wants to show a count, but it accepts `allNotes: [Note]`. SwiftUI re-renders a view when any of its inputs change *by equality*. `allNotes` changes whenever *any* note changes — toggle one note's `done` and the array is a different value, so *every* row re-renders because every row holds the whole array. You have coupled all fifty rows to all fifty notes.

**The fix:** pass the row the *minimum* it needs. If it needs the count, pass the count (a tiny `Int` that changes only when the count changes). If it needs nothing but its own note, pass only the note:

```swift
struct CalmRow: View {
    let note: Note          // only its own data
    let totalCount: Int     // a small, stable-ish scalar

    var body: some View {
        let _ = Self._printChanges()
        HStack {
            Text(note.title)
            Spacer()
            Text("\(totalCount)").foregroundStyle(.secondary)
        }
    }
}
```

Even better, if the count is the same for every row and rarely changes, hoist it out of the row entirely (show it in a header). The general principle: **a view's inputs are its re-render triggers. Minimise the inputs and you minimise the triggers.** A row that takes `let note: Note` re-renders only when *its* note changes — exactly what you want.

When a row genuinely needs to *write* back (toggle `done`), give it a `Binding` to its own element, not the array: `ForEach($notes) { $note in CalmRow(note: $note) }` hands each row a `Binding<Note>` to its element. Writing through it mutates one element; only that row re-renders.

## 2.6 — Cause C: a high-frequency input at the top of a large tree

```swift
VStack {
    TextField("Search", text: $searchText)   // mutates @State on THIS view
    List { ForEach(filtered) { ... } }        // ... so the WHOLE VStack recomputes
}
```

`searchText` is `@State` on `StormyListView`. Every keystroke mutates it, which invalidates `StormyListView.body`, which recomputes *the entire `VStack`* — including the code that builds the `List` and iterates `filtered`. The list-building work runs on every keystroke even though, between keystrokes that do not change the filter result, the list is identical.

The issue is **scope**: the high-frequency state (`searchText`) and the expensive tree (the `List`) live in the *same `body`*, so a change to one re-runs the other. The fix is to *narrow the scope* of the high-frequency state so its churn does not reach the expensive tree.

Two complementary fixes:

1. **Extract the high-frequency control into its own view** so its re-renders are contained:

   ```swift
   struct SearchField: View {
       @Binding var text: String
       var body: some View {
           TextField("Search", text: $text).textFieldStyle(.roundedBorder)
       }
   }
   ```

   Now typing re-renders `SearchField` (cheap) and the parent's `body` (which decides what to show), but if the *list view* is also extracted and takes only the *filtered result* as input, the list rebuilds only when the filtered result actually changes.

2. **Extract the list into its own view that takes only what it needs**, so it re-renders only when its input changes:

   ```swift
   struct ResultsList: View {
       let notes: [Note]          // the already-filtered notes
       var body: some View {
           let _ = Self._printChanges()
           List(notes) { CalmRow(note: $0, totalCount: notes.count) }
       }
   }
   ```

When the parent's `body` recomputes on a keystroke, it recomputes `filtered`, but `ResultsList` only re-renders if `filtered` is a *different value* than last time. Type a character that does not change the filtered set (e.g. extending a query that already matches the same rows) and `ResultsList` does not re-render at all. View extraction is the primary structural tool for containing storms: **small views with minimal inputs re-render less.**

## 2.7 — The fully repaired demo

Putting all four fixes together:

```swift
import SwiftUI
import Observation

@Observable
final class NotesStore {
    var notes: [Note] = (1...50).map { Note(title: "Note \($0)") }
}

struct CalmListView: View {
    @State private var store = NotesStore()    // owns the model with @State
    @State private var searchText = ""

    var body: some View {
        let _ = Self._printChanges()
        VStack(spacing: 0) {
            SearchField(text: $searchText)       // Fix C: extracted control
                .padding()
            ResultsList(notes: filtered)         // Fix C: extracted, takes filtered result
        }
    }

    private var filtered: [Note] {
        searchText.isEmpty ? store.notes
            : store.notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        let _ = Self._printChanges()
        TextField("Search", text: $text).textFieldStyle(.roundedBorder)
    }
}

struct ResultsList: View {
    let notes: [Note]
    var body: some View {
        let _ = Self._printChanges()
        List(notes) { note in
            CalmRow(note: note)                  // Fix B: row takes only its note
        }
        // Fix D: no .id(UUID()); ForEach/List uses note.id automatically.
    }
}

struct CalmRow: View {
    let note: Note                               // Fix B: minimal input
    var body: some View {
        let _ = Self._printChanges()
        Text(note.title)
    }
}

struct Note: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var done: Bool = false
}
```

Type one character into the search field now and read the console:

- `SearchField` prints once (it owns the text field; expected).
- `CalmListView` prints once (its `body` recomputes to recompute `filtered`; expected and cheap).
- `ResultsList` prints **only if `filtered` changed value** — narrowing a query reruns it; typing into an empty field that still matches everything may not.
- `CalmRow` prints **only for rows whose `note` actually changed** — typing in the search field changes no note's data, so on a pure filter the surviving rows re-render only because their position/membership changed, and unchanged rows that stay in the list do not re-render their content.

The fifty-rows-per-keystroke storm is gone. Each view re-renders only when *its* inputs change, and you can prove it from the console.

## 2.8 — The four causes, as a diagnostic checklist

When you suspect a storm, instrument with `_printChanges()` + a counter, reproduce the action once, and ask in order:

1. **Do I see `@identity changed`?** → **Cause D (unstable identity).** Find the `.id(...)` with a per-render value (`UUID()`, `Date()`, a recomputed hash) and remove it or make it stable. Also check for structural-identity churn (an `if`/`switch` that swaps subtrees, a `ForEach` whose `id` is not actually unique/stable).

2. **Does an unrelated state change re-render this view?** → **Cause A (coarse model).** If it is `ObservableObject`, migrate to `@Observable` so tracking is per-property. If it is two `@State`s on one giant view, extract so the unrelated state lives elsewhere.

3. **Does this view re-render when a sibling's data changes?** → **Cause B (over-broad inputs).** The view accepts more than it needs (the whole array, the whole store). Reduce its inputs to the minimum; pass scalars or single elements, not collections.

4. **Does a high-frequency input (typing, dragging, scrolling) re-render an expensive tree?** → **Cause C (scope).** The fast-changing `@State` and the expensive subtree share a `body`. Extract the expensive subtree into its own view that takes only its computed input, so it re-renders only when that input changes.

Most real storms are two or three of these stacked, exactly as in the demo. Fix them in order — identity first (it is the most destructive), then model granularity, then inputs, then scope.

## 2.9 — Two storm causes the four-item list does not cover

Two further causes are worth naming because they are subtle:

**`AnyView` erasure defeats diffing.** Wrapping a view in `AnyView` erases its concrete type, and SwiftUI's diff algorithm relies on the concrete type to match views frame-to-frame. A tree built from `AnyView`s diffs poorly and re-renders more than a strongly-typed `@ViewBuilder` tree. The fix is almost always to replace `AnyView` with `@ViewBuilder` and `if`/`switch` (Week 7's lecture on `@ViewBuilder`). Reach for `AnyView` only when you genuinely need heterogeneous, type-erased views in a collection — and know it costs you diffing precision.

**Creating reference types inside `body`.** Anything you `new` up inside `body` (a `DateFormatter`, a `NumberFormatter`, a view model held as a plain `let`) is reconstructed every render. Formatters are expensive; a model reconstructed every render loses its state (the §1.4 footgun). Hoist creation out of `body`: formatters into `static let`, models into `@State`. If `_printChanges` shows a view re-rendering for no input reason, look for an object being constructed in `body` and compared by reference.

## 2.10 — The "renders exactly once" discipline

The mini-project and challenge this week both end with the same acceptance bar, and now you have the tooling to meet it:

> Tapping **Save** in the edit sheet re-renders the one list cell that changed — exactly once. Tapping **Cancel** re-renders nothing. Prove it with a render counter and `onChange(of:)`.

Here is the measurement harness you will adapt for both deliverables:

```swift
struct CommitProofRow: View {
    let note: Note
    let counter: RenderCounter

    var body: some View {
        let _ = counter.tick()
        Text(note.title)
            .onChange(of: note.title) { old, new in
                print("[onChange] cell '\(old)' -> '\(new)'")
            }
    }
}
```

Run the flow: open the sheet, edit the title, save. You should see exactly one `tick()` for the edited cell, one `onChange` for that cell, and *no* output from any other cell. Run it again: open, edit, cancel. You should see *zero* output. If you see more, walk the §2.8 checklist. "It feels fast" is not the deliverable; the counter output pasted into your PR is.

## 2.11 — Instruments, briefly (Week 15 owns this)

`_printChanges()` and a counter are enough for this week. The heavier tool is **Instruments' SwiftUI template** (Xcode → Product → Profile → SwiftUI), which records `View Body` durations, `Update Groups`, and `Hitches` against a timeline, and the **Hangs/Hitches** instruments which show you when a render storm actually dropped a frame against the 16.67 ms budget (60 Hz) or 8.33 ms (120 Hz ProMotion). You will live in Instruments in Week 15. For Week 8, the console-based counter is the right altitude: it is fast, it is exact, and it answers the only question this week asks — *how many times did this `body` run?*

## 2.12 — The reflexes to internalise this week

- **Instrument before you claim.** `let _ = Self._printChanges()` plus a `RenderCounter.tick()` in `body`. Numbers, not vibes.
- **Read `@identity changed` as a red flag.** It means a teardown/rebuild and a lost `@State`. Hunt the unstable `.id`.
- **Migrate `ObservableObject` to `@Observable`.** Per-property tracking eliminates object-level storms for free.
- **Minimise a view's inputs.** A view re-renders when its inputs change; fewer/smaller inputs mean fewer re-renders.
- **Extract expensive subtrees away from high-frequency state.** Scope is the structural lever.
- **Never `new` a formatter or model inside `body`.** `static let` for formatters, `@State` for models.
- **Prove "exactly once."** A user action should re-render the minimum views the minimum times, and you can count it.

These reflexes plus Lecture 1's ownership table are the whole week. With them, you can look at any SwiftUI screen, name the owner of every piece of state, predict every re-render, and prove your prediction with a counter. That is the skill this week earns and the bar your reviewer holds.

---

## Lecture 2 — checklist before moving on

- [ ] I can add `Self._printChanges()` to a `body` and read `@self`, `_property`, and `@identity` messages.
- [ ] I can build a `RenderCounter` and make exact "rendered N times" claims.
- [ ] I can name and fix Cause A (coarse model → `@Observable`).
- [ ] I can name and fix Cause B (over-broad inputs → minimal inputs).
- [ ] I can name and fix Cause C (scope → view extraction).
- [ ] I can name and fix Cause D (unstable `.id` → remove or stabilise).
- [ ] I can explain the `AnyView`-defeats-diffing and object-in-`body` causes.
- [ ] I have actually run the stormy demo, seen fifty rows storm on one keystroke, and watched the fix bring it to one.

If any box is unchecked, return to that section. The exercises and challenge assume you can instrument and read a storm yourself.

---

**References cited in this lecture**

- Apple — "Managing model data in your app": <https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app>
- Apple — "Migrating from the Observable Object protocol to the Observable macro": <https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro>
- WWDC23 — "Discover Observation in SwiftUI": <https://developer.apple.com/videos/play/wwdc2023/10149/>
- WWDC21 — "Demystify SwiftUI" (identity, lifetime, dependencies): <https://developer.apple.com/videos/play/wwdc2021/10022/>
- WWDC23 — "Analyze hangs with Instruments": <https://developer.apple.com/videos/play/wwdc2023/10248/>
- Apple — "id(_:)" view modifier: <https://developer.apple.com/documentation/swiftui/view/id(_:)>
- Apple — "onChange(of:initial:_:)": <https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-8wgw9>
- Apple — "task(priority:_:)" and "task(id:priority:_:)": <https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:)>
