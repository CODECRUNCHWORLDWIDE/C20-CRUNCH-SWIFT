// Exercise 3 — Handle an onOpenURL deep link that opens a specific note
//
// Goal: write a PURE decoder `DeepLink.path(for:) -> [Route]?`, unit-test it
//       without a simulator, wire `.onOpenURL` to it, and fire
//       `notes://open/<id>` at the booted simulator to push the right note's
//       detail screen — atomically, whether the app is warm or cold.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE
//
//   1. Create a fresh SwiftUI iOS App named "Ex03DeepLink",
//      bundle id com.crunchlabs.Ex03DeepLink.
//   2. Register the custom URL scheme so iOS routes notes:// to your app:
//        Target > Info > URL Types > +  -> URL Schemes = "notes"
//      (or add CFBundleURLTypes to Info.plist; see the bottom of this file).
//   3. Replace the generated files with THIS FILE.
//   4. Build & run, then from the terminal fire a link at the running app:
//
//        xcrun simctl openurl booted notes://open/22222222-2222-2222-2222-222222222222
//
//      The app should push "Ship Week 9". Now prove the COLD path:
//
//        xcrun simctl terminate booted com.crunchlabs.Ex03DeepLink
//        xcrun simctl openurl   booted notes://open/33333333-3333-3333-3333-333333333333
//
//      iOS cold-launches the app and lands on "Call the bank" — same handler,
//      no special cold-launch code.
//
// ACCEPTANCE CRITERIA
//
//   [ ] DeepLink.path(for:) is pure (no SwiftUI), total (nil for garbage),
//       and handles BOTH the custom scheme and the https universal-link host.
//   [ ] A warm `simctl openurl` pushes the correct note's detail.
//   [ ] A cold `simctl openurl` (after terminate) launches AND pushes it.
//   [ ] The unit tests below pass (run with: swift test, or a test target).
//   [ ] Build succeeds with 0 warnings, 0 errors.
//
// FILL IN THE TWO TODOs IN DeepLink. The view wiring is done for you so you can
// focus on the decoder — the decoder is the lesson.

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

// ---- The pure decoder (THE LESSON) -------------------------------------------

enum DeepLink {
    static let universalHost = "notes.example.com"

    /// Pure, total, simulator-free: URL -> navigation path (or nil).
    /// Accepts:  notes://open/<uuid>
    ///           https://notes.example.com/open/<uuid>
    static func path(for url: URL) -> [Route]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let segments: [String]
        switch components.scheme {
        case "notes":
            // host is the first logical segment for a custom scheme: notes://open/<id>
            // TODO 1 — build `segments` as [host] + the path segments.
            //          Hint: [components.host].compactMap { $0 } + splitPath(components.path)
            segments = []   // <-- replace
        case "https":
            guard components.host == universalHost else { return nil }
            segments = splitPath(components.path)
        default:
            return nil
        }
        return route(from: segments)
    }

    private static func splitPath(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    /// segments like ["open", "<uuid>"]
    private static func route(from segments: [String]) -> [Route]? {
        // TODO 2 — require segments == ["open", <valid uuid>] and return
        //          [.note(id: uuid)]; otherwise nil.
        return nil   // <-- replace
    }
}

// ---- App + view (wiring done for you) ----------------------------------------

@main
struct Ex03DeepLinkApp: App {
    var body: some Scene {
        WindowGroup { NotesList() }
    }
}

struct NotesList: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(Note.samples) { note in
                NavigationLink(note.title, value: Route.note(id: note.id))
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Route.self, destination: destination)
        }
        // Custom scheme (warm AND cold launch both arrive here).
        .onOpenURL { url in apply(url) }
        // Universal link transport — same decoder, see Challenge 1.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            apply(url)
        }
    }

    private func apply(_ url: URL) {
        if let newPath = DeepLink.path(for: url) {
            path = newPath          // atomic: replace the whole stack at once
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id):
            let note = Note.find(id)
            Form {
                Section("Title") { Text(note?.title ?? "Unknown note") }
                Section("Body")  { Text(note?.body ?? "") }
            }
            .navigationTitle(note?.title ?? "Note")
        case .settings:
            Form { Text("Settings") }.navigationTitle("Settings")
        }
    }
}

// ==============================================================================
// UNIT TESTS (Swift Testing). Put these in your test target. They run WITHOUT
// a simulator because DeepLink.path(for:) is pure — that is the whole point.
// ==============================================================================
//
// import Testing
// import Foundation
//
// @Test func customSchemeOpensNote() {
//     let id = UUID()
//     let url = URL(string: "notes://open/\(id.uuidString)")!
//     #expect(DeepLink.path(for: url) == [.note(id: id)])
// }
//
// @Test func universalLinkOpensNote() {
//     let id = UUID()
//     let url = URL(string: "https://notes.example.com/open/\(id.uuidString)")!
//     #expect(DeepLink.path(for: url) == [.note(id: id)])
// }
//
// @Test func garbageReturnsNil() {
//     #expect(DeepLink.path(for: URL(string: "notes://open/not-a-uuid")!) == nil)
//     #expect(DeepLink.path(for: URL(string: "https://evil.example.com/open/x")!) == nil)
//     #expect(DeepLink.path(for: URL(string: "notes://delete/everything")!) == nil)
// }
//
// ==============================================================================
// COMPLETED DECODER (compare after you try it)
// ==============================================================================
//
//   case "notes":
//       segments = [components.host].compactMap { $0 } + splitPath(components.path)
//
//   private static func route(from segments: [String]) -> [Route]? {
//       guard segments.first == "open", segments.count >= 2,
//             let id = UUID(uuidString: segments[1])
//       else { return nil }
//       return [.note(id: id)]
//   }
//
// ==============================================================================
// Info.plist URL Type (if you edit the plist directly rather than the UI)
// ==============================================================================
//   <key>CFBundleURLTypes</key>
//   <array>
//     <dict>
//       <key>CFBundleURLName</key>
//       <string>com.crunchlabs.Ex03DeepLink</string>
//       <key>CFBundleURLSchemes</key>
//       <array><string>notes</string></array>
//     </dict>
//   </array>
//
// WHY THE COLD LAUNCH WORKS WITH NO EXTRA CODE:
//   onOpenURL is delivered after the scene connects, in BOTH the warm and the
//   cold case. The launch URL fires after onAppear, so if you also restored a
//   SceneStorage path on appear, the deep link is the last writer and wins —
//   which is what the user wants when they explicitly tap a link.
