# Week 11 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. Point-Free's TCA library, its documentation, and its case studies are open source on GitHub. Their video course is paid and clearly marked, but the docs and sample code teach the framework without it. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **The Composable Architecture — repository and DocC documentation.** The library, the tutorials, and the API reference root. Read the "Getting started" and "Testing" articles before you write a reducer:
  <https://github.com/pointfreeco/swift-composable-architecture>
  <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/>
- **TCA — "Meet the Composable Architecture" tutorial.** The hands-on DocC tutorial that builds a counter, then a feature with effects and dependencies. Do this end to end:
  <https://pointfreeco.github.io/swift-composable-architecture/main/tutorials/meetcomposablearchitecture/>
- **Apple — "Managing model data in your app" / the Observation framework.** The `@Observable` macro is the modern MVVM view model; read what it generates:
  <https://developer.apple.com/documentation/observation>
  <https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app>
- **Apple — "Migrating from the Observable Object protocol to the Observable macro."** Why `@Observable` replaced `ObservableObject`/`@Published`, which is the whole reason "MVVM in SwiftUI" no longer needs a library:
  <https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro>

## The TCA types (reference, skim don't memorize)

- **`Reducer` protocol and the `@Reducer` macro:** <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducer>
- **`Effect`** — the side-effect description: <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/effect>
- **`Store`** and the SwiftUI `@Bindable var store` integration: <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/store>
- **`TestStore`** — the exhaustive testing tool: <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/teststore>
- **`@Dependency` / `DependencyValues` / `DependencyKey`** (the `swift-dependencies` library TCA builds on): <https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/>
- **`@Reducer` composition — `Scope`, `forEach`, `ifLet`:** in the "Composing reducers" article of the docs above.
- **Bindings — `BindingState` / `BindingReducer` / `@Bindable`:** <https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/bindings/>

## Point-Free episodes (the paid course — the free ones are enough)

Point-Free's video series is the canonical TCA teaching. Most episodes are paid, but several foundational ones are **free** and are the best way to internalise *why* the framework is shaped the way it is:

- **"Composable Architecture" collection (free episodes):** <https://www.pointfree.co/collections/composable-architecture>
- **"Reducers and Stores," "Testing," and "Dependencies" collections** — even the free preview of each clarifies the mental model.
- **The Point-Free blog** — release notes and design rationale for each major TCA version: <https://www.pointfree.co/blog>

You do **not** need a Point-Free subscription to complete this week. The open-source docs, the DocC tutorial, and the case-study apps in the repo cover everything the exercises and mini-project require. The subscription is worth it later if you adopt TCA at work.

## The MVVM and architecture lineage (why this matters)

MVVM came to iOS from .NET / WPF by way of ReactiveCocoa, long before SwiftUI. Understanding the lineage explains why "MVVM in SwiftUI" is so light — the binding machinery that used to need a reactive library is now `@Observable` in the language.

- **MVVM — the original Microsoft pattern writeup** (the source, for context): <https://learn.microsoft.com/en-us/dotnet/architecture/maui/mvvm>
- **objc.io — "Architecting SwiftUI apps with MVC, MVVM, and VIPER."** The clearest side-by-side comparison in print, current to the SwiftUI era: <https://www.objc.io/blog/>
- **Swift by Sundell — the architecture articles.** John Sundell's measured, pattern-by-pattern writing, including the "you might not need a view model" position: <https://www.swiftbysundell.com/articles/>
- **Donny Wals — "Architecting SwiftUI apps."** Production-grade, opinionated, and honest about trade-offs: <https://www.donnywals.com/category/swift/>

## The case against VIPER (read the original, then the critique)

- **The original VIPER article — objc.io issue 13, "Architecting iOS Apps with VIPER" (2014).** Read the *source* so your critique is fair, not a strawman: <https://www.objc.io/issues/13-architecture/viper/>
- **The five components** — View, Interactor, Presenter, Entity, Router — and the protocol-per-edge wiring are the things lecture 02 argues are redundant in SwiftUI. Read the original's wiring diagram and ask "what does the Observation framework already give me here?"

## Architectural decision records (the actual deliverable)

- **Michael Nygard — "Documenting Architecture Decisions" (the original ADR post, 2011).** The five-section format the mini-project's ADR follows: <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>
- **`adr.github.io` — the ADR community site and templates:** <https://adr.github.io/>
- **The MADR template** (a widely-used markdown ADR format): <https://github.com/adr/madr>

## Open-source projects to read this week

You learn more from one hour reading a real TCA app than from three hours of tutorials. Pick one and trace a single feature from `State`/`Action` through the reducer to the view:

- **`pointfreeco/swift-composable-architecture` — the `Examples/` directory.** Case studies and full sample apps (Search, SyncUps, Todos, the Tic-Tac-Toe app) maintained by the library authors; the canonical reference for idiomatic TCA: <https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples>
- **`pointfreeco/isowords`** — a full, shipped TCA game with a Vapor backend; the most complete production TCA codebase that is also open source: <https://github.com/pointfreeco/isowords>
- **An `@Observable` MVVM reference** — Apple's own SwiftUI sample apps (e.g. the "Food Truck" and "Backyard Birds" samples) show the modern view-model-light style; read how little glue `@Observable` needs: <https://developer.apple.com/documentation/swiftui/>

## Tools you'll use this week

- **Xcode 16+** — installed from the Mac App Store. `xcodebuild -version` to confirm.
- **Swift Package Manager** — you add `swift-composable-architecture` as a package dependency: **File ▸ Add Package Dependencies ▸ `https://github.com/pointfreeco/swift-composable-architecture`**, pin to the 1.x line. The package pulls in `swift-dependencies`, `swift-case-paths`, and friends automatically.
- **Swift Testing** — the `@Test`/`#expect` framework bundled with Xcode 16; the MVVM view-model tests and several exercises use it.
- **`TestStore`** — TCA's own testing tool; it runs inside a Swift Testing or XCTest target. Exhaustive by default; you will see it fail loudly when state or effects diverge from your assertion.

## Free reading (chapter-level, not whole books)

- **The TCA DocC tutorials** (linked above) are effectively a free book; the "Meet" and "Building SyncUps" tutorials walk a full feature with tests and dependencies.
- **Apple's Observation framework documentation** plus the migration guide is a complete, free treatment of the modern MVVM substrate.

## Paid books (optional, clearly marked)

- **"The Composable Architecture" / Point-Free's video subscription** (paid). The definitive TCA teaching; worth it if you adopt TCA at work. The free docs are enough for this week.
- **"iOS Application Architecture" — objc.io / various** (paid). Older but still the clearest long-form comparison of MVC, MVVM, and VIPER; read it for the *history* that justifies the case against VIPER.

---

*If a link 404s, please open an issue so we can replace it.*
