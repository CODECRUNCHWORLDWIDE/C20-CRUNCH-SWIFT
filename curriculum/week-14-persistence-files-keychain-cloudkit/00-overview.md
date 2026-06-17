# Week 14 — Persistence II: Files, Keychain, SwiftData + CloudKit

Welcome to Week 14 of **C20 · Crunch Swift**. Week 10 taught you SwiftData — one schema, one on-disk SQLite store, durable across a relaunch. That was *the* persistence answer for structured app data, and it remains the default. But "where do I put this byte?" is not always answered by "in a `@Model`." Some bytes are big and opaque — a 40 MB video, a cached PDF, an exported archive — and belong on the file system, not inline in a database. Some bytes are secret — an auth token, a refresh token, an encryption key — and belong in the **Keychain**, the only storage on iOS backed by hardware and an access-control policy, never in `UserDefaults` and never in a plist. And some bytes need to be the *same* on the user's iPhone, iPad, and Mac without you running a server — which is what **CloudKit** sync over a SwiftData store gives you, along with a multi-device edit-conflict problem you have to resolve deterministically or lose data.

This week is the "right place for each byte" week. By Friday you will have a decision tree you can defend in a code review — file system vs Keychain vs SwiftData vs CloudKit — and you will have written the code for all four corners of it. You will store the user's auth token in the Keychain with the correct accessibility class (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, and you will be able to say *why* that one and not `kSecAttrAccessibleAlways`, which Apple deprecated for a reason). You will write a file to the app sandbox atomically, coordinate access to it so a Files-app edit and your app's write don't corrupt each other, and share it with an extension through an App Group container. And you will turn on CloudKit sync on the SwiftData store from Week 10 with a one-line `ModelConfiguration` change — then discover that the one line is the easy part, and the schema constraints CloudKit imposes (every relationship optional, no `.unique`, no `@Attribute(.unique)`) plus the two-device conflict it surfaces are the actual engineering.

The mental shift this week is from "I have *a* persistence layer" to "I have a persistence *strategy* — a threat model and a durability model per category of data, and I can name the trade-off I made for each." A junior engineer reaches for `UserDefaults` for everything because it is one line. A senior engineer asks, for every byte, three questions: *Does it need to be secret? Does it need to survive a reinstall, or must it be wiped on logout? Does it need to be on every device?* The answers route the byte to one of four stores, and getting the routing wrong is how you leak a token to a backup, corrupt a file under concurrent access, or silently lose a user's edit when two devices disagree.

We close the week by adding CloudKit sync to **Notes v1** — the same notes app you have been compounding since Phase II, now wired to the Vapor `notes-api` from Week 13. You will store the auth token in the Keychain, flip the SwiftData store to `cloudKitDatabase: .private`, reproduce a deliberate two-device edit conflict in two Simulators signed into the same iCloud account, and write the conflict-resolution code that picks a deterministic winner — because "last write wins" is a *policy*, not an accident, and a senior reviewer wants to see you chose it on purpose.

## Learning objectives

By the end of this week, you will be able to:

- **Route** any piece of app data to the correct store using an explicit threat-model decision tree — file system, Keychain, SwiftData, or CloudKit — and state the durability and secrecy trade-off you made for each.
- **Navigate** the iOS file system with `FileManager` — the sandbox layout (`Documents`, `Library/Caches`, `Application Support`, `tmp`), `URL.applicationSupportDirectory` and friends, the back-up-vs-purgeable distinction, and an **App Group** container shared with an extension.
- **Write** files **atomically** (`.atomic` / `Data.WritingOptions`) so a crash mid-write never leaves a half-written file, and **coordinate** access with `NSFileCoordinator` / `NSFilePresenter` so an external editor (Files app, another process) and your app don't corrupt each other.
- **Store** a secret in the **Keychain** with the right `kSecClass`, the right `kSecAttrAccessible` class, and — where appropriate — an **access group** for sharing with an extension and `kSecAttrSynchronizable` for iCloud Keychain, and explain why the Keychain (not `UserDefaults`) is the only correct home for a token.
- **Enable** CloudKit sync on a SwiftData store with `ModelConfiguration(cloudKitDatabase:)`, and refactor the schema to satisfy CloudKit's constraints (all relationships optional, no uniqueness constraints, no unstored required properties).
- **Reproduce** a two-device edit conflict deterministically and **resolve** it with a chosen policy (last-write-wins by `updatedAt`, or a field-level merge), explaining why the policy must be deterministic.
- **Recognise** the persistence footguns — a token in `UserDefaults`, a non-atomic write, a file in `Documents` that bloats iCloud Backup, a `.unique` constraint that breaks CloudKit, a conflict policy that loses data — and the production fix for each.

## Prerequisites

This week assumes you have completed **C20 weeks 1–13**, or have equivalent fluency. Specifically:

- You can model a **SwiftData** schema with `@Model`, `@Attribute`, and `@Relationship`, wire a `ModelContainer`, and query with `@Query`/`#Predicate` — Week 10. This week extends that store with CloudKit; you need the Week 10 vocabulary cold.
- You understand `Sendable`, `@MainActor`, and actor isolation — Week 4. Keychain calls are synchronous C APIs you wrap; CloudKit sync runs on background queues and merges into the main context, so the Week 4 rules apply.
- You have built a **networking layer** with `URLSession`, typed errors, and offline-detection — Week 13. The auth token you store in the Keychain this week is the one the `NotesClient` from Week 13 attaches to every request.
- You have the **Notes v1** app from Week 13 checked into Git, wired to the Vapor `notes-api`. This week's mini-project compounds on it: add the Keychain-stored token and CloudKit sync.

**Toolchain.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. The file-system and Keychain work runs entirely in the Simulator with **no Apple Developer membership** (the membership requirement starts Week 15). CloudKit, however, needs a **paid Apple Developer account and the iCloud + CloudKit capability** to actually sync between devices — you can write and compile all the CloudKit code without it, but the two-device conflict drill needs two Simulators (or a Simulator + a device) signed into the same iCloud account, which needs the entitlement. We flag exactly which milestones need the account and give a no-account fallback for each.

## Topics covered

- **The decision tree.** Four stores, three questions (secret? wiped-on-logout-or-durable? on-every-device?). When `UserDefaults` is acceptable (small, non-secret, non-critical settings) and when it is a security bug (anything secret, anything large, anything that must survive correctly).
- **The iOS sandbox.** The container layout — `Documents` (user data, backed up, visible in Files if you opt in), `Library/Application Support` (app data, backed up, hidden), `Library/Caches` (purgeable, *not* backed up, the OS can delete it), `tmp` (ephemeral). The `URL.documentsDirectory` / `.applicationSupportDirectory` / `.cachesDirectory` accessors and why the directory you pick is a backup-and-purge decision.
- **`FileManager`.** Creating, reading, moving, copying, deleting; `contentsOfDirectory`; `createDirectory(withIntermediateDirectories:)`; `fileExists`; `attributesOfItem`; setting `URLResourceValues.isExcludedFromBackup` so a large cache doesn't bloat iCloud Backup.
- **Atomic writes.** `Data.write(to:options: .atomic)` and why it writes to a temp file then renames — so a crash or power loss mid-write never leaves a half-written file. The difference between atomic *write* and atomic *transaction*.
- **File coordination.** `NSFileCoordinator` and `NSFilePresenter` for the case where another process (the Files app, a share extension, another instance) touches the same file — coordinated reads/writes that serialise access and avoid corruption. When you need it (shared containers, document-based apps, iCloud Drive) and when you don't (private sandbox files only your app touches).
- **App Group containers.** `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`, the shared container an app and its extension (widget, share extension, NSE) both read, the App Group entitlement, and the rule that a shared container needs coordination because two processes touch it.
- **The Keychain.** The `Security` framework C API — `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`; `kSecClass` (`kSecClassGenericPassword` for tokens); the **`kSecAttrAccessible`** accessibility classes and the threat each defends against; `kSecAttrAccessGroup` for extension sharing; `kSecAttrSynchronizable` for iCloud Keychain; wrapping the C API in a typed Swift `KeychainStore`.
- **Keychain accessibility classes.** `kSecAttrAccessibleWhenUnlocked`, `…AfterFirstUnlock`, the `…ThisDeviceOnly` variants, and which to pick for an auth token (`…AfterFirstUnlockThisDeviceOnly` — available to background refresh after first unlock, never leaves the device, never restored to a new device from backup). Why `kSecAttrAccessibleAlways` is deprecated.
- **SwiftData + CloudKit.** `ModelConfiguration(cloudKitDatabase: .private("iCloud.…"))`, the iCloud + CloudKit capability and container, the private vs shared vs public CloudKit databases, and how SwiftData mirrors the schema into a CloudKit record type.
- **CloudKit schema constraints.** Why every relationship must be optional, why `@Attribute(.unique)` is forbidden, why every non-optional property needs a default — and how to refactor a Week 10 schema to comply without losing the local-only ergonomics.
- **Conflict resolution.** What a conflict *is* (two devices edit the same record before sync), why CloudKit's default last-writer-wins can silently lose a field, and how to implement a deterministic resolution policy (timestamp-based LWW, or a field-level three-way merge) you chose on purpose.
- **Persistence footguns.** Token in `UserDefaults`/plist, secret in a backed-up file, non-atomic write, uncoordinated shared-container access, `.unique` on a CloudKit model, a non-deterministic conflict policy, and a cache in `Documents` bloating backups.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | The decision tree; the sandbox; `FileManager`; atomic writes       |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | File coordination; App Groups; the Keychain C API + `KeychainStore` |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Keychain accessibility classes; threat model; SwiftData + CloudKit |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | CloudKit schema constraints; conflict resolution; challenge        |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — Keychain token + CloudKit sync on Notes v1          |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; the two-device conflict drill              |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                         |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's File System Programming Guide, the Keychain Services reference, the SwiftData + CloudKit articles, the WWDC sessions, and the canonical community writing on Keychain wrappers and conflict resolution |
| [lecture-notes/01-files-and-the-keychain.md](./02-lecture-notes/01-files-and-the-keychain.md) | The decision tree, the sandbox, `FileManager`, atomic writes, file coordination, App Groups, and the Keychain end to end — the C API, the accessibility classes, and a typed `KeychainStore` |
| [lecture-notes/02-swiftdata-cloudkit-and-conflict-resolution.md](./02-lecture-notes/02-swiftdata-cloudkit-and-conflict-resolution.md) | Turning on CloudKit sync, the schema constraints CloudKit imposes, what a conflict is, and a deterministic resolution policy with measured before/after |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-sandbox-and-atomic-writes.md](./03-exercises/exercise-01-sandbox-and-atomic-writes.md) | Map the sandbox, write a file atomically to the right directory, exclude a cache from backup, and prove it with the file inspector |
| [exercises/exercise-02-keychain-store.swift](./03-exercises/exercise-02-keychain-store.swift) | Wrap the Keychain C API in a typed `KeychainStore`, store and read a token with the correct accessibility class, and test the round-trip |
| [exercises/exercise-03-cloudkit-conflict-resolution.swift](./03-exercises/exercise-03-cloudkit-conflict-resolution.swift) | Model a CloudKit-safe `@Model`, simulate a two-device conflict, and resolve it with a deterministic last-write-wins policy |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-token-leak-then-lockdown.md](./04-challenges/challenge-01-token-leak-then-lockdown.md) | Plant the classic "token in `UserDefaults`" leak, prove it leaks (read it out of the backup), then lock it down in the Keychain with the right accessibility class — and document the threat each step closes |
| [quiz.md](./05-quiz.md) | 13 questions on the decision tree, the sandbox, atomic writes, the Keychain, CloudKit constraints, and conflict resolution |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec for "Notes v1 — Keychain + CloudKit edition": store the token in the Keychain, sync over CloudKit, reproduce and resolve a two-device conflict |

## The "right place for each byte" promise

Week 10 gave you "survives a cold launch." Week 13 gave you "survives the server being down." Week 14 adds the persistence contract a security-conscious reviewer actually checks:

> **No secret is recoverable from a backup, no file write is corruptible by a crash, and no multi-device edit silently loses data.** The auth token lives in the Keychain with `…ThisDeviceOnly`, so it is never written to an unencrypted backup or restored to a thief's device. Every file write is `.atomic`, so a crash mid-write leaves the old file intact, never a half-written one. And when two devices edit the same note offline and then sync, the conflict resolves by a policy you can name, not by luck.

You will *prove* the first one by trying to read the token out of the app's backup container and failing — and contrasting it with the `UserDefaults` value sitting in plaintext right next to it. "It worked on my device" is not the test; "an attacker with your backup can't get your token" is.

## A note on what's not here

Week 14 is the *storage placement and sync* week. It deliberately does **not** cover:

- **CryptoKit and the Secure Enclave.** This week stores a token *securely* (in the Keychain) but does not *encrypt application data at rest* with your own keys, generate a hardware-backed key, or sign a request. `SymmetricKey`, `AES.GCM`, `Curve25519`, and `SecureEnclave.P256` are Week 17. The Keychain protects the key; CryptoKit *uses* keys — different jobs, taught apart on purpose.
- **Certificate pinning and ATS.** Locking down the *transport* (pinning the server's cert, configuring App Transport Security) is also Week 17. This week the network is the Week 13 `NotesClient` over HTTPS; we secure the *storage*, not the wire.
- **A custom sync engine.** CloudKit gives you sync for free; the Phase IV capstone builds a *fallback* sync against the Vapor backend for when CloudKit is unavailable, with an outbox and replay. That is a much bigger system. This week uses SwiftData's built-in CloudKit mirroring and resolves the conflict it surfaces — not a hand-rolled sync engine.

The point of Week 14 is narrow and deep: four stores, the threat model that routes data between them, the Keychain done correctly, and the one CloudKit conflict you must resolve deterministically or lose a user's edit.

## Up next

Continue to **Week 15 — On-device deployment, performance with Instruments** once you have shipped this week's mini-project and proven the token can't be read out of a backup. Week 15 is where the **Apple Developer Program membership becomes required** — you deploy to a physical device, profile it with Instruments, and fix a real hang and a real hitch. The CloudKit work you did this week is the first thing you will profile on-device, because sync merges and background fetches are a classic source of main-thread hangs. Buy the $99 membership this week if you haven't — Week 15 needs it on day one, and we gave you two weeks of lead time on purpose.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
