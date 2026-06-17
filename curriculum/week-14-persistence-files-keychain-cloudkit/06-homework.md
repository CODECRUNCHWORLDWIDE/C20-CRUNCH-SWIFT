# Week 14 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 14 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**.

---

## Problem 1 — Map your own sandbox

**Problem statement.** In a throwaway app, write one file to each of `Documents`, `Application Support`, and `Caches`, then locate them all from the command line. Write `notes/sandbox-map.md`: the full path to each, which two are backed up, which one the OS may purge, and one sentence on which directory you'd choose for (a) a user's exported PDF, (b) the SwiftData store, (c) a downloaded image thumbnail.

**Acceptance criteria.**

- `notes/sandbox-map.md` has the three paths (quoted from `xcrun simctl get_app_container`, not invented), the backup/purge facts, and the three placement choices with one-sentence justifications.
- Committed.

**Hint.** `DATA=$(xcrun simctl get_app_container booted <bundle-id> data)`, then `ls -la "$DATA/Documents"` and the two `Library/` subfolders. PDF → `Documents`; store → `Application Support`; thumbnail → `Caches`.

**Estimated time.** 30 minutes.

---

## Problem 2 — Atomic vs non-atomic, demonstrated

**Problem statement.** Write a small function that saves a `Codable` struct two ways: `.atomic`, and a deliberately non-atomic "truncate then write" version. In `notes/atomic.md`, explain in two sentences the window of corruption the non-atomic version has and why `.atomic` (temp-file-then-rename) has none. (You don't have to crash mid-write — explain the mechanism.)

**Acceptance criteria.**

- Both save functions exist and round-trip correctly in the happy path.
- `notes/atomic.md` describes the corruption window and the temp-rename mechanism.
- Committed.

**Hint.** Non-atomic: `try Data().write(to: url)` (truncate) then `try data.write(to: url)`. The gap between those two lines is the corruption window — a crash there leaves an empty/partial file. `.atomic` never truncates the live file; it renames a fully-written temp over it.

**Estimated time.** 35 minutes.

---

## Problem 3 — Keychain accessibility decision table

**Problem statement.** Build a small table in `notes/keychain-accessibility.md` covering five `kSecAttrAccessible` classes (`…WhenUnlocked`, `…WhenUnlockedThisDeviceOnly`, `…AfterFirstUnlock`, `…AfterFirstUnlockThisDeviceOnly`, `…WhenPasscodeSetThisDeviceOnly`). For each: when it's readable, whether it leaves the device, and one realistic piece of data that's the right fit. Then state which one your `KeychainStore` defaults to and why it's right for an auth token.

**Acceptance criteria.**

- All five classes covered with the three columns.
- The default (`…AfterFirstUnlockThisDeviceOnly`) is named with the two-part justification (background read after first unlock; never restored to a new device).
- Committed.

**Hint.** Lecture 1, §8 has the table. Don't copy it verbatim — pick a *realistic* data example for each row in your own words (e.g. `…WhenPasscodeSetThisDeviceOnly` for a high-value local encryption key tied to the device having a passcode).

**Estimated time.** 35 minutes.

---

## Problem 4 — Round-trip a `Codable` value through the Keychain

**Problem statement.** Extend the `KeychainStore` from exercise 2 with generic `setCodable<T: Codable>(_:account:)` / `getCodable<T: Codable>(account:)` that JSON-encode the value to `Data` and store it. Store a small `Credentials` struct (`accessToken`, `refreshToken`, `expiresAt`), read it back, and assert equality. Test that `getCodable` throws `.itemNotFound` for an absent key.

**Acceptance criteria.**

- `setCodable`/`getCodable` use `JSONEncoder`/`JSONDecoder` over the existing `set`/`get`.
- A passing test: round-trip a `Credentials` value; `getCodable` of a missing account throws `.itemNotFound`.
- Uses a unique service name and cleans up. 0 warnings. Committed.

**Hint.** `try set(JSONEncoder().encode(value), account: account)` and `try JSONDecoder().decode(T.self, from: get(account: account))`. Keep the typed-error behaviour: a missing item must throw `.itemNotFound`, not return nil silently.

**Estimated time.** 45 minutes.

---

## Problem 5 — Make a Week 10 schema CloudKit-safe

**Problem statement.** Take the Week 10 `Note`/`Tag` schema (with `@Attribute(.unique) var name` and a non-optional relationship) and refactor it into a CloudKit-safe shape. In `notes/cloudkit-safe.md`, list every change you made and the CloudKit rule that forced it. Then describe — in two sentences — how you'd enforce "one tag per name" now that `.unique` is gone.

**Acceptance criteria.**

- The refactored schema compiles with `cloudKitDatabase` configured (or you note exactly what each change addresses if you don't have the entitlement).
- `notes/cloudkit-safe.md` lists each change (drop `.unique`, optional relationships, defaulted properties) mapped to its CloudKit rule.
- The "dedupe tags in app logic" approach is described.
- Committed.

**Hint.** Three rules: every relationship optional, no `.unique`, every non-optional property defaulted. Dedup: before inserting a `Tag(name:)`, query for an existing tag with that name and reuse it; on the conflict path, merge duplicate tags deterministically.

**Estimated time.** 45 minutes.

---

## Problem 6 — A field-level merge resolver, fully tested

**Problem statement.** Extend exercise 3's resolution to a three-field record (`title`, `body`, `pinned`), each with its own `updatedAt`. Write `mergeFields` and prove with tests that (a) three non-overlapping edits across two devices all survive, (b) a same-field conflict resolves to the later timestamp, and (c) the merge is order-independent (`merge(a,b)` and `merge(b,a)` converge — careful, naive field-merge is NOT symmetric, so think about the tie rule).

**Acceptance criteria.**

- A `FieldVersioned3` value type with per-field timestamps and a `mergeFields` over it.
- Three passing tests for the three properties above.
- The order-independence test passes (you may need a deterministic tiebreak on equal per-field timestamps).
- 0 warnings. Committed.

**Hint.** For each field independently, take the value with the larger timestamp; on a tie, break it on a stable content rule (e.g. lexicographically larger value) so `merge(a,b)` and `merge(b,a)` pick the same field value. The per-field independence is what lets non-overlapping edits all survive.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a force-unwrap where a typed error was cleaner, a missing `final`). |
| 3 | Works, but misses one criterion (e.g. resolver not actually order-independent, a Keychain `set` that doesn't upsert, a "CloudKit-safe" schema that still has `.unique`). |
| 2 | Compiles and partially works; a core idea is wrong (token left in `UserDefaults`, non-deterministic conflict policy, relationship left non-optional under CloudKit). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−3** for a secret stored anywhere but the Keychain; **−2** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) used to silence the compiler instead of restructuring; **−2** for a non-deterministic conflict policy; **−1** for a large file in a backed-up directory without `isExcludedFromBackup`.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the Keychain accessibility classes (problems 3, 4) and deterministic conflict resolution (problems 5, 6) — so re-run exercises 02 and 03 before resubmitting.
