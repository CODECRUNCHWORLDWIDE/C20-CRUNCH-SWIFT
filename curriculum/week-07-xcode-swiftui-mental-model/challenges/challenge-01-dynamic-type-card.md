# Challenge 1 — A Card That Survives the Largest Dynamic Type

**Time estimate:** ~120 minutes.

## Problem statement

Build a single SwiftUI component — a `NoteCard` — that displays a note with **four** elements:

1. A leading **image** (an SF Symbol, e.g. `note.text`, tinted).
2. A **title** (one or two lines, bold).
3. A **multi-line body** (the note's text, several sentences).
4. A **trailing badge** showing a small piece of metadata — a category pill (e.g. "Work", "Personal") with a coloured background.

You must build it **purely from stacks (`VStack`, `HStack`, `ZStack`) and modifiers** — no `Grid`, no `Table`, no `List`, and no UIKit. The hard requirement is that the card **renders correctly at the largest accessibility Dynamic Type size (`.accessibility5`)** with **no clipping and no truncation of the title or badge**, on both an iPhone SE (3rd generation) and an iPad Pro 13-inch (M4), in both light and dark mode.

This is harder than it looks. At `.accessibility5`, the title font can be three to four times its default size. A naive `HStack` of [image | text | badge] that looks perfect at the default size will, at the largest size, either clip the badge off the trailing edge, truncate the title with an ellipsis, or shove the body text into a one-character-wide sliver. A senior iOS engineer designs the card to *reflow* when the text gets huge, not to clip.

## Acceptance criteria

```
Renders correctly on iPhone SE (3rd gen) and iPad Pro 13-inch,
in light and dark, at Dynamic Type .accessibility5 — no clipping, no truncation.
```

- [ ] `NoteCard` is a reusable `View` taking at least: `title: String`, `body: String`, `symbol: String`, `category: String`, `categoryTint: Color`.
- [ ] Built **only** from `Text`, `Image`, `VStack`/`HStack`/`ZStack`, `Spacer`, and modifiers. No `Grid`, `List`, `Table`, `Form`, or UIKit.
- [ ] At the **default** text size: image leads, title and body stack to its right, badge sits at the trailing top.
- [ ] At **`.accessibility5`**: the layout **reflows** so that nothing clips and the title is never truncated. Acceptable strategies include moving the badge below the text, switching the whole header from an `HStack` to a `VStack`, or using `ViewThatFits` to pick the layout that fits. Pick one and justify it.
- [ ] Uses **semantic** or **asset-catalog** colours so light/dark adaptation requires no branching (the body text uses `.secondary`, the card background uses a semantic or catalog colour).
- [ ] Spacing scales with text size where appropriate — use `@ScaledMetric` for at least the icon size or the inter-element spacing so it grows with the user's chosen text size.
- [ ] Five `#Preview` blocks prove the matrix:
  - default size,
  - `.accessibility5`,
  - `.accessibility5` in dark mode,
  - a card with a very long title (e.g. 12+ words),
  - a card with an empty/short body.
- [ ] Builds with **zero warnings**.

## Starter scaffold

Drop this into a fresh SwiftUI app's `ContentView.swift`. It compiles and renders at the default size, but **it clips and truncates at `.accessibility5`** — your job is to fix the reflow.

```swift
import SwiftUI

struct NoteCard: View {
    let title: String
    let body: String
    let symbol: String
    let category: String
    let categoryTint: Color

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 28

    var body: some View {
        // NAIVE LAYOUT — clips the badge and truncates the title at accessibility5.
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: iconSize))
                .foregroundStyle(categoryTint)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CategoryBadge(category: category, tint: categoryTint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

struct CategoryBadge: View {
    let category: String
    let tint: Color

    var body: some View {
        Text(category)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18), in: .capsule)
            .foregroundStyle(tint)
    }
}

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NoteCard(
                    title: "Refactor the modifier-order section",
                    body: "Split the padding/background example into two and add a screenshot for each so the contrast is unmissable.",
                    symbol: "note.text",
                    category: "Work",
                    categoryTint: .blue
                )
                NoteCard(
                    title: "Buy oat milk",
                    body: "And the good coffee, not the supermarket own-brand.",
                    symbol: "cart.fill",
                    category: "Personal",
                    categoryTint: .green
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Default") {
    ContentView()
}

#Preview("Accessibility 5") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility5)
}
```

Run the "Accessibility 5" preview. You will see the breakage: the badge gets squeezed or clipped and the title may truncate. Now fix it.

## Recommended approach

1. **Detect the size class of the text, not just the device.** Read `@Environment(\.dynamicTypeSize)` and ask `dynamicTypeSize.isAccessibilitySize`. That boolean is your reflow trigger.
2. **Reflow the header.** When `isAccessibilitySize` is true, stop fighting for a single row. Put the badge *under* the text (or above the title), and let the title use the full width. The cleanest expression is often two `body` branches selected by the boolean, or a `ViewThatFits` that tries the horizontal layout first and falls back to the vertical one.
3. **Never truncate the title.** Either omit `.lineLimit` (let it wrap freely) or set a generous limit. Do not set `.lineLimit(1)` on a title that must survive `.accessibility5`.
4. **Scale spacing and the icon.** Use `@ScaledMetric` (already in the starter for the icon) so the icon and the gaps grow with the text; a 28pt icon next to 60pt text looks broken.
5. **Keep colours semantic.** You should not write a single `if colorScheme == .dark`. The body text is `.secondary`; the card background is `Color(.secondarySystemBackground)` or a catalog colour. Dark mode falls out for free.

## Hints

<details>
<summary>Hint 1 — the reflow boolean</summary>

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var useStackedLayout: Bool {
    dynamicTypeSize.isAccessibilitySize
}
```

Branch your `body` on `useStackedLayout`: a compact `HStack` header for normal sizes, a `VStack` header (image + title, then badge, then body) for accessibility sizes.

</details>

<details>
<summary>Hint 2 — ViewThatFits, the elegant alternative</summary>

`ViewThatFits` tries its child views in order and renders the first that fits the proposed space. You can give it the horizontal layout first and the vertical layout second:

```swift
ViewThatFits(in: .horizontal) {
    horizontalHeader   // tried first
    verticalHeader     // used when horizontal doesn't fit
}
```

This is declarative and avoids the explicit boolean — but read the body twice when both layouts are non-trivial; it can surprise you with which one it picks. For this challenge either approach is acceptable; document which you chose and why.

</details>

<details>
<summary>Hint 3 — proving the matrix without 12 simulators</summary>

You do not need to boot every device. Use `#Preview` with `.environment(\.dynamicTypeSize, .accessibility5)` and `.preferredColorScheme(.dark)` to render the hard combinations in the Canvas, then spot-check the two extreme devices (iPhone SE, iPad Pro 13-inch) in the running simulator. The Canvas is your fast oracle; the simulator is your truth.

</details>

## Stretch

- Make the `CategoryBadge` itself reflow: at accessibility sizes, let it wrap its text rather than forcing a single-line capsule that overflows.
- Add a `.accessibilityElement(children: .combine)` so VoiceOver reads the whole card as one element ("Refactor the modifier-order section, Work, …") instead of four disconnected fragments. (Accessibility is Week 16 in full; this is a taste.)
- Add a faint `.shadow` and a hairline `.overlay` border, ordered correctly relative to `.clipShape`, and explain the order in a comment.

## Submission

Commit the `NoteCard` component under `challenges/challenge-01/` in your Week 7 repo, with the five `#Preview` blocks intact. Make sure a fresh clone builds with zero warnings. Include a one-paragraph note explaining which reflow strategy you chose (boolean branch vs `ViewThatFits`) and why.

## Why this matters

Dynamic Type is not optional politeness; a large share of real users run text well above the default, and `.accessibility5` is a setting your app *will* be opened in. A card that clips at the largest size is a bug report waiting to happen and an App Review accessibility note waiting to be written. Building the reflow once, here, on a component you will literally reuse in the mini-project, makes "survives the largest text size" a property you design in from the first stack — not a fire you fight after a beta tester complains.
