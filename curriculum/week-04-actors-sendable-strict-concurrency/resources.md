# Week 4 — Resources

Every resource on this page is **free**. Swift Evolution is public on GitHub. The Swift migration guide and language docs are published openly by the Swift project. WWDC sessions are free on the Apple Developer site with no paid membership. No paywalled books are linked.

Pin three tabs for the week: the **Swift 6 migration guide**, the **Actors proposal (SE-0306)**, and the **Sendable proposal (SE-0302)**. Everything else is depth on top of those three.

## Required reading (work it into your week)

- **Swift Migration Guide — "Migrating to Swift 6"** — the canonical, maintained guide. Read "Data Race Safety" and "Common Compiler Errors" cover to cover:
  <https://www.swift.org/migration/documentation/migrationguide/>
- **Swift Migration Guide — "Common compiler errors"** — every diagnostic you will hit this week, with the fix:
  <https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems>
- **The Swift Programming Language — "Concurrency" chapter** (actors, `Sendable`, isolation):
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>
- **`Sendable` — official API reference**:
  <https://developer.apple.com/documentation/swift/sendable>
- **`MainActor` — official API reference**:
  <https://developer.apple.com/documentation/swift/mainactor>

## The proposals (skim, then read the ones we lean on)

Swift Evolution is the normative design record. You will not read all of them, but when a code review says "per SE-0337 you can enable checking per-module," you should know what that means. All live under `swiftlang/swift-evolution`:

- **SE-0306 — Actors** (the actor model itself):
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md>
- **SE-0302 — `Sendable` and `@Sendable` closures**:
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md>
- **SE-0316 — Global actors** (`@MainActor` is one; `@globalActor` lets you make your own):
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md>
- **SE-0337 — Incremental migration to concurrency checking** (the `-strict-concurrency` levels and upcoming feature flags):
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md>
- **SE-0401 — Remove actor isolation inference caused by property wrappers** (why `@StateObject` no longer drags `@MainActor` onto your type by accident):
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md>
- **SE-0414 — Region-based isolation** (how the compiler proves a non-`Sendable` value can safely cross a boundary because nobody else holds it):
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md>
- **SE-0420 — Inheriting actor isolation (`#isolation`, `isolated` parameters)**:
  <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md>

## Official Swift docs

- **Swift 6 release notes / "What's new"**: <https://www.swift.org/blog/announcing-swift-6/>
- **Enabling complete concurrency checking** (the `swiftLanguageModes` and `SwiftSetting.enableUpcomingFeature` knobs in `Package.swift`):
  <https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/completechecking>
- **`swift-package-manager` — manifest API** (`swiftLanguageModes`, `swiftSettings`):
  <https://developer.apple.com/documentation/packagedescription>
- **`AsyncStream` reference** (used in the mini-project to bridge callbacks):
  <https://developer.apple.com/documentation/swift/asyncstream>

## WWDC sessions (free, no paid membership)

Watch these in order. They are the best single explanation of the model that exists.

- **"Protect mutable state with Swift actors"** (WWDC21) — the foundational actors talk; reentrancy is explained clearly here:
  <https://developer.apple.com/videos/play/wwdc2021/10133/>
- **"Eliminate data races using Swift Concurrency"** (WWDC22) — isolation domains, `Sendable`, the "islands" mental model. The single most useful talk for this week:
  <https://developer.apple.com/videos/play/wwdc2022/110351/>
- **"Migrate your app to Swift 6"** (WWDC24) — the practical, incremental migration walkthrough that mirrors this week's lecture 2:
  <https://developer.apple.com/videos/play/wwdc2024/10169/>
- **"Swift concurrency: Behind the scenes"** (WWDC21) — what a hop actually costs; cooperative thread pool, continuations, and why you should not block:
  <https://developer.apple.com/videos/play/wwdc2021/10254/>
- **"What's new in Swift"** (WWDC24) — the language-mode and region-isolation context for Swift 6:
  <https://developer.apple.com/videos/play/wwdc2024/10136/>

## Deep-dive writing (free, current)

- **Matt Massicotte — "A Swift Concurrency Glossary"** and the concurrency series. The best plain-English unpacking of isolation on the open web:
  <https://www.massicotte.org/>
- **Swift Forums — "Concurrency" category**. Search before you ask; most strict-concurrency questions are already answered by the core team:
  <https://forums.swift.org/c/development/concurrency/>
- **Donny Wals — Swift Concurrency articles** (practical, example-driven, kept current):
  <https://www.donnywals.com/category/swift/>

## Books (free or sample chapters)

- **"The Swift Programming Language"** (the official book — free, the whole thing). Concurrency chapter is the reference for this week:
  <https://docs.swift.org/swift-book/>
- **Apple — "Discover Concurrency in SwiftUI"** sample chapter material in the developer documentation (free):
  <https://developer.apple.com/documentation/swiftui/>

## Tools you'll use this week

- **`swift` toolchain 6.0+** — verify with `swift --version`. On Linux use the `swift.org` tarball or the `swift:6.0` Docker image; on macOS, Xcode 16+.
- **`swift build` / `swift test`** — the SwiftPM build and test commands. We run with `-Xswiftc -strict-concurrency=complete` in Swift 5 mode and with `swiftLanguageModes: [.v6]` in the manifest.
- **`swift build --explain-install-needed`** — not needed; ignore. Use `swift build 2>&1 | head -50` to read diagnostics top-down.
- **`swift-format`** (optional) — keep diffs clean: <https://github.com/swiftlang/swift-format>.

## Open-source projects to read this week

You learn more from one hour reading well-isolated Swift than from three hours of tutorials. Pick one and read how a real codebase handles `Sendable` and actors:

- **`swiftlang/swift`** — the compiler and stdlib. `Sendable.swift` and the actor runtime are readable:
  <https://github.com/swiftlang/swift>
- **`apple/swift-async-algorithms`** — heavy, careful use of `Sendable` and `@Sendable`:
  <https://github.com/apple/swift-async-algorithms>
- **`vapor/vapor`** — server-side Swift, fully migrated to strict concurrency. See how a large async codebase models `Sendable` request state:
  <https://github.com/vapor/vapor>
- **`pointfreeco/swift-dependencies`** — clever, principled isolation and `Sendable` design:
  <https://github.com/pointfreeco/swift-dependencies>

## Glossary cheat sheet

Keep this open in a tab.

| Term | Plain English |
|------|---------------|
| **Isolation domain** | A region of code that runs serially with exclusive access to some mutable state. Each actor is one; the main actor is one. |
| **Actor** | A reference type whose mutable state is protected by an implicit serial executor. Cross-actor access is `async`. |
| **Actor hop** | Switching execution from one isolation domain to another. Always at an `await`. Costs a suspension and possibly a thread switch. |
| **`@MainActor`** | The built-in global actor whose executor is the main thread. Where all UIKit/SwiftUI/AppKit work must happen. |
| **`nonisolated`** | A member that opts out of its enclosing actor's isolation. It may not touch isolated mutable state. |
| **`nonisolated(unsafe)`** | "Trust me, I synchronise this myself." Disables the check for one declaration. Rare and deliberate. |
| **`Sendable`** | A type whose values are safe to pass across an isolation boundary. Value types of `Sendable` parts are implicitly `Sendable`. |
| **`@Sendable` closure** | A closure that may run in another isolation domain. May only capture `Sendable` values; no mutable captures. |
| **Reentrancy** | An actor may start a new message while an earlier one is suspended at an `await`. State can change across that suspension. |
| **`@unchecked Sendable`** | "I promise this is safe; stop checking." The escape hatch we spend the week learning to *not* need. |
| **Strict concurrency** | The complete data-race checking the compiler applies in Swift 6 language mode (or Swift 5 + `-strict-concurrency=complete`). |
| **Language mode** | `swiftLanguageModes: [.v6]` in `Package.swift`. Distinct from the toolchain version. Swift 6 toolchain can compile in v5 *or* v6 mode. |
| **Region-based isolation** | The compiler's analysis (SE-0414) that lets a non-`Sendable` value cross a boundary when it proves nobody else can touch it. |

---

*If a link 404s, please open an issue so we can replace it. Swift Evolution proposal URLs are stable; WWDC session URLs occasionally move — search the session title on developer.apple.com if so.*
