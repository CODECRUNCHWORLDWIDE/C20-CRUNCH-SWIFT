# Lecture 1 — The Structured Concurrency Model: Task Trees and Cancellation

> **Duration:** ~2 hours of reading + hands-on.
> **Outcome:** You can explain the difference between sequencing and concurrency, fan out work with `async let` and a `TaskGroup`, describe a task tree, trace how cancellation propagates down it, and cap concurrency to apply back-pressure.

If you remember one sentence from this lecture, remember this:

> **In structured concurrency, the lifetime of every concurrent task is bounded by a lexical scope.** When that scope exits — by returning, by `throw`, or by being cancelled — the runtime *guarantees* every child task it started is already finished or cancelled. There is no leaked work. That guarantee is the whole reason the model exists.

Hold that sentence next to the way you may have done concurrency before — `DispatchQueue.async { }`, raw threads, completion handlers — where the closure you submit has no relationship to the function that submitted it, and "did all my background work finish before I returned?" is a question you cannot answer from the code. Structured concurrency makes that question answerable by reading the braces.

---

## 1. `await` is not "go parallel"

The single most common misconception, even among engineers who have shipped async code in other languages, is that `await` runs things in parallel. It does not. `await` is a **suspension point**, and on its own it is *sequential*.

Consider:

```swift
func loadProfileScreen() async throws -> Screen {
    let user = try await fetchUser()          // (1) runs, we wait
    let posts = try await fetchPosts()         // (2) starts only after (1) finishes
    let avatar = try await fetchAvatar()       // (3) starts only after (2) finishes
    return Screen(user: user, posts: posts, avatar: avatar)
}
```

If each fetch takes 100 ms, this function takes **300 ms**. The three calls are *sequenced*: each one waits for the previous to complete before starting. The fact that they're `async` changes only *what the thread does while waiting* — it gets returned to the pool to do other work instead of blocking — not the order of operations.

This is usually a bug when the three calls are independent. `fetchPosts()` does not need `user`. We left 200 ms of parallelism on the table. We will fix it in §4 with `async let`.

But first, internalize the distinction, because it drives every decision this week:

- **Sequencing** is doing one thing, then the next. `await; await; await` is sequencing.
- **Concurrency** is multiple tasks making progress in overlapping time. You *opt into* it explicitly with `async let` or a task group. The language never makes your code concurrent behind your back.

> **The mental model.** `await` means "I might pause here; while I'm paused, the thread is free to do something else; resume me when my result is ready." It does not mean "spawn." Spawning is a separate, explicit act.

---

## 2. What suspension actually does

When a function hits an `await` and the awaited work isn't ready, the function **suspends**. Concretely:

1. The function's local state is saved (on the heap, in an async frame — not the C stack).
2. The **thread** running it is returned to the cooperative pool. It is *not* blocked. It goes off and runs other ready tasks.
3. When the awaited work completes, the runtime finds a free pool thread and **resumes** your function from the suspension point.

Two consequences that bite newcomers:

**You can resume on a different thread than you suspended on.** Do not stash anything in thread-local storage across an `await` and expect it to survive. (This is exactly why `@TaskLocal` exists — see §9 — task-locals survive suspension because they belong to the *task*, not the thread.)

**State can change across a suspension point.** Between the moment you suspend and the moment you resume, other tasks ran. Anything you read before the `await` may be stale after it. This is *reentrancy*, and it is the source of a whole bug class we'll meet properly with actors in Week 4. For now: be suspicious of "read, await, then act on what you read."

### The cooperative thread pool — and the cardinal sin

Swift Concurrency does **not** spawn a thread per task. It runs everything on a **cooperative thread pool** sized to roughly your core count. A 10-core machine has ~10 pool threads, and your 10,000 tasks share them by suspending and resuming.

This is wonderful for throughput and it has one absolute rule:

> **Never block a cooperative pool thread.** No `sleep()`, no `DispatchSemaphore.wait()`, no synchronous blocking I/O, no `Thread.sleep`, no busy-loop. If you block a pool thread, you have removed one of your ~10 threads from circulation. Block enough of them and the whole program deadlocks because there's no thread left to resume the very work you're waiting on.

To wait, you `await`. To pause, you `try await Task.sleep(for: .seconds(1))` — which suspends cooperatively and frees the thread — never `Thread.sleep(forTimeInterval:)`, which blocks it.

---

## 3. Anatomy of an `async` function

```swift
func fetchUser(id: UUID) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw APIError.badStatus
    }
    return try JSONDecoder().decode(User.self, from: data)
}
```

- `async` in the signature means "this function may suspend." Callers must `await` it.
- `throws` and `async` compose: the call site reads `try await fetchUser(id:)`. Order matters at the declaration (`async throws`) but at the call site it's always `try await`.
- `URLSession.shared.data(from:)` is the modern async HTTP API. It replaces the `dataTask(with:completionHandler:)` callback dance entirely.
- This function can only be *called* from an async context — another `async` function, a `Task { }`, or `@main`'s async `main()`. You cannot call it from synchronous code without creating a task; the compiler enforces this.

That last point is the "async colouring" rule people complain about: async functions are callable only from async contexts. In a structured-concurrency world this is a feature — it forces you to be explicit about where concurrency boundaries are.

---

## 4. `async let` — concurrency for a small, fixed set

Back to our 300 ms screen loader. The three fetches are independent. We want them running concurrently and to wait for all three. The lightweight tool is `async let`:

```swift
func loadProfileScreen() async throws -> Screen {
    async let user = fetchUser()        // child task starts NOW
    async let posts = fetchPosts()      // child task starts NOW
    async let avatar = fetchAvatar()    // child task starts NOW

    // All three are running concurrently. We join when we read them:
    return Screen(
        user: try await user,
        posts: try await posts,
        avatar: try await avatar
    )
}
```

The moment you write `async let user = fetchUser()`, a **child task** is created and starts running. The binding is a *promise* of a future value. You don't pay for it until you `await` the binding. Now all three fetches overlap, and the function takes ~**100 ms** instead of 300.

Key properties of `async let`:

- **Implicitly concurrent at the point of declaration.** No `Task { }`, no group.
- **Joined at the first `await`** of the binding (or, if you never await it, *implicitly cancelled and awaited* when the scope exits — the runtime will not let a child leak).
- **Structured.** The child tasks are children of the current task. They cannot outlive `loadProfileScreen`. If `loadProfileScreen` is cancelled, so are they.
- **Best for a fixed, small, statically known set** of concurrent operations. Three named fetches: perfect. Ten thousand URLs from a file: wrong tool — use a task group.

If `try await posts` throws, the other two children are automatically cancelled and awaited before the error propagates out of the function. You never end up with `avatar` quietly running after `loadProfileScreen` has already thrown. That automatic cleanup is structured concurrency earning its name.

---

## 5. `TaskGroup` — concurrency for a dynamic set

`async let` is for when you know the children at compile time. When the number of children is data-driven — "fan out one HEAD request per URL in this sitemap" — you use a **task group**.

```swift
struct CheckResult: Sendable {
    let url: URL
    let statusCode: Int?
    let failed: Bool
}

func checkAll(_ urls: [URL]) async -> [CheckResult] {
    await withTaskGroup(of: CheckResult.self) { group in
        for url in urls {
            group.addTask {
                await check(url)            // each child is independent
            }
        }

        var results: [CheckResult] = []
        for await result in group {          // results stream in as they finish
            results.append(result)
        }
        return results
    }
}
```

Read that carefully — there's a lot in it:

- `withTaskGroup(of:body:)` opens a scope. Inside, `group.addTask { }` spawns a child task. The closure's return type must match the `of:` type (`CheckResult.self` here).
- `for await result in group` consumes results **as each child completes**, *not* in the order you added them. The fastest request reports first. This is the streaming property — you can start processing the first result while the others are still in flight.
- The group **will not return** until every child has finished. When the `withTaskGroup` closure exits, all children are guaranteed complete. Structured.
- This version doesn't throw. For throwing children, use `withThrowingTaskGroup(of:)`, and the first child error propagates out (cancelling the rest) unless you catch it inside the `for try await` loop.

### Throwing groups and per-task error isolation

Often you do *not* want one failed URL to abort the whole run — you want to record it and keep going. So make each child return a `Result`-like value (a `CheckResult` with a `failed` flag) and use the **non-throwing** group, as above. Reserve `withThrowingTaskGroup` + propagation for "if any child fails, the whole operation is meaningless, abort everything."

That's a real design decision you make on every fan-out: **does a single failure poison the batch, or is each item independent?** The link-checker treats each URL as independent — one dead link doesn't abort the crawl — so it models failure *as data* (`CheckResult.failed`) and uses a plain `withTaskGroup`.

---

## 6. The task tree

Put §4 and §5 together and you get a **tree**. Every structured child task has exactly one parent. The parent's scope dominates the child's lifetime.

```
                  ┌─────────────────────────────┐
                  │  Task: runLinkCheck()        │   ← root (your @main)
                  └──────────────┬──────────────┘
                                 │ withTaskGroup
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
   │ child: check │    │ child: check │    │ child: check │
   │   url[0]     │    │   url[1]     │    │   url[2]     │  ...
   └──────────────┘    └──────────────┘    └──────────────┘
```

Three structural guarantees the tree gives you:

1. **No child outlives its parent's scope.** When `withTaskGroup`'s closure returns, all `check(url)` children are done. The parent literally cannot return until they are.
2. **Errors propagate up.** In a throwing group, a child's thrown error surfaces at the group boundary (after siblings are cancelled).
3. **Cancellation propagates down.** Cancel the parent and every descendant is marked cancelled. This is the subject of §7, and it is the property that makes a clean Ctrl-C possible.

Contrast with unstructured `Task { }` (Lecture 2): those are *not* in the tree. They have no parent scope, cancellation does not reach them automatically, and "did it finish?" is your problem to track.

---

## 7. Cancellation is cooperative, not preemptive

Here is the rule that trips up everyone coming from other languages or from `Thread.cancel()`-style APIs:

> **Cancelling a task does not stop it.** It sets a flag. The task keeps running until *it* checks the flag and decides to stop. Cancellation in Swift is **cooperative**.

Why cooperative and not preemptive? Because preemptively killing a task mid-operation leaves invariants broken — half-written files, half-held locks, partially mutated state. Cooperative cancellation lets each task choose *safe* stopping points. The cost is that you must actually check.

There are three ways to observe cancellation:

```swift
// 1. Throw if cancelled — the most common, drops you out of the function.
try Task.checkCancellation()      // throws CancellationError if cancelled

// 2. Branch on it — when you want to do cleanup rather than throw.
if Task.isCancelled {
    saveProgressSoFar()
    return partialResult
}

// 3. Built-in cancellation: most async stdlib calls are already cooperative.
try await Task.sleep(for: .seconds(5))   // throws CancellationError if cancelled mid-sleep
```

`Task.sleep`, `URLSession`'s async methods, and most of the async standard library are *already* cancellation-aware: they throw `CancellationError` (or `URLError(.cancelled)`) the instant the task is cancelled, instead of running to completion. So a task that's mostly `await`ing other cancellation-aware work is *already* mostly cooperative for free. The places you must add explicit checks are **long synchronous loops** with no `await` inside them:

```swift
func sumOfPrimes(upTo limit: Int) async throws -> Int {
    var total = 0
    for n in 2...limit {
        if n % 4096 == 0 {                 // check periodically, not every iteration
            try Task.checkCancellation()
        }
        if isPrime(n) { total += n }
    }
    return total
}
```

Check *periodically* (every few thousand iterations), not on every single iteration — `Task.isCancelled` is cheap but not free, and you don't need millisecond cancellation latency.

### How cancellation propagates through the tree

When a parent task is cancelled, the runtime marks **every descendant** cancelled, depth-first through the tree. Each descendant then observes it cooperatively at its own next check point. So:

```swift
await withTaskGroup(of: CheckResult.self) { group in
    for url in urls { group.addTask { await check(url) } }
    for await r in group { results.append(r) }
}
```

If the task running `checkAll` is cancelled, the group is cancelled, every `check(url)` child is cancelled, and the `URLSession` request inside each `check` throws `URLError(.cancelled)` at its next suspension. The whole tree winds down — *if every leaf cooperates*. One uncooperative leaf (a `Thread.sleep`, a `while true {}` with no check) jams the drain. That's why the "drains clean" promise in the README is a real acceptance bar.

### `withTaskCancellationHandler` — react the instant cancellation fires

`Task.isCancelled` is a *poll*. Sometimes you need to react *immediately* when cancellation arrives — to close a socket, cancel an in-flight `URLSessionTask`, signal a continuation. That's `withTaskCancellationHandler`:

```swift
func download(_ url: URL) async throws -> Data {
    let session = URLSession.shared
    let task = session.dataTask(with: url)   // a classic URLSessionTask

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            // (real code: set task.delegate / completionHandler to resume the continuation)
            task.resume()
        }
    } onCancel: {
        // Runs IMMEDIATELY when the surrounding Task is cancelled —
        // possibly on another thread, so capture only Sendable things.
        task.cancel()
    }
}
```

Two things to burn in:

- **`onCancel` runs synchronously and immediately** when cancellation fires, on whatever thread the cancellation happened on. It may run *before* `operation` even starts, or while it's suspended. Keep it tiny and only touch `Sendable` state.
- It does **not** stop `operation`. It runs *alongside* it. Its job is to *nudge* the operation toward stopping (cancel the network task, signal the continuation), after which `operation` observes the failure and unwinds.

Exercise 2 has you build this end-to-end and verify the `onCancel` fires through a two-level tree.

---

## 8. Back-pressure: cap the concurrency

Here is the trap. This looks innocent:

```swift
await withTaskGroup(of: CheckResult.self) { group in
    for url in tenThousandURLs {
        group.addTask { await check(url) }   // adds ALL 10,000 immediately
    }
    for await r in group { results.append(r) }
}
```

`addTask` does not block. The `for` loop spawns all ten thousand children **before the consumer reads a single result**. Now ten thousand `URLSession` requests are in flight at once. You will exhaust your file-descriptor limit, the OS socket table, or the remote server's patience, and the run will collapse with `Too many open files` or a flood of timeouts. Spawning is cheap; the *resources each task holds* are not.

**Back-pressure** means: keep only *N* tasks in flight, and start a new one only when an old one finishes. The idiom is the **sliding window**:

```swift
func checkAll(_ urls: [URL], maxConcurrent: Int) async -> [CheckResult] {
    await withTaskGroup(of: CheckResult.self) { group in
        var results: [CheckResult] = []
        var index = 0

        // 1. Prime the window: start up to `maxConcurrent` tasks.
        let window = min(maxConcurrent, urls.count)
        while index < window {
            let url = urls[index]
            group.addTask { await check(url) }
            index += 1
        }

        // 2. Each time one finishes, collect it and start the next, if any.
        while let result = await group.next() {
            results.append(result)
            if index < urls.count {
                let url = urls[index]
                group.addTask { await check(url) }
                index += 1
            }
        }
        return results
    }
}
```

Now at most `maxConcurrent` requests are ever in flight. `group.next()` returns the next finished child; we collect it and immediately top the window back up. When `index == urls.count` and the window drains, `group.next()` returns `nil` and we exit. This is the exact pattern the mini-project uses for its default of 16 concurrent requests, and Exercise 3 has you measure how throughput changes as you vary the window.

Why not just "use a semaphore to limit to N"? Because a `DispatchSemaphore.wait()` **blocks the cooperative pool thread** — the cardinal sin from §2. There are async-aware semaphore packages, but the sliding-window-over-a-task-group above needs no extra primitive and is the idiomatic Swift answer. (Swift's own `swift-async-algorithms` has helpers, but learn the bare pattern first.)

---

## 9. `@TaskLocal` — threading context without polluting signatures

Sometimes you need a value available *everywhere* in a task tree — a request ID for logging, a deadline, a trace span — without passing it as a parameter through twenty function signatures. Thread-locals don't work (you can resume on a different thread, §2). The structured answer is `@TaskLocal`:

```swift
enum RequestContext {
    @TaskLocal static var requestID: String = "no-request"
}

func handle() async {
    await RequestContext.$requestID.withValue("req-42") {
        await doWork()       // anything reachable from here sees "req-42"
    }
    // outside the withValue scope, requestID is back to "no-request"
}

func doWork() async {
    print("[\(RequestContext.requestID)] working")   // prints [req-42]
    async let a = step()    // child tasks INHERIT the task-local
    _ = await a
}

func step() async {
    print("[\(RequestContext.requestID)] step")       // also prints [req-42]
}
```

Properties:

- Declared `@TaskLocal static var` (must be `static`).
- You don't assign it directly. You **bind** it with `$name.withValue(_:operation:)`, scoped to that operation.
- **Child tasks inherit it.** The `async let a = step()` child sees `req-42` because task-locals flow down the structured tree — unlike thread-locals, which would be lost across a thread hop. (Unstructured `Task { }` also inherits; `Task.detached` does *not* — Lecture 2.)
- It survives suspension, because it lives on the task, not the thread.

This is exactly how `pointfreeco/swift-dependencies` injects dependencies and how server frameworks thread a trace context through a request. In the mini-project you'll use a `@TaskLocal` to carry the run's deadline so the timeout is available to every leaf without a parameter.

---

## 10. Priority

Tasks carry a `TaskPriority`: `.high`, `.medium` (default), `.low` / `.utility`, `.background`. It's a *hint* to the scheduler about ordering, not a hard guarantee.

```swift
group.addTask(priority: .background) { await prefetch(url) }
```

Two facts worth knowing now (we go deeper in Lecture 2):

- **Children inherit the parent's priority** by default. A child of a `.high` task runs at `.high` unless you say otherwise.
- **Priority escalation**: if a high-priority task `await`s the result of a lower-priority task, the runtime *escalates* the lower one so the high-priority waiter isn't stuck behind it. You rarely set priority explicitly; the defaults plus escalation are usually right.

Do not reach for `.high` to "make it faster." Everything at high priority is the same as everything at default priority — you've just removed the scheduler's ability to differentiate.

---

## 11. Putting it together — a complete, runnable fan-out

Here is a self-contained program that fans out, applies back-pressure, respects cancellation, and reports. Save as `main.swift` in a SwiftPM executable and `swift run`:

```swift
import Foundation

struct CheckResult: Sendable {
    let url: URL
    let statusCode: Int?
    let elapsed: Duration
}

func check(_ url: URL) async -> CheckResult {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    let clock = ContinuousClock()
    let start = clock.now
    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode
        return CheckResult(url: url, statusCode: code, elapsed: start.duration(to: clock.now))
    } catch {
        // URLError(.cancelled) lands here too — failure is modelled as data.
        return CheckResult(url: url, statusCode: nil, elapsed: start.duration(to: clock.now))
    }
}

func checkAll(_ urls: [URL], maxConcurrent: Int) async -> [CheckResult] {
    await withTaskGroup(of: CheckResult.self) { group in
        var results: [CheckResult] = []
        var index = 0
        let window = min(maxConcurrent, urls.count)
        while index < window { group.addTask { [u = urls[index]] in await check(u) }; index += 1 }
        while let r = await group.next() {
            results.append(r)
            if index < urls.count { group.addTask { [u = urls[index]] in await check(u) }; index += 1 }
        }
        return results
    }
}

@main
struct Main {
    static func main() async {
        let urls = [
            "https://www.swift.org",
            "https://developer.apple.com",
            "https://github.com/apple/swift",
        ].compactMap(URL.init(string:))

        let results = await checkAll(urls, maxConcurrent: 2)
        for r in results.sorted(by: { $0.url.absoluteString < $1.url.absoluteString }) {
            let status = r.statusCode.map(String.init) ?? "ERR"
            print("\(status)\t\(r.url.absoluteString)\t\(r.elapsed)")
        }
    }
}
```

Two details that matter:

- `[u = urls[index]]` is a **capture list**. We copy the `URL` value into the closure rather than capturing `index` by reference (which mutates in the loop). Capturing the mutable `index` by reference into a concurrent closure is a classic data-race bug; the value capture sidesteps it. (Week 4's strict concurrency would flag the reference capture outright.)
- Failure is `statusCode: nil`, not a thrown error. The batch never aborts on one bad URL.

Run it. You should see three lines, each with a status code and an elapsed `Duration`, in completion order before the sort.

---

## 12. Recap

You should now be able to:

- Explain why `await; await` is sequential and how `async let` makes independent work concurrent.
- Describe a suspension point and why blocking a cooperative pool thread is forbidden.
- Choose `async let` for a fixed small set and a `TaskGroup` for a dynamic set.
- Draw a task tree and state the three guarantees (no leaked children, errors up, cancellation down).
- Implement cooperative cancellation with `Task.checkCancellation()` and react immediately with `withTaskCancellationHandler`.
- Apply back-pressure with a sliding window over a task group.
- Thread context down a tree with `@TaskLocal`.

Next up: the *unstructured* half of the model — `Task { }` vs `Task.detached`, when each is correct, and a blunt accounting of why `DispatchQueue` is the past. Continue to [Lecture 2 — `Task { }` vs `Task.detached`, and why `DispatchQueue` is the past](./02-task-vs-detached-and-why-dispatchqueue-is-the-past.md).

---

## References

- *The Swift Programming Language — Concurrency*: <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/>
- *SE-0304 — Structured concurrency*: <https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md>
- *SE-0317 — `async let` bindings*: <https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md>
- *`TaskGroup` reference*: <https://developer.apple.com/documentation/swift/taskgroup>
- *`withTaskCancellationHandler`*: <https://developer.apple.com/documentation/swift/withtaskcancellationhandler(operation:oncancel:)>
- *`TaskLocal`*: <https://developer.apple.com/documentation/swift/tasklocal>
- *WWDC21 "Explore structured concurrency in Swift"* (10134): <https://developer.apple.com/videos/play/wwdc2021/10134/>
