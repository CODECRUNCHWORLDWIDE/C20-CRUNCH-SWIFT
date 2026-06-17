// Exercise 3 — Reentrancy and @MainActor
//
// Goal: Reproduce a classic actor reentrancy bug (a "check-then-act across an
//       await" race), prove it fails, fix it, and then add a @MainActor method
//       that publishes a result — justifying, in a comment, why it must be on
//       the main actor.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Scaffold an executable package:
//        mkdir Reentrancy && cd Reentrancy
//        swift package init --type executable --name Reentrancy
//
//   2. Set Swift 6 mode in Package.swift:
//        // swift-tools-version: 6.0
//        import PackageDescription
//        let package = Package(
//            name: "Reentrancy",
//            targets: [
//                .executableTarget(
//                    name: "Reentrancy",
//                    swiftSettings: [.swiftLanguageMode(.v6)]
//                )
//            ]
//        )
//
//   3. Replace Sources/Reentrancy/main.swift with THIS file.
//   4. PART A: run it. The buggy loader downloads the same resource more than
//      once because of reentrancy. Observe `downloadCount > 1` for a single URL.
//   5. PART B: implement `FixedLoader` so the same workload downloads each URL
//      EXACTLY once. Switch `main` to use it and confirm.
//   6. PART C: implement the @MainActor `ResultsView.show(_:)` and explain why
//      it must be main-actor-isolated.
//
// NOTE: This file COMPILES as given (it is race-free at the data level — actors
//       see to that). The bug is a LOGIC race across `await`, which the compiler
//       does NOT catch. That is the whole point of the exercise: strict
//       concurrency stops data races, not reentrancy bugs.
//
// ACCEPTANCE CRITERIA
//   [ ] `swift build`: Build complete! (Swift 6 language mode, 0 warnings)
//   [ ] PART A prints a download count > 1 for the shared URL (the bug).
//   [ ] PART B: FixedLoader prints download count == 1 per URL (the fix).
//   [ ] PART C: ResultsView.show is @MainActor and the comment justifies it.
//   [ ] No @unchecked Sendable anywhere.

import Foundation

// A Sendable value: safe to cross any boundary.
struct Resource: Sendable {
    let url: URL
    let bytes: Int
}

// ----------------------------------------------------------------------------
// PART A — the buggy loader (reentrancy)
// ----------------------------------------------------------------------------
//
// `BuggyLoader.load` does: check cache -> await download -> write cache.
// Because the actor is reentrant, a second concurrent call for the same URL
// arrives WHILE the first is suspended at the download, sees an empty cache,
// and starts a SECOND download. We count downloads to prove it.

actor BuggyLoader {
    private var cache: [URL: Resource] = [:]
    private(set) var downloadCount = 0

    func load(_ url: URL) async -> Resource {
        if let cached = cache[url] {          // (1) check
            return cached
        }
        let resource = await fakeDownload(url) // (2) await — suspends; reentrancy window
        cache[url] = resource                  // (3) act
        return resource
    }

    private func fakeDownload(_ url: URL) async -> Resource {
        downloadCount += 1
        // Simulate network latency so concurrent callers overlap inside the window.
        try? await Task.sleep(for: .milliseconds(20))
        return Resource(url: url, bytes: 1024)
    }
}

// ----------------------------------------------------------------------------
// PART B — the fixed loader (coalesce in-flight work)
// ----------------------------------------------------------------------------
//
// Implement this so that N concurrent calls for the same URL trigger exactly
// ONE download. The standard fix: store the in-flight Task in the cache BEFORE
// the first await, so reentrant callers join it instead of starting their own.
//
// FILL IN the body of `load`. Do not change the public surface.

actor FixedLoader {
    private enum Entry {
        case inFlight(Task<Resource, Never>)
        case ready(Resource)
    }
    private var cache: [URL: Entry] = [:]
    private(set) var downloadCount = 0

    func load(_ url: URL) async -> Resource {
        // TODO: implement coalescing.
        //  - if cache[url] is .ready(r), return r
        //  - if cache[url] is .inFlight(task), return await task.value
        //  - otherwise: make a Task that downloads, store it as .inFlight BEFORE
        //    awaiting, await its value, store .ready, and return.
        fatalError("implement me")
    }

    private func fakeDownload(_ url: URL) async -> Resource {
        downloadCount += 1
        try? await Task.sleep(for: .milliseconds(20))
        return Resource(url: url, bytes: 1024)
    }
}

// ----------------------------------------------------------------------------
// PART C — publishing to the main actor
// ----------------------------------------------------------------------------
//
// In a real app the result drives UI. UI state must be mutated on the main
// actor. Implement `show(_:)` to append to `displayed`, and write the WHY in
// the comment marked TODO.

@MainActor
final class ResultsView {
    private(set) var displayed: [Resource] = []

    func show(_ resource: Resource) {
        // TODO: append `resource` to `displayed`.
        // TODO (comment): in 1-2 sentences, why must this method be @MainActor?
        fatalError("implement me")
    }

    func summary() -> String {
        "displayed \(displayed.count) resource(s), \(displayed.reduce(0) { $0 + $1.bytes }) bytes"
    }
}

// ----------------------------------------------------------------------------
// Driver
// ----------------------------------------------------------------------------

@main
struct Reentrancy {
    static func main() async {
        let url = URL(string: "https://example.com/big.json")!

        // PART A: prove the bug.
        let buggy = BuggyLoader()
        await withTaskGroup(of: Resource.self) { group in
            for _ in 0..<5 {
                group.addTask { await buggy.load(url) }   // 5 concurrent loads, same URL
            }
            for await _ in group {}
        }
        let buggyCount = await buggy.downloadCount
        print("PART A — buggy download count for one URL: \(buggyCount)  (bug if > 1)")

        // PART B: prove the fix. Uncomment once FixedLoader.load is implemented.
        // let fixed = FixedLoader()
        // await withTaskGroup(of: Resource.self) { group in
        //     for _ in 0..<5 {
        //         group.addTask { await fixed.load(url) }
        //     }
        //     for await _ in group {}
        // }
        // let fixedCount = await fixed.downloadCount
        // print("PART B — fixed download count for one URL: \(fixedCount)  (must be 1)")

        // PART C: publish to the main actor. Uncomment once show(_:) is implemented.
        // let view = ResultsView()
        // let r = await fixed.load(url)
        // await view.show(r)                 // HOP to the main actor
        // let summary = await view.summary() // also main-actor-isolated
        // print("PART C — \(summary)")
    }
}

// ----------------------------------------------------------------------------
// EXPECTED OUTPUT (after PART B and PART C are implemented and uncommented)
// ----------------------------------------------------------------------------
//
//   PART A — buggy download count for one URL: 5  (bug if > 1)
//   PART B — fixed download count for one URL: 1  (must be 1)
//   PART C — displayed 1 resource(s), 1024 bytes
//
// (PART A may print a number from 2 to 5 depending on scheduling; anything > 1
//  demonstrates the reentrancy bug. PART B must be exactly 1.)
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 10 min)
// ----------------------------------------------------------------------------
//
// FixedLoader.load:
//   func load(_ url: URL) async -> Resource {
//       switch cache[url] {
//       case .ready(let r):
//           return r
//       case .inFlight(let task):
//           return await task.value
//       case nil:
//           let task = Task { await self.fakeDownload(url) }
//           cache[url] = .inFlight(task)        // record BEFORE awaiting
//           let r = await task.value
//           cache[url] = .ready(r)
//           return r
//       }
//   }
//
// ResultsView.show:
//   func show(_ resource: Resource) { displayed.append(resource) }
//   // WHY @MainActor: `displayed` drives the UI; SwiftUI/UIKit require all view
//   // state mutation on the main thread. Marking the method @MainActor makes the
//   // compiler enforce that every caller hops to the main actor first.
//
// ----------------------------------------------------------------------------
