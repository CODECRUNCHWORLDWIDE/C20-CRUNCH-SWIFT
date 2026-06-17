# Exercise 1 — `async let` vs `TaskGroup`

**Goal:** Fan out the *same* independent workload two ways — once with `async let`, once with a `TaskGroup` — run both, and feel in your hands why each exists. By the end you'll have a one-paragraph rule for choosing between them that you can defend in code review.

**Estimated time:** 45 minutes.

---

## Setup

You need the Swift 6.1 toolchain. Verify:

```bash
swift --version
```

You should see `Swift version 6.0` or newer. If not, install from <https://www.swift.org/install/> and come back.

Scaffold a fresh executable package:

```bash
mkdir FanOut && cd FanOut
swift package init --type executable --name FanOut
```

This produces:

```
FanOut/
├── Package.swift
└── Sources/
    └── FanOut/
        └── FanOut.swift      (contains a @main struct)
```

Confirm it runs:

```bash
swift run
```

You should see `Hello, world!` (or similar). Now we replace the body.

---

## Step 1 — A fake "fetch" with a known cost

We don't want to depend on the network for a timing exercise, so we'll simulate work with `Task.sleep`. Replace the contents of `Sources/FanOut/FanOut.swift` with:

```swift
import Foundation

/// Simulates fetching one item. Sleeps for `cost`, then returns a labelled result.
/// Uses Task.sleep (cooperative) — never Thread.sleep, which would block the pool.
func fetch(_ name: String, cost: Duration) async -> String {
    try? await Task.sleep(for: cost)
    return "\(name) (\(cost))"
}

@main
struct FanOut {
    static func main() async {
        print("Run with: swift run FanOut [serial|asynclet|group]")
    }
}
```

Build it:

```bash
swift build
```

Expect no warnings, no errors.

---

## Step 2 — The sequential baseline (the bug)

First, prove to yourself that plain `await` is sequential. Add this function above `@main`:

```swift
func runSerial() async {
    let clock = ContinuousClock()
    let start = clock.now

    let a = await fetch("alpha", cost: .milliseconds(300))
    let b = await fetch("bravo", cost: .milliseconds(300))
    let c = await fetch("charlie", cost: .milliseconds(300))

    let elapsed = start.duration(to: clock.now)
    print("serial:   [\(a), \(b), \(c)]  in \(elapsed)")
}
```

Three 300 ms fetches, one after another. Wire it into `main` (we'll dispatch on the first argument):

```swift
@main
struct FanOut {
    static func main() async {
        let mode = CommandLine.arguments.dropFirst().first ?? "serial"
        switch mode {
        case "serial":   await runSerial()
        default:         print("unknown mode: \(mode)")
        }
    }
}
```

Run it:

```bash
swift run FanOut serial
```

Expected output (timing will vary by a few ms):

```
serial:   [alpha (0.3 seconds), bravo (0.3 seconds), charlie (0.3 seconds)]  in 0.9... seconds
```

**~900 ms.** Three sequential 300 ms waits. This is the trap from Lecture 1, §1.

---

## Step 3 — `async let` (the fixed, small set)

Add the `async let` version:

```swift
func runAsyncLet() async {
    let clock = ContinuousClock()
    let start = clock.now

    async let a = fetch("alpha", cost: .milliseconds(300))
    async let b = fetch("bravo", cost: .milliseconds(300))
    async let c = fetch("charlie", cost: .milliseconds(300))

    let results = await [a, b, c]      // join all three here

    let elapsed = start.duration(to: clock.now)
    print("asynclet: \(results)  in \(elapsed)")
}
```

Add a `case "asynclet": await runAsyncLet()` arm to the switch. Run:

```bash
swift run FanOut asynclet
```

Expected:

```
asynclet: ["alpha (0.3 seconds)", "bravo (0.3 seconds)", "charlie (0.3 seconds)"]  in 0.3... seconds
```

**~300 ms.** All three ran concurrently. Same work, one-third the wall-clock time, and the code barely changed: `let` became `async let`, and we joined with `await [a, b, c]`.

Note the result order is **declaration order** — `async let` joins by name, so `a, b, c` come back in the order you listed them, regardless of which finished first.

---

## Step 4 — `TaskGroup` (the dynamic set)

`async let` is perfect for three named fetches. But what if the count is data-driven — say, a list you read at runtime? Now you want a `TaskGroup`. Add:

```swift
func runGroup(count: Int) async {
    let clock = ContinuousClock()
    let start = clock.now

    let results = await withTaskGroup(of: String.self) { group in
        for i in 0..<count {
            group.addTask {
                await fetch("item-\(i)", cost: .milliseconds(300))
            }
        }
        var collected: [String] = []
        for await r in group {           // arrives in COMPLETION order
            collected.append(r)
        }
        return collected
    }

    let elapsed = start.duration(to: clock.now)
    print("group:    \(results.count) items in \(elapsed)")
}
```

Add `case "group": await runGroup(count: 10)` to the switch. Run:

```bash
swift run FanOut group
```

Expected:

```
group:    10 items in 0.3... seconds
```

**Ten** fetches, still ~300 ms, because they all ran concurrently. You could not write this with `async let` without writing out ten named bindings — and you can't write `count` of them when `count` is a runtime value at all. That's the dividing line.

---

## Step 5 — Observe completion order

Change the costs so they differ, to *see* the streaming behaviour of the group. Edit `runGroup`'s `addTask` to vary the cost:

```swift
group.addTask {
    // Later items finish sooner — reverse the cost.
    await fetch("item-\(i)", cost: .milliseconds(50 * (count - i)))
}
```

And print each result as it arrives:

```swift
for await r in group {
    print("  arrived: \(r)")
    collected.append(r)
}
```

Run again. You'll see the **last** item arrive first (it had the smallest cost), proving `for await ... in group` yields in completion order, not submission order. This is the property that lets you start processing the fastest results while slower ones are still in flight — the basis of the streaming report in the mini-project.

---

## Acceptance criteria

You can mark this exercise done when:

- [ ] `swift build` prints no warnings and no errors.
- [ ] `swift run FanOut serial` takes ~900 ms.
- [ ] `swift run FanOut asynclet` takes ~300 ms and returns results in declaration order.
- [ ] `swift run FanOut group` runs 10 concurrent fetches in ~300 ms.
- [ ] With varied costs, you observed `for await ... in group` yielding in **completion** order, not submission order.
- [ ] You can state, in one sentence, when to use `async let` and when to use a `TaskGroup`.

---

## The rule (write your own version before reading this)

> Use **`async let`** when the set of concurrent operations is **fixed and known at compile time** and small — a handful of independent named fetches you join together. Use a **`TaskGroup`** when the set is **dynamic** (driven by data/runtime count), large, or you want to **stream results as they complete**. Both are structured: children can't outlive the scope, and cancelling the parent cancels them all.

---

## Stretch

- Make `fetch` `throws` (e.g., throw if `cost > .seconds(1)`), switch the group to `withThrowingTaskGroup`, and observe that one child's throw cancels the siblings. Then catch the error *inside* the `for try await` loop and keep going — model failure as data instead.
- Add a fourth mode `detached` that runs the same fan-out with `Task.detached` children created in a loop, collecting their `.value`s. Note what you have to do by hand (hold every handle, await each) that the group did for you — that's the cost of leaving the structured world.
- Measure with `time swift run -c release FanOut group` and compare debug vs release. The concurrency model is the same; the per-task overhead shrinks.

---

When this feels comfortable, move to [Exercise 2 — Cooperative cancellation](./exercise-02-cooperative-cancellation.swift).
