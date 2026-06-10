# Exercise 1 — Environment Injection, No Prop-Drilling

**Goal:** Build an `@Observable` model, inject it *once* at the top of a view tree with `.environment(_:)`, and read it from a view that is five levels deep — without passing the model through a single one of the four views in between. You will *feel* why `@Environment` exists by first writing the prop-drilled version and then deleting all the plumbing.

**Estimated time:** 40 minutes.

---

## Setup

Create a fresh iOS App project in Xcode 16+ (`File ▸ New ▸ Project ▸ App`, Interface: SwiftUI, deployment target iOS 17 or later). You will edit `ContentView.swift` and add one model file.

---

## Part A — The prop-drilled version (write this first, on purpose)

We start with the *wrong* version so the fix lands. Define a model and a five-level-deep tree where the model is threaded through every level even though only the deepest view uses it.

Create `Account.swift`:

```swift
import Observation

@Observable
final class Account {
    var displayName: String = "Ada Lovelace"
    var unreadCount: Int = 3

    func markAllRead() { unreadCount = 0 }
}
```

Replace `ContentView.swift` with the prop-drilled tree:

```swift
import SwiftUI

struct ContentView: View {
    @State private var account = Account()   // owns the model with @State

    var body: some View {
        NavigationStack {
            LevelOne(account: account)        // pass down...
                .navigationTitle("Prop-drilled")
        }
    }
}

struct LevelOne: View {
    let account: Account                      // ...does not use it, just passes it
    var body: some View { LevelTwo(account: account) }
}

struct LevelTwo: View {
    let account: Account                      // ...does not use it, just passes it
    var body: some View { LevelThree(account: account) }
}

struct LevelThree: View {
    let account: Account                      // ...does not use it, just passes it
    var body: some View { LevelFour(account: account) }
}

struct LevelFour: View {
    let account: Account                      // ...does not use it, just passes it
    var body: some View { Badge(account: account) }
}

struct Badge: View {
    let account: Account                      // the ONLY view that actually reads it
    var body: some View {
        VStack {
            Text(account.displayName)
            Text("\(account.unreadCount) unread")
            Button("Mark all read") { account.markAllRead() }
        }
    }
}
```

Run it. It works — tapping "Mark all read" sets the count to zero and the `Badge` updates. But count the cost: **four views** (`LevelOne`…`LevelFour`) each carry an `account` property they never use, purely to relay it. That is prop-drilling. Now imagine adding a *second* shared model — you would thread a second property through all four. This does not scale.

---

## Part B — The `@Environment` version (delete the plumbing)

Now inject the model once and read it directly. Three edits:

**Edit 1 — inject at the top** with `.environment(_:)`:

```swift
struct ContentView: View {
    @State private var account = Account()

    var body: some View {
        NavigationStack {
            LevelOne()                        // no argument
                .navigationTitle("Environment")
        }
        .environment(account)                 // inject ONCE for the whole subtree
    }
}
```

**Edit 2 — delete the plumbing** from the four intermediate views. They no longer carry `account` at all:

```swift
struct LevelOne: View {
    var body: some View { LevelTwo() }
}

struct LevelTwo: View {
    var body: some View { LevelThree() }
}

struct LevelThree: View {
    var body: some View { LevelFour() }
}

struct LevelFour: View {
    var body: some View { Badge() }
}
```

**Edit 3 — read from the environment** in the deepest view, by type:

```swift
struct Badge: View {
    @Environment(Account.self) private var account   // read by type, no argument

    var body: some View {
        VStack {
            Text(account.displayName)
            Text("\(account.unreadCount) unread")
            Button("Mark all read") { account.markAllRead() }
        }
    }
}
```

Run it. Identical behaviour — but `LevelOne` through `LevelFour` are now pure pass-through views with zero knowledge of `Account`. You added a shared dependency without touching any intermediate view. That is the entire value proposition of `@Environment`.

---

## Part C — Prove per-property tracking

Add a second property to the model and a second deep view that reads only *that* property, to prove `@Observable` tracking is per-property.

Add to `Account`:

```swift
var themeName: String = "Aurora"
func cycleTheme() { themeName = themeName == "Aurora" ? "Midnight" : "Aurora" }
```

Add a `Self._printChanges()` line to both `Badge` and a new `ThemeLabel`:

```swift
struct ThemeLabel: View {
    @Environment(Account.self) private var account

    var body: some View {
        let _ = Self._printChanges()
        Text("Theme: \(account.themeName)")    // reads themeName ONLY
    }
}
```

Put both in the tree (e.g. `VStack { Badge(); ThemeLabel() }` somewhere reachable) and add a `Self._printChanges()` to `Badge`. Now:

- Tap **"Mark all read"** (mutates `unreadCount`). The console prints a change for `Badge` (it reads `unreadCount`) but **not** for `ThemeLabel` (it reads only `themeName`).
- Add a "Cycle theme" button that calls `account.cycleTheme()`. Tapping it prints a change for `ThemeLabel` but **not** for `Badge`.

This is the headline win from Lecture 1 §1.4, observed directly: each view re-renders only when a property *it reads* changes.

---

## Expected console output

After Part C, tapping "Mark all read" once prints something like (exact text varies by SwiftUI version):

```
Badge: _account changed.
```

and tapping "Cycle theme" once prints:

```
ThemeLabel: _account changed.
```

Critically, **each tap prints exactly one of the two**, never both. If both views print on a single tap, you accidentally made one view read both properties — check that `ThemeLabel` reads only `themeName`.

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `Account` is an `@Observable final class` with no `@Published` and no `ObservableObject` conformance.
- [ ] `ContentView` owns the model with `@State private var account = Account()` and injects it with `.environment(account)`.
- [ ] `LevelOne` through `LevelFour` carry **zero** properties — they are pure pass-through views.
- [ ] `Badge` and `ThemeLabel` read the model with `@Environment(Account.self) private var account`.
- [ ] The build has **zero warnings** under iOS 17+ with strict concurrency.
- [ ] You verified per-property tracking: a `unreadCount` change re-renders `Badge` and not `ThemeLabel`, and vice versa, observed via `Self._printChanges()`.

---

## Stretch

- Make the read **optional** — declare `@Environment(Account.self) private var account: Account?` and render a placeholder when it is `nil`. Then *remove* the `.environment(account)` injection and confirm the app shows the placeholder instead of trapping. This is the safe pattern for a view that might render outside the injection scope (e.g. in a preview).
- Add a `#Preview` for `Badge` that injects a stub account: `#Preview { Badge().environment(Account()) }`. Confirm the preview renders without a crash — and that *omitting* the `.environment` injection makes the non-optional version trap, the modern, predictable replacement for the legacy `@EnvironmentObject` runtime crash.
- Inside a view, derive a local `@Bindable` from the environment model and bind a `Toggle` to a `Bool` property you add: `@Bindable var account = account` then `Toggle("Compact", isOn: $account.compact)`. This is the §1.5 idiom you will use constantly.

---

## Hints

<details>
<summary>"No Account found" trap at runtime</summary>

A non-optional `@Environment(Account.self)` traps if no `Account` was injected into the subtree. Make sure `.environment(account)` is applied to a view that is an *ancestor* of the reader. If you put `.environment(...)` on a sibling instead of an ancestor, the reader will not see it. Injection flows **down** the tree from where the modifier is attached.

</details>

<details>
<summary>The preview crashes</summary>

A `#Preview` that renders `Badge()` without injecting an `Account` will trap on the non-optional read. Either inject one in the preview (`Badge().environment(Account())`) or use the optional form. This is exactly the failure the typed `@Environment` makes *predictable* — it crashes at the read site with a clear message, not somewhere mysterious.

</details>

<details>
<summary>Both views re-render on every change</summary>

If `Badge` re-renders when you cycle the theme, it is reading `themeName` somewhere — check you did not add `Text(account.themeName)` to `Badge` by accident. Per-property tracking keys off the properties each `body` *actually reads*.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — Bindable sheet edit](exercise-02-bindable-sheet-edit.swift).
