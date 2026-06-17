# Week 18 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 18 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. Push and sandbox-purchase problems require a **physical device** and your Apple Developer membership.

A standing rule for the week: **prove the failure path, not just the success.** Several problems ask for it explicitly; do it for the rest anyway.

---

## Problem 1 — Payload design table

**Problem statement.** Write `notes/payloads.md` describing four push payloads for the notes app: (1) a visible "note shared with you" alert, (2) a silent background refresh, (3) an encrypted shared-note title needing the NSE, (4) a time-sensitive "your sync conflict needs attention." For each, give the `aps` keys, the required `apns-push-type` header, and a one-line note on when it's the right choice (and its constraint, e.g. silent pushes are throttled).

**Acceptance criteria.**

- Four payloads with correct `aps` keys and matching `apns-push-type` (`alert`/`background`).
- The encrypted one uses `mutable-content: 1` and a custom `encryptedTitle` key; the silent one uses `content-available: 1`; the time-sensitive one uses `interruption-level: time-sensitive`.
- A one-line constraint per payload (throttling, entitlement needed, etc.).
- Committed.

**Hint.** `content-available` pairs with `apns-push-type: background`; an `alert` payload with `apns-push-type: alert`. Time-sensitive needs the Time Sensitive Notifications entitlement.

**Estimated time.** 35 minutes.

---

## Problem 2 — The NSE fallback path

**Problem statement.** In a Notification Service Extension, implement `didReceive` that decrypts an `encryptedTitle` payload with AES-GCM, and write the `serviceExtensionTimeWillExpire` path. Then deliberately break decryption (wrong key) and a slow path (sleep past the budget) and confirm by eye on a device (or via the Push Console + a `.apns` drag) that the fallback body shows — never the error, never the ciphertext.

**Acceptance criteria.**

- `didReceive` decrypts and sets `body`, falling back to a generic string on failure.
- `serviceExtensionTimeWillExpire` delivers `bestAttempt`.
- You demonstrated both failure paths (wrong key → fallback body; budget exceeded → original/best-effort) without leaking the error or ciphertext.
- A one-line note on why a notification is a leak surface (it shows on the lock screen).
- Committed.

**Hint.** GCM `open` throws on a wrong key (it's authenticated). For the budget test, `Thread.sleep` past ~30 s in `didReceive` (debug only) and confirm the expiry handler fires. Never put `error.localizedDescription` in the visible body.

**Estimated time.** 50 minutes.

---

## Problem 3 — Purchase flow guards under test

**Problem statement.** Using a `.storekit` config and `SKTestSession`, write tests proving the three purchase-flow guards: (a) a purchase verifies and flips the derived gate to true, (b) `finish()` is called (an unfinished transaction re-appears in `Transaction.unfinished`), and (c) the gate is derived from `currentEntitlements` (a fresh `Store` instance after purchase still reports access).

**Acceptance criteria.**

- Three passing tests covering verify, finish, and derive.
- The "finish" test asserts `Transaction.unfinished` is empty after the purchase completes.
- The "derive" test constructs a second `Store` and confirms the gate without any cached flag.
- 0 warnings. Committed.

**Hint.** `SKTestSession(configurationFileNamed:)`, `session.clearTransactions()` between tests. After `finish()`, iterate `Transaction.unfinished` and assert it's empty. The derive test is just exercise 2's `entitlementSurvivesNewStoreInstance`.

**Estimated time.** 50 minutes.

---

## Problem 4 — Server-notification handler

**Problem statement.** In a Vapor route (or a Linux Swift package), write a function that takes an App Store Server Notification *type* and an `originalTransactionId` and updates an in-memory `EntitlementStore` correctly: `REFUND`/`EXPIRED`/`REVOKE` revoke, `DID_RENEW`/`SUBSCRIBED` extend, `DID_FAIL_TO_RENEW` marks grace (keeps access). Write tests for all five behaviours.

**Acceptance criteria.**

- A handler switching on notification type with the correct action per type.
- Five tests: refund revokes, expired revokes, renew extends, subscribed grants, fail-to-renew keeps access (grace).
- A one-line note that the grace case must NOT revoke (the lockout bug).
- 0 warnings. Committed.

**Hint.** You don't need the real signature verification for this problem — test the *state machine* with the decoded type as input. Key the store on `originalTransactionId`. The grace test asserts access is still true after `DID_FAIL_TO_RENEW`.

**Estimated time.** 45 minutes.

---

## Problem 5 — MetricKit upload wiring

**Problem statement.** Build a `MetricsCollector` (exercise 3) and a real `PayloadUploader` that POSTs to your Vapor backend over the signed, pinned `NotesClient` from Week 17. Add a Vapor route that accepts a payload, tags it metric/diagnostic, and stores it (or logs its size). Write a test that drives `handle(json:kind:)` against a mock and asserts the right bytes/kind are shipped.

**Acceptance criteria.**

- `MetricsCollector` registers via `MXMetricManager.shared.add(self)`.
- A `PayloadUploader` that ships over the secure client; a Vapor route that receives it.
- A passing test against a mock uploader for both kinds.
- A failing uploader does NOT crash the collector (best-effort).
- 0 warnings. Committed.

**Hint.** Reuse exercise 3's `handle` seam and `MockUploader`. The real uploader just wraps `NotesClient.uploadMetric`. On a device, register at launch and a real payload arrives within ~24h — note that in your commit message.

**Estimated time.** 40 minutes.

---

## Problem 6 — Stale-token detection

**Problem statement.** Write a Vapor function `sendPush(to token: String, payload: Data)` (using APNSwift or a thin wrapper) that sends a push and, on a `BadDeviceToken` / `Unregistered` (410) response from APNs, **expires** the token in your token store so you stop sending to it. Write a test (mocking the APNs response) proving a 410 expires the token and a 200 leaves it active.

**Acceptance criteria.**

- The sender reads the APNs response status and expires the token on `BadDeviceToken`/`410 Unregistered`.
- Two tests: a 200 keeps the token; a 410 expires it (the token store reflects it).
- A one-line note on why this matters (silent failure: sending to a dead token forever).
- 0 warnings. Committed.

**Hint.** You can mock the APNs client behind a protocol so the test injects the status. The real APNSwift client surfaces the reason; map `BadDeviceToken`/`Unregistered` to "expire." This is the failure path exercise 1 had you observe from the device side.

**Estimated time.** 40 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/StoreKit/UserNotifications, and the failure path (where asked) is actually exercised. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. a cached gate flag alongside the derived one, a hardcoded price in the paywall). |
| 3 | Works, but misses one criterion (e.g. no `finish()`, no `serviceExtensionTimeWillExpire`, grace case revokes, failure path not shown). |
| 2 | Compiles and partially works; a core idea is wrong (grants on `.unverified`; caches the gate; revokes on first billing failure; wrong `apns-push-type`). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for granting entitlement on an unverified or unfinished transaction; **−2** for revoking during a grace period (the paying-customer lockout); **−2** for a leaked secret/error in a visible notification body; **−1** for a cached gate flag where `currentEntitlements` was the point; **−1** for any suppressed Swift 6 concurrency warning.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the push token/environment failure modes (problems 1, 6) and the StoreKit verify/finish/derive + edge-case guards (problems 3, 4) — so re-run exercises 01 and 02 before resubmitting.
