# Week 7 — Quiz

Thirteen multiple-choice questions. Take it with your lecture notes closed. Aim for 10/13 before moving to Week 8. Answer key at the bottom — don't peek.

---

**Q1.** What is the single most accurate one-sentence summary of SwiftUI's model?

- A) SwiftUI gives you long-lived view objects that you imperatively mutate when the model changes.
- B) A view is a value that describes the UI as a function of state; when state changes, SwiftUI re-invokes `body`, diffs the result, and applies the minimum mutation.
- C) SwiftUI compiles your `body` to UIKit `UIView`s once at launch and never recomputes it.
- D) SwiftUI is a styling layer over HTML/CSS rendered in a web view.

---

**Q2.** Why is a SwiftUI `View` a `struct` (a value type) rather than a `class`?

- A) Because Swift forbids `class` types from conforming to protocols.
- B) Because a view is a cheap, copyable description with no identity of its own, which lets SwiftUI hold the old and new values side by side and diff them without heap-allocation pressure.
- C) Because `struct`s render faster on the GPU than `class`es.
- D) There is no reason; it is an arbitrary Apple convention and `class` works identically.

---

**Q3.** Your `body` does this. What is wrong?

```swift
var body: some View {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    logAnalytics(event: "viewed")
    return Text(formatter.string(from: .now))
}
```

- A) Nothing — this is idiomatic SwiftUI.
- B) `body` must be pure: it can be invoked very often, so allocating a `DateFormatter` and firing a side-effecting analytics call inside it is a performance and correctness bug. Move the formatter out and fire analytics from `.onAppear`/`.task`.
- C) `DateFormatter` is not available in SwiftUI.
- D) You cannot use `return` inside a `@ViewBuilder` body.

---

**Q4.** What is the relationship between `App`, `Scene`, and `WindowGroup`?

- A) `App` is a `Scene`, which is a `WindowGroup`; they are three names for the same protocol.
- B) `App.body` returns a `Scene`; `WindowGroup` is a concrete `Scene`; the `WindowGroup`'s closure returns the root `View`. The chain is App ▸ Scene ▸ View.
- C) `WindowGroup` is the entry point and `App` is optional.
- D) `Scene` returns an `App`, which returns a `WindowGroup`.

---

**Q5.** What is the difference between a **scheme**, a **target**, and a **build configuration** in Xcode?

- A) They are synonyms.
- B) A target is *what* gets built; a build configuration (Debug/Release) is *how* it's built; a scheme ties a set of targets + a configuration to a specific action (Run, Archive, Test).
- C) A scheme is *what* gets built; a target is *how*; a configuration picks the simulator.
- D) Only schemes exist; "target" and "configuration" are legacy terms.

---

**Q6.** Why is `body`'s return type written `some View` rather than `AnyView`?

- A) `AnyView` is deprecated.
- B) `some View` is an opaque type: there is one specific concrete type, fixed at compile time, so the diffing engine knows the exact static shape of the tree. `AnyView` is a type-erased existential box that hides the type from the diff engine and acts as an opacity wall.
- C) `some View` and `AnyView` are identical; the choice is stylistic.
- D) `AnyView` cannot be returned from a computed property.

---

**Q7.** What does `@ViewBuilder` do with this block, and what is the resulting static type?

```swift
var body: some View {
    Text("a")
    Text("b")
}
```

- A) It throws a compile error — a function may return only one value.
- B) It rewrites the two statements into `ViewBuilder.buildBlock(Text("a"), Text("b"))`, producing a `TupleView<(Text, Text)>`.
- C) It puts them into an `Array<Text>` and renders the array.
- D) It picks the last statement (`Text("b")`) and discards the first.

---

**Q8.** You write an `if`/`else` in `body` whose branches contain `@State`. You flip from the `if` branch to the `else` branch and back. What happens to the state in the `if` branch?

- A) It is preserved across the flip; SwiftUI caches both branches.
- B) `@ViewBuilder` compiles `if`/`else` to `_ConditionalContent`, which treats the two branches as different identities. Switching branches is a removal + insertion, so the `if` branch's state is destroyed and recreated when you return to it.
- C) It is shared between the two branches.
- D) The app crashes; you cannot put `@State` inside conditional content.

---

**Q9.** These two render differently. Why?

```swift
// A
Text("Hi").padding().background(.yellow)
// B
Text("Hi").background(.yellow).padding()
```

- A) They render identically; modifier order never matters.
- B) Each modifier returns a new view that *wraps* the one beneath it. In A, `.background` paints behind the padded view (colour includes the inset). In B, `.background` paints behind the bare text, then `.padding` adds transparent space outside the colour.
- C) `.padding()` in B is ignored because it comes after a colour.
- D) B fails to compile because `.padding()` must come first.

---

**Q10.** In SwiftUI's layout model, who decides a view's size?

- A) The parent forces an exact size on every child.
- B) The parent *proposes* a size; the child *chooses* its own size (it may ignore the proposal); the parent then *places* the child. The child is sovereign over its size.
- C) The layout engine computes all sizes globally by solving a constraint system, as in Auto Layout.
- D) Sizes are fixed at compile time from the `#Preview` device.

---

**Q11.** Why does this `Text` not fill the screen, and what fixes it?

```swift
Text("Short").background(.red)
```

- A) It does fill the screen; the question is wrong.
- B) `Text` *chooses* only the size its string needs, so `.background` paints a small rectangle hugging the word. To fill, wrap it in a view that chooses to be large: `.frame(maxWidth: .infinity, maxHeight: .infinity)` *before* `.background`.
- C) Add `.fillScreen()`.
- D) Replace `Text` with `Label`.

---

**Q12.** You want light/dark mode to work with **zero** branching code. What is the correct approach?

- A) Read `@Environment(\.colorScheme)` everywhere and pick colours with `if scheme == .dark`.
- B) Use semantic colours (`.primary`, `.secondary`, `Color(.systemBackground)`) and asset-catalog colour sets with light/dark variants; the system re-resolves them automatically when appearance changes. Reading `colorScheme` to *choose* colours by hand is the anti-pattern.
- C) Ship two separate apps.
- D) Hard-code dark colours; light mode is deprecated.

---

**Q13.** When is `EquatableView` / the `.equatable()` modifier the right tool?

- A) On every view, always, for free performance.
- B) On a view whose `body` is genuinely expensive to compute and whose inputs are cheap and honest to compare, so SwiftUI can skip recomputing `body` when the inputs are unchanged. It is an optimisation to apply after measuring, not a default — and a dishonest `==` causes stale UI.
- C) Only on views that contain a stored closure.
- D) It is required for any view in a `ForEach`.

---

## Answer key

<details>
<summary>Click to reveal answers</summary>

1. **B** — The defining sentence of the framework. A is the UIKit model SwiftUI replaces; C and D are simply false.

2. **B** — Value semantics are the keystone: cheap copies let SwiftUI keep old and new view values side by side and diff them. A is false (classes can conform to protocols); C is nonsense; D misses the entire point.

3. **B** — `body` must be a pure, fast function of the view's state. Allocating a `DateFormatter` on every invocation and firing a side-effecting analytics call inside `body` are both bugs. Hoist the formatter (or use a cached static) and move side effects to `.onAppear`/`.task`.

4. **B** — App ▸ Scene ▸ View. `App.body: some Scene`; `WindowGroup` is a concrete `Scene`; its trailing closure returns the root `View`.

5. **B** — Target = *what*, configuration = *how* (Debug vs Release), scheme = *which targets + which configuration, for which action*. This vocabulary matters in Week 15 (device deployment) and Week 22 (CI).

6. **B** — `some View` is an opaque type the compiler resolves to one fixed concrete type, giving the diff engine the static shape it needs to be fast. `AnyView` erases the type and acts as an opacity wall — use it only when you truly cannot express the type statically.

7. **B** — `@ViewBuilder` is a result builder; two sibling statements compile to `buildBlock(_:_:)`, which returns a `TupleView<(Text, Text)>`. That is why you can write views without commas or `return`.

8. **B** — `if`/`else` compiles to `_ConditionalContent`, and the two branches have *different identities*. Flipping branches is remove + insert, so the departed branch's `@State` is destroyed and re-created on return. This is a common Week 8 surprise; the cause is here.

9. **B** — Modifiers wrap; order is composition order. `.padding().background()` paints behind the padded view; `.background().padding()` paints behind the bare text and pads outside the colour. Read chains bottom-up.

10. **B** — Propose, choose, place. The child is sovereign over its own size and may ignore the parent's proposal. This is fundamentally unlike Auto Layout's global constraint solving.

11. **B** — `Text` chooses only the width/height its glyphs need, so the background hugs the word. Insert `.frame(maxWidth: .infinity, maxHeight: .infinity)` *before* `.background` to add a view that chooses the large size and centres the text inside it.

12. **B** — Semantic colours and asset-catalog colour sets with light/dark variants make appearance adaptation automatic. Branching on `colorScheme` to pick a colour by hand is the anti-pattern; reading `colorScheme` is only legitimate to *display* the mode, not to choose colours.

13. **B** — `.equatable()` lets SwiftUI compare old and new view values with your `==` before calling `body`, skipping recomputation when inputs are unchanged. It pays off only for expensive bodies with cheap, honest equality, and only after you have measured. A dishonest `==` shows stale UI — a correctness bug. It is not required for `ForEach` (that needs `Identifiable`/`id:`).

</details>

---

If you scored under 10, re-read the lectures for the questions you missed — especially Q8 (conditional content identity) and Q9/Q11 (modifier order and propose/choose/place), which bite hardest in Week 8. If you scored 12 or 13, you're ready for the [homework](./06-homework.md) and the mini-project.
