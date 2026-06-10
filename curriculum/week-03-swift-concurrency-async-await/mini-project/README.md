# Mini-Project — Parallel Link-Checker CLI

> Build a real command-line tool, `linkcheck`, that takes a `sitemap.xml`, fans out to **N concurrent HTTP `HEAD` requests** (default 16), collects results into a `TaskGroup`, honours `--timeout`, **cancels cleanly on Ctrl-C**, and prints a final report. Pure structured concurrency — no `DispatchQueue` for the work, only for trapping the signal. Runs on Linux and macOS on the open-source Swift 6.1 toolchain. No Xcode, no Mac required.

This is the week's centrepiece. Everything in the lectures and exercises converges here: `async`/`await`, a bounded `TaskGroup` for back-pressure, `withTaskCancellationHandler` to cancel in-flight requests, a `@TaskLocal` deadline, and the `DispatchSource`-trapped Ctrl-C from Lecture 2. By the time it's done you will have a tool you actually use — point it at your own site's sitemap and find your dead links.

**Estimated time:** ~8.5 hours (split across Thursday, Friday, Saturday in the suggested schedule).

---

## What you will build

A command-line tool invoked like this:

```bash
# Check every <loc> in a sitemap, 16 concurrent HEAD requests, 5s timeout.
swift run linkcheck --sitemap sitemap.xml

# Tune concurrency and timeout.
swift run linkcheck --sitemap sitemap.xml --concurrency 32 --timeout 3

# Read a sitemap from a URL instead of a local file.
swift run linkcheck --sitemap https://example.com/sitemap.xml

# Only print failures (CI mode); exit non-zero if any link is dead.
swift run linkcheck --sitemap sitemap.xml --failures-only
```

A `sitemap.xml` is the standard search-engine sitemap format — a flat list of URLs:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
  <url><loc>https://example.com/about</loc></url>
  <url><loc>https://example.com/blog/structured-concurrency</loc></url>
  <url><loc>https://example.com/contact</loc></url>
</urlset>
```

Your tool extracts every `<loc>`, issues a `HEAD` request to each (concurrently, but capped), and reports which are alive, which are dead, and which timed out.

By the end you will have a public GitHub repo of ~300–450 lines of Swift (excluding tests) that handles malformed input, never spawns more than `--concurrency` requests at once, and **drains every in-flight request when you press Ctrl-C**.

---

## Rules

- **You may** read the Swift documentation, the lecture notes, the Swift Evolution proposals, and the docs for the one HTTP dependency below.
- **HTTP client:** use **`swift-server/async-http-client`** (`AsyncHTTPClient`). It is the production server-side Swift HTTP client, it is fully `async`/`await`, and it works identically on Linux and macOS — unlike `URLSession`, whose async surface is uneven on Linux in some toolchains. Add it in `Package.swift`.
  - Acceptable alternative: `URLSession`'s `data(for:)` if you are on macOS and prefer zero dependencies. If you go this route, the `HEAD` method is set via `URLRequest.httpMethod = "HEAD"`, and you must verify it builds and runs on Linux too (it should on 6.1, but test it).
- **Argument parsing:** use **`apple/swift-argument-parser`** (`ArgumentParser`). It is the standard, it is what `swift` itself uses, and it gives you `--flags`, help text, and validation for free.
- **XML parsing:** the sitemap is simple enough that you may parse it with `Foundation`'s `XMLParser` (event-based, works on Linux) **or** a small regex/string scan over `<loc>...</loc>`. No third-party XML library.
- **Concurrency:** all fan-out must be **structured** (a `TaskGroup`). The only unstructured task allowed is the single root `Task { }` that bridges synchronous `main` glue into async, plus the `DispatchSource` signal trap. No `DispatchQueue` for the actual work.
- Target the **Swift 6.1 toolchain**. Build must be warning-free.

---

## Acceptance criteria

- [ ] A new public GitHub repo named `c20-week-03-linkcheck-<yourhandle>`.
- [ ] Package layout matches the C20 standard:
  ```
  linkcheck/
  ├── Package.swift
  ├── .gitignore
  ├── README.md
  ├── samples/
  │   └── sample-sitemap.xml          (12+ URLs, mix of live/dead)
  ├── Sources/
  │   └── linkcheck/
  │       ├── LinkCheck.swift          (@main entry, arg parsing, signal trap)
  │       ├── Sitemap.swift            (parse sitemap.xml → [URL])
  │       ├── Checker.swift            (the bounded TaskGroup fan-out)
  │       └── Report.swift             (result types + final report)
  └── Tests/
      └── linkcheckTests/
          ├── SitemapTests.swift
          └── CheckerTests.swift
  ```
- [ ] `swift build` and `swift build -c release` both print **no warnings, no errors**.
- [ ] `swift test` reports **at least 12** passing tests across `Sitemap` and `Checker`. The `Checker` tests inject a **fake** `URLChecking` so they do not hit the network.
- [ ] `swift run linkcheck --sitemap samples/sample-sitemap.xml` runs and prints a final report.
- [ ] At most `--concurrency` (default 16) requests are ever in flight at once. Prove it (a counter, a log line, or a test).
- [ ] `--timeout` (default 5 seconds) bounds each request; a slow URL is reported as `timeout`, not left hanging, and never blocks the whole run.
- [ ] **Ctrl-C cancels every in-flight request and the process exits in under one second**, printing a partial report. A hung Ctrl-C is a failing submission.
- [ ] Malformed input does not crash: a missing file throws a clean error message and a non-zero exit; a malformed `<loc>` line is skipped with a warning on `stderr`.
- [ ] No `Thread.sleep`, no `DispatchSemaphore.wait()`, no synchronous blocking I/O on a cooperative pool thread anywhere.
- [ ] Exit code is `0` when all links are OK, non-zero when any link is dead (so it's usable in CI).
- [ ] `README.md` includes a one-paragraph description, exact setup/run commands from a fresh clone, the sample sitemap, and the expected report output.

---

## Suggested order of operations

Build it incrementally. Each phase produces a commit.

### Phase 1 — Package skeleton (~45 min)

```bash
mkdir linkcheck && cd linkcheck
swift package init --type executable --name linkcheck
git init
```

Edit `Package.swift` to add the two dependencies and the test target:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "linkcheck",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    ],
    targets: [
        .executableTarget(
            name: "linkcheck",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "linkcheckTests",
            dependencies: ["linkcheck"]
        ),
    ]
)
```

Confirm `swift build` resolves and compiles. First commit: `Package skeleton with ArgumentParser + AsyncHTTPClient`.

### Phase 2 — Result types and the report (~1 h)

In `Sources/linkcheck/Report.swift`, model the outcome as **data** (failure is not an exception here — one dead link must not abort the crawl):

```swift
import Foundation

enum CheckOutcome: Sendable, Equatable {
    case ok(status: Int)                 // 2xx / 3xx
    case dead(status: Int)               // 4xx / 5xx
    case timeout
    case transportError(String)          // DNS, connection refused, TLS, etc.
    case cancelled                       // task was cancelled before completing
}

struct CheckResult: Sendable, Equatable {
    let url: URL
    let outcome: CheckOutcome
    let elapsed: Duration
}

struct Report {
    let results: [CheckResult]
    let totalRequested: Int              // for partial (cancelled) reports

    var ok: Int { results.filter { if case .ok = $0.outcome { true } else { false } }.count }
    var dead: [CheckResult] { results.filter { if case .dead = $0.outcome { true } else { false } } }
    var failed: [CheckResult] {
        results.filter {
            switch $0.outcome {
            case .dead, .timeout, .transportError: true
            default: false
            }
        }
    }
    var hasFailures: Bool { !failed.isEmpty }

    func render(failuresOnly: Bool) -> String {
        var lines: [String] = []
        let shown = failuresOnly ? failed : results
        for r in shown.sorted(by: { $0.url.absoluteString < $1.url.absoluteString }) {
            lines.append("  \(symbol(r.outcome)) \(label(r.outcome))\t\(r.url.absoluteString)")
        }
        lines.append("")
        lines.append("checked \(results.count) / \(totalRequested) URLs")
        lines.append("  ok:      \(ok)")
        lines.append("  dead:    \(dead.count)")
        lines.append("  failed:  \(failed.count)")
        return lines.joined(separator: "\n")
    }

    private func symbol(_ o: CheckOutcome) -> String {
        switch o {
        case .ok: "✓"
        case .dead, .transportError, .timeout: "✗"
        case .cancelled: "•"
        }
    }
    private func label(_ o: CheckOutcome) -> String {
        switch o {
        case .ok(let s): "OK \(s)"
        case .dead(let s): "DEAD \(s)"
        case .timeout: "TIMEOUT"
        case .transportError(let m): "ERR \(m)"
        case .cancelled: "CANCELLED"
        }
    }
}
```

Test the report rendering against hand-built `[CheckResult]`. Commit: `Result types + report rendering + tests`.

### Phase 3 — Sitemap parsing (~1 h)

In `Sources/linkcheck/Sitemap.swift`, define a function that turns sitemap XML data into URLs, skipping malformed entries:

```swift
import Foundation

enum SitemapError: Error, CustomStringConvertible {
    case empty
    var description: String {
        switch self {
        case .empty: "sitemap contained no <loc> URLs"
        }
    }
}

struct Sitemap {
    /// Extracts every <loc> URL. Returns the valid URLs and a list of warnings
    /// for entries that could not be parsed into a URL.
    static func parse(_ data: Data) throws -> (urls: [URL], warnings: [String]) {
        let xml = String(decoding: data, as: UTF8.self)
        var urls: [URL] = []
        var warnings: [String] = []

        // Simple, robust-enough scan for <loc>…</loc>. The sitemap schema is flat.
        var search = xml.startIndex
        while let open = xml.range(of: "<loc>", range: search..<xml.endIndex),
              let close = xml.range(of: "</loc>", range: open.upperBound..<xml.endIndex) {
            let raw = xml[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" {
                urls.append(url)
            } else {
                warnings.append("skipping malformed <loc>: '\(raw)'")
            }
            search = close.upperBound
        }

        if urls.isEmpty { throw SitemapError.empty }
        return (urls, warnings)
    }
}
```

Test against: a well-formed sitemap (returns N URLs), one with a malformed `<loc>` (returns N-1 + a warning), and an empty one (throws `.empty`). Commit: `Sitemap parser + tests`.

### Phase 4 — The checker, behind a protocol (~2 h)

The key design move for testability: hide the network behind a protocol so tests inject a fake. In `Sources/linkcheck/Checker.swift`:

```swift
import Foundation
import AsyncHTTPClient
import NIOCore

/// The seam that lets tests run without a network.
protocol URLChecking: Sendable {
    func head(_ url: URL, timeout: Duration) async -> CheckOutcome
}

/// Production implementation over AsyncHTTPClient.
struct HTTPChecker: URLChecking {
    let client: HTTPClient

    func head(_ url: URL, timeout: Duration) async -> CheckOutcome {
        do {
            var request = HTTPClientRequest(url: url.absoluteString)
            request.method = .HEAD
            let deadline = NIODeadline.now() + .milliseconds(Int64(timeout.components.seconds * 1000))
            let response = try await client.execute(request, deadline: deadline)
            let code = Int(response.status.code)
            return (200...399).contains(code) ? .ok(status: code) : .dead(status: code)
        } catch is CancellationError {
            return .cancelled
        } catch let error as HTTPClientError where error == .deadlineExceeded {
            return .timeout
        } catch {
            if Task.isCancelled { return .cancelled }
            return .transportError("\(error)")
        }
    }
}

/// Fan out over URLs with a bounded TaskGroup (back-pressure) and collect results.
/// `maxConcurrent` requests are in flight at most. Cancellation drains the group.
func checkAll(
    _ urls: [URL],
    using checker: some URLChecking,
    maxConcurrent: Int,
    timeout: Duration
) async -> Report {
    let results = await withTaskGroup(of: CheckResult.self) { group in
        var collected: [CheckResult] = []
        var index = 0
        let window = min(max(maxConcurrent, 1), urls.count)

        // Prime the window.
        while index < window {
            let url = urls[index]
            group.addTask { await timedCheck(url, using: checker, timeout: timeout) }
            index += 1
        }

        // One-in, one-out: collect a finished result, start the next.
        while let result = await group.next() {
            collected.append(result)
            if index < urls.count, !Task.isCancelled {
                let url = urls[index]
                group.addTask { await timedCheck(url, using: checker, timeout: timeout) }
                index += 1
            }
        }
        return collected
    }
    return Report(results: results, totalRequested: urls.count)
}

private func timedCheck(
    _ url: URL,
    using checker: some URLChecking,
    timeout: Duration
) async -> CheckResult {
    let clock = ContinuousClock()
    let start = clock.now
    let outcome = await checker.head(url, timeout: timeout)
    return CheckResult(url: url, outcome: outcome, elapsed: start.duration(to: clock.now))
}
```

> **Why `some URLChecking` and not `any URLChecking`?** Generic over the concrete type (opaque, `some`) lets the compiler specialise and keeps the value `Sendable`-clean. We covered the `some`-vs-`any` decision in Week 2; here `some` is right because we have a single concrete checker per run.

Now write `CheckerTests.swift` with a fake:

```swift
import Testing
import Foundation
@testable import linkcheck

struct FakeChecker: URLChecking {
    let map: [String: CheckOutcome]
    func head(_ url: URL, timeout: Duration) async -> CheckOutcome {
        // Simulate a tiny bit of latency so concurrency is real.
        try? await Task.sleep(for: .milliseconds(5))
        return map[url.absoluteString] ?? .dead(status: 404)
    }
}

@Test func checkAll_collects_every_url_once() async {
    let urls = (0..<50).compactMap { URL(string: "https://x/\($0)") }
    let map = Dictionary(uniqueKeysWithValues: urls.map { ($0.absoluteString, CheckOutcome.ok(status: 200)) })
    let report = await checkAll(urls, using: FakeChecker(map: map), maxConcurrent: 8, timeout: .seconds(5))
    #expect(report.results.count == 50)
    #expect(report.ok == 50)
    #expect(report.hasFailures == false)
}

@Test func checkAll_reports_dead_links_as_data_without_aborting() async {
    let urls = (0..<10).compactMap { URL(string: "https://x/\($0)") }
    var map: [String: CheckOutcome] = [:]
    for (i, u) in urls.enumerated() {
        map[u.absoluteString] = i == 3 ? .dead(status: 500) : .ok(status: 200)
    }
    let report = await checkAll(urls, using: FakeChecker(map: map), maxConcurrent: 4, timeout: .seconds(5))
    #expect(report.results.count == 10)     // one dead link did NOT abort the batch
    #expect(report.failed.count == 1)
}
```

Commit: `Checker behind URLChecking protocol + bounded fan-out + tests`.

### Phase 5 — The CLI entry point and Ctrl-C trap (~2 h)

In `Sources/linkcheck/LinkCheck.swift`, wire `ArgumentParser`, load the sitemap (file or URL), run the checker, and trap `SIGINT`:

```swift
import Foundation
import ArgumentParser
import AsyncHTTPClient

@main
struct LinkCheck: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "linkcheck",
        abstract: "Check every URL in a sitemap.xml with concurrent HEAD requests."
    )

    @Option(help: "Path or URL to the sitemap.xml.") var sitemap: String
    @Option(help: "Max concurrent requests.") var concurrency: Int = 16
    @Option(help: "Per-request timeout, in seconds.") var timeout: Int = 5
    @Flag(help: "Print only failures; exit non-zero if any link is dead.")
    var failuresOnly = false

    func run() async throws {
        let urls = try await loadSitemap(sitemap)
        FileHandle.standardError.write(Data(
            "checking \(urls.count) URLs (concurrency \(concurrency), timeout \(timeout)s)…\n".utf8))

        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try? client.syncShutdown() }
        let checker = HTTPChecker(client: client)
        let deadline = Duration.seconds(timeout)

        // Run the structured fan-out as one cancellable unstructured task,
        // so the SIGINT handler can cancel the whole tree.
        let work = Task { await checkAll(urls, using: checker, maxConcurrent: concurrency, timeout: deadline) }

        let sigint = installSIGINTHandler(cancelling: work)
        defer { sigint.cancel() }

        let report = await work.value
        print(report.render(failuresOnly: failuresOnly))

        if report.hasFailures {
            throw ExitCode(1)     // CI-friendly non-zero exit
        }
    }

    private func loadSitemap(_ source: String) async throws -> [URL] {
        let data: Data
        if let url = URL(string: source), url.scheme == "http" || url.scheme == "https" {
            let client = HTTPClient(eventLoopGroupProvider: .singleton)
            defer { try? client.syncShutdown() }
            let response = try await client.execute(HTTPClientRequest(url: source), deadline: .now() + .seconds(10))
            var body = try await response.body.collect(upTo: 16 * 1024 * 1024)
            data = Data(body.readBytes(length: body.readableBytes) ?? [])
        } else {
            data = try Data(contentsOf: URL(fileURLWithPath: source))
        }
        let (urls, warnings) = try Sitemap.parse(data)
        for w in warnings { FileHandle.standardError.write(Data("warning: \(w)\n".utf8)) }
        return urls
    }
}

/// Trap Ctrl-C with a DispatchSource signal source — the one place GCD is still
/// the right tool (Lecture 2, §6). On SIGINT, cancel the work task; cancellation
/// propagates down the TaskGroup to every in-flight request.
func installSIGINTHandler<R: Sendable>(cancelling work: Task<R, Never>) -> DispatchSourceSignal {
    signal(SIGINT, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    source.setEventHandler {
        FileHandle.standardError.write(Data("\n^C — cancelling in-flight requests…\n".utf8))
        work.cancel()
    }
    source.resume()
    return source
}
```

Run it against your sample sitemap. Hit Ctrl-C mid-run and confirm it drains in under a second. Commit: `CLI entry point + SIGINT trap + sitemap-from-URL`.

### Phase 6 — Sample data + README + polish (~1 h)

- Write `samples/sample-sitemap.xml` with 12+ URLs: some live (`https://www.swift.org`, `https://developer.apple.com`), at least one guaranteed-dead (`https://www.swift.org/this-page-does-not-exist-404`), and a deliberately malformed `<loc>not a url</loc>` to exercise the warning path.
- Run `swift run linkcheck --sitemap samples/sample-sitemap.xml` and paste the report into the README under "Example output."
- Run `swift build -c release` and confirm zero warnings.
- Add a one-line CI: `.github/workflows/ci.yml` running `swift build && swift test` on a `swift:6.1` container. (Optional this week; required from Week 5.)
- Push to GitHub.

Commit: `Sample sitemap + README + CI`.

---

## Example expected output

For a sample sitemap of 12 URLs where one returns 404, one is malformed, and the rest are OK:

```
$ swift run linkcheck --sitemap samples/sample-sitemap.xml
warning: skipping malformed <loc>: 'not a url'
checking 11 URLs (concurrency 16, timeout 5s)…
  ✓ OK 200	https://developer.apple.com
  ✓ OK 200	https://github.com/apple/swift
  ✗ DEAD 404	https://www.swift.org/this-page-does-not-exist-404
  ✓ OK 200	https://www.swift.org

checked 11 / 11 URLs
  ok:      10
  dead:    1
  failed:  1
$ echo $?
1
```

On Ctrl-C mid-run:

```
$ swift run linkcheck --sitemap samples/large-sitemap.xml --concurrency 16
checking 1204 URLs (concurrency 16, timeout 5s)…
^C — cancelling in-flight requests…

checked 312 / 1204 URLs
  ok:      308
  dead:    4
  failed:  4
```

The exact ordering varies (results stream in completion order before the sort), but the report is deterministic in its counts and the process exits promptly.

---

## Rubric

| Criterion | Weight | What "great" looks like |
|----------|-------:|-------------------------|
| Builds and runs | 20% | `swift build`, `swift test`, `swift run` all clean on a fresh clone; release builds warning-free |
| Structured concurrency | 20% | Fan-out is a bounded `TaskGroup`; failure modelled as data; no `DispatchQueue` for work |
| Back-pressure | 15% | Never more than `--concurrency` in flight; proven by a counter or test |
| Cancellation | 20% | Ctrl-C drains every in-flight request in < 1 s; partial report prints; no hang, no leak |
| Testability | 15% | `URLChecking` protocol with a fake; ≥ 12 tests; no test hits the network |
| README quality | 10% | Someone unfamiliar can clone and run in < 5 minutes; expected output shown |

---

## Stretch (optional)

- Add `--retry N` with bounded retries and jittered backoff — that's **[Challenge 1](../challenges/challenge-01-retry-with-bounded-concurrency.md)**, which builds directly on this.
- Add a `@TaskLocal` carrying the run's `deadline`, so `timedCheck` reads the timeout from the task-local instead of a parameter — exactly the pattern from Lecture 1, §9.
- Follow `3xx` redirects one hop and report the final status (configurable with `--follow-redirects`).
- Emit `--format json` (a `Codable` report) so the output is machine-readable for CI dashboards.
- Add a progress line on `stderr` that updates in place (`checked 312 / 1204…`) using a throttled print, without blocking the work.

---

## What this prepares you for

- **Week 4** takes this exact tool and turns on **strict concurrency**. The result aggregator becomes an `actor`, the `@unchecked Sendable` shortcuts you may have reached for become real `Sendable` conformances, and the compiler proves the whole thing race-free. The link-checker is your migration subject.
- **Week 13** rebuilds the HTTP layer as a production `URLSession`/networking actor with typed errors, retry-with-jitter, and offline detection. The retry challenge here is that lecture's warm-up.
- The "fan out, bound it, cancel cleanly, report" shape is the spine of every batch job, every prefetch, every parallel sync you will write for the rest of the track — including the capstone's CloudKit/Vapor sync path.

---

## Submission

When done:

1. Push your repo to GitHub with a public URL.
2. Ensure `README.md` has the setup commands and the expected report output.
3. Ensure `swift build`, `swift test`, and `swift run linkcheck --sitemap samples/sample-sitemap.xml` are all green on a fresh clone.
4. Include a short transcript (or asciinema) of a **clean Ctrl-C mid-run** — that's the artifact that proves you earned the week's skill.
5. Post the repo URL in your cohort tracker. You built a real tool; show it.
