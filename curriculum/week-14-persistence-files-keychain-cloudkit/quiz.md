# Week 14 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 15. Answer key with explanations at the bottom — don't peek.

---

**Q1.** Where should an OAuth access token be stored on iOS?

- A) `UserDefaults`, keyed by `"authToken"`.
- B) A JSON file in `Documents`.
- C) The **Keychain**, as a generic password with an appropriate accessibility class.
- D) A SwiftData `@Model`.

---

**Q2.** Why is storing a token in `UserDefaults` a security bug, not just a style choice?

- A) `UserDefaults` is slow.
- B) `UserDefaults` is an **unencrypted plist** in `Library/Preferences` that is backed up in plaintext — anyone with the backup can read the token.
- C) `UserDefaults` has a 1 KB size limit.
- D) It isn't a bug; `UserDefaults` is encrypted at rest.

---

**Q3.** You have a 150 MB downloaded video the app can re-download. Which directory?

- A) `Documents` — so it's backed up.
- B) `Library/Application Support`.
- C) `Library/Caches` — not backed up, and the OS may purge it under storage pressure (you re-download).
- D) `UserDefaults`.

---

**Q4.** What does `Data.write(to:options: .atomic)` guarantee?

- A) The write is encrypted.
- B) The write happens on a background thread.
- C) The file on disk is always either the complete old contents or the complete new contents — never half-written — because it writes to a temp file and renames.
- D) Multiple files are written as one transaction.

---

**Q5.** When do you need `NSFileCoordinator` rather than a plain atomic write?

- A) Always, for every file write.
- B) Never — atomic writes make coordination obsolete.
- C) When a **second process** can touch the same file (an App Group container shared with an extension, a Files-app-editable document, iCloud Drive).
- D) Only for files larger than 100 MB.

---

**Q6.** For an auth token that a background-refresh task must read while the screen is locked, and that must never be restored to a new device from a backup, which accessibility class?

- A) `kSecAttrAccessibleWhenUnlocked`
- B) `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- C) `kSecAttrAccessibleAlways`
- D) `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

---

**Q7.** Why does a correct `KeychainStore.set(_:account:)` try `SecItemUpdate` before `SecItemAdd`?

- A) Update is faster.
- B) `SecItemAdd` returns `errSecDuplicateItem` if the item already exists, so a naive add-only `set` fails on the second write; the upsert updates if present and adds if not.
- C) `SecItemAdd` doesn't accept a value.
- D) Update encrypts; add doesn't.

---

**Q8.** You enable `cloudKitDatabase: .private(...)` on a Week 10 SwiftData store that has `@Attribute(.unique) var name` on `Tag`. What happens?

- A) It works fine; CloudKit enforces the uniqueness.
- B) SwiftData rejects the schema — CloudKit has **no uniqueness constraint**, so `.unique` is forbidden on a synced model.
- C) It silently duplicates every tag.
- D) CloudKit converts `.unique` into a public-database lookup.

---

**Q9.** Why must every relationship on a CloudKit-synced `@Model` be optional?

- A) CloudKit doesn't support relationships at all.
- B) Records sync **independently and out of order**, so the target of a relationship may not have arrived yet — the reference must be allowed to be temporarily nil.
- C) Optional relationships are faster.
- D) It's a SwiftData limitation unrelated to CloudKit.

---

**Q10.** Two devices edit the same note's `body` while offline, then both sync. With CloudKit's default behaviour, what determines the winner?

- A) The device with the lower battery.
- B) Whichever change CloudKit **receives last** (network timing) — non-deterministic, and it overwrites the whole record.
- C) The note's `createdAt`.
- D) Both edits are always merged automatically.

---

**Q11.** What makes a timestamp-based last-write-wins policy *deterministic* where the default is not?

- A) It uses a faster clock.
- B) "Last" means "last **edited**" (the larger `updatedAt`), which every device computes identically regardless of which version arrived first.
- C) It runs on the main thread.
- D) It picks randomly but seeds the RNG the same way.

---

**Q12.** Why is conflict resolution written as a **pure function over two snapshots** rather than inside a CloudKit completion handler?

- A) Pure functions are required by Swift 6.
- B) It is deterministic by construction, unit-testable without CloudKit or two devices, and you can assert order-independence (`resolve(a,b) == resolve(b,a)`).
- C) Completion handlers can't read `@Model` objects.
- D) It runs faster.

---

**Q13.** You turned on CloudKit sync, the app works locally, but data never appears on the second device and nothing errors at your call site. What's the first thing to check?

- A) Re-install the app.
- B) The `NSPersistentCloudKitContainer.eventChangedNotification` **export events and their errors** — a schema-constraint violation fails the export *silently*, surfacing only in that event.
- C) The device's battery level.
- D) Whether `@Query` is sorted.

---

## Answer key

**Q1 — C.** A token is a secret; the secret branch of the decision tree is always the Keychain, stored as a generic password with the right `kSecAttrAccessible` class. (Lecture 1, §1, §7.)

**Q2 — B.** `UserDefaults` is an unencrypted plist in `Library/Preferences`, backed up in plaintext. A token there is readable by anyone with the backup — you prove exactly this in the challenge with `plutil -p`. (Lecture 1, §1; challenge 1.)

**Q3 — C.** Regenerable data goes in `Caches`: not backed up (saves the user's iCloud quota) and purgeable (the OS reclaims space, you re-download). Putting it in `Documents` bloats every backup. (Lecture 1, §2.)

**Q4 — C.** `.atomic` writes to a temp file and renames it into place; rename is atomic at the FS level, so the destination is always all-or-nothing. It is NOT a multi-file transaction (D is the trap). (Lecture 1, §4.)

**Q5 — C.** Atomic protects against a crash within *your* write; coordination protects against *another process* writing concurrently. You need it for shared App Group containers and externally-editable documents, not for private single-writer sandbox files. (Lecture 1, §5, §6.)

**Q6 — B.** `…AfterFirstUnlockThisDeviceOnly`: `AfterFirstUnlock` so background work can read it while locked; `ThisDeviceOnly` so it's never restored to another device from a backup. The exact reasoning for an auth token. (Lecture 1, §8.)

**Q7 — B.** `SecItemAdd` errors with `errSecDuplicateItem` on an existing item, so an add-only `set` breaks the second time you store the same key. The upsert tries update first, adds on `errSecItemNotFound`. (Lecture 1, §9; exercise 2.)

**Q8 — B.** CloudKit has no uniqueness constraint, so SwiftData forbids `@Attribute(.unique)` on a synced model and rejects the schema at container creation. You move the dedup into app logic. (Lecture 2, §2.)

**Q9 — B.** CloudKit syncs records independently and out of order; the target of a relationship may not have arrived, so the reference must be optional. (Lecture 2, §2.)

**Q10 — B.** CloudKit's default is record-level last-writer-wins where "last" = "last received," which depends on network timing — non-deterministic, and it overwrites the entire record (losing edits to other fields too). (Lecture 2, §3.)

**Q11 — B.** Timestamp-LWW redefines "last" as "last edited" via `updatedAt`, which is a property of the data, not the network — so every device computes the same winner regardless of arrival order. (Lecture 2, §4.)

**Q12 — B.** A pure function over `Sendable` snapshots is deterministic by construction, testable without CloudKit, and you can assert `resolve(a,b) == resolve(b,a)`. That order-independence test IS the convergence guarantee. (Lecture 2, §4, §5; exercise 3.)

**Q13 — B.** Sync is invisible; a missed constraint fails the export silently. The `eventChangedNotification` export event carries the error. Always install the observer in development. (Lecture 2, §6.)

---

*Score 11+? On to Week 15. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the Keychain accessibility classes and the deterministic-conflict-resolution function are the two ideas this week is graded on.*
