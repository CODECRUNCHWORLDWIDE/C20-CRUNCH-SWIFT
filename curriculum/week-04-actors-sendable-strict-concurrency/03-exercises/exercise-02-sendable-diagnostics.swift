// Exercise 2 — Satisfying the Sendable checker
//
// Goal: This file is full of strict-concurrency diagnostics. Your job is to
//       make it compile under Swift 6 language mode WITHOUT @unchecked Sendable,
//       and to write down, for each fix, the exact diagnostic the compiler
//       raised. The point is to read diagnostics fluently and apply the right
//       structural fix every time.
//
// Estimated time: 40 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Scaffold an executable package:
//
//        mkdir Sendables && cd Sendables
//        swift package init --type executable --name Sendables
//
//   2. Set Swift 6 mode in Package.swift:
//
//        // swift-tools-version: 6.0
//        import PackageDescription
//        let package = Package(
//            name: "Sendables",
//            targets: [
//                .executableTarget(
//                    name: "Sendables",
//                    swiftSettings: [.swiftLanguageMode(.v6)]
//                )
//            ]
//        )
//
//   3. Replace Sources/Sendables/main.swift with THIS file.
//   4. Run `swift build`. You will get several errors. Fix them one at a time,
//      top to bottom. After EACH fix, paste the diagnostic you saw into the
//      DIAGNOSTIC LOG at the bottom of this file (a comment block).
//   5. `swift run Sendables` should print the EXPECTED OUTPUT at the very bottom.
//
// RULES
//   - No `@unchecked Sendable`. If you are tempted, you have not understood the fix.
//   - Do not delete functionality. The `main` driver must still produce the
//     expected output. You may add `Sendable`, `@Sendable`, `actor`, `let`,
//     `nonisolated`, and you may turn classes into structs.
//
// ACCEPTANCE CRITERIA
//   [ ] `swift build`: Build complete! (Swift 6 language mode, 0 warnings)
//   [ ] No `@unchecked Sendable` anywhere.
//   [ ] `swift run Sendables` prints the expected output.
//   [ ] The DIAGNOSTIC LOG lists each diagnostic you fixed and the fix you made.

import Foundation

// ----------------------------------------------------------------------------
// PROBLEM 1 — a value object that should be Sendable but is a class
// ----------------------------------------------------------------------------
//
// This is passed across a Task boundary below. As a mutable class it is not
// Sendable. It has no reason to have reference semantics — it is plain data.
//
// FIX HINT: make it a struct (then it is implicitly Sendable), or a final
//           class with only `let` properties conforming to Sendable.

final class Coordinate {
    var latitude: Double
    var longitude: Double
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// ----------------------------------------------------------------------------
// PROBLEM 2 — an immutable config class that just needs to declare Sendable
// ----------------------------------------------------------------------------
//
// All properties are already `let`. It is genuinely safe to share. It just
// needs to SAY so.
//
// FIX HINT: conform to Sendable. Nothing else.

final class RequestConfig {
    let baseURL: URL
    let timeout: TimeInterval
    init(baseURL: URL, timeout: TimeInterval) {
        self.baseURL = baseURL
        self.timeout = timeout
    }
}

// ----------------------------------------------------------------------------
// PROBLEM 3 — a shared mutable registry touched from a Task
// ----------------------------------------------------------------------------
//
// `EventLog` is mutated from inside a `Task` in `main`. A mutable class captured
// by a @Sendable closure is exactly the race the checker stops.
//
// FIX HINT: make it an `actor`. Then the call sites in `main` need `await`.

final class EventLog {
    private var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
    func count() -> Int { lines.count }
    func all() -> [String] { lines }
}

// ----------------------------------------------------------------------------
// PROBLEM 4 — a closure-taking API whose closure escapes to another domain
// ----------------------------------------------------------------------------
//
// `runLater` stashes the closure in a Task. The closure therefore crosses an
// isolation boundary and must be @Sendable. Right now it is not annotated, and
// it captures a mutable var below, which is also illegal.
//
// FIX HINT: annotate the parameter `@Sendable`, and at the call site avoid
//           capturing a mutable `var` — capture a `let` snapshot instead.

func runLater(_ work: @escaping () -> Void) {
    Task {
        work()
    }
}

// ----------------------------------------------------------------------------
// PROBLEM 5 — a global mutable singleton
// ----------------------------------------------------------------------------
//
// A `static var` is non-isolated global mutable state — a data race by
// definition under strict concurrency.
//
// FIX HINT: either make it `static let` (immutable), or isolate it to an actor.
//           Here it only needs to be read, so `let` is the honest fix.

enum BuildInfo {
    static var version = "1.0.0"
}

// ----------------------------------------------------------------------------
// Driver
// ----------------------------------------------------------------------------

@main
struct Sendables {
    static func main() async {
        // Uses PROBLEM 1 + PROBLEM 4: a Coordinate crosses into a Task.
        let here = Coordinate(latitude: 37.3349, longitude: -122.009)
        runLater {
            print("coordinate: \(here.latitude), \(here.longitude)")
        }

        // Uses PROBLEM 2: a config crosses into a Task.
        let config = RequestConfig(baseURL: URL(string: "https://example.com")!,
                                   timeout: 30)
        runLater {
            print("config: \(config.baseURL.absoluteString) t=\(config.timeout)")
        }

        // Uses PROBLEM 3: a shared log mutated from concurrent tasks.
        let log = EventLog()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<3 {
                group.addTask {
                    log.append("event \(i)")
                }
            }
        }
        print("events: \(log.count())")

        // Uses PROBLEM 5.
        print("version: \(BuildInfo.version)")

        // Give the fire-and-forget runLater tasks a moment to print.
        try? await Task.sleep(for: .milliseconds(50))
    }
}

// ----------------------------------------------------------------------------
// EXPECTED OUTPUT (order of the two runLater lines may vary; the rest is fixed)
// ----------------------------------------------------------------------------
//
//   coordinate: 37.3349, -122.009
//   config: https://example.com t=30.0
//   events: 3
//   version: 1.0.0
//
// (The "coordinate" and "config" lines come from fire-and-forget tasks and may
//  interleave with each other, but each appears exactly once.)
//
// ----------------------------------------------------------------------------
// DIAGNOSTIC LOG  (fill this in as you fix each problem)
// ----------------------------------------------------------------------------
//
// PROBLEM 1 diagnostic:
//   <paste the exact compiler error here>
//   FIX: <one sentence>
//
// PROBLEM 2 diagnostic:
//   <paste>
//   FIX:
//
// PROBLEM 3 diagnostic:
//   <paste>
//   FIX:
//
// PROBLEM 4 diagnostic:
//   <paste>
//   FIX:
//
// PROBLEM 5 diagnostic:
//   <paste>
//   FIX:
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 10 min)
// ----------------------------------------------------------------------------
//
// PROBLEM 1:
//   struct Coordinate { let latitude: Double; let longitude: Double }
//   (a struct of Sendable parts is implicitly Sendable; making the fields `let`
//    is cleaner since you never mutate them)
//
// PROBLEM 2:
//   final class RequestConfig: Sendable { ... }   // all-let already, just say it
//
// PROBLEM 3:
//   actor EventLog { ... }
//   // then in main: await log.append(...), await log.count()
//
// PROBLEM 4:
//   func runLater(_ work: @escaping @Sendable () -> Void) { Task { work() } }
//   // call sites capture `here` and `config` which are now Sendable (after 1 & 2)
//
// PROBLEM 5:
//   enum BuildInfo { static let version = "1.0.0" }
//
// ----------------------------------------------------------------------------
