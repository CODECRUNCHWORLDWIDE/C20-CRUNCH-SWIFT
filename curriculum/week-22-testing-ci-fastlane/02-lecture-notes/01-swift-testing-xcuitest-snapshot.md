# Lecture 1 — Testing at scale: Swift Testing, XCUITest, and snapshots

> "A test you don't trust is worse than no test, because a red build you've learned to ignore trains the whole team to ignore red builds. The job this week is tests worth running — at three layers, each catching a class of bug the others can't."

This is the lecture that decides whether your CI net catches bugs or just burns runner minutes. The framing for the week: **three test layers, each with a distinct job.** **Swift Testing** for logic — fast, isolated, hundreds of them. **XCUITest** for the user-facing flows a unit test can't reach — slow, few, high-value. **Snapshot tests** for the *rendering* of SwiftUI views — because "the layout broke" is a regression no view-model assertion catches. Use the wrong layer and you get a slow, flaky suite that tests the wrong things. Use them right and a failing test points straight at the bug.

We build it bottom-up: Swift Testing first (the foundation, the default in 2026), then XCUITest (the expensive top), then snapshots (the rendering contract in the middle), then how the three compose into a suite a senior engineer trusts.

---

## 1. Swift Testing — the default for new tests in 2026

Swift Testing shipped with Xcode 16 and is now the default framework for new test targets. It is not "XCTest with nicer syntax"; it is a ground-up redesign around Swift Concurrency, macros, and parallelism. The minimum:

```swift
import Testing
@testable import HelloNotes

@Test func newNoteHasTrimmedTitle() {
    let note = Note(title: "  Groceries  ")
    #expect(note.title == "Groceries")
}
```

Three things are already different from XCTest:

- **`@Test`** marks a function as a test — it can be free-standing (no class), `async`, and `throws`. No `XCTestCase` subclass, no `test` prefix.
- **`#expect`** is the universal assertion. It is a macro, so on failure it shows you the *actual values*: `#expect(a == b)` failing prints `a → 3, b → 4`, not a bare "assertion failed." One macro replaces the whole `XCTAssertEqual`/`XCTAssertTrue`/`XCTAssertNil` zoo.
- **Tests run in parallel by default**, in randomised order, isolated. This surfaces hidden inter-test dependencies XCTest's serial default hid — and makes a big suite fast.

### `#expect` vs `#require`

`#expect` records a failure and **keeps going** — good for checking several independent things in one test. `#require` records a failure and **stops the test** (it `throws`), so use it when continuing makes no sense — typically unwrapping:

```swift
@Test func decodesNote() throws {
    let data = try #require(sampleJSON.data(using: .utf8))   // stop if nil; unwraps non-optionally
    let note = try JSONDecoder().decode(Note.self, from: data)
    #expect(note.title == "Groceries")                        // keep going to check more
    #expect(note.body.isEmpty == false)
}
```

`try #require(optional)` is the idiom that replaces `XCTUnwrap` — it unwraps and fails-fast if nil, so the rest of the test can use a non-optional value.

### Parameterized tests — one test, many inputs

This is where Swift Testing leaves XCTest behind. Instead of a `for` loop (which reports as one test and stops at the first failure) or six near-identical methods, you pass `arguments:`:

```swift
@Test(arguments: [
    ("  hi ", "hi"),
    ("Groceries", "Groceries"),
    ("\nstandup\n", "standup"),
    ("", ""),
])
func titleIsTrimmed(input: String, expected: String) {
    #expect(Note(title: input).title == expected)
}
```

Each argument runs as a **separate, independently-reported test case** — four green/red dots, run in parallel, each failure pointing at its own input. You can zip two collections (`arguments: zip(inputs, expected)`) or take the cross product of two (`arguments: topics, sortOrders`). Parameterized tests turn "I should test more cases" from tedious into trivial, which means you actually do it.

### Suites and tags — organising at scale

`@Suite` groups related tests (and can carry shared setup via `init`/`deinit` as `async`/`throws`). **Tags** let you slice the suite across files — run "just the fast ones" on every PR, "the slow ones" nightly:

```swift
extension Tag {
    @Tag static var persistence: Self
    @Tag static var slow: Self
}

@Suite("Note store", .tags(.persistence))
struct NoteStoreTests {
    let context: ModelContext

    init() throws {
        // Per-test fresh in-memory store (Week 10) — fast, isolated.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        context = ModelContext(container)
    }

    @Test func insertThenFetch() throws {
        context.insert(Note(title: "Groceries"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
    }

    @Test(.tags(.slow)) func bulkInsert() throws {
        for i in 0..<10_000 { context.insert(Note(title: "n\(i)")) }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 10_000)
    }
}
```

On CI you can then run `--filter-tag persistence` or skip `slow` on PRs. The `init`/`deinit` replace `setUp`/`tearDown` and run **per test instance**, which (combined with parallel execution) is why each test gets a fresh, isolated store — exactly the `isStoredInMemoryOnly` discipline from Week 10, now structural.

### async, throws, and known issues

Tests are `async`/`throws` first-class, so testing your actors and `async` APIs is natural:

```swift
@Test func importerAddsNotes() async throws {
    let importer = NoteImporter(modelContainer: testContainer)   // @ModelActor from Week 10
    let n = try await importer.importTitles(["a", "b", "c"])
    #expect(n == 3)
}
```

And when a test fails *for a known reason* you haven't fixed yet, `withKnownIssue` records it without going red — so the suite stays green and the known failure is tracked, not ignored:

```swift
@Test func knownLayoutBug() {
    withKnownIssue("Re-enable after fixing the iPad split bug (#412)") {
        #expect(computeColumns(for: .pad) == 3)   // currently returns 2
    }
}
```

### XCTest still exists, and that's fine

You do **not** rip out XCTest. The two frameworks coexist in one test target and one scheme. XCTest remains for legacy suites, for `XCUITest` (UI tests are still XCTest-based), and for `measure { }` performance tests Swift Testing doesn't yet cover. The rule: **new logic tests in Swift Testing; keep XCTest where it's already working or where it's the only API.** They run side by side.

---

## 2. XCUITest — the expensive layer, used sparingly

XCUITest drives the *real app* through the accessibility layer — taps, types, scrolls — in a launched process on a simulator. It is the only layer that proves "a user can actually add a note end to end." It is also **slow** (a launch per test) and **flaky** if written carelessly. So you write *few* of them, covering the critical user journeys, and you write them *robustly*.

```swift
import XCTest

final class AddNoteUITests: XCTestCase {
    func testUserCanAddANote() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]   // deterministic: start from empty store
        app.launch()

        app.buttons["add-note-button"].tap()                 // by accessibilityIdentifier, not label
        let field = app.textFields["note-title-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))     // WAIT, don't assume it's there
        field.typeText("Buy milk")
        app.buttons["save-note-button"].tap()

        XCTAssertTrue(app.staticTexts["Buy milk"].waitForExistence(timeout: 5))
    }
}
```

The four rules that make UI tests trustworthy:

1. **Query by `accessibilityIdentifier`, never by visible label.** Labels are localised, change with copy edits, and break tests for non-bugs. Add stable identifiers in the app (`.accessibilityIdentifier("add-note-button")`) and query those. This is the same accessibility work from Week 16 paying a second dividend.
2. **`waitForExistence(timeout:)` everywhere.** The UI is asynchronous; an element may not exist the instant you query it. Asserting on `.exists` immediately is the number-one source of flake. Wait for it.
3. **Launch into deterministic state.** A UI test that depends on whatever notes happen to be in the simulator is non-repeatable. Pass a launch argument (`-uitest-reset`) the app reads to wipe to a known state (an in-memory store, or a cleared one), so every run starts identical.
4. **Use the page-object pattern** to keep tests readable and maintainable (next section in the exercise): wrap each screen's elements and actions in a struct, so the test reads like a script and a UI change is fixed in one place.

XCUITest is the layer you're tempted to overuse (it feels like "real" testing) and should use least — a handful of critical-path journeys, not every permutation. Permutations belong in Swift Testing, where they run in milliseconds, not seconds.

### Making the app testable for UI tests

The robustness of a UI test is half the test's job and half the *app's* cooperation. Two app-side affordances pay off enormously:

```swift
// 1. Stable identifiers on every element a test will touch.
Button("Add", systemImage: "plus", action: addNote)
    .accessibilityIdentifier("add-note-button")

// 2. A launch-argument-driven reset to deterministic state.
@main
struct HelloNotesApp: App {
    init() {
        if CommandLine.arguments.contains("-uitest-reset") {
            // Use an in-memory store so every UI-test run starts from a known empty state.
            // (No disk writes; nothing leaks between runs.)
            AppConfig.useInMemoryStore = true
        }
        if CommandLine.arguments.contains("-uitest-seed") {
            AppConfig.seedFixtures = true     // a known set of notes for read-path tests
        }
    }
    // ...
}
```

The launch arguments are a *contract between the test and the app*: the test launches with `-uitest-reset` (or `-uitest-seed`) and the app honours it by configuring deterministic state before the first frame. This is what makes a UI test repeatable — it never depends on "whatever happens to be in the simulator." You can extend the contract with `launchEnvironment` to pass values (a base URL pointing at a stubbed server, a feature flag), so the same app binary runs against a controlled world during tests. An app with no such hooks is an app whose UI tests flake on leftover state; a few well-placed launch arguments turn flaky into deterministic.

A second robustness trick: disable animations during UI tests (`UIView.setAnimationsEnabled(false)` behind a launch flag) so the test isn't racing a transition. Animations are lovely for users and a source of timing flake for tests; turning them off under the test flag removes a whole class of "the element existed but wasn't hittable yet" failures.

---

## 3. Snapshot testing — the rendering contract

Between logic (Swift Testing) and full UI (XCUITest) sits a gap: a SwiftUI view can have correct *data* and *broken layout* — clipped text, a misaligned stack, a colour that regressed, a Dynamic Type size that overflows. No view-model assertion catches that, and an XCUITest checking "the text exists" passes even when it's rendered off-screen. **Snapshot tests** close the gap: they render a view to an image, compare it pixel-by-pixel to a recorded reference, and fail on any visual change.

Using `pointfreeco/swift-snapshot-testing`:

```swift
import SnapshotTesting
import SwiftUI
import XCTest
@testable import HelloNotes

final class NoteRowSnapshotTests: XCTestCase {
    func testNoteRow_default() {
        let view = NoteRow(note: Note(title: "Groceries", body: "milk, eggs"))
            .frame(width: 320)
        assertSnapshot(of: view, as: .image)
    }

    func testNoteRow_accessibilityXXXL() {
        let view = NoteRow(note: Note(title: "Groceries", body: "milk, eggs"))
            .frame(width: 320)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        assertSnapshot(of: view, as: .image)   // proves it doesn't clip at the largest Dynamic Type
    }
}
```

How it works and the rules:

- **Record once, verify forever.** The first run (in *record mode*) captures the reference image to disk (committed to Git, under `__Snapshots__`). Every subsequent run renders again and diffs against it. A diff = a test failure with a side-by-side image of what changed.
- **Record mode is deliberate.** You enable recording (`withSnapshotTesting(record: .all)` or per-assertion) *only* when you've intentionally changed the UI and want to re-baseline. Accidentally leaving record mode on makes every test pass trivially — the snapshot-testing equivalent of `XCTAssert(true)`. Review reference-image diffs in PRs like any other change.
- **Pin the environment.** Snapshots are sensitive to device, scale, OS version, and traits. Pin a fixed size/trait (`.frame`, `.environment(\.sizeCategory, …)`) and run them on a **fixed simulator** on CI, or the same view "changes" between a contributor's M3 and the runner. Variant snapshots (light/dark, Dynamic Type sizes, iPhone/iPad) are how you prove the layout holds across the matrix that matters.

Snapshot tests are where you catch "someone added a modifier and the title now truncates at XXXL" — a real, shippable regression that is invisible to every other layer. They are cheap to write and worth their weight for any view whose layout is a contract.

### Testability is a design property, not an afterthought

The reason your tests are fast and reliable is mostly decided *before* you write them — in how the app is built. Two habits make a codebase testable:

- **Inject dependencies; don't reach for singletons.** A view model that constructs its own `URLSession.shared` and `ModelContainer` is hard to test — you can't substitute a fake network or an in-memory store. One that takes them in its initializer (the Week 11 architecture work) is trivial to test: pass a stub client and an `isStoredInMemoryOnly` container. The Week 10 in-memory-store discipline and the Week 13 protocol-backed networking client both exist *partly* so this week is easy.
- **Test the seam, not the implementation.** Assert on the *behaviour a caller observes* — "after `addNote`, the store has one row," "after a 500 response, the client retries twice and then surfaces a typed error" — not on private internals. Tests coupled to implementation details break on every refactor and train people to delete them. Tests coupled to behaviour survive refactors and catch real regressions.

A test data builder keeps this clean:

```swift
extension Note {
    static func fixture(title: String = "Test", body: String = "", pinned: Bool = false) -> Note {
        Note(title: title, body: body, isPinned: pinned)
    }
}

@Test func pinnedNotesSortFirst() {
    let notes = [.fixture(title: "a"), .fixture(title: "b", pinned: true)]
    #expect(notes.sortedPinnedFirst().first?.title == "b")
}
```

The `fixture` builder gives every test a one-line way to make exactly the object it needs, with sensible defaults — so tests stay short and read like the scenario they describe, not like object-graph assembly. Small thing; large effect on whether people keep the suite alive.

### Running the right subset at the right time — test plans

A big suite has fast logic tests (run on every PR) and slow UI/integration tests (run nightly). **Test plans** (`.xctestplan` files) let one scheme define multiple configurations — "PR" (logic + snapshots, skip the `.slow` tag and the UI target) and "nightly" (everything). On CI you select the plan with `-testPlan`:

```bash
xcodebuild test -scheme HelloNotes -testPlan PR \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' | xcbeautify
```

This is how you keep the PR gate under a few minutes (so people don't route around it) while still running the expensive coverage on a schedule. The anti-pattern is one giant configuration that runs everything on every commit — it's so slow that people merge before it finishes, which defeats the gate. Split by speed, gate on the fast core, schedule the rest.

---

## 4. Composing the three layers into a suite you trust

The three layers aren't alternatives; they're a pyramid:

```text
        /\         XCUITest — few, critical user journeys (slow, high-value)
       /  \        add-a-note, sign-in, purchase, the deep-link route
      /----\
     /      \      Snapshot — view rendering contracts (medium count)
    /        \     each important view × {light/dark, default/XXXL Dynamic Type}
   /----------\
  /            \   Swift Testing — logic, hundreds, fast & parallel
 /______________\  trimming, predicates, migrations, view-model state, importers
```

The senior heuristics for which layer:

- **Logic, transformations, edge cases → Swift Testing.** It's fast, parallel, and parameterized — so you test the whole input space. The bulk of your tests live here.
- **"The layout/rendering is correct" → Snapshot.** Anything where *how it looks* is the contract: cells, empty states, the widget view, the Dynamic Island layout, Dynamic Type behaviour.
- **"A real user can complete this flow" → XCUITest.** The handful of journeys whose breakage means "the app is unusable." Keep this set small; each test is expensive.
- **Keep them green and fast.** A suite that takes 40 minutes or flakes 1-in-5 gets ignored. Tag the slow ones, quarantine the flaky ones (don't delete — fix or `withKnownIssue` with a tracking number), and make the PR gate run the fast, reliable core on every commit.

The anti-pattern is the inverted pyramid: a hundred slow XCUITests asserting things a Swift Testing function could check in a millisecond, no snapshot coverage, and a logic layer with three tests. That suite is slow, flaky, and tests the wrong things — and the team learns to merge through its red.

### Coverage is a guide, not a goal

Xcode reports code coverage, and it's a useful *map of what's untested* — but chasing a coverage *number* is a trap. 100% coverage of trivial getters proves nothing; 60% coverage that hits every branch of your sync-conflict logic and your retry policy is far more valuable. Use coverage to *find the gaps that matter* (the un-hit `catch` block in the networking layer, the migration path nobody exercised), not as a target to satisfy. A test written only to bump a percentage is a test written for the wrong reason — it'll assert something trivial, couple to an implementation detail, and break on the next refactor. Aim coverage at *risk*: the code whose failure would reach a user, the edge cases that bit you before, the paths a casual reading would miss.

### What *not* to test

Knowing what to skip keeps the suite lean:

- **Don't test the framework.** SwiftUI's `List` renders rows; SwiftData saves; `URLSession` makes requests. Apple tests those. Test *your* logic, not theirs.
- **Don't test trivial pass-throughs.** A computed property that returns a stored value, an `init` that assigns its arguments — there's no logic to break.
- **Don't write a test that can only pass.** A snapshot left in record mode, an `#expect(true)`, a UI test that waits and asserts nothing — these are green theatre that erode trust when someone notices they never fail.
- **Don't duplicate a layer.** If a Swift Testing function already proves the sort logic, don't also assert sort order in a slow XCUITest; the UI test should prove the *flow*, and trust the unit test for the *logic*.

The goal isn't maximum tests; it's maximum *signal per minute of CI*. Every test should be able to fail for a real reason, and when it fails, point at a real bug. A suite of those, sized by risk, is what a senior engineer builds — and it's what makes a red build mean something.

Concretely, a high-signal test asserts a behaviour a user (or a caller) would notice and that has real branches to get wrong:

```swift
// HIGH signal: a real branch with a real consequence.
@Test func retryThenSurfaceTypedError() async throws {
    let client = NotesClient(transport: FlakyTransport(failuresBeforeSuccess: 5)) // exceeds retry budget
    await #expect(throws: NotesError.unreachable) {
        try await client.fetchNotes()                // 3 retries, then a typed error the UI maps to a banner
    }
}

// LOW signal: tests the framework / a trivial pass-through. Delete it.
@Test func noteTitleStores() {
    #expect(Note(title: "x").title == "x")           // proves Swift assigns a stored property
}
```

The first catches a real regression (someone breaks the retry count, or swallows the error); the second can only fail if Swift itself breaks. Keep the first; never write the second.

---

## 5. Recap — three layers, each with a job

You will write all three this week and run them on CI. The discipline that makes the suite *trusted* rather than *tolerated* is matching each test to the layer that fits its job:

1. **Swift Testing is the foundation.** `@Test`/`#expect`/`#require`, parameterized `arguments:` for the whole input space, `@Suite` + tags to organise and slice, `async`/`throws` first-class, fresh in-memory stores per test. Hundreds of these, fast and parallel. The default in 2026; XCTest coexists for legacy and UI/perf APIs.
2. **XCUITest is the expensive top, used sparingly.** A few critical user journeys, driven by accessibility identifiers (not labels), waited on with `waitForExistence`, launched into deterministic state, organised with page objects. Slow and flaky if abused — so abuse it not.
3. **Snapshot testing is the rendering contract.** Render a view, diff against a committed reference image, catch layout/Dynamic-Type/dark-mode regressions nothing else sees. Record deliberately, pin the environment, review image diffs in PRs.

Underneath all three is one enabling habit from earlier weeks: **testability is a design property.** Inject dependencies instead of reaching for singletons; use the Week 10 in-memory store and the Week 11 protocol-backed seams; test the behaviour a caller observes, not the implementation. A codebase built that way makes this week easy; one that wasn't makes every test a fight against tangled state. If you find a test painful to write, that pain is usually telling you something about the *design* — the seam you wish existed is the seam the production code should have had.

And remember the negative space: coverage is a map, not a target; skip the framework, the trivial pass-throughs, the can-only-pass tests, and the duplicated layers. Maximum signal per minute of CI, sized by risk — that's the suite, not maximum green dots.

A suite built this way catches real bugs cheaply and stays green and fast — which is the only kind of suite a team keeps. Lecture 2 takes this suite and puts it on a `macos` runner: `xcodebuild` through `xcbeautify`, GitHub Actions gating every PR, and a fastlane lane that signs with `match` and ships to TestFlight. The tests are the cargo; the pipeline is the conveyor. Build good cargo first.
