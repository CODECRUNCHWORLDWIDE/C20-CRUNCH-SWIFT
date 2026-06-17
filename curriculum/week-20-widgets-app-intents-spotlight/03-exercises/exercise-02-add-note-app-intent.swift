// Exercise 2 — An AddNote App Intent + App Shortcut
//
// Goal: Write an AppIntent whose perform() inserts a Note into the SHARED
//       App Group store (the same one the widget reads in exercise 1), register
//       an AppShortcut so it works in Siri/Shortcuts with zero user setup, and
//       reload the widget after the write so the Home Screen reflects it.
//
//       The lesson: an intent runs OFF your app's process, on the system's
//       schedule, possibly while the app is terminated — so it must construct
//       its own store access and pass back only Sendable values.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop this into your Hello, Notes APP target (App Intents compile into the app;
// you do NOT need a separate intents extension — that's the legacy world). It
// reuses the `AppGroup` constant and the `Note` @Model from exercise 1.
//
//   1. Add this file to the app target.
//   2. Build and run the app once.
//   3. Open the SHORTCUTS app in the Simulator -> find "Hello Notes" ->
//      run "Add Note" -> type some text -> confirm a row appears in the app
//      and the widget total ticks up.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] AddNote.perform() inserts into the App Group store, NOT a captured
//       app singleton.
//   [ ] An AppShortcutsProvider registers "Add a note in Hello Notes" and friends
//       (every phrase contains \(.applicationName)).
//   [ ] After perform(), WidgetCenter.shared.reloadTimelines is called.
//   [ ] Running the shortcut adds a note that survives and shows in the app.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import AppIntents
import SwiftData
import WidgetKit
import Foundation

// ----------------------------------------------------------------------------
// A small store accessor the intent uses. Constructed FRESH inside the intent,
// pointed at the shared App Group store — never a captured app-process singleton.
// ----------------------------------------------------------------------------

enum IntentStore {
    @MainActor
    static func addNote(text: String, pinned: Bool) throws -> String {
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Title is the first line; body is the rest (a tiny, real product decision).
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        let note = Note(title: firstLine, body: trimmed)
        // If your Note has an `isPinned` field (mini-project V2), set it here.
        context.insert(note)
        try context.save()
        return note.title   // a Sendable String, never the model object
    }
}

// ----------------------------------------------------------------------------
// The intent. A verb the whole system can invoke.
// ----------------------------------------------------------------------------

struct AddNote: AppIntent {
    static let title: LocalizedStringResource = "Add Note"
    static let description = IntentDescription("Creates a new note with the text you provide.")

    @Parameter(title: "Text", requestValueDialog: "What should the note say?")
    var text: String

    @Parameter(title: "Pinned", default: false)
    var pinned: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add note saying \(\.$text)") {
            \.$pinned
        }
    }

    // @MainActor because our IntentStore access is main-actor isolated. The work
    // is fast (one insert + save), which is what an interactive/Siri intent wants.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = try IntentStore.addNote(text: text, pinned: pinned)
        // Tell WidgetKit the data moved so the Home Screen widget refreshes.
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentNoteWidget")
        return .result(dialog: "Added a note: \(title).")
    }
}

// ----------------------------------------------------------------------------
// A read-only intent too, so you feel the difference between an action and a query.
// ----------------------------------------------------------------------------

struct ShowNoteCount: AppIntent {
    static let title: LocalizedStringResource = "Show Note Count"
    static let description = IntentDescription("Tells you how many notes you have.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let count = try context.fetchCount(FetchDescriptor<Note>())  // SELECT COUNT(*), no objects
        return .result(dialog: count == 1 ? "You have 1 note." : "You have \(count) notes.")
    }
}

// ----------------------------------------------------------------------------
// App Shortcuts: pre-package the intents with Siri phrases, zero user setup.
// EVERY phrase must contain \(.applicationName) or Siri won't route to you.
// ----------------------------------------------------------------------------

struct NotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNote(),
            phrases: [
                "Add a note in \(.applicationName)",
                "Make a note in \(.applicationName)",
                "New \(.applicationName) note"
            ],
            shortTitle: "Add Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: ShowNoteCount(),
            phrases: [
                "How many notes do I have in \(.applicationName)",
                "\(.applicationName) note count"
            ],
            shortTitle: "Note Count",
            systemImageName: "number"
        )
    }
}

// ----------------------------------------------------------------------------
// WHY perform() constructs its own store (write before reading):
//
//   When Siri or an interactive widget invokes AddNote, your app may be fully
//   TERMINATED. There is no AppState.shared, no @Environment modelContext, no
//   running main actor of your UI. iOS spins up a tiny context, runs perform(),
//   tears it down. So the intent must open the shared App Group store itself and
//   return only a Sendable String. Capturing an app singleton would crash (or be
//   nil) in exactly the case the intent is most useful: app closed, Siri asked.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Shortcut doesn't appear in the Shortcuts app: build and RUN the app once so
//   the system registers the AppShortcutsProvider. It can take a few seconds; pull
//   to refresh the gallery. A clean build + relaunch usually surfaces it.
//
// - Siri says it can't find the action: a phrase is missing \(.applicationName).
//   That token is the anchor Siri uses to route to your app. No exceptions.
//
// - "Type 'AddNote' does not conform to 'AppIntent'": you likely forgot the
//   static `title` (it's required) or the return type of perform() isn't an
//   IntentResult. `some IntentResult & ProvidesDialog` is the minimum here.
//
// - Strict-concurrency error capturing the container/context across the actor:
//   keep all the SwiftData work inside the @MainActor perform() (or a @MainActor
//   helper like IntentStore). Don't Task.detached out of it. The container is
//   Sendable; the context and Note are not.
//
// - The added note doesn't show in the running app: the app and the intent must
//   point at the SAME AppGroup.storeURL. If the app still uses the default store
//   (exercise 1 step 3 not done), the intent writes to a different file.
//
// ----------------------------------------------------------------------------
