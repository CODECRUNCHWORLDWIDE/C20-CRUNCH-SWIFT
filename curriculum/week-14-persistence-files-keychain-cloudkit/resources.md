# Week 14 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. Note that *running* CloudKit between devices needs the paid Apple Developer account, but *reading* every doc and *compiling* every sample does not.

## Required reading (work it into your week)

- **File System Programming Guide — "About the iOS File System."** The sandbox layout, which directory is backed up, which is purgeable:
  <https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup>
- **`FileManager`.** The file CRUD API reference — creating, moving, listing, attributes:
  <https://developer.apple.com/documentation/foundation/filemanager>
- **"Storing keys in the keychain."** Apple's canonical Keychain guide — read this before you touch `SecItemAdd`:
  <https://developer.apple.com/documentation/security/storing-keys-in-the-keychain>
- **"Restricting keychain item accessibility."** The `kSecAttrAccessible` classes and the threat each defends — this is lecture 1, §8:
  <https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility>
- **"Syncing model data across a person's devices" (SwiftData + CloudKit).** The one-line config and the schema constraints — central to lecture 2:
  <https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices>

## The Keychain and Security framework (reference, skim don't memorize)

- **`SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete`:** <https://developer.apple.com/documentation/security/keychain-services>
- **`kSecClass` and item-class keys:** <https://developer.apple.com/documentation/security/item-class-keys-and-values>
- **`kSecAttrAccessible` values:** <https://developer.apple.com/documentation/security/item-attribute-keys-and-values>
- **Keychain access groups (`kSecAttrAccessGroup`):** <https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps>
- **iCloud Keychain (`kSecAttrSynchronizable`):** <https://developer.apple.com/documentation/security/ksecattrsynchronizable>

## The file system (reference)

- **`Data.WritingOptions` (`.atomic`):** <https://developer.apple.com/documentation/foundation/data/writingoptions>
- **`NSFileCoordinator`:** <https://developer.apple.com/documentation/foundation/nsfilecoordinator>
- **`NSFilePresenter`:** <https://developer.apple.com/documentation/foundation/nsfilepresenter>
- **App Group containers (`containerURL(forSecurityApplicationGroupIdentifier:)`):** <https://developer.apple.com/documentation/foundation/filemanager/1412643-containerurl>
- **`URLResourceValues.isExcludedFromBackup`:** <https://developer.apple.com/documentation/foundation/urlresourcevalues/1780002-isexcludedfrombackup>

## CloudKit (reference)

- **CloudKit framework:** <https://developer.apple.com/documentation/cloudkit>
- **`NSPersistentCloudKitContainer`** (what SwiftData uses under the hood; its event/error API is in lecture 2): <https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer>
- **`CKContainer.accountStatus`** (detecting "not signed into iCloud"): <https://developer.apple.com/documentation/cloudkit/ckcontainer>
- **CloudKit Console** (inspect the records SwiftData mirrored): <https://icloud.developer.apple.com/dashboard/>

## WWDC sessions (free, watch in this order)

- **"Build great apps for tomorrow with today's SDKs"** — patterns, but the persistence parts are useful framing.
- **"Sync to iCloud with CloudKit"** (WWDC23) — the CloudKit sync model, private vs shared vs public:
  <https://developer.apple.com/videos/play/wwdc2023/10185/>
- **"Model your schema with SwiftData"** (WWDC23) — relationships and the constraints that matter when you add CloudKit:
  <https://developer.apple.com/videos/play/wwdc2023/10195/>
- **"What's new in SwiftData"** (WWDC24) — the CloudKit + history interplay relevant to sync and dedup:
  <https://developer.apple.com/videos/play/wwdc2024/10137/>
- **"Protect mutable state with Swift actors"** (WWDC21) — the concurrency rules that govern background sync merges:
  <https://developer.apple.com/videos/play/wwdc2021/10133/>

## The Keychain done right (why people get it wrong)

The raw Keychain C API is the most-misused secure-storage surface on iOS. These are the references that fix the common mistakes — token in `UserDefaults`, wrong accessibility class, no upsert.

- **OWASP Mobile — "Data Storage on iOS."** The canonical "where NOT to put a secret" list:
  <https://mas.owasp.org/MASTG/0x06d-Testing-Data-Storage/>
- **Apple — "Encrypting your app's files"** (data protection classes, which mirror the Keychain accessibility classes):
  <https://developer.apple.com/documentation/uikit/protecting-the-user-s-privacy/encrypting-your-app-s-files>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — Keychain and SwiftData articles.** Paul Hudson keeps these current per OS release:
  <https://www.hackingwithswift.com/quick-start/swiftdata>
- **Donny Wals — "SwiftData and CloudKit."** Production articles on the schema constraints and conflict behaviour:
  <https://www.donnywals.com/category/swift/>
- **Fatbobman's blog — the SwiftData + CloudKit deep dives.** The best long-form writing on what the mirror does and where it breaks:
  <https://fatbobman.com/en/>
- **Pol Piella — Keychain and persistence notes:**
  <https://www.polpiella.dev/>

## Open-source projects to read this week

You learn more from one hour reading a real Keychain wrapper than from three tutorials. Read how they query, upsert, and pick accessibility:

- **`kishikawakatsumi/KeychainAccess`** — the most-used Swift Keychain wrapper; read it to see the C API tamed, then write your own (don't depend on it for the exercise):
  <https://github.com/kishikawakatsumi/KeychainAccess>
- **`apple/sample-backyard-birds`** — Apple's SwiftData sample; the schema is a good reference for the CloudKit-safe shape:
  <https://github.com/apple/sample-backyard-birds>

## Tools you'll use this week

- **Xcode 16+** — `xcodebuild -version` to confirm.
- **`xcrun simctl get_app_container booted <bundle-id> data`** — find the app's data container so you can inspect the sandbox and (in the challenge) read `UserDefaults` plaintext out of it.
- **A plist/SQLite inspector** — `plutil -p <path>` prints a plist (you'll use it to read a leaked token out of `UserDefaults` in the challenge); `sqlite3` opens the SwiftData store.
- **CloudKit Console** (<https://icloud.developer.apple.com/dashboard/>) — see the record types SwiftData mirrored and inspect synced records. Needs the paid account.
- **The Simulator's `Features ▸ Toggle Network`** (or Network Link Conditioner) — force two clients offline for the conflict drill.

## Free books (chapter-level, not whole books)

- **Apple's "Security" and "SwiftData" documentation groups** read as free books; the Keychain Services article set and the SwiftData "Syncing" article are the two to read end to end.

## Paid books (optional, clearly marked)

- **"Practical SwiftData" — Donny Wals** (paid). The CloudKit chapter is the most production-focused treatment of the schema constraints and conflict behaviour in 2026.
- **"iOS App Security" — various** (paid). Older but the Keychain and data-protection chapters remain the clearest print explanation of the accessibility classes.

---

*If a link 404s, please open an issue so we can replace it.*
