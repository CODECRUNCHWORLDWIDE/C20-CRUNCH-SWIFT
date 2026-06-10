// Exercise 2 — Persist and restore navigation state across a cold launch
//
// Goal: persist the navigation PATH with @SceneStorage (per-scene, restoration-
//       scoped) and the selected TAB with @AppStorage (app-wide preference),
//       then prove restoration with the simulator's terminate-and-relaunch
//       gesture. After a cold launch the app must land on the SAME tab, at the
//       SAME depth, on the SAME note the user left.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Create a fresh SwiftUI iOS App in Xcode named "Ex02Restore".
//      Set the bundle identifier to com.crunchlabs.Ex02Restore so the
//      simctl commands below match.
//   2. Replace the generated App + ContentView files with THIS FILE
//      (delete the @main from the generated file; this file declares its own).
//   3. Build & run. Navigate two notes deep in the Notes tab, switch to the
//      Search tab, then back to Notes.
//   4. Reproduce a COLD LAUNCH from the terminal:
//
//        xcrun simctl terminate booted com.crunchlabs.Ex02Restore
//        xcrun simctl launch    booted com.crunchlabs.Ex02Restore
//
//      A correct solution relaunches onto the Notes tab, two screens deep,
//      on the note you left. If it shows the root list, your SceneStorage
//      restore is not wired (see TODO 3 / TODO 4).
//
// ACCEPTANCE CRITERIA
//
//   [ ] The selected tab survives a cold launch (via @AppStorage).
//   [ ] The Notes navigation path survives a cold launch (via @SceneStorage).
//   [ ] Restoration is proven with simctl terminate + simctl launch, NOT with
//       Xcode Stop/Run (see Lecture 1 sec. 1.8 for why).
//   [ ] Build succeeds with 0 warnings, 0 errors (the switch must be exhaustive).
//
// FILL IN THE FOUR TODOs. The completed form is at the bottom in comments.

import SwiftUI

// ---- Model -------------------------------------------------------------------

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

// @AppStorage requires RawRepresentable with a String/Int RawValue.
enum AppTab: String, Hashable {
    case notes, search
}

// ---- App ---------------------------------------------------------------------

@main
struct Ex02RestoreApp: App {
    // TODO 1 — persist the selected tab APP-WIDE with @AppStorage, default .notes.
    //          Hint: @AppStorage("selectedTab") private var selectedTab: AppTab = .notes
    @State private var selectedTab: AppTab = .notes   // <-- replace with @AppStorage

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Tab("Notes", systemImage: "note.text", value: AppTab.notes) {
                    NotesTab()
                }
                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                    NavigationStack {
                        Text("Search is a separate tab with its own (empty) stack.")
                            .navigationTitle("Search")
                    }
                }
            }
        }
    }
}

// ---- Notes tab with a restorable path ----------------------------------------

struct NotesTab: View {
    @State private var path: [Route] = []

    // TODO 2 — persist the path PER-SCENE with @SceneStorage as encoded Data.
    //          Hint: @SceneStorage("notes.path") private var stored: Data?
    private var stored: Data? = nil   // <-- replace with @SceneStorage

    var body: some View {
        NavigationStack(path: $path) {
            List(Note.samples) { note in
                NavigationLink(note.title, value: Route.note(id: note.id))
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Route.self, destination: destination)
        }
        // TODO 3 — restore the path from `stored` when the view appears.
        //          .onAppear { restore() }
        // TODO 4 — save the path to `stored` whenever it changes.
        //          .onChange(of: path) { _, newValue in save(newValue) }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id):
            let note = Note.find(id)
            Form {
                Section("Title") { Text(note?.title ?? "Unknown note") }
                Section("Body")  { Text(note?.body ?? "") }
                Section { NavigationLink("Open Settings", value: Route.settings) }
            }
            .navigationTitle(note?.title ?? "Note")
        case .settings:
            Form { Text("Settings, two screens deep.") }
                .navigationTitle("Settings")
        }
    }

    // Implement these once you have replaced the @SceneStorage stub.
    private func save(_ path: [Route]) {
        // stored = try? JSONEncoder().encode(path)
    }

    private func restore() {
        // guard let data = stored,
        //       let decoded = try? JSONDecoder().decode([Route].self, from: data)
        // else { return }
        // path = decoded
    }
}

// ==============================================================================
// COMPLETED REFERENCE (uncomment to compare after you have tried it yourself)
// ==============================================================================
//
// @main
// struct Ex02RestoreApp: App {
//     @AppStorage("selectedTab") private var selectedTab: AppTab = .notes
//
//     var body: some Scene {
//         WindowGroup {
//             TabView(selection: $selectedTab) {
//                 Tab("Notes", systemImage: "note.text", value: AppTab.notes) {
//                     NotesTab()
//                 }
//                 Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
//                     NavigationStack {
//                         Text("Search is a separate tab with its own (empty) stack.")
//                             .navigationTitle("Search")
//                     }
//                 }
//             }
//         }
//     }
// }
//
// struct NotesTab: View {
//     @State private var path: [Route] = []
//     @SceneStorage("notes.path") private var stored: Data?
//
//     var body: some View {
//         NavigationStack(path: $path) {
//             List(Note.samples) { note in
//                 NavigationLink(note.title, value: Route.note(id: note.id))
//             }
//             .navigationTitle("Notes")
//             .navigationDestination(for: Route.self, destination: destination)
//         }
//         .onAppear { restore() }
//         .onChange(of: path) { _, newValue in save(newValue) }
//     }
//
//     private func save(_ path: [Route]) {
//         stored = try? JSONEncoder().encode(path)
//     }
//
//     private func restore() {
//         guard let data = stored,
//               let decoded = try? JSONDecoder().decode([Route].self, from: data)
//         else { return }
//         path = decoded
//     }
//     // destination(_:) unchanged from the starter.
// }
//
// WHY @AppStorage FOR THE TAB AND @SceneStorage FOR THE PATH?
//   The selected tab is a user PREFERENCE — most users keep one tab choice
//   across every window, so it is app-wide (@AppStorage). The navigation path
//   is a WINDOW POSITION — two windows on iPad can be at different depths, and
//   it must survive a process kill, so it is per-scene restoration storage
//   (@SceneStorage). Picking the wrong wrapper is a real bug: an @AppStorage
//   path would make every window share one depth; a @SceneStorage tab would
//   reset the tab choice when the user opens a second window.
