# Week 18 — Quiz

Fourteen questions. Take it with your lecture notes closed. Aim for 11/14 before moving to Week 19. Answer key with explanations at the bottom — don't peek.

---

**Q1.** Why are APNs **auth keys (`.p8`, token-based)** preferred over **certificates (`.p12`)** in 2026?

- A) Certificates are more secure.
- B) One auth key works for all your apps and never expires; you sign a short-lived JWT per request, instead of managing per-app certificates that expire annually.
- C) Auth keys don't require a JWT.
- D) Certificates can't send alert payloads.

---

**Q2.** You print the device token with `deviceToken.description`. What's wrong?

- A) Nothing; that's the correct form.
- B) `description` on `Data` gives `<a1b2 ...>` with angle brackets and spaces — you must hex-encode the bytes (`map { String(format: "%02x", $0) }`) to get the token APNs expects.
- C) `description` is too slow.
- D) The token should be base64, not hex.

---

**Q3.** A correctly-formed push to a valid token silently fails to arrive. The most common cause?

- A) The payload is too large.
- B) Wrong environment: a development (Xcode) build's token only works against `api.sandbox.push.apple.com`; sending to `api.push.apple.com` (production) returns `BadDeviceToken`.
- C) `interruption-level` was omitted.
- D) The app was in the foreground.

---

**Q4.** Which payload key tells the OS to hand the notification to your **Notification Service Extension** before display?

- A) `content-available: 1`
- B) `mutable-content: 1`
- C) `interruption-level: time-sensitive`
- D) `thread-id`

---

**Q5.** Your Notification Service Extension exceeds its time budget without calling the content handler. What does the user see?

- A) Nothing — the push is dropped.
- B) The **original, unmodified** notification — which for an encrypted payload means ciphertext or your placeholder. You must implement `serviceExtensionTimeWillExpire` to deliver a best effort.
- C) A system error notification.
- D) The decrypted content anyway.

---

**Q6.** How does the Notification Service Extension (a separate process) read the decryption key the main app stored?

- A) Through `UserDefaults`.
- B) Through a Keychain item in a shared **App Group access group** (`kSecAttrAccessGroup`), which both targets are entitled to.
- C) The key is passed in the payload.
- D) Extensions share memory with the app.

---

**Q7.** In the StoreKit 2 purchase flow, what must you do with the `VerificationResult` wrapping the transaction?

- A) Ignore it; StoreKit already verified it.
- B) Check it (`checkVerified`) and **throw on `.unverified`** — never grant entitlement on an unverified transaction, which could be forged.
- C) Send it to Apple to verify.
- D) Store it in the Keychain.

---

**Q8.** You forget to call `transaction.finish()`. What happens?

- A) Nothing; `finish()` is optional.
- B) StoreKit considers the product undelivered and re-presents the transaction via `Transaction.updates` on **every launch** — the "my purchase keeps coming back" bug.
- C) The purchase is refunded.
- D) The app crashes.

---

**Q9.** Where should the "does this user have Pro?" gate get its truth?

- A) A cached `Bool hasPro` set to true on purchase and persisted.
- B) Derived from `Transaction.currentEntitlements` (excluding transactions with a `revocationDate`), recomputed on every relevant change — a cached flag drifts on refund/expiry/restore.
- C) `UserDefaults`.
- D) The server only; the client never knows.

---

**Q10.** Why does a `Transaction.updates` listener need to run from app launch, not just during a purchase?

- A) It doesn't; purchases only happen in the foreground.
- B) Transactions arrive **outside** a purchase flow — renewals, refunds, Family Sharing grants, Ask-to-Buy approvals, and purchases made on another device — and the listener catches them all.
- C) To speed up the paywall.
- D) To retry failed purchases.

---

**Q11.** Why must you validate a transaction **server-side** when StoreKit already verified it on-device?

- A) On-device verification is fake.
- B) A jailbroken device can hand your backend a forged or replayed transaction; on-device verification unlocks the feature optimistically, but the authoritative entitlement requires your backend to re-verify Apple's signature.
- C) The server is faster.
- D) Apple requires it for all apps.

---

**Q12.** A subscription renewal **fails** (expired card) and enters a **grace period**. What should your server do?

- A) Revoke the entitlement immediately.
- B) **Keep access** during the grace period (mark "retrying"), and revoke only if grace expires with no recovery (`EXPIRED`) — revoking on the first failure locks out a paying customer over a transient issue.
- C) Refund the user.
- D) Downgrade the plan.

---

**Q13.** A user **refunds** a subscription. How does your server learn, and what should it do?

- A) The app tells the server on next launch; do nothing until then.
- B) Via the **App Store Server Notifications V2** `REFUND` webhook; revoke the entitlement immediately (keyed on `originalTransactionId`) — otherwise you serve premium content to someone who got their money back.
- C) It never learns; refunds are invisible.
- D) Via email from Apple.

---

**Q14.** What's the difference between an `MXMetricPayload` and an `MXDiagnosticPayload`?

- A) They're the same thing.
- B) `MXMetricPayload` is **aggregated histograms** across ~24h (CPU, memory, launch time, hang time, hitches) for spotting trends; `MXDiagnosticPayload` is **per-incident** diagnostics (crashes, hangs, disk-write exceptions) with call-stack trees you symbolicate.
- C) Metrics are for crashes; diagnostics are for performance.
- D) Diagnostics arrive every minute; metrics arrive yearly.

---

## Answer key

**Q1 — B.** One `.p8` covers all apps, never expires, and you sign a short-lived JWT (ES256) per request. Certificates are per-app and expire annually. (Lecture 1, §3.)

**Q2 — B.** `Data.description` yields a bracketed, spaced string, not the token. Hex-encode the bytes. This is a classic, real bug. (Lecture 1, §2.)

**Q3 — B.** Tokens are environment-specific: a development build's token works only against the sandbox APNs host. Wrong host → `BadDeviceToken`. (Lecture 1, §2, §6; exercise 1.)

**Q4 — B.** `mutable-content: 1` triggers the Notification Service Extension. `content-available: 1` is the silent/background push; they're different. (Lecture 1, §4–5.)

**Q5 — B.** Exceeding the budget without calling the handler shows the original notification. Implement `serviceExtensionTimeWillExpire` to deliver `bestAttempt`. (Lecture 1, §5.)

**Q6 — B.** The extension is a separate process and can't read the app's default Keychain. A shared App Group access-group Keychain item is the supported channel. (Lecture 1, §5.)

**Q7 — B.** `.unverified` means StoreKit couldn't validate Apple's signature — possibly forged. Throw and don't grant. Checking the result is the whole point of StoreKit 2's design. (Lecture 2, §2.)

**Q8 — B.** Without `finish()`, StoreKit re-presents the transaction every launch via `Transaction.updates` — the "purchase keeps coming back" bug. (Lecture 2, §2.)

**Q9 — B.** Derive the gate from `currentEntitlements` (excluding `revocationDate`), recomputed on change. A cached `Bool` drifts on refund, expiry, and cross-device restore. (Lecture 2, §3.)

**Q10 — B.** Transactions arrive outside the purchase flow — renewals, refunds, Family Sharing, Ask-to-Buy, other devices. The launch-time listener catches them. (Lecture 2, §3.)

**Q11 — B.** The client can lie (jailbroken device, forged/replayed transaction). On-device verification unlocks optimistically; the server re-verifies for the authoritative grant. (Lecture 2, §4.)

**Q12 — B.** Keep access during grace; revoke only on final `EXPIRED`. Revoking on the first `DID_FAIL_TO_RENEW` locks out a paying customer over an expired card. (Lecture 2, §5.)

**Q13 — B.** The `REFUND` App Store Server Notification tells the server; revoke immediately, keyed on `originalTransactionId`. Not revoking serves Pro to a refunded user — the canonical revenue leak. (Lecture 2, §5.)

**Q14 — B.** `MXMetricPayload` = aggregated histograms for trends; `MXDiagnosticPayload` = per-incident crash/hang/disk-write diagnostics with call stacks. MetricKit complements Instruments (your device vs the field). (Lecture 2, §6.)

---

*Score 11+? On to Week 19 and Phase IV. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — the push environment/token failure modes and the verify/finish/derive StoreKit guards are the two clusters this week is graded on.*
