# Exercise 1 — A ModelContainer that survives relaunch

**Goal.** Stand up the smallest possible real SwiftData app: one `@Model`, one `ModelContainer`, a list, and an "add" button. Then prove the data is durable by force-quitting the app and relaunching it from cold. This is the entire promise of the week distilled to one screen — if you can do this, persistence works; everything else this week is refinement.

**Estimated time.** 40 minutes.

**Prerequisites.** Xcode 16+, an iOS 18 Simulator (iOS 17 works; the APIs here are all iOS 17+). The Hello, Notes app from Week 9 is *not* required for this exercise — we build a throwaway `Scratch` app so the focus stays on the container. You'll do the real migration in the mini-project.

---

## Step 1 — Scaffold a fresh SwiftUI app

In Xcode: **File ▸ New ▸ Project ▸ iOS ▸ App.** Name it `Scratch`, Interface **SwiftUI**, Language **Swift**, Storage **None** (we wire SwiftData by hand so you see every piece — do *not* pick the "SwiftData" template, which hides the setup). Set the deployment target to iOS 17.0 or later.

Confirm it builds and runs in the Simulator before you touch anything. You should see "Hello, world!"

## Step 2 — Define a `@Model`

Create a new Swift file `Note.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date

    init(title: String, body: String = "", createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
```

Three things to notice and be able to explain in a code review:

- It's a **`class`**, not a `struct`. Persistence needs identity (lecture 1, §3). Mark it `final`.
- Every stored property has a default in the `init` so adding one later is a *lightweight* migration.
- No `id` property — SwiftData gives every model a `persistentModelID` for free, and `@Model` makes the type `Identifiable` via that.

## Step 3 — Install the container on the app

Open `ScratchApp.swift` and attach the container to the scene:

```swift
import SwiftUI
import SwiftData

@main
struct ScratchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)   // <- builds the container, store, and mainContext
    }
}
```

That one modifier builds the `ModelContainer`, creates the on-disk SQLite store under Application Support, installs a `mainContext` into the environment under `\.modelContext`, and makes `@Query` work in any descendant view.

## Step 4 — Read with `@Query`, write with the context

Replace `ContentView.swift` entirely:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    VStack(alignment: .leading) {
                        Text(note.title).font(.headline)
                        Text(note.createdAt, format: .dateTime.hour().minute().second())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Notes (\(notes.count))")
            .toolbar {
                Button("Add", systemImage: "plus", action: addNote)
            }
            .overlay {
                if notes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "note.text",
                                           description: Text("Tap + to add one, then force-quit and relaunch."))
                }
            }
        }
    }

    private func addNote() {
        let note = Note(title: "Note #\(notes.count + 1)")
        context.insert(note)
        // The mainContext autosaves, but we save explicitly so durability is
        // guaranteed the instant the user adds — not whenever autosave fires.
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(notes[index])
        }
        try? context.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)   // preview uses an ephemeral store
}
```

Note the `#Preview` uses `inMemory: true` — previews must never write to the real store. That's `ModelConfiguration(isStoredInMemoryOnly: true)` under the hood (lecture 1, §4).

## Step 5 — Run, add, and SEE the data

Run on the Simulator. Tap **Add** three or four times. You should see notes accumulate, newest first, and the title count update:

```text
Notes (4)

Note #4    12:01:07
Note #3    12:01:05
Note #2    12:01:03
Note #1    12:01:01
```

So far this looks exactly like the in-memory `NotesStore` from Week 8. The difference is invisible until you kill the process.

## Step 6 — The relaunch test (the whole point)

This is the acceptance bar. Backgrounding is *not* the test — the process stays alive and any in-memory array survives. You must **kill the process** and relaunch cold.

**Option A — the UI way:** In the Simulator, open the App Switcher (Hardware ▸ Home twice, or swipe up and pause), and swipe the `Scratch` card up to force-quit. Then tap the app icon on the home screen to relaunch.

**Option B — the CLI way (more reliable, scriptable):**

```bash
# Find the booted simulator and your bundle id, then kill and relaunch.
xcrun simctl terminate booted com.yourname.Scratch
xcrun simctl launch booted com.yourname.Scratch
```

Replace `com.yourname.Scratch` with your actual bundle id (Xcode ▸ target ▸ Signing & Capabilities ▸ Bundle Identifier).

**Expected result:** the app relaunches and your four notes are **still there**, in the same order. If they are, persistence works. If they vanished, you either forgot `.modelContainer(for:)`, forgot to `save()`, or accidentally used `inMemory: true` on the real app (not just the preview).

## Step 7 — Look at the actual database (optional, illuminating)

Prove to yourself that there is a real SQLite file with Core Data tables in it:

```bash
# Locate the app's data container, then find the store.
DATA=$(xcrun simctl get_app_container booted com.yourname.Scratch data)
find "$DATA" -name "*.store" 2>/dev/null
# Open it and list tables — you'll see ZNOTE (the Z-prefix is Core Data's).
sqlite3 "$DATA/Library/Application Support/default.store" ".tables"
sqlite3 "$DATA/Library/Application Support/default.store" "SELECT ZTITLE, ZCREATEDAT FROM ZNOTE;"
```

Seeing `ZNOTE` with a `Z_PK` and `Z_ENT` column makes lecture 1's "SwiftData is Core Data underneath" concrete. You wrote `@Model`; Core Data wrote `ZNOTE`.

---

## Acceptance criteria

- [ ] A `@Model final class Note` with three properties, each defaulted in `init`.
- [ ] `.modelContainer(for: Note.self)` on the app scene (and `inMemory: true` only in the `#Preview`).
- [ ] `@Query(sort:order:)` drives a `List`; `context.insert` + `save()` adds; `context.delete` + `save()` removes.
- [ ] Build with **0 warnings, 0 errors**.
- [ ] You added at least 4 notes, force-quit the process (App Switcher *or* `xcrun simctl terminate`), relaunched cold, and the notes were **still there in the correct order**.
- [ ] (Stretch) You found the `.store` file and listed the `ZNOTE` table with `sqlite3`.

## What you just proved

You proved the three runtime objects from lecture 1 actually work together: the **container** owns the SQLite store on disk, the **context** staged your inserts and flushed them on `save()`, and **`@Query`** read them back and re-rendered the list. And you proved the week's promise — *state the user created survived the process dying* — with a kill-and-relaunch, not a vibe. Every other exercise this week builds on this skeleton.

---

## Hints (read only if stuck > 10 min)

- **Notes vanish on relaunch but the app didn't crash.** Almost always: you removed the `try? context.save()` (and autosave didn't fire before you killed it), or your real app scene is using `inMemory: true`. Check `ScratchApp.swift`, not the preview.
- **`@Query` is empty even after adding.** `@Query` only works inside a `View` whose environment has a `\.modelContext`. If you moved the list into a child view that you present *without* the container in scope, the environment is missing. Keep `.modelContainer` on the top-level scene.
- **`Cannot use instance member 'notes' within property initializer`.** You tried to reference `notes` before the view is initialised. `notes.count` is fine inside `body` and inside methods; just not in a stored-property default.
- **`xcrun simctl` says "No devices are booted."** Run the app from Xcode first so a simulator is booted, then run the `simctl` commands against `booted`.
