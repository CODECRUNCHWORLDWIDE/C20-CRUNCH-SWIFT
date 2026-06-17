# Challenge 1 — Edit in a Sheet: Cancel Discards, Save Commits, List Updates Exactly Once

**Time estimate:** ~110 minutes.

## Problem statement

Build a single-screen SwiftUI app: a list of contacts, each tappable to open an **edit sheet**. The sheet edits the contact's `name` and `email`. The sheet has two buttons:

- **Cancel** — discards every change made in the sheet. The list is unchanged. Nothing re-renders.
- **Save** — commits the changes to the contact. The one list cell that changed re-renders **exactly once**. No other cell re-renders.

The catch — and the entire point — is that you must **prove** these two claims with instrumentation, not assert them by eye. You will use `onChange(of:)` to detect the commit and a render counter to count the cell re-renders. Your submission includes the console output that proves it.

This is the senior pattern from Lecture 1 §1.11 (draft-and-commit) plus the measurement discipline from Lecture 2 §2.10. It is the hardest part of this week's mini-project, extracted so you can solve it in isolation first.

## What you build

```text
ContactsApp/
└── (a single iOS App target, iOS 17+)
    ├── ContactsRoot.swift     — owns the store, presents the sheet
    ├── ContactStore.swift     — @Observable model: [Contact]
    ├── Contact.swift          — @Observable contact + a Draft type
    ├── ContactRow.swift       — a row that ticks a render counter
    └── EditContactSheet.swift — the draft-and-commit edit sheet
```

(You may keep it all in one file while developing — split before you submit.)

## Functional requirements

1. The store is an `@Observable final class ContactStore` holding `var contacts: [Contact]`, seeded with at least 5 contacts.
2. `Contact` is an `@Observable final class` with `let id`, `var name`, `var email`.
3. Tapping a row presents an edit sheet via `.sheet(item:)` bound to a `@State var editing: Contact?`.
4. The sheet creates a **draft** (a separate `@Observable` instance, or a value-type `struct`) seeded from the contact. The `TextField`s bind to the *draft*, never the live contact.
5. **Cancel** dismisses without touching the live contact.
6. **Save** copies the draft's fields back onto the live contact (one assignment per changed field), then dismisses.
7. Each row reads only *its own* contact's fields (`name`, `email`) — minimal inputs, so per-property tracking re-renders only the changed cell.

## Proof requirements (the hard part)

You must demonstrate, with console output, all four of:

1. **Save re-renders the edited cell exactly once.** A `RenderCounter` (a reference type outside the dependency graph) ticks in the row's `body` and prints `[row <id>] render #N`. After a save that changes the name, the edited cell's counter increments by exactly 1; no other cell's counter changes.
2. **Save fires `onChange(of:)` exactly once for the changed field.** Attach `.onChange(of: contact.name)` (and one for `email`) to the row; on save, the changed field's `onChange` fires once with the correct `(old, new)` pair.
3. **Cancel re-renders nothing.** After opening the sheet, editing the text, and tapping Cancel, no row's counter increments and no `onChange` fires. Zero console output from the list.
4. **Editing a field and then *changing it back* before saving, then saving, re-renders zero or one time consistently** — explain in your README which you observed and why. (This tests whether you guard the commit on `old != new`.)

## Acceptance criteria

- [ ] A single iOS App target, iOS 17+, building with **zero warnings** under strict concurrency.
- [ ] `ContactStore` and `Contact` are `@Observable`; no `@Published`, no `ObservableObject`.
- [ ] The sheet edits a **draft**; Cancel provably discards (the live contact is untouched until Save).
- [ ] `@Bindable` is used to bind the sheet's `TextField`s to the draft.
- [ ] The sheet is presented with `.sheet(item:)`, not `.sheet(isPresented:)` (item-based presentation passes the contact identity in and ties lifetime to it).
- [ ] A `RenderCounter` ticks in the row body; you have console output showing **save = exactly one tick on the changed cell, zero elsewhere**.
- [ ] `onChange(of:)` on the row fires **once** on save for the changed field, **zero** times on cancel.
- [ ] A `README.md` in the challenge folder with: the proof console output pasted in (save case and cancel case), and a one-paragraph explanation of *why* it renders exactly once (in terms of per-property tracking and the draft boundary).

## Suggested order of operations

### Phase 1 — Models (~20 min)

```swift
import Observation

@Observable
final class Contact: Identifiable {
    let id = UUID()
    var name: String
    var email: String
    init(name: String, email: String) { self.name = name; self.email = email }
}

@Observable
final class ContactStore {
    var contacts: [Contact]
    init(_ contacts: [Contact]) { self.contacts = contacts }

    static let sample = ContactStore([
        Contact(name: "Ada Lovelace", email: "ada@analytical.engine"),
        Contact(name: "Grace Hopper", email: "grace@navy.mil"),
        Contact(name: "Alan Turing", email: "alan@bletchley.uk"),
        Contact(name: "Katherine Johnson", email: "kj@nasa.gov"),
        Contact(name: "Margaret Hamilton", email: "mh@mit.edu"),
    ])
}
```

### Phase 2 — Render counter + row (~20 min)

```swift
import SwiftUI

final class RenderCounter {
    private var counts: [UUID: Int] = [:]
    func tick(_ id: UUID) {
        counts[id, default: 0] += 1
        print("[row \(id.uuidString.prefix(4))] render #\(counts[id]!)")
    }
}

struct ContactRow: View {
    let contact: Contact          // reads contact.name / contact.email only
    let counter: RenderCounter

    var body: some View {
        let _ = counter.tick(contact.id)
        VStack(alignment: .leading) {
            Text(contact.name).font(.headline)
            Text(contact.email).font(.subheadline).foregroundStyle(.secondary)
        }
        .onChange(of: contact.name) { old, new in
            print("[onChange name \(contact.id.uuidString.prefix(4))] '\(old)' -> '\(new)'")
        }
        .onChange(of: contact.email) { old, new in
            print("[onChange email \(contact.id.uuidString.prefix(4))] '\(old)' -> '\(new)'")
        }
    }
}
```

### Phase 3 — The draft-and-commit sheet (~40 min)

This is the crux. Seed a draft from the contact, bind `TextField`s to the draft with `@Bindable`, commit on Save with a guard.

```swift
@Observable
final class ContactDraft {
    var name: String
    var email: String
    init(from c: Contact) { name = c.name; email = c.email }
}

struct EditContactSheet: View {
    let contact: Contact
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ContactDraft

    init(contact: Contact) {
        self.contact = contact
        _draft = State(initialValue: ContactDraft(from: contact))
    }

    var body: some View {
        @Bindable var draft = draft
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                TextField("Email", text: $draft.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }     // discard: touch nothing
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if contact.name != draft.name { contact.name = draft.name }
                        if contact.email != draft.email { contact.email = draft.email }
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### Phase 4 — Root + presentation (~10 min)

```swift
struct ContactsRoot: View {
    @State private var store = ContactStore.sample
    @State private var counter = RenderCounter()
    @State private var editing: Contact?

    var body: some View {
        NavigationStack {
            List(store.contacts) { contact in
                ContactRow(contact: contact, counter: counter)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = contact }
            }
            .navigationTitle("Contacts")
        }
        .sheet(item: $editing) { contact in
            EditContactSheet(contact: contact)
        }
    }
}
```

### Phase 5 — Prove it (~20 min)

Run in the simulator with the console open. Perform each scenario and capture the output:

- **Save scenario:** tap "Ada Lovelace", change the name to "Ada Byron", tap Save. Expect exactly one `[row <id>] render #N` for Ada's row and one `[onChange name ...]` line. No other row prints.
- **Cancel scenario:** tap "Grace Hopper", change the email, tap Cancel. Expect **zero** lines from the list.
- **Change-back scenario:** tap a contact, change the name, change it back to the original, tap Save. Observe whether the `old != new` guard suppresses the commit (it should — the field equals the original, so no assignment, so no `onChange`, so no row re-render).

Paste all three outputs into the challenge `README.md`.

## Stretch

- **Add a "discard confirmation."** If the draft differs from the contact when Cancel is tapped, present a `.confirmationDialog` asking "Discard changes?" before dismissing. Use a computed `var hasChanges: Bool { draft.name != contact.name || draft.email != contact.email }` to gate it. Prove that an unchanged draft dismisses without the dialog.
- **Value-type draft instead of reference.** Re-implement the draft as a plain `struct ContactDraft` held in `@State` and bound with `$draft.name` directly (no `@Bindable`, because `@State` of a value type already projects bindings). Compare the two approaches in your README — which reads better, and why does the value-type version *not* need `@Bindable`?
- **Add a new-contact flow.** Reuse the same sheet for "Add" by passing a fresh `Contact` and inserting it into the store on Save. Prove the list gains exactly one row and renders the new row exactly once.
- **Break it deliberately.** Bind the sheet's `TextField` directly to the *live* contact via `@Bindable var contact = contact` (skip the draft). Observe the storm: the row now re-renders on every keystroke, and Cancel cannot discard. Capture that console output too — knowing the broken signature is half of recognising it in review.

## Submission

Commit your `ContactsApp` under `challenges/challenge-01/` in your Week 8 GitHub repo. The `README.md` must contain the three pasted console outputs (save, cancel, change-back) and the one-paragraph "why exactly once" explanation. Make sure the project builds with zero warnings on a fresh clone.

## Why this matters

"Edit a copy, commit on save, discard on cancel" is the single most common stateful interaction in every productivity app you will ever build — and the one beginners get wrong most often, in one of two ways: they bind the sheet straight to the live model (so Cancel is a lie and the list storms on every keystroke), or they edit a copy and forget to commit (so Save silently loses the edit). Getting it right *and proving it with a counter* is the exact skill the syllabus says this week earns: "pick the correct state primitive for a given ownership scenario and defend the choice in a code review." This challenge *is* that code review, with you on both sides of it.
