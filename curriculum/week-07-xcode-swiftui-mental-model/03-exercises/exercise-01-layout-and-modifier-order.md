# Exercise 1 — Layout and the Modifier-Order Rule

**Time estimate:** ~45 minutes.

## Goal

Build a small, real layout — a profile header — from `Text`, `Image`, `Button`, and the stack primitives. Then take *two adjacent modifiers* (`.padding()` and `.background()`), swap their order, and document — in words and in a screenshot — exactly how the rendered result changes. By the end you will never again guess at modifier order; you will read a chain bottom-up and predict the result.

This is a guided exercise. You write the code in Xcode, run it in the Canvas and the Simulator, and answer three short questions in a `notes.md`.

## Setup

1. In Xcode 16, create a new project: File ▸ New ▸ Project ▸ iOS ▸ App. Name it `ModifierOrder`, interface **SwiftUI**, language **Swift**, storage **None**.
2. Open `ContentView.swift`. You will replace its contents across the steps below.
3. Toggle the Canvas with `⌥⌘↵` and pin it so it refreshes as you type.

## Step 1 — Build the profile header

Replace `ContentView` with this. It is complete and correct — type it in (do not paste), then run it.

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProfileHeader(
                name: "Ada Lovelace",
                role: "Analytical Engine, lead",
                symbol: "person.crop.circle.fill"
            )
            Spacer()
        }
        .padding()
    }
}

struct ProfileHeader: View {
    let name: String
    let role: String
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                Text(role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") {
                print("Edit tapped")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
}
```

Run it (`⌘R`) on any simulator. You should see an icon, a two-line name/role block, a spacer, and an "Edit" button, all on one row, with the row inset from the screen edges. Tap "Edit" and confirm `Edit tapped` prints in the Debug area (`⌘⇧Y`).

Read the tree out loud: an `HStack` containing an `Image`, a `VStack` of two `Text`s, a `Spacer` (which pushes the button to the trailing edge), and a `Button`. The `Spacer` is what makes the layout fill the width and right-align the button. Remove the `Spacer` temporarily and watch the button slide left against the text — then put it back. That is `Spacer` choosing to be as large as proposed.

## Step 2 — Add a background card, the WRONG way first

Wrap the `ProfileHeader`'s `HStack` so it looks like a card. Apply the background *before* the padding and observe the bug:

```swift
struct ProfileHeader: View {
    let name: String
    let role: String
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                Text(role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") {
                print("Edit tapped")
            }
            .buttonStyle(.borderedProminent)
        }
        .background(Color(.secondarySystemBackground))   // ← background FIRST
        .padding()                                        // ← padding SECOND
        .clipShape(.rect(cornerRadius: 12))
    }
}
```

Run it. **The card colour hugs the content with no breathing room, and the padding is transparent space *outside* the coloured rectangle.** The corners may also look wrong because you are clipping the padded (transparent) region. This is the modifier-order rule biting: `.background` painted behind the bare `HStack`, then `.padding` added clear space outside the colour.

## Step 3 — Fix the order

Swap the two modifiers so padding is *inside* the background, and move the clip to the end:

```swift
        .padding()                                        // ← padding FIRST
        .background(Color(.secondarySystemBackground))    // ← background SECOND
        .clipShape(.rect(cornerRadius: 12))
```

Run it again. **Now the card colour fills the padded region — the content has comfortable inset space inside a single rounded coloured card.** Same three modifiers, two of them merely reordered, completely different result.

## Step 4 — Make the card fill the width

The card currently hugs its content's width. Make it a full-width card (the usual look) by inserting a frame *before* the background:

```swift
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)  // choose to fill width
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)                             // outer margin from screen edges
```

Run it. The card now spans the width with a margin from the screen edges, content inset comfortably inside the coloured, rounded surface. Read the chain bottom-up and confirm you can name what each modifier wraps.

## Deliverable — `notes.md`

Create a `notes.md` in the project folder and answer these three questions in your own words (2–4 sentences each):

1. In Step 2, *why* did the yellow/grey card hug the content instead of including the padding? Describe what `.background` wraps when it is applied before `.padding`.
2. In Step 3, what changed structurally when you swapped the two modifiers? Use the phrase "wraps the result of."
3. In Step 4, why was `.frame(maxWidth: .infinity)` necessary to make the card fill the width, given that the `Text` and `Image` are sovereign over their own size? Reference propose/choose/place.

Take one screenshot of the Step 2 (wrong) result and one of the Step 4 (final) result and reference them in `notes.md`.

## Acceptance criteria

- [ ] The Step 1 layout builds and runs; tapping "Edit" prints `Edit tapped`.
- [ ] You have *seen, in the Canvas or Simulator,* the difference between Step 2 and Step 3 with your own eyes (not just read about it).
- [ ] The Step 4 card fills the width with an outer horizontal margin and inner padding inside a single rounded coloured surface.
- [ ] `notes.md` answers all three questions correctly and references both screenshots.
- [ ] Xcode shows **Build Succeeded** with **zero warnings**.

## Hints

<details>
<summary>Hint 1 — "wraps the result of"</summary>

`view.a().b()` produces `b(a(view))`. The modifier furthest from the view is the *outermost* wrapper. So `.background().padding()` is `padding(background(hstack))` — padding wraps a view that is *already* the coloured background, so the padding sits outside the colour.

</details>

<details>
<summary>Hint 2 — why frame is needed for full width</summary>

`.background` paints behind exactly the size of the view it wraps. An `HStack` of an icon, two lines of text, a `Spacer`, and a button… actually *does* try to fill the width because of the `Spacer`. But once you wrap it in `.padding()`, the padded view still reports the `HStack`'s width. `.frame(maxWidth: .infinity)` inserts a view that, when proposed the full width, *chooses* the full width and centres/leads its child within it — so the subsequent `.background` paints the full width. Without it, the card width depends on content.

</details>

<details>
<summary>Hint 3 — clip must be last</summary>

`.clipShape(.rect(cornerRadius:))` clips whatever is beneath it. Put it *after* `.background` so you round the painted card. Put it before and you round the content's bounds, then paint an unrounded rectangle behind — square corners.

</details>

## Why this matters

The modifier-order rule is the number-one source of "why does my SwiftUI layout look wrong" in an engineer's first month. Every card, every button, every coloured surface you build for the rest of this course depends on getting padding/background/frame/clip in the right order. Drill it once, here, with your eyes — and it becomes reflex.
