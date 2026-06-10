# Lecture 2 — Why value-typed navigation enables deep links by construction

> **Reading time:** ~85 minutes. **Hands-on time:** ~55 minutes (you write a pure URL decoder, unit-test it without a simulator, then wire `onOpenURL` and a universal link to it).

Lecture 1 built the post-iOS-16 navigation model and asserted, repeatedly, that value-typed navigation "makes deep links fall out for free." This lecture makes the argument honestly. We are going to implement the *same* deep-link feature twice — once on the legacy `isActive` model and once on the value-typed model — and watch the legacy version fail in three specific, reproducible ways that the value-typed version cannot. Then we will build the production deep-link pipeline: a pure decoder, the `onOpenURL` transport for custom schemes, the universal-link transport for HTTPS links, and the rule that unifies them.

The claim, stated precisely: **when a screen is identified by a value rather than by "whichever view is currently on top," a deep link becomes a pure function `(URL) -> [Route]` — and pure functions are testable, composable, and identical across every entry point (cold launch, warm `onOpenURL`, Spotlight, universal link).** "By construction" means you do not write deep-link handling as a feature; it is a consequence of how you modelled navigation.

## 2.1 — The feature we are implementing

The product requirement is mundane and universal: *the user taps a link — in Messages, in a push notification, in Spotlight — that should open a specific note. Whether the app was already running or had been killed, tapping the link lands the user on that note's detail screen.*

The link is `notes://open/<uuid>` (custom scheme) or `https://notes.example.com/open/<uuid>` (universal link). Both name the same note by its `id`. Both should produce the same result.

That is the whole feature. It sounds trivial. On the legacy model it is a multi-day battle. On the value-typed model it is a function and three lines of wiring.

## 2.2 — The legacy `isActive` implementation (and where it breaks)

Here is the deep-link feature on the pre-iOS-16 model. We are writing it *to throw it away*, so you recognize the failure modes when you inherit a codebase that still ships it.

```swift
// LEGACY — broken by design. Do not ship. Read to understand the failure modes.
struct LegacyNotesList: View {
    let notes: [Note]
    @State private var activeNoteID: UUID?          // which note is "pushed"
    @State private var isDetailActive = false       // is the detail showing?

    var body: some View {
        NavigationView {
            List(notes) { note in
                NavigationLink(
                    destination: LegacyNoteDetail(noteID: note.id),
                    isActive: Binding(
                        get: { isDetailActive && activeNoteID == note.id },
                        set: { active in
                            if active { activeNoteID = note.id; isDetailActive = true }
                            else { isDetailActive = false }
                        }
                    )
                ) { Text(note.title) }
            }
        }
        .onOpenURL { url in
            // The "deep link handler" — and the source of all three bugs.
            guard let id = LegacyNotesList.parseID(from: url) else { return }
            activeNoteID = id
            isDetailActive = true
        }
    }

    static func parseID(from url: URL) -> UUID? {
        guard url.scheme == "notes",
              url.host == "open",
              let last = url.pathComponents.last,
              let id = UUID(uuidString: last)
        else { return nil }
        return id
    }
}
```

This *appears* to work in the happy path. It breaks in three ways that you will hit in QA, not in the demo.

**Failure 1 — it cannot navigate two levels deep.** The link `notes://open/<id>` is fine. But the moment product asks for `notes://open/<id>/tag/<tagID>` — "open this note, then push its tag" — you have no second boolean for the tag level, and adding one (`isTagActive`) means coordinating `isDetailActive` and `isTagActive` so they flip in the right order. There is no array, so there is no "depth." Every level is a new boolean and a new coordination bug. The value-typed model handles arbitrary depth because the depth *is* the array length.

**Failure 2 — it glitches mid-animation when the app is warm.** If the user is *already* three screens deep and a new deep link arrives, setting `isDetailActive = true` while another `isActive` is still true makes SwiftUI try to reconcile two conflicting active links during an in-flight transition. The observable symptom is the stack popping to root and then pushing — a visible double-animation — or, worse, landing on the wrong note. There is no atomic "set the whole stack" operation; you can only flip booleans one at a time, and the intermediate states are visible.

**Failure 3 — it cannot be restored or tested.** The navigation state is `activeNoteID` + `isDetailActive` — two `@State` properties scattered across the view, not a single serializable value. You cannot write it to `SceneStorage` as one unit. And `parseID(from:)` returns a single `UUID?`, not a *path*, so you cannot unit-test "this URL produces this navigation state" — because there is no value that *is* the navigation state. You can only test the URL-to-id step, then hope the boolean choreography that follows is correct.

These are not implementation bugs you can fix by trying harder. They are consequences of modelling navigation as a scatter of booleans instead of as data. The new model removes them by removing the booleans.

## 2.3 — The value-typed implementation (and why it does not break)

Same feature, value-typed model. Start with the routes and a **pure decoder** — the heart of the whole approach:

```swift
import Foundation

enum Route: Hashable, Codable {
    case note(id: UUID)
    case tag(id: UUID)
    case settings
}

enum DeepLink {
    /// Pure, total, simulator-free. Returns the full navigation path the URL
    /// should produce, or nil if the URL is not a link we recognize.
    /// Handles BOTH the custom scheme and the universal-link host.
    static func path(for url: URL) -> [Route]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        // Normalize the two transports to the same logical "open/<id>[/tag/<id>]" form.
        let segments: [String]
        switch components.scheme {
        case "notes":
            // notes://open/<id>  -> host is "open", path is "/<id>"
            segments = [components.host].compactMap { $0 } + pathSegments(components.path)
        case "https":
            // https://notes.example.com/open/<id> -> path is "/open/<id>"
            guard components.host == "notes.example.com" else { return nil }
            segments = pathSegments(components.path)
        default:
            return nil
        }

        return route(from: segments)
    }

    private static func pathSegments(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    /// segments like ["open", "<noteID>"] or ["open", "<noteID>", "tag", "<tagID>"]
    private static func route(from segments: [String]) -> [Route]? {
        guard segments.first == "open", segments.count >= 2,
              let noteID = UUID(uuidString: segments[1])
        else { return nil }

        var path: [Route] = [.note(id: noteID)]

        if segments.count >= 4, segments[2] == "tag",
           let tagID = UUID(uuidString: segments[3]) {
            path.append(.tag(id: tagID))
        }
        return path
    }
}
```

Stare at `DeepLink.path(for:)`. It has **no SwiftUI import, no view, no `@State`, no simulator dependency.** It is a pure function from `URL` to `[Route]?`. That is the entire deep-link logic. It handles the two-level case (`/open/<id>/tag/<tagID>`) that broke Failure 1 — because the result is an *array*, and arrays have arbitrary length. It is total — garbage URLs return `nil`, so the app does nothing rather than crashing. And because it is pure, you unit-test it in milliseconds with Swift Testing:

```swift
import Testing
import Foundation

@Test func customSchemeOpensNote() throws {
    let id = UUID()
    let url = URL(string: "notes://open/\(id.uuidString)")!
    #expect(DeepLink.path(for: url) == [.note(id: id)])
}

@Test func universalLinkOpensNote() throws {
    let id = UUID()
    let url = URL(string: "https://notes.example.com/open/\(id.uuidString)")!
    #expect(DeepLink.path(for: url) == [.note(id: id)])
}

@Test func twoLevelDeepLink() throws {
    let noteID = UUID(); let tagID = UUID()
    let url = URL(string: "notes://open/\(noteID.uuidString)/tag/\(tagID.uuidString)")!
    #expect(DeepLink.path(for: url) == [.note(id: noteID), .tag(id: tagID)])
}

@Test func garbageReturnsNil() {
    #expect(DeepLink.path(for: URL(string: "notes://open/not-a-uuid")!) == nil)
    #expect(DeepLink.path(for: URL(string: "https://evil.example.com/open/x")!) == nil)
    #expect(DeepLink.path(for: URL(string: "notes://delete/everything")!) == nil)
}
```

You cannot write `twoLevelDeepLink` against the legacy model, because there is no value that represents "two levels deep." Here it is one `#expect`. That is the difference between modelling navigation as data and modelling it as code.

Now the wiring. The view *applies* the decoded path; that is all:

```swift
struct NotesList: View {
    let store: NotesStore
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(store.notes) { note in
                NavigationLink(note.title, value: Route.note(id: note.id))
            }
            .navigationDestination(for: Route.self, destination: destination)
        }
        .onOpenURL { url in
            // The ENTIRE deep-link handler. Atomic, total, glitch-free.
            if let newPath = DeepLink.path(for: url) {
                path = newPath           // REPLACE the whole stack at once
            }
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .note(let id): NoteDetailView(noteID: id, store: store)
        case .tag(let id):  TagDetailView(tagID: id, store: store)
        case .settings:     SettingsView()
        }
    }
}
```

Three lines of handler. `path = newPath` is **atomic** — it sets the entire stack in one assignment, which kills Failure 2: there is no intermediate state, no two booleans flipping out of order, no double-animation. SwiftUI diffs the old path against the new path and animates the single coherent transition. And because `Route` is `Codable`, this same `path` writes to `SceneStorage` for restoration (Failure 3 gone). One model, all three failures removed, not by effort but by construction.

## 2.4 — Why `onOpenURL` handles both warm and cold launch

A subtle but critical point: `.onOpenURL { }` fires in **both** lifecycle situations.

- **Warm:** the app is running, the user taps `notes://open/<id>` in Messages. iOS foregrounds the app and delivers the URL to `onOpenURL`. The handler runs, `path = newPath`, the stack animates to the note.
- **Cold:** the app was killed. The user taps the same link. iOS launches the process, builds the view tree, and *then* delivers the URL to `onOpenURL` once the scene is ready. The handler runs with the same code path.

You do not write two handlers. The framework guarantees `onOpenURL` is called after the scene is connected in both cases. This is why putting the handler on a view that is always present (the root `NavigationStack` content) matters — if it is on a conditionally-rendered child, the cold-launch delivery may arrive before that child exists, and the link drops.

There is one ordering hazard to know. On a cold launch, `SceneStorage` restoration (Lecture 1) *also* runs, restoring the path the user left. If the deep link arrives, you want the link to **win** — the user tapped a link to go somewhere specific; honour it over where they happened to be. The value-typed model makes this a non-issue: restoration sets `path` in `onAppear`, the deep link sets `path` in `onOpenURL`, and `onOpenURL` for a launch URL fires after `onAppear`, so the link's assignment is the last writer. If you ever see the *restored* path win over the link, your handler is firing too early — move it up to the always-present root.

## 2.5 — Custom schemes vs universal links: two transports, one decoder

You have seen the decoder handle both `notes://` and `https://`. Here is why you need both and what each costs.

| | Custom scheme (`notes://`) | Universal link (`https://…`) |
|---|---|---|
| **Setup** | Register a URL Type in the target (one Info.plist entry) | Associated Domains entitlement + AASA file on the server |
| **Transport** | `.onOpenURL { }` | `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` |
| **Works from a web page?** | No | Yes — tap in Safari opens the app |
| **Works if app not installed?** | No — the OS shows an error | Yes — falls back to your website |
| **Can another app claim the scheme?** | Yes — `notes://` is not owned by anyone | No — the AASA proves you own the domain |
| **Apple's stance** | Fine for internal/inter-app plumbing | Required for user-facing links |

The senior position: **use a custom scheme for plumbing you control (your own widget tapping into your own app), and universal links for anything a human might click.** Both decode through the *same* `DeepLink.path(for:)`. You write the decoder once; the two transports just hand it a URL.

The universal-link transport looks like this:

```swift
struct NotesList: View {
    @State private var path: [Route] = []
    let store: NotesStore

    var body: some View {
        NavigationStack(path: $path) { /* … as before … */ }
            .onOpenURL { url in apply(url) }                          // custom scheme
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }   // universal link
                apply(url)
            }
    }

    private func apply(_ url: URL) {
        if let newPath = DeepLink.path(for: url) { path = newPath }
    }
}
```

Same `apply(_:)`. Same decoder. The only difference is which modifier delivered the URL. That is the payoff of writing a transport-agnostic decoder: adding a second transport is two lines, not a second implementation.

## 2.6 — What the universal-link transport requires on the server side

For a universal link to *reach* `onContinueUserActivity`, two things must be true, and both are about proving you own the domain. (You wire this end to end in Challenge 1; here is the shape.)

**1. The Associated Domains entitlement** lists the domains your app claims:

```
applinks:notes.example.com
```

This goes in the target's `Signing & Capabilities → Associated Domains`. In the simulator you can use a local domain; on a device it must match a domain you actually serve.

**2. The `apple-app-site-association` (AASA) file** is served from that domain and declares which paths map to your app:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.crunchlabs.HelloNotes"],
        "components": [
          { "/": "/open/*", "comment": "Opens a specific note" }
        ]
      }
    ]
  }
}
```

The AASA rules that trip everyone:

- It must be served at **`https://<domain>/.well-known/apple-app-site-association`** (the `.well-known` location; the bare-root location is legacy).
- It must be served over **HTTPS** with **no redirects** and `Content-Type: application/json` (the `.json` extension on the file itself is *not* used — the file has no extension).
- `appIDs` is `<TeamID>.<BundleID>`. Get the Team ID wrong and iOS silently refuses to associate.
- iOS fetches the AASA at install time (and periodically), via Apple's CDN. In the simulator, a freshly-installed app fetches it on first install; Challenge 1 shows the `simctl` trick to force it locally without a public domain or a paid account.

The thing to internalize: **the AASA is how the OS verifies the link is allowed to open your app.** It is a security boundary, which is exactly why universal links cannot be spoofed and custom schemes can. The decoder does not change; the *transport's trust model* does.

## 2.7 — The full pipeline, drawn

Putting the whole week together, here is the data flow for "a tap opens a note," regardless of source:

```text
   ┌─────────────┐   ┌──────────────┐   ┌────────────────────┐
   │ Messages /  │   │ Spotlight /  │   │ Push notification /│
   │ Safari tap  │   │ widget tap   │   │ cold launch URL    │
   └──────┬──────┘   └──────┬───────┘   └─────────┬──────────┘
          │  https://…       │  notes://           │  either
          ▼                  ▼                     ▼
   onContinueUserActivity   onOpenURL          onOpenURL
   (NSUserActivityType-     (custom scheme)    (launch URL,
    BrowsingWeb)                                fires after onAppear)
          │                  │                     │
          └──────────────────┼─────────────────────┘
                             ▼
              DeepLink.path(for: url) -> [Route]?      ← pure, tested, total
                             │
                       (if non-nil)
                             ▼
                   path = newPath  (+ selectedTab if tabbed)   ← atomic assignment
                             │
                             ▼
              NavigationStack diffs old vs new path
                             ▼
              right screen, right depth, one animation
```

Every arrow into `DeepLink.path(for:)` carries a `URL`. Every arrow out is a `[Route]`. The middle is one pure function. Restoration plugs into the same `path` via `SceneStorage`. The legacy model has no equivalent middle box — it has a tangle of booleans where the box should be, which is why it breaks at every arrow.

## 2.8 — Defending this in a code review

When a teammate proposes the `isActive` model (because they found it on Stack Overflow), here is the review comment that wins, with concrete failure modes rather than taste:

> "Let's model navigation as a `[Route]` path instead of `isActive` booleans. Three concrete reasons:
> (1) **Depth.** Product already wants `open/<id>/tag/<id>`. An array gives us arbitrary depth for free; booleans give us a coordination bug per level.
> (2) **Atomicity.** A warm deep link with `isActive` flips two bindings and visibly double-animates — I can reproduce it. `path = newPath` is one assignment, one transition.
> (3) **Restoration + testing.** `Route: Codable` writes straight to `SceneStorage` for cold-launch restoration, and `DeepLink.path(for:)` is a pure function we unit-test without a simulator. The boolean model has no single value to store or to assert against."

That is the senior move: not "the new API is newer," but "here are the three bugs the old model ships and the new one cannot."

## 2.9 — Two failure modes worth seeing before you ship

Two bugs catch nearly everyone the first time they wire deep links into a real app. Both are easy to fix once you have seen them, and miserable to debug if you have not.

**The conditional-root drop.** A common structure is a root view that shows a loading spinner until the store finishes loading, then swaps in the navigation stack:

```swift
// BUG: onOpenURL is on a view that doesn't exist yet at cold-launch delivery.
var body: some View {
    if store.isLoaded {
        NotesList(store: store)
            .onOpenURL { url in apply(url) }   // <- attached to a conditional child
    } else {
        ProgressView()
    }
}
```

On a cold launch, the launch URL is delivered as soon as the scene connects — which may be *before* `store.isLoaded` flips true, so the `NotesList` (and its `onOpenURL`) does not exist yet. The URL is dropped silently. The fix is to attach `onOpenURL` to a view that is **always** present and buffer the URL until the app is ready:

```swift
// FIX: handler is always present; buffer the link until the store is loaded.
@State private var pendingURL: URL?

var body: some View {
    Group {
        if store.isLoaded { NotesList(store: store) } else { ProgressView() }
    }
    .onOpenURL { url in pendingURL = url }
    .onChange(of: store.isLoaded) { _, loaded in
        if loaded, let url = pendingURL { apply(url); pendingURL = nil }
    }
}
```

The principle generalizes: **the deep-link handler must live above every conditional in your view tree, and if your app has an async startup, buffer the URL until startup completes.** This is the single most common "works warm, drops cold" bug.

**The stale-id push.** A deep link names a note by `id`. By the time the link arrives, that note may have been deleted (synced away on another device, removed by the user). If your destination force-unwraps `Note.find(id)!`, the app crashes on a link to a deleted note. The decoder is *not* the place to validate existence — the decoder is pure and has no store. Validate in the destination view, and degrade gracefully:

```swift
case .note(let id):
    if let note = store.note(id: id) {
        NoteDetailView(note: note)
    } else {
        ContentUnavailableView("Note not found", systemImage: "questionmark.folder",
                               description: Text("This note may have been deleted."))
    }
```

The division of labour is the lesson: **the decoder validates that the URL is well-formed (a valid UUID); the view validates that the referenced thing still exists.** Keep them separate. A pure decoder cannot check existence, and a view that assumes existence crashes on stale links.

## 2.10 — What to take away

- A deep link, modelled correctly, is a **pure function `(URL) -> [Route]?`**. Write it with no SwiftUI dependency; unit-test it in milliseconds.
- The legacy `isActive` model fails three ways — no arbitrary depth, warm-link animation glitches, and no serializable/testable navigation value. These are structural, not fixable by effort.
- The value-typed model removes all three: arrays have depth, `path = newPath` is atomic, and `Route: Codable` serializes for both `SceneStorage` restoration and URL decoding.
- `onOpenURL` fires for **both warm and cold launch** — one handler, two lifecycles. Put it on the always-present root so the cold-launch URL is not dropped.
- Custom schemes and universal links are **two transports for one decoder**. Custom scheme = your plumbing; universal link = anything a human clicks. Universal links require the Associated Domains entitlement and an AASA file that proves domain ownership.
- A deep link applied warm and the same link applied cold land on the **identical** screen — because both run the same `apply(url)` against the same `path`. That is the README's second contract, and it is a consequence of the model, not extra work.

Next: the exercises. You will build the value-typed stack, persist it across a cold launch, and wire `onOpenURL` to the decoder you just read.
