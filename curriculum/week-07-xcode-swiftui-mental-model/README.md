# Week 7 — Xcode, the SwiftUI Mental Model, and Your First App

Welcome to **Phase II** of C20 · Crunch Swift. For six weeks you have lived in the open-source Swift toolchain on Linux, building a Vapor service and a CLI client with shared codable types. This week you move onto the Mac, open **Xcode 16+** for the first time, and ship your first **SwiftUI** app into the **iOS Simulator**.

This is a deliberate hinge in the course. The language is no longer the lesson — you already write idiomatic Swift. The lesson is now a *framework* with a strong opinion about how user interfaces should be expressed: **SwiftUI is a function from state to a view tree, and the system re-invokes that function and diffs the result whenever the state changes.** Internalise that one sentence and most of SwiftUI stops being magic. Miss it, and you will spend the next five weeks fighting a framework you do not understand.

By Friday you should be able to scaffold a SwiftUI app target in Xcode, read the generated `App` and `Scene` declarations without flinching, build a non-trivial view hierarchy from `Text`, `Image`, `Button`, and the stack primitives, explain *why* modifier order changes the rendered result, and run the same screen across an iPhone SE and an iPad Pro 13-inch with both light and dark mode and the largest Dynamic Type setting — without it breaking.

We do not teach SwiftUI from drag-and-drop down. We teach it from the layout system up. The Canvas preview is a tool, not a crutch; you will read the `View` protocol, the `@ViewBuilder` result builder, and the `Layout` protocol as the real source of truth.

## Learning objectives

By the end of this week, you will be able to:

- **Navigate** Xcode 16+ — the project navigator, the editor, the inspectors, the Canvas, the scheme selector, and the run destination — and explain what a *scheme* and a *build configuration* are.
- **Distinguish** the SwiftUI `App` protocol, the `Scene` protocol, and the `WindowGroup` scene, and explain what each contributes to app launch.
- **Explain** the `View` protocol contract: `associatedtype Body` and the `@ViewBuilder var body: some Body` requirement, and why `body` is a computed property and not a stored one.
- **State** the central SwiftUI claim — *view is a function of state* — and describe how SwiftUI diffs the returned tree to compute the minimum set of UI updates.
- **Describe** what `@ViewBuilder` does (it is a result builder that turns a sequence of statements into a single composed view) and what `EquatableView` does (it lets you supply a custom equality to short-circuit diffing).
- **Build** a layout from `Text`, `Image`, `Button`, `VStack`, `HStack`, and `ZStack`, and reason about how the layout system negotiates size top-down and bottom-up.
- **Apply** the modifier-order rule: modifiers wrap views, each returning a *new* view, so `.padding().background()` and `.background().padding()` render differently.
- **Configure** an asset catalog with a colour set and an app icon, and verify the app adapts between light and dark appearance automatically.
- **Support** Dynamic Type so a view survives the largest accessibility text size without truncation or clipping.
- **Render** the same view across multiple devices using `#Preview` and adapt the layout so it reads correctly on a 4.7-inch phone and a 13-inch tablet.

## Prerequisites

This week assumes you have completed **C20 weeks 1–6** (Phase I — Swift the language and Vapor server-side) or have equivalent Swift fluency. Specifically:

- You write idiomatic Swift: value vs reference types, optionals, `guard`/`if let`, protocols, generics, `some` vs `any`, and basic `async`/`await`.
- You can read a `Codable` `struct` and know why `struct Note: Codable, Sendable` is the shape we share between client and server (Week 6).
- You can use a terminal, Git (`clone`, `commit`, `push`), and Swift Package Manager.

New hard requirement starting this week:

- **A Mac with Apple Silicon (M1 or newer recommended)** running a current macOS, with **Xcode 16 or newer** installed from the Mac App Store. The iOS Simulator ships with Xcode and is free. You do **not** need an Apple Developer Program membership yet — that becomes required in Week 15.

You do **not** need any prior SwiftUI, UIKit, or iOS experience. We start at the `App` entry point and the `View` protocol.

## Topics covered

- The Xcode 16 tour: project navigator, editor, the inspectors (File / Attributes / History), the Canvas preview, the scheme selector, the run destination, and the Debug area.
- **Schemes** vs **targets** vs **build configurations** — what each is, why a scheme bundles a build action with a run destination, and how `Debug` and `Release` differ.
- **Asset catalogs** (`Assets.xcassets`): image sets with `1x`/`2x`/`3x`, colour sets with light/dark variants, the app icon, and the accent colour.
- The SwiftUI app entry point: the `@main` `App` protocol, the `Scene` protocol, and the `WindowGroup` scene.
- The `View` protocol contract: `associatedtype Body: View` and `@ViewBuilder var body: Body { get }`.
- **View is a function of state.** How SwiftUI invokes `body`, builds a tree of lightweight value-type view descriptions, diffs it against the previous tree, and applies the minimum UI mutation.
- `@ViewBuilder` — the result builder that lets `body` read like a list of subviews, and what `buildBlock`, `buildOptional`, and `buildEither` compile your `if`/`switch` into.
- `EquatableView` and the `.equatable()` modifier — supplying custom equality to short-circuit re-render of an expensive subtree.
- The layout primitives: `Text`, `Image`, `Label`, `Button`, `Spacer`, `Divider`, and `VStack` / `HStack` / `ZStack`.
- The **`Layout` protocol** at a conceptual level: the parent proposes a size, the child chooses its size, the parent places the child. `sizeThatFits` and `placeSubviews`.
- **The modifier-order rule.** A modifier returns a new view that wraps the old one, so order is composition order. `.padding().background()` ≠ `.background().padding()`.
- Light/dark mode via semantic colours and the asset catalog; `@Environment(\.colorScheme)`.
- **Dynamic Type** and the `@ScaledMetric` property wrapper; previewing at `.accessibility5`.
- Multi-device previews with the `#Preview` macro; designing for iPhone SE and iPad Pro 13-inch.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target.

| Day       | Focus                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Xcode tour, schemes, build configs, asset catalogs |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | App/Scene, the View protocol, body as state→view   |    2h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | @ViewBuilder, EquatableView, the Layout protocol   |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Primitives, stacks, the modifier-order rule        |    1h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | Light/dark, Dynamic Type, multi-device previews    |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0.5h    |     6h      |
| Saturday  | Mini-project deep work ("Hello, Notes")            |    0h    |    0h     |     0h     |    0h     |   1h     |     3h       |    0h      |     4h      |
| Sunday    | Quiz, review, polish                               |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **6h**   | **8.5h**     | **2h**     | **35.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Curated Apple docs, WWDC sessions, books, and open-source SwiftUI to read |
| [lecture-notes/01-swiftui-is-a-function-of-state.md](./lecture-notes/01-swiftui-is-a-function-of-state.md) | Xcode tour, App/Scene, the View protocol, and why view is a function of state with diffing |
| [lecture-notes/02-viewbuilder-equatableview-layout-modifiers.md](./lecture-notes/02-viewbuilder-equatableview-layout-modifiers.md) | How `body` is invoked: `@ViewBuilder`, `EquatableView`, the `Layout` protocol, and the modifier-order rule |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-layout-and-modifier-order.md](./exercises/exercise-01-layout-and-modifier-order.md) | Build a layout from Text/Image/Button/stacks, then reorder two modifiers and observe the change |
| [exercises/exercise-02-asset-catalog-light-dark.swift](./exercises/exercise-02-asset-catalog-light-dark.swift) | Drive an asset-catalog colour set and verify light/dark adaptation |
| [exercises/exercise-03-iphone-se-ipad-pro-previews.swift](./exercises/exercise-03-iphone-se-ipad-pro-previews.swift) | Render one view on iPhone SE and iPad Pro 13-inch and adapt the layout to fit both |
| [challenges/README.md](./challenges/README.md) | Index of weekly challenges |
| [challenges/challenge-01-dynamic-type-card.md](./challenges/challenge-01-dynamic-type-card.md) | Recreate a card layout that survives the largest Dynamic Type setting |
| [quiz.md](./quiz.md) | 13 multiple-choice questions with an answer key |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for the "Hello, Notes" mini-project |

## The "renders on both, in both" promise

C20 Phase II uses a recurring acceptance marker for every screen you build:

```
Renders correctly on iPhone SE (3rd gen) and iPad Pro 13-inch,
in light and dark, at Dynamic Type .accessibility5 — no clipping, no truncation.
```

If your view looks right on the simulator you happen to have booted but clips at the largest text size, or overflows on the 4.7-inch phone, you are not done. The point of Week 7 is to make that line ordinary. Three device classes, two appearances, the largest text size — a senior iOS engineer checks all six combinations by reflex, and so will you.

## What this week is NOT

- **It is not state management.** `@State`, `@Observable`, `@Environment`, and `@Bindable` are next week. This week every note is hard-coded; nothing the user does changes the data. We are learning to *describe* a UI before we learn to *drive* it.
- **It is not navigation.** No `NavigationStack`, no sheets, no tabs. One screen. That is Week 9.
- **It is not persistence.** No SwiftData, no files, no network. The notes live in an array literal in source. That is Week 10.
- **It is not UIKit.** We do not teach `UIViewController` or `UIView`. We will name UIKit when it explains why SwiftUI is shaped the way it is, but you write zero UIKit this week.

We are intentionally holding everything else still so the one new idea — *view is a function of state, and the system diffs the result* — lands cleanly.

## Stretch goals

If you finish the regular work early and want to push further:

- Read Apple's **"Declaring a custom view"** and the **`View` protocol reference**, then explain in writing why `body`'s return type is `some View` and not `AnyView`: <https://developer.apple.com/documentation/swiftui/view>.
- Watch the WWDC session **"Demystify SwiftUI"** (WWDC21) — still the single best explanation of identity, lifetime, and dependencies: <https://developer.apple.com/videos/play/wwdc2021/10022/>.
- Implement a tiny custom `Layout` conformance (a "flow layout" that wraps tags onto new lines). You will fully understand `sizeThatFits` and `placeSubviews` only after you write one.
- Open the **`pointfreeco/swift-composable-architecture`** repo and read one feature's `View`. Note how the `body` reads as a pure function of a store's state: <https://github.com/pointfreeco/swift-composable-architecture>.
- Write a one-page note for your future self comparing the SwiftUI render loop to React's reconciliation. The diffing analogy is real and worth making precise.

## Up next

Continue to **Week 8 — State: `@State`, `@Observable`, `@Environment`, `@Bindable`** once you have pushed "Hello, Notes" to your GitHub. Week 8 takes the static "Hello, Notes" you build this week and gives it a real, mutable `NotesStore`. Everything you build this week compounds — keep the repo.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
