# Week 7 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Layout and the modifier-order rule](exercise-01-layout-and-modifier-order.md)** — build a layout from `Text`, `Image`, `Button`, and stacks, then reorder `.padding()` and `.background()` and document the visible difference. (~45 min)
2. **[Exercise 2 — Asset catalog, light & dark](exercise-02-asset-catalog-light-dark.swift)** — drive an asset-catalog colour set with light/dark variants and prove the view adapts with zero branching code. (~35 min)
3. **[Exercise 3 — iPhone SE & iPad Pro previews](exercise-03-iphone-se-ipad-pro-previews.swift)** — render one view across iPhone SE (3rd gen) and iPad Pro 13-inch with multiple `#Preview`s and adapt the layout so it reads on both. (~40 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills, and in SwiftUI the muscle memory is "where does this modifier go."
- Run it in the **Canvas** first (`⌥⌘↵`), then in the **Simulator** (`⌘R`). When the Canvas and the running app disagree, the running app is the truth.
- Exercises 2 and 3 are `.swift` files containing complete, correct SwiftUI views plus a "YOUR TURN" drill. You drop them into a fresh SwiftUI app target (or a Swift Playground app) and run them. They compile and render as written.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must end with a clean build — **`Build Succeeded`** in Xcode's status bar, with **zero warnings**. A warning is a defect this week.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-07` to compare.

## What you need

- A Mac with **Xcode 16 or newer** (free from the Mac App Store).
- The bundled **iOS Simulator** — specifically the **iPhone SE (3rd generation)** and **iPad Pro 13-inch (M4)** simulators. If you do not have them, add them under Xcode ▸ Settings ▸ Components, or Window ▸ Devices and Simulators ▸ Simulators ▸ `+`.
- No Apple Developer Program membership (that is Week 15).
