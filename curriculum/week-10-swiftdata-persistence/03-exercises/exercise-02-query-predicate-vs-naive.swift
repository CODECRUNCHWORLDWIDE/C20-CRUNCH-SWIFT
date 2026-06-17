// Exercise 2 — #Predicate (in SQLite) vs naive .filter (in memory)
//
// Goal: Prove, with two numbers, that filtering with a #Predicate inside a
//       FetchDescriptor is dramatically cheaper than fetching every row and
//       filtering the array in Swift. Same answer, very different cost.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This file is a SWIFT TESTING suite (the `import Testing` / `@Test` style
// shipped with Xcode 16). Drop it into a test target of any iOS 17+/macOS 14+
// app, or a Swift package test target that depends on SwiftData. It builds its
// own in-memory ModelContainer, so it never touches your real store and needs
// no app UI.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U (or `swift test` in a package).
//   3. Read the printed timings in the test log. The predicate version should
//      be many times faster; the assertions enforce "correct AND not slower".
//
// If your project still uses XCTest, the conversion is mechanical: replace
// `@Test func x() async throws` with `func testX() async throws` inside an
// `XCTestCase`, and `#expect(a == b)` with `XCTAssertEqual(a, b)`.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] All tests pass.
//   [ ] The log prints two timings, and the predicate fetch is faster than the
//       naive in-memory filter (the test asserts it returns no more rows and
//       takes no longer).
//   [ ] You can explain, in one sentence, WHY the predicate version wins.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import SwiftData
import Testing

// ----------------------------------------------------------------------------
// The model under test
// ----------------------------------------------------------------------------

@Model
final class Article {
    var title: String
    var topic: String
    var views: Int
    var createdAt: Date

    init(title: String, topic: String, views: Int, createdAt: Date = .now) {
        self.title = title
        self.topic = topic
        self.views = views
        self.createdAt = createdAt
    }
}

// ----------------------------------------------------------------------------
// A tiny monotonic timer. ContinuousClock ignores wall-clock adjustments, so
// it is the right tool for "how long did this take" measurements.
// ----------------------------------------------------------------------------

func elapsed<T>(_ work: () throws -> T) rethrows -> (value: T, duration: Duration) {
    let clock = ContinuousClock()
    let start = clock.now
    let value = try work()
    return (value, clock.now - start)
}

// ----------------------------------------------------------------------------
// The test suite
// ----------------------------------------------------------------------------

@MainActor
struct PredicateVsNaiveTests {

    /// Build a fresh in-memory container and seed it with `count` articles,
    /// of which exactly `matching` have topic == "swift".
    func seededContext(count: Int, matching: Int) throws -> ModelContext {
        let schema = Schema([Article.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        for i in 0..<count {
            let isMatch = i < matching
            context.insert(Article(
                title: "Article \(i)",
                topic: isMatch ? "swift" : "kotlin",
                views: i % 1000,
                createdAt: Date(timeIntervalSince1970: TimeInterval(i))
            ))
        }
        try context.save()
        return context
    }

    @Test("Predicate and naive filter return the SAME rows")
    func sameAnswer() throws {
        let context = try seededContext(count: 5_000, matching: 37)

        // Naive: fetch everything, filter the array in Swift.
        let naive = try context.fetch(FetchDescriptor<Article>())
            .filter { $0.topic == "swift" }

        // Predicate: SQLite does the filtering; only matches are materialised.
        let predicated = try context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { $0.topic == "swift" }
        ))

        #expect(naive.count == 37)
        #expect(predicated.count == 37)
        #expect(naive.count == predicated.count)
    }

    @Test("Predicate fetch is not slower than naive in-memory filter")
    func predicateIsFaster() throws {
        // Big enough that the difference is real, small enough to run in CI fast.
        let context = try seededContext(count: 50_000, matching: 50)

        let naive = elapsed {
            (try? context.fetch(FetchDescriptor<Article>()))?
                .filter { $0.topic == "swift" } ?? []
        }

        // Re-seed a clean context so the two reads don't share warmed caches.
        let context2 = try seededContext(count: 50_000, matching: 50)

        let predicated = elapsed {
            (try? context2.fetch(FetchDescriptor<Article>(
                predicate: #Predicate { $0.topic == "swift" }
            ))) ?? []
        }

        print("naive  (fetch-all + .filter): \(naive.duration)  -> \(naive.value.count) rows")
        print("predicate (filter in SQLite): \(predicated.duration)  -> \(predicated.value.count) rows")

        // Same answer...
        #expect(naive.value.count == predicated.value.count)
        // ...and the predicate version should not be slower. (We compare with a
        // generous margin so CI variance never flakes the test.)
        #expect(predicated.duration <= naive.duration)
    }

    @Test("Sort descriptors order rows in SQLite, newest first")
    func sortedQuery() throws {
        let context = try seededContext(count: 100, matching: 100)

        let sorted = try context.fetch(FetchDescriptor<Article>(
            predicate: #Predicate { $0.topic == "swift" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))

        #expect(sorted.count == 100)
        // createdAt was assigned increasing per index, so reverse means
        // the highest createdAt (last inserted) is first.
        let dates = sorted.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test("fetchCount counts in SQLite without building objects")
    func cheapCount() throws {
        let context = try seededContext(count: 10_000, matching: 250)

        let count = try context.fetchCount(FetchDescriptor<Article>(
            predicate: #Predicate { $0.topic == "swift" }
        ))

        #expect(count == 250)
    }
}

// ----------------------------------------------------------------------------
// WHY the predicate wins (write this in your own words before reading):
//
//   The #Predicate is translated into a SQL WHERE clause and evaluated INSIDE
//   SQLite, so only the matching rows are ever read off disk and turned into
//   Swift `Article` objects. The naive version fetches EVERY row, faults each
//   one into a full managed object, hands you a 50,000-element array, and then
//   throws ~49,950 of them away. You paid to materialise the whole table to
//   keep 0.1% of it.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `ModelContext(container)` makes a fresh context bound to a container. For
//   tests that's cleaner than reaching for `container.mainContext`.
//
// - If the predicate test "flakes" (predicate occasionally measured slower on a
//   tiny dataset), increase `count` to 50_000+ so the gap dwarfs the noise.
//   At small N both are sub-millisecond and timing noise dominates.
//
// - `#Predicate { $0.topic == "swift" }` needs the element type to be
//   inferable. Inside `FetchDescriptor<Article>(predicate:)` it infers Article.
//   Standalone, write `#Predicate<Article> { $0.topic == "swift" }`.
//
// - Strict-concurrency warning about ModelContext crossing an actor boundary?
//   The whole suite is `@MainActor`, so the context never leaves the main
//   actor. Don't `Task.detached` inside a test here.
//
// ----------------------------------------------------------------------------
