// Exercise 1 — Swift Testing: parameterized and tagged
//
// Goal: Write the foundation layer the right way — Swift Testing suites with
//       #expect/#require, a parameterized test that covers the whole input space
//       with one function, and tags so CI can run "just the fast ones" on PRs.
//       Each parameterized argument reports as its own pass/fail.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into your Hello, Notes UNIT-TEST target (the Swift Testing template target,
// or any test target — Swift Testing and XCTest coexist). It tests small, pure
// notes logic plus a SwiftData store with a fresh in-memory container per test.
//
//   1. Add to the unit-test target.
//   2. Run with Cmd-U. Watch each parameterized case report separately.
//   3. In the test navigator, filter by tag to run just the fast suite.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (incl. Swift 6 strict-concurrency).
//   [ ] Uses @Test, #expect, and try #require (the XCTUnwrap replacement).
//   [ ] A parameterized @Test(arguments:) where each input reports independently.
//   [ ] A @Suite carrying a tag, plus a .slow-tagged test inside it.
//   [ ] A fresh isStoredInMemoryOnly container per test (isolated, parallel-safe).
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Testing
import SwiftData
import Foundation
@testable import HelloNotes   // your app module

// ----------------------------------------------------------------------------
// A tiny piece of pure logic under test. (Mirror whatever your app actually does;
// here, title normalisation: trim, collapse whitespace, default empty -> "Untitled".)
// ----------------------------------------------------------------------------

enum NoteTitle {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.isEmpty ? "Untitled" : collapsed
    }
}

// ----------------------------------------------------------------------------
// Tags — declared once, applied across suites/tests so CI can slice the run.
// ----------------------------------------------------------------------------

extension Tag {
    @Tag static var logic: Self
    @Tag static var persistence: Self
    @Tag static var slow: Self
}

// ----------------------------------------------------------------------------
// Pure-logic suite. Fast, no I/O. Parameterized over the whole input space.
// ----------------------------------------------------------------------------

@Suite("Title normalization", .tags(.logic))
struct TitleNormalizationTests {

    // ONE function, MANY cases. Each tuple reports as its own pass/fail dot,
    // runs in parallel, and a failure points at the exact failing input.
    @Test(arguments: [
        ("  Groceries  ", "Groceries"),
        ("standup\nnotes", "standup notes"),
        ("multiple   spaces", "multiple spaces"),
        ("\t\n  \t", "Untitled"),
        ("", "Untitled"),
        ("já", "já"),                          // unicode passes through
    ])
    func normalizeProducesExpected(input: String, expected: String) {
        #expect(NoteTitle.normalize(input) == expected)
    }

    @Test func requireUnwrapsOrFailsFast() throws {
        // try #require replaces XCTUnwrap: stops the test if nil, hands back a
        // non-optional so the rest of the test is clean.
        let data = try #require("Groceries".data(using: .utf8))
        let s = try #require(String(data: data, encoding: .utf8))
        #expect(s == "Groceries")
    }
}

// ----------------------------------------------------------------------------
// Persistence suite. Fresh in-memory store per test instance (init runs per test),
// so tests are isolated and safe to run in parallel.
// ----------------------------------------------------------------------------

@Suite("Note store", .tags(.persistence))
struct NoteStoreTests {
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        context = ModelContext(container)
    }

    @Test func insertThenCount() throws {
        context.insert(Note(title: NoteTitle.normalize("  a ")))
        context.insert(Note(title: NoteTitle.normalize("b")))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 2)
    }

    @Test func predicateFiltersInStore() throws {
        for t in ["swift", "kotlin", "swift", "rust"] {
            context.insert(Note(title: t))
        }
        try context.save()
        let swiftNotes = try context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.title == "swift" }
        ))
        #expect(swiftNotes.count == 2)
    }

    // A deliberately heavier test, tagged .slow so CI can skip it on fast PR runs.
    @Test(.tags(.slow)) func bulkInsert() throws {
        for i in 0..<5_000 { context.insert(Note(title: "n\(i)")) }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 5_000)
    }
}

// ----------------------------------------------------------------------------
// An async test — Swift Testing makes testing actors/async natural.
// ----------------------------------------------------------------------------

@Suite("Async work", .tags(.logic))
struct AsyncTests {
    @Test func asyncComputationReturns() async throws {
        let result = await Task { NoteTitle.normalize("  hi  ") }.value
        #expect(result == "hi")
    }
}

// ----------------------------------------------------------------------------
// WHY parameterized beats a for-loop (write it before reading):
//
//   A `for (input, expected) in cases { #expect(... ) }` loop reports as ONE test
//   and STOPS reporting useful info at the first failure (you see "a test failed"
//   but not which input). @Test(arguments:) reports each case as a SEPARATE test,
//   runs them in parallel, and a failure names the exact failing input. Same
//   coverage, vastly better signal — so you actually add cases.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - "Cannot find 'Note' in scope": add `@testable import HelloNotes` (your module
//   name), and make sure the test target depends on the app target.
//
// - A parameterized test fails for ONE input only: that's the feature — the other
//   inputs are green. Read the failing case's input in the test report; fix the
//   logic or the expectation.
//
// - Tests interfere with each other intermittently: you shared mutable state
//   across tests. With per-test `init` building a fresh in-memory container, each
//   test is isolated. Don't use a `static` shared context.
//
// - Strict-concurrency warning: keep the ModelContext on the test (it's created
//   in init and used in the same test). Don't pass it into a Task.detached.
//
// - To run just the fast tests on CI: filter by tag. In a test plan or via
//   `xcodebuild ... -only-test-configuration` / the `.serialized`/tag filters;
//   simplest is a test plan that excludes the `.slow` tag for PR runs.
//
// ----------------------------------------------------------------------------
