// Exercise 2 — Bindable sheet edit, propagates exactly once
//
// Goal: Use @Bindable to two-way bind a sheet's fields to an @Observable model,
//       and PROVE with a render counter that an edit propagates to the list cell
//       exactly once — not zero times (lost edit), not twice (storm).
//
// Estimated time: 45 minutes.
//
// HOW TO RUN THIS FILE
//
// 1. Create a fresh iOS App project in Xcode 16+ (SwiftUI, iOS 17+ deployment).
// 2. Replace the generated ContentView.swift with the contents of THIS FILE.
// 3. Set the app's root view to `ExerciseTwoRoot` (rename the generated
//    `ContentView` usage in the @main App struct to `ExerciseTwoRoot`, OR
//    just rename `ExerciseTwoRoot` below to `ContentView`).
// 4. Run on an iPhone simulator. Open the console:
//    View ▸ Debug Area ▸ Activate Console.
//
// WHAT TO DO IN THE RUNNING APP
//
//   - Tap a row. A sheet opens editing a DRAFT copy of that note.
//   - Change the title. Tap "Save". Watch the console.
//   - Reopen, change the title, tap "Cancel". Watch the console.
//
// WHAT THE CONSOLE MUST SHOW
//
//   On SAVE:   the edited row's counter ticks exactly ONCE, e.g.
//                [row <id>] render #2
//              and the onChange fires once for that row, e.g.
//                [onChange] '<old>' -> '<new>'
//              No OTHER row ticks.
//
//   On CANCEL: ZERO output. No row ticks, no onChange. The draft is discarded.
//
// ACCEPTANCE CRITERIA
//
//   [ ] The model is an @Observable final class (no @Published, no ObservableObject).
//   [ ] The sheet edits a DRAFT, not the live note — Cancel must be able to discard.
//   [ ] @Bindable is used to bind the sheet's TextFields to the DRAFT model.
//   [ ] Save commits the draft back to the store; Cancel does nothing.
//   [ ] On Save, exactly one row re-renders, exactly once (counter proves it).
//   [ ] On Cancel, zero rows re-render.
//   [ ] Build has zero warnings under iOS 17+ strict concurrency.
//
// Inline notes explain each decision. There are no TODOs — this file is complete
// and runnable. Study WHY it renders exactly once; that understanding is the
// deliverable, and the challenge formalises it.

import SwiftUI
import Observation

// ----------------------------------------------------------------------------
// Model — an @Observable reference type. Per-property tracking means a view
// re-renders only when a property it reads changes (Lecture 1, §1.4).
// ----------------------------------------------------------------------------

@Observable
final class Note: Identifiable {
    let id = UUID()
    var title: String
    var body: String

    init(title: String, body: String = "") {
        self.title = title
        self.body = body
    }
}

@Observable
final class NotesStore {
    var notes: [Note]

    init(notes: [Note]) { self.notes = notes }

    static let sample = NotesStore(notes: [
        Note(title: "Buy oat milk"),
        Note(title: "Renew passport"),
        Note(title: "Refactor the storm demo"),
    ])
}

// ----------------------------------------------------------------------------
// Render counter — a reference type OUTSIDE SwiftUI's dependency graph, so
// ticking it in `body` does not itself trigger a re-render (Lecture 2, §2.1).
// One counter per row, keyed by note id.
// ----------------------------------------------------------------------------

final class RenderCounters {
    private var counts: [UUID: Int] = [:]

    func tick(_ id: UUID) {
        counts[id, default: 0] += 1
        print("[row \(id.uuidString.prefix(4))] render #\(counts[id]!)")
    }
}

// ----------------------------------------------------------------------------
// Root + list
// ----------------------------------------------------------------------------

struct ExerciseTwoRoot: View {
    // The root OWNS the store with @State (it is the creation point, Lecture 1 §1.4).
    @State private var store = NotesStore.sample

    // The counter is a plain reference held in @State so it survives re-renders.
    // We never mutate it in a way SwiftUI tracks; it lives outside the graph.
    @State private var counters = RenderCounters()

    // The note currently being edited. `nil` means no sheet. Using `.sheet(item:)`
    // ties the sheet's lifetime to this optional identity.
    @State private var editing: Note?

    var body: some View {
        NavigationStack {
            List(store.notes) { note in
                RowView(note: note, counters: counters)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = note }
            }
            .navigationTitle("Notes")
        }
        // .sheet(item:) presents when `editing` is non-nil and passes the item in.
        .sheet(item: $editing) { note in
            // We pass the LIVE note so Save can write straight to it, AND a draft
            // is created INSIDE the sheet so Cancel can discard. See EditSheet.
            EditSheet(note: note)
        }
    }
}

struct RowView: View {
    // The row takes ONLY its own note (Lecture 2, §2.5 — minimal inputs).
    let note: Note
    let counters: RenderCounters

    var body: some View {
        // Tick the counter every time this row's body runs.
        let _ = counters.tick(note.id)
        let _ = Self._printChanges()
        Text(note.title)
            // Side effect to confirm the value changed (Lecture 1, §1.9).
            .onChange(of: note.title) { oldValue, newValue in
                print("[onChange] '\(oldValue)' -> '\(newValue)'")
            }
    }
}

// ----------------------------------------------------------------------------
// The edit sheet — draft-and-commit.
//
// The sheet receives the LIVE note. It copies the editable fields into a local
// @Observable DRAFT held with @State. The TextFields bind to the DRAFT via
// @Bindable. "Save" copies the draft fields back onto the live note (one
// mutation per changed field). "Cancel" simply dismisses — the draft dies and
// the live note was never touched.
//
// This is the senior pattern: edit a copy, commit on save, discard on cancel.
// ----------------------------------------------------------------------------

@Observable
final class NoteDraft {
    var title: String
    var body: String
    init(from note: Note) {
        self.title = note.title
        self.body = note.body
    }
}

struct EditSheet: View {
    let note: Note                         // the live note (commit target)
    @Environment(\.dismiss) private var dismiss

    // The draft is created ONCE when the sheet appears (@State creation point).
    @State private var draft: NoteDraft

    init(note: Note) {
        self.note = note
        // Seed the draft from the live note. _draft is the underscore form for
        // initialising @State from an init parameter.
        _draft = State(initialValue: NoteDraft(from: note))
    }

    var body: some View {
        // Re-bind the draft locally to get $-projectable bindings (Lecture 1 §1.5).
        @Bindable var draft = draft

        NavigationStack {
            Form {
                TextField("Title", text: $draft.title)
                TextField("Body", text: $draft.body, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Discard: do NOTHING to the live note. Just dismiss.
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Commit: write each changed field back. We guard so we
                        // do not assign an unchanged value (which would still be
                        // a no-op for @Observable, but the guard makes intent clear
                        // and avoids a spurious onChange for unchanged fields).
                        if note.title != draft.title { note.title = draft.title }
                        if note.body != draft.body { note.body = draft.body }
                        dismiss()
                    }
                }
            }
        }
    }
}

// ----------------------------------------------------------------------------
// @main entry point. If your generated App already references ContentView,
// either rename ExerciseTwoRoot to ContentView, or point the App at this view.
// ----------------------------------------------------------------------------

#Preview {
    ExerciseTwoRoot()
}

// ----------------------------------------------------------------------------
// WHY IT RENDERS EXACTLY ONCE (read this — it is the lesson)
//
//  - The list reads `store.notes` to build rows. Editing a note's `title` does
//    NOT change the `notes` array itself (same elements, same order), so the
//    list-building code is not the thing that re-renders the row's TEXT.
//
//  - Each RowView reads `note.title`. Because Note is @Observable, the row is
//    subscribed to that note's `title` key path ONLY. Committing `note.title`
//    on Save fires the registrar for that one note's `title`, re-rendering
//    exactly that one row, exactly once. Other rows read other notes' titles;
//    they are not subscribed to the edited note, so they do not re-render.
//
//  - On Cancel we touch nothing. No key path mutates. No row re-renders. The
//    draft (a separate @Observable instance) is deallocated with the sheet.
//
//  - If you (wrongly) bound the sheet's TextField straight to the LIVE note via
//    @Bindable, every keystroke would mutate `note.title`, re-rendering the row
//    on every character AND making Cancel impossible (the change already
//    happened). That is the §1.11 "Wrong #2" bug. The draft is what makes
//    Cancel real and Save a single commit.
// ----------------------------------------------------------------------------
