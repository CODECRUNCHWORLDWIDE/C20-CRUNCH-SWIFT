# Exercise 1 — Extract `NotesCore`

**Goal:** Take the request/response types currently living inside your Week 5 Vapor target, lift them into a standalone `NotesCore` SwiftPM library package, and import them back into the server through a local `path:` dependency. By the end the server compiles against the shared package and its tests still pass — and you have the package every later client will import.

**Estimated time:** 45 minutes.

This is a refactor, not a rewrite. The behavior of `notes-api` does not change. What changes is *where the wire types are defined*: they move from "inside the server" to "a package the server depends on."

---

## Setup

You need your Week 5 `notes-api` repository, building and passing tests:

```bash
cd notes-api
swift build
swift test
```

If that does not pass, fix Week 5 first. We are about to move types around; you want a green baseline so any new failure is unambiguously caused by this exercise.

Put the server inside a workspace folder so the shared package can sit beside it:

```bash
mkdir -p notes-workspace
mv notes-api notes-workspace/notes-api
cd notes-workspace
```

---

## Step 1 — Scaffold the `NotesCore` package

```bash
swift package init --type library --name NotesCore
```

Wait — that scaffolds *into the current directory*, which is the workspace root, not what we want. Make the folder first:

```bash
mkdir NotesCore
cd NotesCore
swift package init --type library --name NotesCore
```

You now have `NotesCore/Package.swift`, `NotesCore/Sources/NotesCore/NotesCore.swift`, and a test stub.

Replace `NotesCore/Package.swift` with a Swift 6 manifest:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotesCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotesCore", targets: ["NotesCore"])
    ],
    targets: [
        .target(
            name: "NotesCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NotesCoreTests",
            dependencies: ["NotesCore"]
        )
    ]
)
```

---

## Step 2 — Move the types in

Delete `Sources/NotesCore/NotesCore.swift`. Create four files. These are the shared wire types — note the `public` on every type, property, and initializer.

`Sources/NotesCore/Note.swift`:

```swift
import Foundation

public struct Note: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String,
        body: String,
        tags: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

`Sources/NotesCore/CreateNoteRequest.swift`:

```swift
import Foundation

public struct CreateNoteRequest: Codable, Sendable, Hashable {
    public var title: String
    public var body: String
    public var tags: [String]

    public init(title: String, body: String, tags: [String] = []) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}
```

`Sources/NotesCore/UpdateNoteRequest.swift`:

```swift
import Foundation

public struct UpdateNoteRequest: Codable, Sendable, Hashable {
    public var title: String?
    public var body: String?
    public var tags: [String]?

    public init(title: String? = nil, body: String? = nil, tags: [String]? = nil) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}
```

`Sources/NotesCore/APIError.swift`:

```swift
import Foundation

public struct APIError: Codable, Sendable, Error, Hashable {
    public var error: Bool
    public var reason: String

    public init(error: Bool = true, reason: String) {
        self.error = error
        self.reason = reason
    }
}
```

Build the package on its own first:

```bash
swift build
```

Expect zero errors. If you forgot a `public`, the build still succeeds (the types are just internal) — the failure will surface in Step 4 when the server cannot see them. So also run the package's own test in Step 6 to confirm visibility from a separate target.

---

## Step 3 — Delete the old definitions from the server

In `notes-workspace/notes-api`, find wherever Week 5 defined the create/update/response structs (often a `DTOs.swift` or inline in the controller). **Delete those struct definitions.** Keep the Fluent model (`NoteModel` / `Note` the `final class`) — that stays in the server. We are only removing the *value-type wire structs* that now live in `NotesCore`.

---

## Step 4 — Depend on `NotesCore` from the server

Edit `notes-api/Package.swift`. Add the local package to `dependencies` and the product to the executable target:

```swift
dependencies: [
    // ... existing Vapor / Fluent dependencies ...
    .package(path: "../NotesCore")
],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            // ... existing .product(...) entries ...
            .product(name: "NotesCore", package: "NotesCore")
        ],
        swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    // ... test target ...
]
```

Add `import NotesCore` to every server file that used the moved types (the controller, any DTO mapping). The compiler will tell you exactly which files: each one will fail with "cannot find type 'CreateNoteRequest' in scope" until you add the import.

---

## Step 5 — Add the `@retroactive Content` conformances

Vapor route handlers can only return/accept types that conform to `Content`. The shared types do not (and must not — `NotesCore` has no business depending on Vapor). Add the conformance *in the server*:

`notes-api/Sources/App/NotesCore+Content.swift`:

```swift
import Vapor
import NotesCore

extension Note: @retroactive Content {}
extension CreateNoteRequest: @retroactive Content {}
extension UpdateNoteRequest: @retroactive Content {}
extension APIError: @retroactive Content {}
```

If your Fluent class is also named `Note`, you now have a collision: server-local `Note` (the class) vs `NotesCore.Note` (the struct). Rename the Fluent class to `NoteModel` (recommended — see Lecture 1 §8) and add a `toDTO()` that returns `NotesCore.Note`. Update the controller to return `Note` (the DTO) and map with `try model.toDTO()`.

---

## Step 6 — Build and test everything

From the workspace root, build and test the server (it pulls in `NotesCore` automatically):

```bash
cd notes-api
swift build
swift test
```

Then the package on its own:

```bash
cd ../NotesCore
swift test
```

Both should be green:

```
Test Suite 'All tests' passed at 2026-06-09 14:02:11.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.183 seconds
```

---

## Step 7 — Prove the drift guarantee

This is the payoff. In `NotesCore/Sources/NotesCore/Note.swift`, rename `body` to `content`. Rebuild the server:

```bash
cd ../notes-api
swift build
```

It **fails** — `NoteModel.toDTO()` and the controller reference `body`, which no longer exists on the shared type. The server cannot compile against a contract it disagrees with. That is the entire point of the shared package. **Revert the rename** and confirm the build goes green again.

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `notes-workspace/NotesCore/` is a standalone library package; `swift build` and `swift test` pass inside it.
- [ ] Every wire type in `NotesCore` is `public` with a `public init`, and conforms to `Codable, Sendable`.
- [ ] The server no longer defines the wire structs; it imports them from `NotesCore`.
- [ ] `notes-api/Package.swift` has `.package(path: "../NotesCore")` and the target depends on the `NotesCore` product.
- [ ] The `@retroactive Content` conformances live in the server, not in `NotesCore`.
- [ ] `swift build` and `swift test` pass in `notes-api`.
- [ ] You watched a rename in `NotesCore` break the server build, then reverted it.

---

## Stretch

- Add a `keyEncodingStrategy`/`keyDecodingStrategy` of `.convertToSnakeCase`/`.convertFromSnakeCase` on the server and confirm the JSON on the wire is now `created_at`. Then re-fetch with `curl` to see the snake_case keys.
- Move the round-trip tests from Lecture 1 into `NotesCoreTests` and confirm they pass against the extracted package.
- Publish `NotesCore` to a local Git repo (`git init`, `git tag 0.1.0`) and switch the server's dependency from `.package(path:)` to `.package(url: "file:///.../NotesCore", from: "0.1.0")`. Confirm `swift package resolve` writes a `Package.resolved` with the tag. The import code does not change — only the dependency line.

---

## Hints

<details>
<summary>If the server can't find a type after the move</summary>

You forgot `import NotesCore` in that file, or you forgot `public` on the type or its initializer. A `struct`'s synthesized memberwise initializer is `internal` — you must write a `public init` by hand for consumers to construct the type.

</details>

<details>
<summary>If you get "ambiguous type name 'Note'"</summary>

You have both a server-local `Note` (the Fluent class) and `NotesCore.Note` (the struct) in scope. Rename the Fluent class to `NoteModel`. If you must refer to the struct explicitly, write `NotesCore.Note`.

</details>

<details>
<summary>If `@retroactive` errors as an unknown keyword</summary>

`@retroactive` requires the Swift 6 compiler. Confirm `swift --version` reports 6.x and your manifest is `swift-tools-version:6.0`. On an older toolchain the conformance compiles without the keyword but emits a warning; on 6.0 the keyword silences it explicitly.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — A `URLSession` CLI client](./exercise-02-cli-client.swift).
