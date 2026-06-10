# Exercise 1 — A protocol with an `associatedtype`, and a generic function over it

**Goal:** Define a protocol with an `associatedtype`, provide **two** conforming types with different associated types, and write a **generic function constrained by that protocol**. Prove it all with Swift Testing. This is the exact skill the syllabus names for the week, drilled in isolation before the mini-project compounds it.

**Estimated time:** 45 minutes.

---

## Setup

You need the Swift 6 toolchain. Verify:

```bash
swift --version
```

You should see `Swift version 6.x`. If not, install from <https://www.swift.org/install/> and come back.

Scaffold a library package:

```bash
mkdir RepositoryKit && cd RepositoryKit
swift package init --type library --name RepositoryKit
```

You now have `Package.swift`, `Sources/RepositoryKit/RepositoryKit.swift`, and `Tests/RepositoryKitTests/RepositoryKitTests.swift`. Open `Package.swift` and confirm the tools version is `6.0` or higher; if your scaffold targets an older version, bump the first line to `// swift-tools-version: 6.0`.

---

## Step 1 — Define the protocol with an `associatedtype`

We will model a tiny **repository** abstraction: something that stores items keyed by an id, where both the item type and the id type are chosen by the conformer. Replace the contents of `Sources/RepositoryKit/RepositoryKit.swift`:

```swift
public protocol Repository {
    associatedtype Item
    associatedtype ID: Hashable

    var count: Int { get }

    mutating func insert(_ item: Item, id: ID)
    func item(for id: ID) -> Item?
    func allIDs() -> [ID]
}
```

Two associated types: `Item` (what we store) and `ID` (the key, constrained to `Hashable` so it can back a dictionary). Note we constrained `ID` *in the protocol* — every conformer's id will be `Hashable`, which a generic function can then rely on.

Add a protocol extension with a default `contains` that every conformer gets free:

```swift
public extension Repository {
    func contains(_ id: ID) -> Bool {
        item(for: id) != nil
    }
}
```

---

## Step 2 — First conforming type: an in-memory user store

Below the protocol, add:

```swift
public struct User: Equatable {
    public let name: String
    public init(name: String) { self.name = name }
}

public struct InMemoryUserRepository: Repository {
    // Swift INFERS Item == User and ID == Int from the method signatures below.
    private var storage: [Int: User] = [:]

    public init() {}

    public var count: Int { storage.count }

    public mutating func insert(_ item: User, id: Int) {
        storage[id] = item
    }

    public func item(for id: Int) -> User? {
        storage[id]
    }

    public func allIDs() -> [Int] {
        Array(storage.keys)
    }
}
```

`Item` is inferred as `User`, `ID` as `Int`. You did not write a `typealias` — the compiler reads the method signatures and decides.

---

## Step 3 — Second conforming type: a different `Item` and `ID`

The whole point of an `associatedtype` is that a *different* conformer picks *different* types. Add a document store keyed by `String`:

```swift
public struct Document: Equatable {
    public let title: String
    public let body: String
    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public struct InMemoryDocumentRepository: Repository {
    private var storage: [String: Document] = [:]

    public init() {}

    public var count: Int { storage.count }

    public mutating func insert(_ item: Document, id: String) {
        storage[id] = item
    }

    public func item(for id: String) -> Document? {
        storage[id]
    }

    public func allIDs() -> [String] {
        Array(storage.keys)
    }
}
```

`InMemoryDocumentRepository` has `Item == Document` and `ID == String`. Same protocol, two completely different associated-type choices — and no inheritance.

---

## Step 4 — The generic function constrained by the protocol

Now the payoff. Write a generic function that works over **any** `Repository`, and constrain it on the associated types when it needs to. Add to the same file:

```swift
/// Returns the items for the given ids, skipping ids that are absent.
/// Works over ANY Repository — the associated types are inferred per call.
public func presentItems<R: Repository>(in repository: R, ids: [R.ID]) -> [R.Item] {
    ids.compactMap { repository.item(for: $0) }
}

/// Counts how many of the repository's items satisfy a predicate.
/// Constrains R.Item to be Equatable so we can compare against a target.
public func countMatching<R: Repository>(
    _ target: R.Item,
    in repository: R
) -> Int where R.Item: Equatable {
    repository.allIDs()
        .compactMap { repository.item(for: $0) }
        .filter { $0 == target }
        .count
}
```

`presentItems` uses `R.ID` and `R.Item` — reaching into the associated types. `countMatching` adds a `where R.Item: Equatable` constraint so `==` type-checks. Neither function knows or cares whether it is operating on users or documents.

---

## Step 5 — Prove it with Swift Testing

Replace `Tests/RepositoryKitTests/RepositoryKitTests.swift`:

```swift
import Testing
@testable import RepositoryKit

@Suite("Repository conformances")
struct RepositoryTests {

    @Test("User repository stores and retrieves by Int id")
    func userStore() {
        var repo = InMemoryUserRepository()
        repo.insert(User(name: "Ada"), id: 1)
        repo.insert(User(name: "Grace"), id: 2)

        #expect(repo.count == 2)
        #expect(repo.item(for: 1) == User(name: "Ada"))
        #expect(repo.item(for: 99) == nil)
        #expect(repo.contains(2))          // from the protocol extension
        #expect(!repo.contains(99))
    }

    @Test("Document repository uses a String id and a different Item type")
    func documentStore() {
        var repo = InMemoryDocumentRepository()
        repo.insert(Document(title: "RFC", body: "..."), id: "rfc-1")

        #expect(repo.count == 1)
        #expect(repo.item(for: "rfc-1")?.title == "RFC")
        #expect(repo.contains("rfc-1"))
    }

    @Test("Generic presentItems works over any Repository")
    func genericPresentItems() {
        var repo = InMemoryUserRepository()
        repo.insert(User(name: "Ada"), id: 1)
        repo.insert(User(name: "Grace"), id: 3)

        let found = presentItems(in: repo, ids: [1, 2, 3])  // 2 is absent
        #expect(found.count == 2)
        #expect(found.contains(User(name: "Ada")))
        #expect(found.contains(User(name: "Grace")))
    }

    @Test("Generic countMatching constrains the associated type to Equatable")
    func genericCountMatching() {
        var repo = InMemoryUserRepository()
        repo.insert(User(name: "Ada"), id: 1)
        repo.insert(User(name: "Ada"), id: 2)
        repo.insert(User(name: "Grace"), id: 3)

        #expect(countMatching(User(name: "Ada"), in: repo) == 2)
        #expect(countMatching(User(name: "Grace"), in: repo) == 1)
    }
}
```

Run it:

```bash
swift test
```

Expected output (numbers and timing will differ):

```
Test Suite 'Repository conformances' started ...
✔ Test userStore() passed
✔ Test documentStore() passed
✔ Test genericPresentItems() passed
✔ Test genericCountMatching() passed
Test run with 4 tests passed after 0.00x seconds.
```

Confirm there are no warnings:

```bash
swift build -Xswiftc -warnings-as-errors
```

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `Repository` declares **two** associated types (`Item`, and `ID: Hashable`) and at least three requirements.
- [ ] There is a protocol extension providing a default `contains(_:)`.
- [ ] **Two** conforming types exist with **different** `Item` and `ID` types, and you wrote **no** `typealias` (the compiler inferred them).
- [ ] `presentItems` and `countMatching` are generic functions constrained on `Repository`, and `countMatching` uses a `where R.Item: Equatable` clause.
- [ ] `swift test` reports 4 passing tests, 0 failures.
- [ ] `swift build -Xswiftc -warnings-as-errors` produces zero warnings.
- [ ] You can explain, in your own words, why `let r: Repository = InMemoryUserRepository()` does **not** compile.

---

## Stretch

- Add a third conformer `FileDocumentRepository` whose `item(for:)` reads from disk (use `FileManager`); confirm `presentItems` works over it with no change to the generic function. This previews the mini-project's disk-backed store.
- Write a type eraser `AnyRepository<Item, ID: Hashable>` (the three-layer pattern from Lecture 2) so you can hold a heterogeneous `[AnyRepository<User, Int>]`. Add a test that stores two *different* concrete user repositories in one array.
- Replace `where R.Item: Equatable` with a primary-associated-type spelling: declare `protocol Repository<Item, ID>` and write a function taking `some Repository<User, Int>`. Note how the call sites change.

---

## Hints

<details>
<summary>Why doesn't `let r: Repository = ...` compile?</summary>

`Repository` has associated types, so it is a PAT (protocol with associated type). The compiler cannot lay out a `Repository` value because it does not know the concrete `Item` and `ID`, and therefore does not know the size or layout of values the requirements return. Use it as a generic constraint (`<R: Repository>`), as `some Repository<...>`, or as `any Repository<...>` — not as a bare type. See Lecture 1 §5.

</details>

<details>
<summary>The compiler can't infer my associated type</summary>

Inference works from the requirement *implementations*. If you wrote `func item(for id: Int) -> User?`, Swift infers `ID == Int`, `Item == User`. If inference still fails (rare, usually with defaulted generics), add it explicitly: `typealias Item = User`.

</details>

<details>
<summary>`compactMap` vs `map`</summary>

`item(for:)` returns an optional. `map` would give you `[User?]`; `compactMap` drops the `nil`s and gives you `[User]`, which is exactly what `presentItems` should return.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — Refactor `any` to `some`](exercise-02-any-to-some.swift).
