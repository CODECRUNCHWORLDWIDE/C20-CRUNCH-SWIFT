# Mini-Project — Notes v1: Keychain + CloudKit edition

This week Notes v1 gets a secure credential store and multi-device sync. You will take the **Notes v1** app from Week 13 — the one wired to the Vapor `notes-api` with the `NotesClient` actor — store its auth token in the **Keychain** with the correct accessibility class, flip the SwiftData store to **CloudKit private-database sync**, refactor the schema to satisfy CloudKit's constraints, and then run the **two-device edit-conflict drill** until the right edit wins every time, deterministically.

This is a *compounding* project. It is not a new app. You start from the Week 13 codebase — the notes app with the networking layer and offline write-replay — and you add the secure-storage and sync layers underneath it. The point of the week is to feel that "make the same data appear on every device" is one config line plus a pile of *correctness* work: the schema constraints, the conflict policy, and the silent-failure observer. The UI barely changes. The data layer changes completely.

---

## Where you're starting from

Your Week 13 app has, roughly:

- A SwiftData store (`Note`, `Tag`) from Week 10, with `@Attribute(.unique) var name` on `Tag` and non-optional relationships.
- A `NotesClient` actor that calls the Vapor `notes-api`, attaching an auth token to each request — currently the token is held in memory (or worse, `UserDefaults`).
- Offline write-replay: writes go to SwiftData when the server is unreachable and replay when it returns.
- The Week 9 navigation (`NavigationStack`/`NavigationSplitView`, value-typed links, the `notes://open/:id` deep link).

If you don't have a clean Week 13 checkpoint, the minimal version (a SwiftData notes app with a fake login that produces a token) is enough — the Keychain and CloudKit work is the same either way.

## What you're building toward

By the end you have:

- The auth token in the **Keychain** via a typed `KeychainStore`, with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, attached to every `NotesClient` request and wiped on logout.
- A **CloudKit-safe** schema: every relationship optional, no `@Attribute(.unique)`, every property defaulted.
- **CloudKit private-database sync** turned on via `ModelConfiguration(cloudKitDatabase:)`, with the iCloud + Background Modes capabilities configured.
- A **sync observer** logging import/export events and their errors, so a silent export failure surfaces immediately.
- A **deterministic conflict-resolution policy** (record-level LWW by `updatedAt`, with a field-level merge stretch) written as a pure function and unit-tested.
- A passing **two-device conflict drill**: edit the same note differently on two offline clients, reconnect, and the later-edited version wins — the same on both.
- A passing **token-leak test**: the token is *not* extractable from the `UserDefaults` plist (it's in the Keychain).

---

## Milestone 1 — Move the token to the Keychain (≈ 1 h)

Replace whatever currently holds the token with the `KeychainStore` from exercise 2.

```swift
import Foundation

enum AuthStore {
    static let keychain = KeychainStore(service: "com.crunch.notes.auth")
    // default accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    static func save(token: String) throws {
        try keychain.setString(token, account: "primary")
    }
    static var token: String? {
        try? keychain.getString(account: "primary")
    }
    static func clear() {
        try? keychain.delete(account: "primary")
    }
}
```

Wire it into the `NotesClient` so every request reads the token from the Keychain:

```swift
actor NotesClient {
    private let session: URLSession

    func authorizedRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = AuthStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // ...the rest of the Week 13 client, unchanged...
}
```

On login, `try AuthStore.save(token: response.accessToken)`. On logout, `AuthStore.clear()` — and because the token is `ThisDeviceOnly`, logout means *gone*, not "still in a backup somewhere."

Decisions you must defend in review:

- **Why the Keychain, not `UserDefaults`?** A token is a secret; `UserDefaults` is a plaintext backed-up plist. (You proved this in the challenge.)
- **Why `…AfterFirstUnlockThisDeviceOnly`?** Background offline-replay may run while locked (needs `AfterFirstUnlock`), and the session must not transplant to a new device from a backup (needs `ThisDeviceOnly`).

## Milestone 2 — Make the schema CloudKit-safe (≈ 1.5 h)

Refactor `Note` and `Tag` to satisfy CloudKit's three constraints. Compare carefully to the Week 10 versions.

```swift
import Foundation
import SwiftData

@Model
final class Note {
    var title: String = ""            // defaulted (records sync out of order)
    var body: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now    // the conflict tiebreaker — bumped on EVERY edit
    var tags: [Tag]? = []             // optional to-many, CloudKit-safe

    init(title: String = "", body: String = "",
         createdAt: Date = .now, updatedAt: Date = .now, tags: [Tag]? = []) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }

    /// Every mutation routes through here so updatedAt is never stale.
    func edit(title: String? = nil, body: String? = nil, now: Date = .now) {
        if let title { self.title = title }
        if let body  { self.body = body }
        self.updatedAt = now
    }
}

@Model
final class Tag {
    var name: String = ""             // NO .unique — CloudKit forbids it; dedupe in app logic
    var notes: [Note]? = []

    init(name: String = "", notes: [Note]? = []) {
        self.name = name
        self.notes = notes
    }
}
```

The changes, each mapped to its CloudKit rule:

- **`@Attribute(.unique)` removed** from `Tag.name` — CloudKit has no uniqueness constraint. You now dedupe by name in app logic (Milestone 3).
- **Relationships optional** (`tags: [Tag]?`) — the related records may not have synced yet.
- **Every non-optional property defaulted** — a record predating a new field needs a fill-in value.

Because `.unique` is gone, your tag-add logic must reuse an existing tag by name *in code*:

```swift
func tag(named raw: String, in context: ModelContext) throws -> Tag {
    let name = raw.trimmingCharacters(in: .whitespaces).lowercased()
    let existing = try context.fetch(
        FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
    ).first
    if let existing { return existing }
    let tag = Tag(name: name)
    context.insert(tag)
    return tag
}
```

This isn't bulletproof across devices (two devices can both create "swift" offline), which is exactly why you also need the conflict-resolution step to merge duplicates — but it handles the common single-device case and keeps the local store clean.

## Milestone 3 — Turn on CloudKit sync (≈ 1.5 h)

In Xcode, on the app target: add the **iCloud** capability, check **CloudKit**, and create a container `iCloud.com.crunch.notes`. Add the **Background Modes** capability with **Remote notifications**. (Both need the paid Apple Developer account.) Then the one line:

```swift
import SwiftUI
import SwiftData

@main
struct NotesApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema([Note.self, Tag.self])
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.crunch.notes")
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create syncing ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(container)
    }

    init() { observeSync() }
}
```

Install the **sync observer** (lecture 2, §6) so a silent export failure shows up:

```swift
import CoreData
import OSLog

let syncLog = Logger(subsystem: "com.crunch.notes", category: "cloudkit")

func observeSync() {
    NotificationCenter.default.addObserver(
        forName: NSPersistentCloudKitContainer.eventChangedNotification,
        object: nil, queue: .main
    ) { notification in
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }
        if let error = event.error {
            syncLog.error("CloudKit \(String(describing: event.type)) FAILED: \(error.localizedDescription)")
        } else if event.endDate != nil {
            syncLog.log("CloudKit \(String(describing: event.type)) finished")
        }
    }
}
```

Run on two Simulators signed into the same iCloud account. Create a note on one; it appears on the other within a few seconds. Watch the log for `export finished` / `import finished`. If you see an `export FAILED` with a schema error, you missed a constraint in Milestone 2 — fix the schema, delete the app from both Simulators, and retry (a bad schema can poison the CloudKit record type; the CloudKit Console lets you reset the development schema).

**No-account fallback.** Without the paid account you can't sync between devices, but you can still: keep the CloudKit-safe schema, compile the config, run the conflict-resolution *logic* tests (Milestone 4), and demonstrate the local store works exactly as before. Note in your README which milestones you ran locally vs synced.

## Milestone 4 — The deterministic conflict policy (≈ 1.5 h)

Bring in the pure-function resolver from exercise 3 and wire it into the app's edit path. The policy: record-level last-write-wins by `updatedAt`, with the every-mutation-bumps-`updatedAt` discipline guaranteeing the tiebreak is valid.

```swift
struct NoteSnapshot: Sendable, Equatable {
    var title: String
    var body: String
    var updatedAt: Date
}

/// Deterministic LWW — the same on every device regardless of arrival order.
func resolveLWW(_ a: NoteSnapshot, _ b: NoteSnapshot) -> NoteSnapshot {
    if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt ? a : b }
    return a.body >= b.body ? a : b     // stable tiebreak on exact-timestamp ties
}
```

Write the unit test that proves order-independence (`resolveLWW(a,b) == resolveLWW(b,a)`), and the test that the later edit wins. These run with `isStoredInMemoryOnly` and *no CloudKit*, which is the whole point — your conflict logic is testable without two devices.

For the **field-level merge stretch**, track a per-field timestamp and keep non-overlapping edits from both devices (exercise 3, `mergeFields`). Wire it so that a title edit on the iPhone and a body edit on the iPad both survive a sync.

## Milestone 5 — The two-device conflict drill (≈ 1.5 h)

The acceptance bar for the sync half of the week (needs the paid account + two clients on one iCloud account).

1. Run the app on **two Simulators** (or a Simulator + a device) both signed into the **same iCloud account**.
2. Create a note "Standup" with body "blockers?" on client A. Confirm it syncs to client B.
3. Take **both offline** (`Features ▸ Toggle Network`, or airplane mode, on each).
4. On client A, edit the body to "blockers + demo". On client B, edit the body to "blockers, then planning". Note the order you made the edits.
5. Bring **both back online**. Sync runs.
6. With your `updatedAt` policy, the **later-edited** version wins — deterministically, the same on both clients. Confirm both clients converge to the same body (not one showing A's version and the other showing B's — that divergence is the bug determinism prevents).
7. Repeat with the field-level merge (if you did the stretch): edit the *title* on A and the *body* on B; both survive.

Record this as a short clip or screenshot sequence in your repo's README. "Two devices, conflicting edits, deterministic winner, no data lost" is the deliverable.

## Milestone 6 — The token-leak test (≈ 0.5 h)

Prove the credential half of the week's promise.

1. Log in (produce and store a token through `AuthStore`).
2. From the command line, try to read it out of the preferences plist:
   ```bash
   DATA=$(xcrun simctl get_app_container booted com.crunch.notes data)
   plutil -p "$DATA/Library/Preferences/com.crunch.notes.plist"
   ```
3. The token is **not** there — it's in the Keychain, not `UserDefaults`. Confirm the app still authenticates (the `NotesClient` reads the token from the Keychain).

Record the (empty-of-token) plist output as evidence.

---

## Acceptance criteria

- [ ] The auth token is stored in the **Keychain** via a typed `KeychainStore` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, read by the `NotesClient`, and wiped on logout. It is **not** in `UserDefaults` (proven by `plutil -p`).
- [ ] The schema is **CloudKit-safe**: every relationship optional, no `@Attribute(.unique)`, every non-optional property defaulted — and you can map each change to its CloudKit rule.
- [ ] Tag dedup is done **in app logic** (reuse by name), since store-enforced uniqueness is gone.
- [ ] **CloudKit private-database sync** is enabled via `ModelConfiguration(cloudKitDatabase:)`, with the iCloud + Background Modes capabilities configured (or the no-account fallback documented).
- [ ] The **sync observer** logs import/export events and their errors.
- [ ] Conflict resolution is a **deterministic pure function** of two snapshots, unit-tested for order-independence and "later edit wins."
- [ ] **The two-device conflict drill passes** (with the account): conflicting offline edits resolve to the later-edited version, the same on both devices, with no data lost.
- [ ] The Week 13 networking (offline write-replay) and Week 9 navigation **still work** unchanged.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict-concurrency.

## Stretch goals

- **Field-level merge.** Track a per-field `updatedAt` and keep non-overlapping edits from two devices (exercise 3, `mergeFields`). Demonstrate a title edit and a body edit both surviving a sync.
- **iCloud account-status UI.** Detect "not signed into iCloud" with `CKContainer.accountStatus` and show a subtle "sync paused — not signed into iCloud" banner. Never *block* the app on iCloud.
- **Tag-merge on conflict.** When two devices created the same-named tag offline, dedupe them on the next sync (merge their notes, delete the duplicate) — the practical consequence of losing `.unique`.
- **A coordinated App Group export.** Write a "shared snapshot" file to an App Group container with `NSFileCoordinator`, and read it from a tiny widget (or a second target) to prove coordinated multi-process access (lecture 1, §5–6).

## What this milestone earns you

You can now persist a sensitive credential in the Keychain correctly and resolve a multi-device sync conflict deterministically — the literal "skill earned" line for the week. More than that: you turned a single-device app into a multi-device one with one config line and a pile of *correctness* work, and you can name every trade-off — the constraints CloudKit forced, the uniqueness you moved into app logic, the conflict policy you chose on purpose. Week 15 takes this exact app onto a *physical device* and profiles it with Instruments — and CloudKit sync merges are a classic source of the main-thread hangs you'll hunt there. A solid, correct data layer is the thing you profile; you built it this week.
