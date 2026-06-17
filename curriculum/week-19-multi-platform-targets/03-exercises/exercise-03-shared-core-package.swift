// Exercise 3 — Extract a shared core package that compiles for all five platforms
//
// Goal: Make the share/adapt line PHYSICAL. Move the model and a platform-
//       agnostic domain function into a SwiftPM package declared for iOS,
//       macOS, watchOS, and visionOS. The constraint is the lesson: because the
//       package must compile for EVERY platform, the compiler refuses any
//       platform-specific UI code in it — the line becomes a build-enforced
//       boundary, not a convention. Then test the domain ONCE, because the same
//       compiled code runs everywhere.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
// This is the CONTENT of a SwiftPM package's source file plus its test file and
// the Package.swift you declare it with. Create a package and a test target,
// then `swift test` (or Cmd-U) builds it for the host and runs the tests; the
// multi-platform `platforms:` declaration is what proves cross-platform intent.
//
//   1. File ▸ New ▸ Package (or `swift package init --type library`). Name it
//      NotesCore. Replace Package.swift with the one below.
//   2. Put the `NotesCore` source (section 2) in Sources/NotesCore/.
//   3. Put the tests (section 3) in Tests/NotesCoreTests/.
//   4. `swift test`. Then try section 4's BROKEN code to FEEL the boundary.
//
// ACCEPTANCE CRITERIA
//
//   [ ] The package declares all of iOS/macOS/watchOS/visionOS and builds.
//   [ ] The model and domain function are `public` and have ZERO platform
//       branches and ZERO UIKit/AppKit imports.
//   [ ] The domain tests pass (and you understand they cover every platform).
//   [ ] You tried adding a UIKit import (section 4) and watched the build FAIL,
//       proving the boundary is real.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

// ============================================================================
// 1. Package.swift — the declaration that makes "all platforms" a build fact.
// ============================================================================
/*
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotesCore",
    platforms: [
        .iOS(.v18), .macOS(.v15), .watchOS(.v11), .visionOS(.v2),
    ],
    products: [
        .library(name: "NotesCore", targets: ["NotesCore"]),
    ],
    targets: [
        .target(name: "NotesCore"),
        .testTarget(name: "NotesCoreTests", dependencies: ["NotesCore"]),
    ]
)
*/

// ============================================================================
// 2. Sources/NotesCore/NotesCore.swift — SHARED, platform-agnostic. No UI.
//    Only Foundation (and SwiftData) — things that exist on every platform.
// ============================================================================

import Foundation

/// The model — `public` so every shell can use it across the package boundary.
/// (In the real app this is a @Model; here a struct keeps the exercise import-
/// free so it compiles anywhere, including in a plain `swift test`.)
public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, body: String = "", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }
}

/// Pure domain logic — the SAME answer on every platform, so it lives in the
/// core. No `#if os`, no UIKit, no AppKit. The iPhone, the Mac, the Watch, and
/// the Vision shell all call THIS, unchanged.
public enum NotesDomain {

    /// The N most recently updated notes, newest first. (The watch shows 3.)
    public static func recent(_ notes: [Note], limit: Int) -> [Note] {
        Array(notes.sorted { $0.updatedAt > $1.updatedAt }.prefix(max(0, limit)))
    }

    /// A glanceable summary line — identical on every face and screen.
    public static func summary(_ notes: [Note]) -> String {
        switch notes.count {
        case 0: return "No notes"
        case 1: return "1 note"
        default: return "\(notes.count) notes"
        }
    }

    /// Case- and diacritic-insensitive search — platform-agnostic.
    public static func matching(_ notes: [Note], query: String) -> [Note] {
        guard !query.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query)
        }
    }
}

// ============================================================================
// 3. Tests/NotesCoreTests/NotesCoreTests.swift — test the domain ONCE.
//    This coverage applies to EVERY platform, because it's the same code.
// ============================================================================

#if canImport(Testing)
import Testing
@testable import NotesCore   // (or `import NotesCore` since the API is public)

struct NotesDomainTests {

    private func sample() -> [Note] {
        (0..<5).map { Note(title: "Note \($0)", body: "body \($0)",
                           updatedAt: Date(timeIntervalSince1970: TimeInterval($0))) }
    }

    @Test("recent returns the newest N, newest first")
    func recent() {
        let r = NotesDomain.recent(sample(), limit: 3)
        #expect(r.count == 3)
        #expect(r.map(\.title) == ["Note 4", "Note 3", "Note 2"])
    }

    @Test("recent clamps a limit larger than the collection")
    func recentClamped() {
        #expect(NotesDomain.recent(sample(), limit: 100).count == 5)
        #expect(NotesDomain.recent(sample(), limit: 0).isEmpty)
    }

    @Test("summary pluralizes correctly")
    func summary() {
        #expect(NotesDomain.summary([]) == "No notes")
        #expect(NotesDomain.summary([Note(title: "a")]) == "1 note")
        #expect(NotesDomain.summary(sample()) == "5 notes")
    }

    @Test("matching is case-insensitive across title and body")
    func matching() {
        let notes = [Note(title: "Swift", body: "great"), Note(title: "Kotlin", body: "SWIFTLY")]
        #expect(NotesDomain.matching(notes, query: "swift").count == 2)  // title + body hit
        #expect(NotesDomain.matching(notes, query: "").count == 2)       // empty = all
    }
}
#endif

// ============================================================================
// 4. FEEL the boundary — uncomment this in the NotesCore source and watch the
//    build FAIL on watchOS/macOS. The compiler enforces the share/adapt line.
// ============================================================================
//
//   import UIKit                              // ❌ no UIKit on macOS/watchOS
//   public func iconColor() -> UIColor { .red }   // breaks the multi-platform build
//
// The failure is the lesson: anything that needs UIKit/AppKit is a SHELL
// concern, not a CORE concern. The package physically can't hold it. That's the
// share/adapt line, made of build settings instead of good intentions.

// ----------------------------------------------------------------------------
// WHY this matters (write it in your own words first):
//
//   The package's `platforms:` list means it must compile for iOS, macOS,
//   watchOS, AND visionOS. So you CANNOT sneak platform-only UI into it without
//   breaking a build — the share/adapt line stops being a convention you might
//   violate and becomes a boundary the compiler enforces. And because the
//   domain logic is the SAME compiled code on every platform, testing it once
//   tests it for all of them; you don't re-test `recent()` per platform.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Forgot `public`? Across a package boundary, types/inits/funcs default to
//   `internal` and are invisible to the app targets. The model, its init, and
//   every domain function that a shell calls must be `public`.
//
// - `swift test` builds for the HOST platform (your Mac). The `platforms:` list
//   declares INTENT and gates which OS versions; to truly build for watchOS you
//   add the package to a watchOS app target in Xcode. The discipline (no UIKit)
//   is what guarantees it'll compile there.
//
// - `localizedCaseInsensitiveContains` is Foundation, available everywhere —
//   that's why search can live in the core. A UIKit-based search highlight,
//   by contrast, would be shell.
//
// - If you make `Note` a real `@Model`, `import SwiftData` — it's available on
//   all four platforms, so it's still legitimately "core." Just never import a
//   UI framework.
//
// ----------------------------------------------------------------------------
