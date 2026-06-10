# Exercise 1 — A value-typed `NavigationStack`

> **Estimated time:** 50 minutes. **Goal:** build a `NavigationStack` whose state is a `[Route]` array, push screens with `NavigationLink(value:)`, register destinations once with `navigationDestination(for:)`, and then drive the same path programmatically from buttons — push, pop, pop-to-root, and replace.

This is the foundational drill of the week. Everything else (restoration, deep links, the split view) is a variation on "mutate the path array." Get this one in your fingers and the rest is composition.

## What you are building

A two-screen app:

- **Root:** a list of three notes. Tapping a row pushes that note's detail. A toolbar exposes programmatic controls.
- **Detail:** shows a note's title and body, plus a `NavigationLink(value:)` to a Settings screen so you can go two deep.

You will drive navigation three ways from the root toolbar: **push** the second note, **pop to root**, and **replace** the entire stack with "note → settings" in one assignment.

## Setup

Create a fresh iOS App in Xcode (File → New → Project → App, SwiftUI interface, name it `Ex01Navigation`), or add a single file to any existing SwiftUI target. Replace the generated `ContentView.swift` with the starter below.

## Starter code

```swift
import SwiftUI

// ---- Model (shared across all Week 9 exercises) ------------------------------

struct Note: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var body: String

    static let samples: [Note] = [
        Note(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
             title: "Buy milk", body: "Oat, not dairy."),
        Note(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
             title: "Ship Week 9", body: "Navigation, scenes, deep links."),
        Note(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
             title: "Call the bank", body: "About the universal-links domain."),
    ]

    static func find(_ id: UUID) -> Note? { samples.first { $0.id == id } }
}

enum Route: Hashable, Codable {
    case note(id: UUID)
    case settings
}

// ---- Root --------------------------------------------------------------------

struct ContentView: View {
    // TODO 1 — own the navigation path as @State. Start empty (= at root).

    var body: some View {
        // TODO 2 — wrap the List in a NavigationStack bound to your path.
        List(Note.samples) { note in
            // TODO 3 — replace this Text with a NavigationLink(value:) that
            //          pushes Route.note(id: note.id).
            Text(note.title)
        }
        .navigationTitle("Notes")
        // TODO 4 — register a navigationDestination(for: Route.self) that
        //          switches on the route and returns the right view.
        // TODO 5 — add a toolbar with three buttons that mutate the path:
        //            • "Push 2nd"     -> push Route.note(id: 2nd note)
        //            • "Replace"      -> set path to [note(1st), settings]
        //            • "Pop to root"  -> empty the path
    }
}

// ---- Detail screens ----------------------------------------------------------

struct NoteDetailView: View {
    let noteID: UUID

    var body: some View {
        let note = Note.find(noteID)
        Form {
            Section("Title") { Text(note?.title ?? "Unknown note") }
            Section("Body")  { Text(note?.body ?? "") }
            Section {
                // A link from inside a pushed screen pushes onto the SAME path.
                NavigationLink("Open Settings", value: Route.settings)
            }
        }
        .navigationTitle(note?.title ?? "Note")
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Settings live two screens deep when reached from a note.")
        }
        .navigationTitle("Settings")
    }
}

#Preview { ContentView() }
```

## Steps

1. **Own the path.** Add `@State private var path: [Route] = []` to `ContentView`. The empty array is "at the root." This view is the navigation container, so it owns the state — that is the Week 8 ownership rule applied to navigation.

2. **Wrap in a `NavigationStack`.** Change `body` so the `List` is inside `NavigationStack(path: $path) { … }`. Move the `.navigationTitle`, the destination, and the toolbar *inside* the stack (they attach to the stack's content).

3. **Make the rows value-typed links.** Replace `Text(note.title)` with `NavigationLink(note.title, value: Route.note(id: note.id))`. Note that you are *not* naming a destination view here — only a value. The link is now data.

4. **Register the destination once.** Add `.navigationDestination(for: Route.self) { route in … }` to the `List`. Inside, `switch route` and return `NoteDetailView(noteID:)` for `.note` and `SettingsView()` for `.settings`. One registration handles every `Route` in the path, at any depth — including the `.settings` route a `NoteDetailView` pushes.

5. **Drive it programmatically.** Add a `.toolbar { }` with three buttons that mutate `path` directly:
   - `path.append(.note(id: Note.samples[1].id))` — push.
   - `path = [.note(id: Note.samples[0].id), .settings]` — replace (two deep, atomically).
   - `path.removeAll()` — pop to root.

## Expected output / acceptance criteria

- [ ] Tapping a note row pushes its detail; the back button returns to the list.
- [ ] Inside a detail, "Open Settings" pushes a third screen; Back returns to the note, Back again to the list.
- [ ] The toolbar "Push 2nd" button pushes "Ship Week 9" from anywhere.
- [ ] The toolbar "Replace" button jumps straight to Settings-on-top-of-a-note in **one** animation (you can tap Back twice afterward, proving the stack is genuinely two deep).
- [ ] The toolbar "Pop to root" button returns to the list from any depth.
- [ ] The build shows **0 warnings, 0 errors**. In particular the `switch route` in your destination must be exhaustive — if the compiler warns about a missing case, that is a real navigation bug, not pedantry.

Manually verify by tapping. There is no console output to check; the proof is that the four operations all work and Back is always coherent.

## Hints

<details>
<summary>Hint 1 — the stack wrapping (Step 2)</summary>

```swift
var body: some View {
    NavigationStack(path: $path) {
        List(Note.samples) { note in
            NavigationLink(note.title, value: Route.note(id: note.id))
        }
        .navigationTitle("Notes")
        .navigationDestination(for: Route.self, destination: destination)
        .toolbar { /* buttons */ }
    }
}
```
The `.navigationDestination` and `.toolbar` go on the `List`, **inside** the `NavigationStack`. If you put `navigationDestination` outside the stack, links do nothing and you get a purple runtime warning.
</details>

<details>
<summary>Hint 2 — the destination function (Step 4)</summary>

Pulling the closure out into a `@ViewBuilder` method keeps `body` readable:

```swift
@ViewBuilder
private func destination(_ route: Route) -> some View {
    switch route {
    case .note(let id): NoteDetailView(noteID: id)
    case .settings:     SettingsView()
    }
}
```
</details>

## Reference solution

```swift
import SwiftUI

struct Note: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var body: String

    static let samples: [Note] = [
        Note(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
             title: "Buy milk", body: "Oat, not dairy."),
        Note(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
             title: "Ship Week 9", body: "Navigation, scenes, deep links."),
        Note(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
             title: "Call the bank", body: "About the universal-links domain."),
    ]

    static func find(_ id: UUID) -> Note? { samples.first { $0.id == id } }
}

enum Route: Hashable, Codable {
    case note(id: UUID)
    case settings
}

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(Note.samples) { note in
                NavigationLink(note.title, value: Route.note(id: note.id))
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Route.self, destination: destination)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Push 2nd") {
                        path.append(.note(id: Note.samples[1].id))
                    }
                    Button("Replace") {
                        path = [.note(id: Note.samples[0].id), .settings]
                    }
                    Button("Pop to root") {
                        path.removeAll()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id): NoteDetailView(noteID: id)
        case .settings:     SettingsView()
        }
    }
}

struct NoteDetailView: View {
    let noteID: UUID

    var body: some View {
        let note = Note.find(noteID)
        Form {
            Section("Title") { Text(note?.title ?? "Unknown note") }
            Section("Body")  { Text(note?.body ?? "") }
            Section {
                NavigationLink("Open Settings", value: Route.settings)
            }
        }
        .navigationTitle(note?.title ?? "Note")
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Settings live two screens deep when reached from a note.")
        }
        .navigationTitle("Settings")
    }
}

#Preview { ContentView() }
```

## What you just proved

You proved that **every navigation operation is array mutation**. Push is `append`, pop-to-root is `removeAll`, replace is assignment. There is not one `isActive` boolean in this file, and the "Replace" button — which sets a two-deep stack in a single assignment — is the exact primitive a deep link uses. Exercise 3 will reuse it verbatim: a deep link computes a `[Route]` and assigns it to this same `path`.
