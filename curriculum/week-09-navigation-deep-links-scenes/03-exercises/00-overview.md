# Week 9 — Exercises

Three focused drills that build the navigation layer you will assemble in the mini-project. Do them in order; each one assumes the previous. Exercise 1 is a guided Markdown walkthrough with full starter and solution code. Exercises 2 and 3 are runnable Swift files you complete and run in the simulator (or as a self-contained SwiftUI app target).

## Index

1. **[Exercise 1 — A value-typed `NavigationStack`](./exercise-01-value-typed-stack.md)** — build a `NavigationStack` bound to a `[Route]` path, push with `NavigationLink(value:)`, register destinations with `navigationDestination(for:)`, then drive it programmatically from a button (push, pop-to-root, replace). Guided, with full solution. (~50 min)
2. **[Exercise 2 — Scene restoration across a cold launch](./exercise-02-scene-restoration.swift)** — persist the navigation path with `@SceneStorage` and the selected tab with `@AppStorage`, then prove restoration with the simulator's terminate-and-relaunch gesture. Runnable. (~45 min)
3. **[Exercise 3 — An `onOpenURL` deep link](./exercise-03-open-url-deep-link.swift)** — write a pure `DeepLink.path(for:)` decoder, wire `onOpenURL` to it, and fire `notes://open/<id>` at the booted simulator to push the right note's detail screen. Runnable. (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste from the solution. Muscle memory is the entire point of these drills, and navigation bugs are usually typos in a `switch` or a misplaced modifier.
- Run it in the simulator. Use the app. Tap Back. Watch the path change.
- For the storage exercises, **test restoration with `xcrun simctl terminate` then `xcrun simctl launch`, not with Xcode's Stop/Run** — see Lecture 1 §1.8 for why the difference matters.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must build with **0 warnings, 0 errors**. A warning is a bug this week — especially an unhandled `switch` case, which the compiler will flag and which is a real navigation bug, not pedantry.

## The shared `Route` and `Note`

All three exercises (and the mini-project) use the same minimal model. Define it once and reuse it:

```swift
import Foundation

struct Note: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var body: String

    static let samples: [Note] = [
        Note(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
             title: "Buy milk", body: "Oat, not dairy."),
        Note(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
             title: "Ship Week 9", body: "Navigation, scenes, deep links."),
        Note(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
             title: "Call the bank", body: "About the universal-links domain."),
    ]
}

enum Route: Hashable, Codable {
    case note(id: UUID)
    case settings
}
```

The fixed UUIDs in `Note.samples` are deliberate: they let you fire a deep link like `notes://open/22222222-2222-2222-2222-222222222222` from the terminal and know exactly which note should open, without first reading a random id out of a log.

## Solutions

Full reference solutions are inline at the bottom of Exercise 1, and as the completed (uncommented-hint) form of Exercises 2 and 3. The course is open source — additional community solutions live in forks. After you finish, search GitHub for `c20-week-09` to compare your approach with others'.
