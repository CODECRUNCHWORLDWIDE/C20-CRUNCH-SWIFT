# Phase II Integration Project — "Notes v1"

This is the Phase II gate. Everything from Weeks 7–12 converges here into **one polished, persistent, reactive, multi-platform SwiftUI app** that you can demo on three simulators and walk through in a code review. It is not a new app — it is the culmination of Hello, Notes: the SwiftUI you learned in Week 7, the state ownership from Week 8, the navigation from Week 9, the SwiftData persistence from Week 10, the architecture you committed to in Week 11, and the reactive debounced search you mastered this week, all assembled into something that *feels finished*.

The headline new feature this week is **search-as-you-type, debounced via `AsyncStream`** — the reactive work of Week 12 made real. But the deliverable is the whole app: full CRUD, tag filtering, deep links, dark mode, Dynamic Type, SwiftData persistence that survives cold launch with state restoration, running on iPhone + iPad + Mac, and tested with XCUITest. This is the app that goes in your portfolio as "Notes v1," and it is the foundation the entire Production iOS phase builds on.

---

## Where you're starting from

By now your Hello, Notes app has:

- A SwiftData `@Model` `Note` (and `Tag`, many-to-many) persisted on disk, surviving cold launch (Week 10).
- A `NavigationSplitView` (iPad/Mac) / `NavigationStack` (iPhone) layout with value-typed navigation and a `notes://open/:id` deep link (Week 9).
- An architecture you chose and defended in an ADR (Week 11) — plain `@Observable` MVVM is the recommended default for Notes v1's stakes, but if your Week 11 ADR chose TCA for the search feature, carry that forward.
- Light/dark mode and Dynamic Type support (Week 7).

If any of those is shaky, this week is where you firm it up — the integration project is graded on the *whole* surviving together, not on new code in isolation.

## What "Notes v1" must be

A reviewer running your app on three simulators should see:

1. **Full CRUD** — create, read, update, delete notes, persisted in SwiftData, surviving a force-quit relaunch.
2. **Tag filtering** — pick a tag, see only its notes (the dynamic `#Predicate` from Week 10).
3. **Search-as-you-type** — a debounced (`AsyncStream`, ~300 ms) search over title and body that fires once per typing burst, never per keystroke, and composes with the tag filter.
4. **Deep links** — `notes://open/:id` opens any note from a cold launch (Week 9).
5. **State restoration** — kill the app mid-navigation (a note open, a tag selected, a search active) and on relaunch it restores where you were.
6. **Multi-platform** — iPhone (stack), iPad and Mac (sidebar-detail), all from one codebase, all correct.
7. **Dark mode + Dynamic Type** — correct at the largest accessibility text size and in dark mode.
8. **XCUITest** — at least one UI test that types into search and asserts the debounced result, and one that creates a note and asserts it persists.

---

## Milestone 1 — The reactive search model (≈ 2.5 h)

The new feature. Build the debounced search as an `@Observable @MainActor` model fed by an `AsyncStream`, consumed in a `.task` (lecture 2, §3–5). This is the Week 12 work made real against the SwiftData store.

```swift
import SwiftUI
import SwiftData

@Observable
@MainActor
final class NotesSearchModel {
    var query = "" {
        didSet { continuation?.yield(query) }
    }
    var selectedTag: String?
    private(set) var results: [Note] = []
    private(set) var isSearching = false

    private var continuation: AsyncStream<String>.Continuation?
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Drive from .task in the view; the loop's lifetime is the view's.
    func observe() async {
        let stream = AsyncStream<String>(bufferingPolicy: .bufferingNewest(1)) { cont in
            self.continuation = cont
            cont.onTermination = { _ in Task { @MainActor in self.continuation = nil } }
        }

        var debounceTask: Task<Void, Never>?
        for await q in stream {
            debounceTask?.cancel()
            debounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                await self.runSearch(q)
            }
        }
    }

    func tagChanged() {
        // Re-run with the current query when the tag filter changes.
        continuation?.yield(query)
    }

    private func runSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        let tag = selectedTag
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        // The filter runs IN SQLITE via #Predicate (Week 10), not in memory.
        let predicate: Predicate<Note>
        if trimmed.isEmpty, let tag {
            predicate = #Predicate { note in note.tags.contains { $0.name == tag } }
        } else if trimmed.isEmpty {
            predicate = #Predicate { _ in true }
        } else if let tag {
            predicate = #Predicate { note in
                (note.title.localizedStandardContains(trimmed)
                 || note.body.localizedStandardContains(trimmed))
                && note.tags.contains { $0.name == tag }
            }
        } else {
            predicate = #Predicate { note in
                note.title.localizedStandardContains(trimmed)
                || note.body.localizedStandardContains(trimmed)
            }
        }
        let descriptor = FetchDescriptor<Note>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        results = (try? context.fetch(descriptor)) ?? []
    }
}
```

The view drives it with `.task` and binds the inputs:

```swift
struct SearchableNotesView: View {
    @Environment(\.modelContext) private var context
    @State private var model: NotesSearchModel?
    let allTags: [String]

    var body: some View {
        Group {
            if let model {
                List(model.results) { note in
                    NavigationLink(value: note) { NoteRow(note: note) }
                }
                .searchable(text: Binding(get: { model.query }, set: { model.query = $0 }))
                .overlay {
                    if model.isSearching { ProgressView() }
                    else if model.results.isEmpty {
                        ContentUnavailableView("No matches", systemImage: "magnifyingglass")
                    }
                }
                .task { await model.observe() }   // structural lifetime
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if model == nil { model = NotesSearchModel(context: context) }
        }
    }
}
```

Note the choices: `.bufferingNewest(1)` (only the latest keystroke matters), debounce by cancelling a per-keystroke task (structural cancellation, no `AnyCancellable`), and the filter pushed into SQLite via `#Predicate` (Week 10's footgun lesson — never fetch-all-then-filter). This is every Phase II lesson firing at once.

## Milestone 2 — Compose search with the tag filter (≈ 1 h)

Wire the tag chips (Week 10) to set `model.selectedTag` and call `model.tagChanged()`, so the search re-runs with the new tag. Search and tag must *compose* — both constraints apply — which the predicate above already handles. Confirm by selecting a tag, then typing: the results narrow on both axes. This is the `combineLatest` composition from lecture 1, done the async way (re-yielding the current query when the tag changes).

## Milestone 3 — State restoration across cold launch (≈ 1.5 h)

The "where was I?" promise. Persist the navigation and filter state so a kill-and-relaunch restores it:

```swift
struct ContentView: View {
    @SceneStorage("navPath") private var navPathData: Data?
    @SceneStorage("selectedTag") private var selectedTag: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SearchableNotesView(allTags: /* ... */ [])
                .navigationDestination(for: Note.self) { NoteDetailView(note: $0) }
        }
        .onChange(of: path) { _, newPath in
            navPathData = try? JSONEncoder().encode(newPath.codable)
        }
        .task {
            if let data = navPathData,
               let codable = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) {
                path = NavigationPath(codable)
            }
        }
    }
}
```

`@SceneStorage` persists per-scene UI state across cold launch (Week 9). Encode the `NavigationPath` (value-typed navigation makes it `Codable` — Week 9's payoff) and the selected tag, restore on launch. Now: open a note, select a tag, force-quit, relaunch — and you are back where you were. (Note: SwiftData model identity persists; the `NavigationPath` stores the note's value/hash, so restoration re-resolves it against the store.)

## Milestone 4 — Multi-platform polish (≈ 1.5 h)

One codebase, three platforms. Use `NavigationSplitView` on iPad/Mac (sidebar of tags, content list, detail) and `NavigationStack` on iPhone, switching on size class:

```swift
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            NavigationStack { /* iPhone stack */ }
        } else {
            NavigationSplitView { /* sidebar */ } content: { /* list */ } detail: { /* detail */ }
        }
    }
}
```

Run on iPhone SE, iPad Pro 13-inch, and "My Mac" (Designed for iPad or a native macOS target). The search, the tag filter, and the deep link must work on all three. Verify dark mode (toggle in the Simulator's Environment Overrides) and Dynamic Type at the largest setting (Settings ▸ Accessibility ▸ Display & Text Size, or the Xcode preview's Dynamic Type slider) — list cells must not truncate or overlap.

## Milestone 5 — XCUITest (≈ 1.5 h)

Prove the app works without you driving it by hand. Two UI tests minimum:

```swift
import XCTest

final class NotesV1UITests: XCTestCase {
    func testSearchDebouncesAndFilters() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-seed"]   // seed deterministic notes on launch
        app.launch()

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("swift")                  // a fast burst

        // The debounced result appears; assert a known seeded note is shown
        // and a non-matching one is not.
        XCTAssertTrue(app.staticTexts["SwiftUI layout"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Kotlin flows"].exists)
    }

    func testCreateNotePersists() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add"].tap()
        app.textFields["Title"].tap()
        app.textFields["Title"].typeText("Persisted note")
        // Navigate back, terminate, relaunch, assert it's still there.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Persisted note"].waitForExistence(timeout: 2))
    }
}
```

Add a `--uitest-seed` launch argument your app reads at startup to insert a fixed set of notes into an in-memory-or-temp store, so the UI test is deterministic and never depends on prior state. The search test is the one that *proves the reactive feature* end-to-end: type a burst, assert the right note appears and the wrong one doesn't.

## Milestone 6 — Record the demo (≈ 0.5 h)

The Phase II gate requires a recorded screen capture. Record a ~2-minute walkthrough on each of the three simulators (or one recording cycling through them): create a note, tag it, search for it (showing the debounce — type fast, one result settles), open it via the deep link from a cold launch, and show it surviving a force-quit relaunch with state restored. Put the recording (or a link) in the repo README. "It works on three platforms" is the deliverable; the recording is the evidence.

---

## Acceptance criteria (the Phase II gate)

- [ ] **Full CRUD** persisted in SwiftData, surviving a force-quit relaunch.
- [ ] **Search-as-you-type** debounced via `AsyncStream` (~300 ms, `.bufferingNewest(1)`, structural cancellation), firing **once per burst**, with the filter running in SQLite via `#Predicate` (not in-memory).
- [ ] **Search composes with the tag filter** — both constraints apply simultaneously.
- [ ] **Deep link** `notes://open/:id` opens a note from cold launch.
- [ ] **State restoration** — navigation + selected tag restore across a kill-and-relaunch (`@SceneStorage` + codable `NavigationPath`).
- [ ] **Multi-platform** — runs correctly on iPhone (stack), iPad and Mac (split view) from one codebase.
- [ ] **Dark mode + Dynamic Type** — correct at the largest text size and in dark mode; no truncation or overlap.
- [ ] **XCUITest** — at least one test asserting the debounced search result and one asserting a created note persists across relaunch.
- [ ] **An architecture you can defend** — the search lives in a view model (or reducer) per your Week 11 ADR; logic is testable, not crammed in views.
- [ ] **A recorded demo** on three simulators in the repo README.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict concurrency.

## Stretch goals

- **Combine variant behind a flag.** Wire the *same* search with a Combine `.debounce` pipeline behind a build flag, and note in the README which you shipped and why (carry the challenge's `DECISION.md` here). Demonstrating you can do both is the senior signal.
- **`swift-async-algorithms` debounce.** Replace the hand-rolled per-keystroke cancellation with the library's `.debounce(for:)` and compare line count and behaviour. Note the simplification.
- **Search highlighting.** Highlight the matched substring in the result rows (an `AttributedString` over the title/body) — a small polish that makes the search feel premium.
- **Empty-and-loading choreography.** Distinguish "no query yet" (show all/recent), "searching" (spinner), and "no matches" (ContentUnavailableView) cleanly, with no flicker between states. Reactive UIs live or die on these transitions.

## What this milestone earns you

You shipped a non-trivial SwiftUI app with persistence, navigation, architecture, multi-platform support, state restoration, and reactive debounced search — UI-tested and demo-recorded. That is the literal Phase II "skill earned": *can ship a non-trivial SwiftUI app with persistence, navigation, and reactive search.* "Notes v1" is now the first of your three portfolio apps and the foundation of Phase III. Every Production iOS week — networking, persistence II, performance, accessibility, security, push — compounds on this exact app. You did not build a toy this phase; you built the thing the rest of the track makes production-grade. Clear the gate, record the demo, and walk into Phase III with a real app in hand.

## How this rolls into Phase III

Week 13 (URLSession) wires "Notes v1" to the Vapor `notes-api` from Phase I: the local SwiftData store becomes the offline cache, the network becomes the source of truth, and your debounced search becomes search-against-a-server with the same `AsyncStream` discipline. The cancellation you proved this week is what stops a cancelled search from racing a stale server response onto the screen. Keep "Notes v1" clean — it is about to get a networking layer, a retry policy, and an offline-first write-replay queue, and a messy foundation makes all three harder.
