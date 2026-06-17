// Exercise 3 — Spotlight indexing + deep-link routing
//
// Goal: Index your notes into Core Spotlight so a Home Screen search finds them,
//       keep the index in sync when a note is deleted (no ghost results), and
//       route a tapped result into your navigation stack via the
//       CSSearchableItemActionType activity continuation.
//
//       The lesson: every off-process entry point — a Spotlight tap, a widget
//       tap, a deep link — funnels into the SAME navigation-as-state machinery
//       you built in Week 9. A new entry point is a new `path.append`, not a new
//       navigation system.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// Drop into your Hello, Notes APP target. It indexes the SwiftData notes and
// wires the continuation into a NavigationStack. Run it in the Simulator, add
// notes, then SEARCH from the Home Screen (swipe down) for a note's text, tap
// the result, and land on that note.
//
//   1. Add to the app target.
//   2. Call NoteSpotlight.reindexAll(...) after the store loads (e.g. in .task).
//   3. Add/delete notes; search Spotlight; tap a result; confirm you deep-link.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] Notes are indexed with a routable uniqueIdentifier derived from the
//       note's persistent identity.
//   [ ] Deleting a note de-indexes it (deleteSearchableItems).
//   [ ] onContinueUserActivity(CSSearchableItemActionType) routes the tapped
//       result into the navigation stack and lands on the correct note.
//   [ ] You can explain why the uniqueIdentifier must be stable and routable.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import SwiftUI
import SwiftData
import CoreSpotlight
import UniformTypeIdentifiers

// ----------------------------------------------------------------------------
// A stable, routable Spotlight id for a Note. We use the SwiftData persistent id
// encoded to a string; round-tripping it lets us re-fetch the exact note on tap.
// ----------------------------------------------------------------------------

extension Note {
    /// A stable string id for Spotlight. Stored explicitly so it survives launches.
    var spotlightID: String {
        // Use your own stable key. If your @Model has a `var uid: UUID` field,
        // prefer that. Here we derive from the persistent model id's URI.
        persistentModelID.storeIdentifier.map { "\($0)" } ?? "\(ObjectIdentifier(self))"
    }
}

// ----------------------------------------------------------------------------
// Indexing: write notes into Core Spotlight; remove them on delete.
// ----------------------------------------------------------------------------

enum NoteSpotlight {

    static let domain = "notes"

    /// Index (or re-index) a batch of notes. Call on add/edit and at launch.
    static func index(_ notes: [Note]) async throws {
        let items = notes.map { note -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = note.title
            attributes.contentDescription = note.body
            // Add tag names as keywords if your model has tags (mini-project).
            // attributes.keywords = note.tags.map(\.name)

            let item = CSSearchableItem(
                uniqueIdentifier: note.spotlightID,
                domainIdentifier: domain,
                attributeSet: attributes
            )
            item.expirationDate = .distantFuture
            return item
        }
        try await CSSearchableIndex.default().indexSearchableItems(items)
    }

    /// Remove a single note from the index (call on delete) so it can't ghost.
    static func deindex(id: String) async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id])
    }

    /// Convenience: reindex everything from the store. Cheap for hundreds of notes.
    @MainActor
    static func reindexAll(in context: ModelContext) async throws {
        let notes = try context.fetch(FetchDescriptor<Note>())
        try await index(notes)
    }
}

// ----------------------------------------------------------------------------
// Routing: a tapped Spotlight result arrives as an NSUserActivity. Resolve the
// uniqueIdentifier back to a Note and push it onto the navigation path.
// ----------------------------------------------------------------------------

struct SpotlightRoutedNotesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading) {
                        Text(note.title).font(.headline)
                        Text(note.body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.self) { NoteDetail(note: $0) }
        }
        .task {
            // Keep the index fresh whenever the screen appears.
            try? await NoteSpotlight.reindexAll(in: context)
        }
        // A Spotlight tap lands here.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let match = notes.first(where: { $0.spotlightID == id })
            else { return }
            path.append(match)   // route into the SAME stack a NavigationLink uses
        }
    }
}

struct NoteDetail: View {
    @Bindable var note: Note
    var body: some View {
        Form {
            TextField("Title", text: $note.title)
            TextField("Body", text: $note.body, axis: .vertical)
        }
        .navigationTitle(note.title)
    }
}

// ----------------------------------------------------------------------------
// A delete that also de-indexes, so Spotlight never shows a ghost result.
// ----------------------------------------------------------------------------

@MainActor
func deleteNote(_ note: Note, in context: ModelContext) async {
    let id = note.spotlightID
    context.delete(note)
    try? context.save()
    try? await NoteSpotlight.deindex(id: id)   // index stays in sync with the store
}

// ----------------------------------------------------------------------------
// WHY the uniqueIdentifier must be stable and routable (write it before reading):
//
//   The uniqueIdentifier you index is EXACTLY what iOS hands back in the activity
//   when the user taps the result. If it isn't stable across launches, the id in
//   the index won't match any note next time and the tap lands nowhere. If it
//   isn't routable — i.e. you can't turn it back into a specific note — you can't
//   deep-link. So derive it from the note's persistent identity (a UUID field is
//   cleanest), use the SAME derivation when indexing and when resolving the tap,
//   and de-index on delete so a stale id can't survive the note it pointed at.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - Nothing appears in Spotlight search: indexing is async and the system needs a
//   moment. Make sure reindexAll actually ran (put a Logger line in it) and search
//   for text that's in a note's title or body. Force-quit and relaunch; the index
//   persists across launches.
//
// - Tap opens the app but lands on the list, not the note: the continuation isn't
//   firing or the id doesn't match. Confirm onContinueUserActivity uses
//   `CSSearchableItemActionType` (not a custom type) and that spotlightID is
//   computed the SAME way at index time and resolve time.
//
// - Deleted notes still show in Spotlight: you didn't de-index. Every delete path
//   must call NoteSpotlight.deindex(id:). Use the deleteNote helper above.
//
// - If your @Model lacks a stable UUID, ADD ONE (`var uid = UUID()`), index by it,
//   and resolve by it. persistentModelID.storeIdentifier works but a real UUID
//   field is the cleaner, recommended approach for routing.
//
// - On iOS 18 you can instead make Note's AppEntity conform to IndexedEntity and
//   let App Intents index it for you. Doing it explicitly with CSSearchableIndex
//   first (as here) teaches what that bridge automates.
//
// ----------------------------------------------------------------------------
