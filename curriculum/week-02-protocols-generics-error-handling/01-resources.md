# Week 2 — Resources

Every resource on this page is **free**. `docs.swift.org` and `swift.org` are free without an account. Swift Evolution proposals are public on GitHub. WWDC sessions stream free on the Apple Developer site without a paid membership. No paywalled books are linked.

## Required reading (work it into your week)

- **Protocols** — The Swift Programming Language (Swift 6), the normative chapter:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/>
- **Generics** — TSPL, the chapter behind every example this week:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/>
- **Opaque and Boxed Protocol Types** — TSPL, the `some` vs `any` chapter:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/>
- **Error Handling** — TSPL, the `throws` / `try` / `do`-`catch` / `defer` chapter:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/>

## The Swift Evolution proposals (skim the rationale, don't memorize)

The `some`/`any` distinction was designed in the open. The first time someone in code review says "per SE-0335 this should be `any`," you will know what they mean. Read the **Motivation** sections; skip the grammar.

- **SE-0244 — Opaque Result Types** (`some` in return position):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0244-opaque-result-types.md>
- **SE-0335 — Introduce existential `any`** (the clearest single doc on *why* the keyword exists):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md>
- **SE-0341 — Opaque Parameter Declarations** (`some` in parameter position):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0341-opaque-parameters.md>
- **SE-0309 — Unlock existentials for all protocols** (PATs can be existentials):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0309-unlock-existential-types-for-all-protocols.md>
- **SE-0346 — Lightweight same-type requirements / primary associated types** (`any Container<Int>`):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md>
- **SE-0413 — Typed throws** (`throws(MyError)`, Swift 6):
  <https://github.com/apple/swift-evolution/blob/main/proposals/0413-typed-throws.md>

## Official Swift docs

- **Swift standard library — `Result`**: <https://developer.apple.com/documentation/swift/result>
- **Swift standard library — `Sequence`**: <https://developer.apple.com/documentation/swift/sequence>
- **Swift standard library — `IteratorProtocol`**: <https://developer.apple.com/documentation/swift/iteratorprotocol>
- **Swift standard library — `Hashable`**: <https://developer.apple.com/documentation/swift/hashable>
- **Swift standard library — `Comparable`**: <https://developer.apple.com/documentation/swift/comparable>
- **Swift Package Manager — manifest reference** (for `Package.swift` this week):
  <https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/>
- **Install Swift** (Linux / macOS / Windows toolchains):
  <https://www.swift.org/install/>

## WWDC sessions (free, no paid membership)

- **Embrace Swift generics** — WWDC 2022. The canonical talk on `some` vs `any`, with the box/diamond mental model:
  <https://developer.apple.com/videos/play/wwdc2022/110352/>
- **Design protocol interfaces in Swift** — WWDC 2022. Primary associated types and when to erase:
  <https://developer.apple.com/videos/play/wwdc2022/110353/>
- **Protocol-Oriented Programming in Swift** — WWDC 2015 (Dave Abrahams). The origin talk; still the best framing of POP vs inheritance:
  <https://developer.apple.com/videos/play/wwdc2015/408/>
- **Generics in Swift** / **Protocol and value-oriented programming in UIKit apps** — WWDC 2016, the practical follow-ups:
  <https://developer.apple.com/videos/play/wwdc2016/419/>

## Libraries we touch this week

- **swift-collections** — `OrderedDictionary` (you'll use it for LRU in the challenge), `Deque`, `Heap`:
  <https://github.com/apple/swift-collections>
- **Swift Testing** — the `@Test` / `#expect` framework that ships with the toolchain:
  <https://developer.apple.com/documentation/testing/>
- **swift-algorithms** — generic algorithm package; great reading for `where`-clause style:
  <https://github.com/apple/swift-algorithms>

## Open-source projects to read this week

You learn more from one hour reading well-written Swift than from three hours of tutorials. Pick one and scroll:

- **`swiftlang/swift` — `stdlib/public/core/`** — see how `Sequence`/`Collection` turn one requirement into dozens of free methods:
  <https://github.com/swiftlang/swift/tree/main/stdlib/public/core>
- **`apple/swift-collections`** — `Sources/OrderedCollections/OrderedDictionary` is a clean generic + protocol design:
  <https://github.com/apple/swift-collections>
- **`pointfreeco/swift-dependencies`** — a masterclass in `some`/`any` and protocol-witness design:
  <https://github.com/pointfreeco/swift-dependencies>
- **`vapor/vapor`** — server-side Swift you'll use in Week 5; `AbortError` and `Content` are good error/protocol reading:
  <https://github.com/vapor/vapor>

## Free articles worth your time

- **Swift.org blog** — official posts on language features and migration:
  <https://www.swift.org/blog/>
- **Hacking with Swift — "What's the difference between `some` and `any`?"** (Paul Hudson, free article, current per Swift release):
  <https://www.hackingwithswift.com/quick-start/concurrency/whats-the-difference-between-some-and-any>
- **Swift by Sundell — articles on protocols, generics, and type erasure** (free):
  <https://www.swiftbysundell.com/articles/>

## Tools you'll use this week

- **`swift` toolchain** — `swift build`, `swift test`, `swift run`. Verify with `swift --version` (expect `6.x`).
- **`swift build -Xswiftc -warnings-as-errors`** — treat warnings as errors, the C20 default.
- **`swift package init --type library`** — scaffold the cache package.
- **Git** — version control. `git --version` to confirm.

## Glossary cheat sheet

Keep this open in a tab.

| Term | Plain English |
|------|---------------|
| **Protocol** | A list of requirements (methods, properties, associated types) a type can conform to. Not a class; usually adopted by `struct`s. |
| **Protocol extension** | A default implementation attached to every conformer of a protocol. The engine of protocol-oriented programming. |
| **`associatedtype`** | A type placeholder inside a protocol that the conforming type fills in. Makes a protocol a "PAT." |
| **PAT** | Protocol with Associated Type (or a `Self` requirement). Cannot be used as a bare type; only as a constraint, `some`, or `any`. |
| **Generic** | Code written once, type-checked, and specialised for any type satisfying its constraints. No boxing. |
| **`where` clause** | The way to attach constraints to type parameters or associated types (`where C.Element: Equatable`). |
| **Conditional conformance** | A generic type conforming to a protocol only when its element does (`extension Stack: Equatable where Element: Equatable`). |
| **`some` (opaque type)** | One specific concrete type the compiler knows and the caller doesn't. Zero run-time cost; preserves type identity. |
| **`any` (existential)** | A run-time box holding any conforming type. Dynamic dispatch, possible heap allocation, erased type identity. |
| **Existential container** | The fixed-size buffer + witness-table pointer Swift uses to store an `any` value. |
| **Type erasure** | Wrapping a PAT conformer in a concrete `Any…` type so it can be stored/passed without naming the concrete type. |
| **`Error`** | The empty protocol any thrown value conforms to. Idiomatically an `enum`. |
| **`throws` / `try`** | A function that can fail is `throws`; every call to it is marked `try`. Typed throws (`throws(E)`) pins the error type. |
| **`Result<Success, Failure>`** | A generic enum (`.success`/`.failure`) for storing or passing an outcome as a value. |
| **`defer`** | Schedules cleanup to run on every scope exit, including a thrown error. Runs LIFO. |

---

*If a link 404s, please open an issue so we can replace it.*
