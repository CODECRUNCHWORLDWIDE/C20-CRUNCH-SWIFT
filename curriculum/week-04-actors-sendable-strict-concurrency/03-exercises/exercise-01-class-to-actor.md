# Exercise 1 — From Class to Actor

**Goal:** Take a shared mutable `class` that races under strict concurrency, convert it into an `actor`, get the module compiling under Swift 6 language mode, then write down every actor hop in the call graph and what each one costs. The deliverable is half code, half analysis — pricing hops out loud is the skill that separates "I made the warnings go away" from "I understand the model."

**Estimated time:** 45 minutes.

---

## Setup

You need Swift 6.0 or newer. Verify:

```bash
swift --version
```

You should see `Swift version 6.x`. If you don't, install the toolchain from <https://www.swift.org/install/> (Linux) or Xcode 16+ (macOS), and come back.

Scaffold a library package:

```bash
mkdir HitCounter && cd HitCounter
swift package init --type library --name HitCounter
```

Set the package to Swift 6 mode. Replace `Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HitCounter",
    targets: [
        .target(
            name: "HitCounter",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HitCounterTests",
            dependencies: ["HitCounter"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
```

---

## Step 1 — The racy starting point

Put this in `Sources/HitCounter/PageStats.swift`. It models per-page hit counts for an analytics endpoint.

```swift
import Foundation

public final class PageStats {
    private var hitsByPage: [String: Int] = [:]
    private var totalHits = 0

    public init() {}

    public func record(page: String) {
        hitsByPage[page, default: 0] += 1
        totalHits += 1
    }

    public func hits(for page: String) -> Int {
        hitsByPage[page] ?? 0
    }

    public func total() -> Int {
        totalHits
    }

    public func topPages(limit: Int) -> [(page: String, hits: Int)] {
        hitsByPage
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (page: $0.key, hits: $0.value) }
    }
}
```

Now write a test that hammers it concurrently. Replace `Tests/HitCounterTests/HitCounterTests.swift`:

```swift
import XCTest
@testable import HitCounter

final class HitCounterTests: XCTestCase {
    func testConcurrentRecording() async {
        let stats = PageStats()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    stats.record(page: "/home")
                }
            }
        }
        XCTAssertEqual(stats.total(), 1_000)
    }
}
```

Build it:

```bash
swift build
```

**Expected:** it does **not** build. You should see something like:

```
error: capture of 'stats' with non-sendable type 'PageStats'
       in a '@Sendable' closure
```

The `group.addTask { }` closure is `@Sendable`; it captured a mutable class. The compiler just refused to let you ship the race. Good. (If you had compiled this in Swift 5 with checking off, it would have built and then *intermittently failed the assertion* — `total()` would sometimes be 994, sometimes 1000, because `totalHits += 1` is not atomic.)

---

## Step 2 — Convert to an actor

Change `final class` to `actor` and delete `public` on the methods you don't need exported as-is (keep them `public` if you want; an actor's methods can be public). The minimal change:

```swift
import Foundation

public actor PageStats {
    private var hitsByPage: [String: Int] = [:]
    private var totalHits = 0

    public init() {}

    public func record(page: String) {
        hitsByPage[page, default: 0] += 1
        totalHits += 1
    }

    public func hits(for page: String) -> Int {
        hitsByPage[page] ?? 0
    }

    public func total() -> Int {
        totalHits
    }

    public func topPages(limit: Int) -> [(page: String, hits: Int)] {
        hitsByPage
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (page: $0.key, hits: $0.value) }
    }
}
```

Now fix the test — every cross-actor call needs `await`:

```swift
import XCTest
@testable import HitCounter

final class HitCounterTests: XCTestCase {
    func testConcurrentRecording() async {
        let stats = PageStats()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1_000 {
                group.addTask {
                    await stats.record(page: "/home")   // await: hop to the actor
                }
            }
        }
        let total = await stats.total()                  // await: hop to the actor
        XCTAssertEqual(total, 1_000)
    }
}
```

Build and test:

```bash
swift build
swift test
```

**Expected:**

```
Build complete! (Swift 6 language mode, 0 warnings)
...
Test Suite 'HitCounterTests' passed
```

The test now passes *deterministically* — `total()` is always exactly 1000, because the actor serialises all 1000 `record` calls.

---

## Step 3 — Map the hops

Open `Sources/HitCounter/HopMap.md` (create it) and answer the following **for the test above**. Be specific.

1. The `group.addTask { await stats.record(page: "/home") }` runs 1000 times. **How many actor hops does each task incur, and where?** (Hint: count the boat trip in *and* the boat trip back.)
2. The final `await stats.total()` — how many hops, and what domain is the test code in before and after?
3. The 1000 `record` calls are submitted concurrently but the actor runs them serially. **Does that serialisation happen via hops, or via the actor's executor queue?** Explain the difference.
4. Suppose a caller does this in a loop:
   ```swift
   for page in pages {                 // pages.count == 10_000
       await stats.record(page: page)
   }
   ```
   How many hops total? Rewrite `PageStats` to add a `record(pages: [String])` method that takes the whole batch, and state the new hop count. This is the §5 "batch into the actor" move from Lecture 1.

---

## Step 4 — Add the batch method and prove the win

Add to `PageStats`:

```swift
public func record(pages: [String]) {
    for page in pages {
        hitsByPage[page, default: 0] += 1
        totalHits += 1
    }
}
```

Add a test:

```swift
func testBatchRecording() async {
    let stats = PageStats()
    let pages = Array(repeating: "/api", count: 5_000)
    await stats.record(pages: pages)            // ONE hop in, one hop out
    let total = await stats.total()
    XCTAssertEqual(total, 5_000)
}
```

Build and test. In your `HopMap.md`, state plainly: the loop version is `2 * 5000 = 10_000` hops; the batch version is `2` hops. Same work, 5000× fewer boundary crossings.

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `Package.swift` sets `.swiftLanguageMode(.v6)` on both targets.
- [ ] `PageStats` is an `actor`, not a `class`. No `@unchecked Sendable` anywhere.
- [ ] `swift build` prints `Build complete! (Swift 6 language mode, 0 warnings)`.
- [ ] `swift test` shows both tests passing.
- [ ] `HopMap.md` answers all four questions in Step 3 and the batch comparison in Step 4, with concrete hop counts.
- [ ] You can explain, out loud, the difference between "the actor serialises calls via its executor queue" and "each call is a hop." (They are different mechanisms; hops are about *crossing in/out*, serialisation is about *ordering once inside*.)

---

## Stretch

- Add a `nonisolated` computed property `var label: String` that returns a fixed string (touches no isolated state). Confirm a caller can read `stats.label` with **no** `await`. Then try to make it read `totalHits` and watch the compiler reject it.
- Add a `topPages(limit:)` call from a `@MainActor` context (write a tiny `@MainActor func report()`), and trace the hops: main → actor → main. Confirm the returned `[(page: String, hits: Int)]` tuple is `Sendable` (both components are) so it crosses back cleanly.
- Measure a hop. Time 1,000,000 `await stats.total()` calls versus 1,000,000 in-actor reads (add a method that loops internally). The homework walks through this in detail; do a rough version here.

---

## Hints

<details>
<summary>If the test closure still won't compile after converting to an actor</summary>

You must add `await` *inside* the `group.addTask { }` closure, before `stats.record(...)`. The closure body is now calling a cross-actor method, which is implicitly `async`. The closure itself remains `@Sendable` — but now it only captures `stats` (an actor, which **is** `Sendable`) and a `String` literal (also `Sendable`), so the capture is clean.

</details>

<details>
<summary>Answer sketch for the hop count in Step 3</summary>

Each `record` task: 1 hop *in* (the task's domain → the actor's executor) and 1 hop *back* (actor → resume the task). So 2 hops per task, 2000 hops for 1000 tasks. The final `total()` is 2 more. The serialisation of the 1000 records is **not** done by hops — it is done by the actor's executor queue accepting one message at a time. Hops get you to the door; the executor queue is the line inside.

</details>

---

When this exercise feels comfortable, move to [Exercise 2 — Satisfying the Sendable checker](./exercise-02-sendable-diagnostics.swift).
