# Challenge 1 — Raise `NotesCore` Swift Testing Coverage Above 70%

**Time estimate:** ~90 minutes.

## Problem statement

Take the `NotesCore` package you built in Exercise 1 (the shared `Note`, `CreateNoteRequest`, `UpdateNoteRequest`, and `APIError` types) and raise its **Swift Testing line coverage above 70%**, measured by `swift test --enable-code-coverage`. You will get there by writing two families of tests:

1. **Round-trip `Codable` tests** — encode a value, decode it back, assert it equals the original. This proves the wire format is *symmetric*: anything the server encodes, a client decodes back to the same value, with no field lost, reordered, or mistyped.
2. **Edge-case decoding tests for malformed payloads** — feed the decoder JSON that is wrong in specific ways (missing key, wrong type, bad date format, extra unknown key) and assert that it fails (or succeeds) for the *right* reason. This is where the real bugs hide: a wire type that silently swallows garbage is a production incident.

This is the Phase I gate deliverable. Do it on the real `NotesCore` package, not a throwaway, so the coverage you earn here counts toward the mini-project and the demo.

## Why coverage, and why 70%

Coverage is a floor, not a ceiling. A package with 95% coverage and no assertions is worthless; a package with 70% coverage where every test asserts real behaviour is trustworthy. We pick 70% because, for a small package of pure value types, 70% line coverage is the point at which you have necessarily written round-trip tests for every type *and* hit the non-happy paths. You cannot reach 70% on `NotesCore` by accident — the malformed-payload branches force you to think about failure, which is the entire skill.

## Setup

You need a decoder and encoder configured the same way the server and CLI configure theirs, or your round-trip tests will pass against a config the wire never uses. Put a tiny helper in your test target so every test shares one config:

```swift
import Foundation
import Testing
@testable import NotesCore

enum WireJSON {
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
```

> **Why `.iso8601` on both sides.** `JSONEncoder`'s default `dateEncodingStrategy` is `.deferredToDate`, which writes a `Double` (seconds since the 2001 reference date) — unreadable on the wire and a portability trap. The `notes-api` and the CLI both use `.iso8601` (Lecture 1 §10). Your tests must use the same strategy, or you will "prove" a round-trip that the real wire never performs.

## Required tests

Write at least these. They are the minimum to clear 70% and they are the minimum a reviewer would expect.

### Round-trip (one per type)

- [ ] `Note` round-trips: build a `Note` with non-empty `tags`, encode, decode, `#expect(decoded == original)`.
- [ ] `Note` round-trips with **empty** `tags` (the empty-array edge).
- [ ] `CreateNoteRequest` round-trips with and without tags (exercise the `tags: [] ` default).
- [ ] `UpdateNoteRequest` round-trips with **all fields present**.
- [ ] `UpdateNoteRequest` round-trips with **all fields nil** (the "patch nothing" edge).
- [ ] `UpdateNoteRequest` round-trips with a **mix** of present and nil fields.
- [ ] `APIError` round-trips.

### Malformed-payload decoding (the bug-finders)

- [ ] Decoding a `Note` from JSON **missing the `title` key** throws `DecodingError.keyNotFound`, and the failing key is `title`.
- [ ] Decoding a `Note` where `tags` is a **string instead of an array** throws `DecodingError.typeMismatch`.
- [ ] Decoding a `Note` where `createdAt` is **not a valid ISO-8601 string** throws `DecodingError.dataCorrupted` (or `typeMismatch`, depending on the input) — assert it *throws*, and inspect the error.
- [ ] Decoding a `Note` from JSON with an **extra unknown key** *succeeds* (Swift's `Codable` ignores unknown keys by default — assert that it does, because this is the property that lets the server add fields without breaking old clients).
- [ ] Decoding an `UpdateNoteRequest` from `{}` (empty object) **succeeds** with all fields `nil` (absent key == `nil` for optionals — the trap from Lecture 1 §5).
- [ ] Decoding an `UpdateNoteRequest` where `"title": null` **succeeds** with `title == nil` (null == absent for optionals — same trap, the other branch).

### Parameterized (use Swift Testing's strength)

- [ ] At least **one** parameterized `@Test(arguments:)` that round-trips several `Note` values in one test function — e.g. notes with 0, 1, and 20 tags. Parameterized tests are where Swift Testing beats XCTest; use one here.

## Worked examples

A round-trip test:

```swift
@Test("Note survives an encode/decode round trip")
func noteRoundTrips() throws {
    let original = Note(
        id: UUID(),
        title: "Buy oat milk",
        body: "the barista kind",
        tags: ["errand", "grocery"],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_500)
    )

    let data = try WireJSON.encoder.encode(original)
    let decoded = try WireJSON.decoder.decode(Note.self, from: data)

    #expect(decoded == original)
}
```

A malformed-payload test that inspects the error, not just the throw:

```swift
@Test("Decoding a Note without a title fails on the title key")
func noteMissingTitleThrowsKeyNotFound() throws {
    let json = Data("""
    {
      "id": "1B4E28BA-2FA1-11D2-883F-0016D3CCA427",
      "body": "no title here",
      "tags": [],
      "createdAt": "2026-06-09T12:00:00Z",
      "updatedAt": "2026-06-09T12:00:00Z"
    }
    """.utf8)

    #expect(throws: DecodingError.self) {
        try WireJSON.decoder.decode(Note.self, from: json)
    }

    // Stronger: confirm it is the *title* key that is missing.
    do {
        _ = try WireJSON.decoder.decode(Note.self, from: json)
        Issue.record("expected decoding to throw")
    } catch let DecodingError.keyNotFound(key, _) {
        #expect(key.stringValue == "title")
    }
}
```

A parameterized round-trip:

```swift
@Test("Note round-trips across tag-count edges", arguments: [0, 1, 20])
func noteRoundTripsByTagCount(tagCount: Int) throws {
    let tags = (0..<tagCount).map { "tag-\($0)" }
    let original = Note(
        id: UUID(),
        title: "t",
        body: "b",
        tags: tags,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    let data = try WireJSON.encoder.encode(original)
    let decoded = try WireJSON.decoder.decode(Note.self, from: data)
    #expect(decoded.tags.count == tagCount)
    #expect(decoded == original)
}
```

## Measuring coverage

```bash
swift test --enable-code-coverage
```

SwiftPM writes coverage data to `.build/debug/codecov/`. To get a human-readable per-file report, find the test binary and the profdata and run `llvm-cov`:

```bash
# Locate the built test bundle (the path varies by platform; this finds it).
BIN=$(swift build --show-bin-path)
# On Linux the test executable is named "<Package>PackageTests.xctest".
xcrun llvm-cov report \
  "$BIN/NotesCorePackageTests.xctest" \
  -instr-profile "$BIN/codecov/default.profdata" \
  2>/dev/null || \
llvm-cov report \
  "$BIN/NotesCorePackageTests.xctest" \
  -instr-profile "$BIN/codecov/default.profdata"
```

> On Linux, drop the `xcrun` prefix and call `llvm-cov` directly (it ships with the Swift toolchain). On macOS, `xcrun llvm-cov` finds the right one. The report prints a line-coverage percentage per file; sum across the `Sources/NotesCore/*.swift` files for the package figure.

You want the `NotesCore` source files — not the test files — above 70% in the `Lines` / `Cover` column.

## Acceptance criteria

- [ ] A `NotesCoreTests` test target with the round-trip, malformed-payload, and parameterized tests above.
- [ ] `swift test` passes: **0 failures**.
- [ ] `swift test --enable-code-coverage` runs, and the `llvm-cov report` shows `NotesCore` source files **above 70% line coverage**.
- [ ] At least one parameterized `@Test(arguments:)` test.
- [ ] At least three malformed-payload tests that assert the *kind* of `DecodingError`, not merely that something threw.
- [ ] No `@testable import` is used to reach into private state you should not be testing — these are public wire types; test them through their public API.
- [ ] A short `coverage.md` in the package root with the `llvm-cov` report pasted in and the package coverage figure stated.

## Stretch

- Add a **schema-evolution test**: encode a `Note` with the current type, then decode it into a *future* `NoteV2` that has an extra optional field, and assert the old payload decodes cleanly with the new field `nil`. This is the test that proves your wire format can evolve without breaking old clients — the whole reason the field is optional.
- Add a **fuzz-ish test**: generate 1,000 random `Note` values (random tag counts, random unicode titles including emoji and combining characters), round-trip each, assert equality. Unicode in titles is the classic "works in the demo, breaks in Tokyo" bug; prove it does not.
- Push coverage past **90%** and write one sentence on the marginal test that took you from 70% to 90% — and whether it was worth writing.

## Hints

<details>
<summary>If your round-trip fails on the dates</summary>

You almost certainly forgot to set `dateEncodingStrategy`/`dateDecodingStrategy` to `.iso8601` on *both* the encoder and decoder. The default `.deferredToDate` encodes a `Double`; if you encode with the default and decode with `.iso8601` (or vice versa), the round-trip fails. Use the shared `WireJSON` helper for every test so the config can never drift between encode and decode.

</details>

<details>
<summary>If coverage is stuck below 70%</summary>

The lines you are missing are almost always the failure branches inside the decoder — which you only hit by feeding malformed JSON. A package of pure structs with synthesized `Codable` has very few lines; the way to cover them is to exercise both the success path (round-trip) and the failure path (malformed payload). If you wrote only happy-path tests, your malformed-payload tests are what push you over.

</details>

<details>
<summary>If `llvm-cov` cannot find the test binary on Linux</summary>

The test bundle name follows the pattern `<PackageName>PackageTests.xctest` and lives under `swift build --show-bin-path`. List the bin path (`ls "$(swift build --show-bin-path)"`) to find the exact name; it can differ slightly by toolchain version. The `.profdata` is under `codecov/` in that same directory.

</details>

## Submission

Commit the test target and `coverage.md` to your `NotesCore` package under the mini-project workspace. A reviewer clones, runs `swift test --enable-code-coverage`, regenerates the report, and confirms the figure. The most common review-fail is "the README claims 78% but a fresh run shows 61%" — regenerate and verify before you submit.

## Why this matters

Every shared package in the rest of this track lives or dies on its tests. In Phase II your SwiftUI client decodes `NotesCore` types; in Phase III your `NotesClient` actor decodes them off a flaky network. If `NotesCore` is not proven correct, every bug downstream is ambiguous — "is it the client, the server, or the wire type?" A well-tested shared package answers "not the wire type" definitively, which is worth more in a 3 AM incident than any feature. This challenge builds the habit while the package is small enough to test exhaustively.
