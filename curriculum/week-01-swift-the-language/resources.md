# Week 1 — Resources

Every resource on this page is **free**. The Swift language is open-source under Apache-2.0. The Swift Programming Language book is published openly at swift.org. The standard library, the compiler, and SwiftPM are all public on GitHub. No paywalled books are linked.

## Required reading (work it into your week)

- **About Swift** — the canonical swift.org overview of the open-source language:
  <https://www.swift.org/about/>
- **The Swift Programming Language — "The Basics"** — constants, variables, type inference, optionals:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/>
- **The Swift Programming Language — "Optional Chaining"**:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/optionalchaining/>
- **The Swift Programming Language — "Structures and Classes"** — the value-vs-reference distinction:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/>
- **The Swift Programming Language — "Collection Types"** — `Array`, `Set`, `Dictionary`:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/>

## Installing the toolchain

- **Install Swift (all platforms)** — the official getting-started page:
  <https://www.swift.org/install/>
- **Swiftly — the Swift toolchain installer for Linux and macOS** (the recommended path in 2026):
  <https://www.swift.org/install/linux/swiftly/>
- **Swift on Linux — getting started**:
  <https://www.swift.org/install/linux/>
- **Official Swift Docker images** (`swift:6.1` on Docker Hub) — the no-install path:
  <https://hub.docker.com/_/swift>

## Swift Package Manager

- **Swift Package Manager documentation**:
  <https://www.swift.org/documentation/package-manager/>
- **`Package.swift` manifest API reference (PackageDescription)**:
  <https://developer.apple.com/documentation/packagedescription>
- **`swift package`, `swift build`, `swift run`, `swift test` — the SwiftPM CLI**:
  <https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Usage.md>

## Testing

- **Swift Testing** — the modern testing framework with `@Test` and `#expect`, bundled in the toolchain:
  <https://developer.apple.com/documentation/testing>
- **Swift Testing on GitHub** — the open-source repository, readable Swift:
  <https://github.com/swiftlang/swift-testing>
- **Migrating from XCTest to Swift Testing**:
  <https://developer.apple.com/documentation/testing/migratingfromxctest>

## The language reference and evolution

You will not read the whole language reference cover to cover, but the first time someone in a code review writes "that's a copy-on-write buffer, it won't allocate until you mutate it" you will want to know what they mean.

- **The Swift Programming Language — Language Reference** (the normative grammar):
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/aboutthelanguagereference/>
- **Swift Evolution** — every accepted language change, with its design rationale:
  <https://github.com/swiftlang/swift-evolution>
- **Swift 6.1 release notes / "What's new"** — the changes you should recognize on sight:
  <https://www.swift.org/blog/>

## Editors

C20 is open-source-first. You do **not** need Xcode for Weeks 1–6.

- **VS Code + the Swift extension** (primary, cross-platform — the same UI on Linux, macOS, Windows):
  <https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode>
- **The Swift VS Code extension home** (LSP-backed via SourceKit-LSP):
  <https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html>
- **Xcode** (macOS only; acknowledged, not required this week — free from the Mac App Store):
  <https://developer.apple.com/xcode/>

## Free book

- **The Swift Programming Language** — the official book, free, kept current per release. Read it on the web or download the Swift-DocC bundle:
  <https://docs.swift.org/swift-book/>

## Open courseware and talks

- **Swift.org blog** — the official channel for release announcements and deep dives:
  <https://www.swift.org/blog/>
- **WWDC "Meet Swift Testing" (2024)** — the introduction to the testing framework you'll use all track:
  <https://developer.apple.com/videos/play/wwdc2024/10179/>
- **Hacking with Swift — "100 Days of SwiftUI" (free)** — Paul Hudson's free track; the early days cover the same language fundamentals:
  <https://www.hackingwithswift.com/100/swiftui>

## Tools you'll use this week

- **`swift` CLI** — installed with the toolchain. Verify with `swift --version`.
- **`swiftc`** — the compiler, for single-file compiles outside a package.
- **`git`** — version control. `git --version` to confirm.
- **Docker** (optional) — the `swift:6.1` image is the fastest way to prove your code runs on Linux from a Mac.

## Open-source projects to read this week

You learn more from one hour reading well-written Swift than from three hours of tutorials. Pick one and just scroll:

- **`swiftlang/swift`** — the compiler and the standard library. Read `stdlib/public/core/Optional.swift` to see that `Optional` is just an `enum`:
  <https://github.com/swiftlang/swift>
- **`swiftlang/swift-package-manager`** — SwiftPM itself, written in Swift:
  <https://github.com/swiftlang/swift-package-manager>
- **`apple/swift-argument-parser`** — the CLI-argument library; clean, idiomatic, heavily tested:
  <https://github.com/apple/swift-argument-parser>
- **`apple/swift-collections`** — `OrderedDictionary`, `Deque`, `Heap`; great collection source we revisit in Week 6:
  <https://github.com/apple/swift-collections>

## Glossary cheat sheet

Keep this open in a tab.

| Term | Plain English |
|------|---------------|
| **Swift 6.1** | The language and toolchain version current in 2026. `swift --version` reports it. |
| **Toolchain** | The bundle that ships the compiler, SwiftPM, the REPL, LLDB, the stdlib, Foundation, and Swift Testing. |
| **SwiftPM** | Swift Package Manager — the build tool and dependency manager. Like `cargo` for Rust or `npm` for Node. |
| **`Package.swift`** | The package manifest. Swift code (not JSON/YAML) that declares targets and dependencies. |
| **Target** | A unit of build: an `executableTarget`, a `target` (library), or a `testTarget`. |
| **`nil`** | Swift's "no value." Only an `Optional` can be `nil`. There is no `null`. |
| **`Optional<Wrapped>`** | An `enum` with cases `.none` and `.some(Wrapped)`. `T?` is sugar for `Optional<T>`. |
| **Value type** | `struct` and `enum`. Copied on assignment. Lives inline. |
| **Reference type** | `class`. Shared on assignment via a reference. Reference-counted (ARC). |
| **COW** | Copy-on-write — `Array`/`String`/`Dictionary`/`Set` share storage until one copy mutates. |
| **REPL** | Read-Eval-Print Loop — run `swift` with no arguments to get an interactive prompt. |
| **Swift Testing** | The modern test framework: `@Test`, `#expect`, `#require`. Bundled with the toolchain. |
| **XCTest** | The older test framework (`XCTestCase`, `XCTAssert`). Still supported; not our default. |

---

*If a link 404s, please open an issue so we can replace it.*
