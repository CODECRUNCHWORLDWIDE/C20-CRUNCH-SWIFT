// Exercise 2 — XCUITest with a page object
//
// Goal: Drive the real add-note flow through the UI the ROBUST way: query by
//       accessibility identifier (not visible label), wait for elements with
//       waitForExistence, launch into deterministic state, and wrap each screen
//       in a page object so the test reads like a script and survives UI changes.
//
// Estimated time: 55 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into your Hello, Notes UI-TEST target (XCUITest is XCTest-based). You must
// ALSO add accessibility identifiers in the APP (shown at the bottom) and have the
// app honour a `-uitest-reset` launch argument to start from an empty store.
//
//   1. Add accessibilityIdentifier(...) to the app's add button, title field,
//      save button, and rows (see the APP-SIDE block at the bottom).
//   2. Make the app reset its store when launched with `-uitest-reset`.
//   3. Add this file to the UI-test target. Run with Cmd-U.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] Queries elements by accessibilityIdentifier, never by visible text.
//   [ ] Uses waitForExistence(timeout:) before asserting/interacting.
//   [ ] Launches with an argument that resets to deterministic state.
//   [ ] A page object (NotesListScreen / NoteEditorScreen) wraps the elements;
//       the test body reads like a user story.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import XCTest

// ----------------------------------------------------------------------------
// Page objects: each screen's elements + actions in one place. A UI change is
// fixed HERE, once, not across every test.
// ----------------------------------------------------------------------------

struct NotesListScreen {
    let app: XCUIApplication

    var addButton: XCUIElement { app.buttons["add-note-button"] }

    func row(titled title: String) -> XCUIElement {
        app.staticTexts["note-row-title-\(title)"]
    }

    @discardableResult
    func tapAdd() -> NoteEditorScreen {
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button never appeared")
        addButton.tap()
        return NoteEditorScreen(app: app)
    }

    func assertRowExists(titled title: String, timeout: TimeInterval = 5) {
        XCTAssertTrue(row(titled: title).waitForExistence(timeout: timeout),
                      "Expected a row titled \(title)")
    }
}

struct NoteEditorScreen {
    let app: XCUIApplication

    var titleField: XCUIElement { app.textFields["note-title-field"] }
    var saveButton: XCUIElement { app.buttons["save-note-button"] }

    @discardableResult
    func typeTitle(_ text: String) -> NoteEditorScreen {
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field never appeared")
        titleField.tap()
        titleField.typeText(text)
        return self
    }

    @discardableResult
    func save() -> NotesListScreen {
        saveButton.tap()
        return NotesListScreen(app: app)
    }
}

// ----------------------------------------------------------------------------
// The test — reads like a user story because the page objects hide the queries.
// ----------------------------------------------------------------------------

final class AddNoteUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false   // stop at the first failure; a broken flow cascades
    }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]   // deterministic: start from empty store
        app.launch()
        return app
    }

    func testUserCanAddANote() {
        let app = launchedApp()
        let list = NotesListScreen(app: app)

        list.tapAdd()
            .typeTitle("Buy milk")
            .save()

        list.assertRowExists(titled: "Buy milk")
    }

    func testAddingTwoNotesShowsBoth() {
        let app = launchedApp()
        let list = NotesListScreen(app: app)

        list.tapAdd().typeTitle("Groceries").save()
        list.tapAdd().typeTitle("Standup").save()

        list.assertRowExists(titled: "Groceries")
        list.assertRowExists(titled: "Standup")
    }
}

// ----------------------------------------------------------------------------
// APP-SIDE (add these in the app target, NOT here):
//
//   // In the notes list view:
//   Button("Add", systemImage: "plus", action: addNote)
//       .accessibilityIdentifier("add-note-button")
//
//   // In the editor:
//   TextField("Title", text: $title)
//       .accessibilityIdentifier("note-title-field")
//   Button("Save", action: save)
//       .accessibilityIdentifier("save-note-button")
//
//   // On each row's title text:
//   Text(note.title)
//       .accessibilityIdentifier("note-row-title-\(note.title)")
//
//   // Reset to deterministic state when launched for UI tests:
//   @main struct HelloNotesApp: App {
//       init() {
//           if CommandLine.arguments.contains("-uitest-reset") {
//               // Use an in-memory container, or wipe the store, so every UI-test
//               // run starts from a known empty state.
//               AppConfig.useInMemoryStore = true
//           }
//       }
//       ...
//   }
//
// ----------------------------------------------------------------------------
// WHY query by identifier and wait, not by label (write it before reading):
//
//   Visible labels are localised and change with copy edits, so a query by label
//   breaks the test for a NON-bug. A stable accessibilityIdentifier is contract,
//   not copy. And the UI is asynchronous: an element may not exist the instant you
//   query it, so asserting .exists immediately flakes — waitForExistence polls
//   until it appears (or the timeout). Identifier + wait = a test that fails ONLY
//   when the app is actually broken.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Element "not found": you queried the wrong collection (buttons vs staticTexts
//   vs textFields) or the identifier doesn't match. Use the Accessibility Inspector
//   or `po app.debugDescription` in the debugger to see the real tree.
//
// - Test flakes intermittently: you skipped waitForExistence somewhere and the UI
//   hadn't settled. Every first touch of a screen should wait.
//
// - Notes from a previous run leak in: the app isn't honouring -uitest-reset.
//   Confirm the launch argument resets to an empty/in-memory store.
//
// - typeText does nothing: the field wasn't focused. tap() it first, then typeText.
//
// - The test is slow: that's XCUITest — a launch per test. Keep UI tests FEW
//   (critical journeys only); push permutations into Swift Testing (exercise 1).
//
// ----------------------------------------------------------------------------
