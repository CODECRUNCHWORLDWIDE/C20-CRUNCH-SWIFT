# Week 17 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 17 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency. Every problem must build with **0 warnings**. The Secure Enclave problems (5) require a **physical device**.

A standing rule for the week: **every security control gets a one-sentence threat statement.** Several problems below ask for it explicitly; do it for the rest anyway.

---

## Problem 1 — Audit an `Info.plist` for ATS red flags

**Problem statement.** Given the snippet below, write `notes/ats-review.md` identifying every issue, explaining the threat each weakening introduces, and proposing the minimal fix. Then write the corrected plist.

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.partner.example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Acceptance criteria.**

- `notes/ats-review.md` identifies `NSAllowsArbitraryLoads = true` as the global red flag and the cleartext-HTTP exception as a downgrade to a passive-eavesdropper attack.
- A corrected plist that removes the global switch and scopes the exception as narrowly as possible (TLS minimum, not cleartext) — or explains why the partner domain must be fixed server-side instead.
- Committed.

**Hint.** `NSAllowsArbitraryLoads` overrides everything — it's the thing a reviewer rejects first. `NSExceptionAllowsInsecureHTTPLoads = true` means cleartext, which a passive eavesdropper reads. Prefer `NSExceptionMinimumTLSVersion`.

**Estimated time.** 30 minutes.

---

## Problem 2 — SPKI hash two ways and reconcile them

**Problem statement.** Compute the SPKI SHA-256 of one host two ways: (a) the `openssl` one-liner from lecture 1, and (b) from inside an app by logging what your `PinningDelegate` computes. They will likely differ (the ASN.1 SPKI-header issue). In `notes/spki.md`, record both values, explain *why* they differ, and state which one you'd pin and why.

**Acceptance criteria.**

- Both hashes recorded for the same host.
- A correct explanation of the difference (`SecKeyCopyExternalRepresentation` returns the raw key; `openssl` hashes the full ASN.1-wrapped SPKI).
- A decision: pin the value your delegate computes (client-consistent) *or* fix the delegate to prepend the ASN.1 header (spec-consistent) — and why production code uses a vetted library.
- Committed.

**Hint.** The two can't both be your pin — they must agree on both ends. The lesson is that mismatched encoding self-inflicts an outage, which is why TrustKit exists. Either approach is correct if both ends use it.

**Estimated time.** 45 minutes.

---

## Problem 3 — AES-GCM file encryption with tamper detection

**Problem statement.** Write `EncryptedFileStore` with `save(_ data: Data, to url: URL, using key: SymmetricKey)` and `load(from url: URL, using key: SymmetricKey) throws -> Data`. Save AES-GCM-sealed; load by opening. Write a test that round-trips a payload, and a second test that flips one byte on disk and asserts `load` **throws** (tamper detected). State the threat the encryption answers.

**Acceptance criteria.**

- `save` writes `sealedBox.combined`; `load` reconstructs the box and `open`s it.
- A passing round-trip test and a passing tamper test (`#expect(throws:)` after corrupting the file).
- A one-sentence threat statement (e.g. "a forensic image of the file system can't read the cache without the key").
- 0 warnings. Committed.

**Hint.** `sealed.combined!` is the on-disk blob. To corrupt, read the file, XOR a byte, write it back, then `load`. GCM's auth tag makes `open` throw on any change.

**Estimated time.** 45 minutes.

---

## Problem 4 — ECDH + HKDF two-party channel

**Problem statement.** Simulate two parties ("client" and "server") that each generate a `Curve25519.KeyAgreement` key pair, exchange public keys, derive the same `SymmetricKey` via HKDF, and use it to AES-GCM a message in each direction. Write a test asserting the message round-trips both ways. Then add a test where one side uses a *different* salt in HKDF and assert decryption **fails** — proving the context-binding matters.

**Acceptance criteria.**

- Both sides derive the same key with matching salt/info and exchange messages successfully.
- A test where mismatched salt causes the derived keys to differ and `open` throws.
- A one-sentence note on why the salt mismatch breaks it (different derived keys).
- 0 warnings. Committed.

**Hint.** `hkdfDerivedSymmetricKey(using:salt:sharedInfo:outputByteCount:)` must use identical salt/sharedInfo on both sides. Change the salt on one side and the keys diverge, so AES-GCM `open` fails its tag check.

**Estimated time.** 45 minutes.

---

## Problem 5 — Secure Enclave key with biometric gating (device)

**Problem statement.** On a physical device, generate a `SecureEnclave.P256.Signing.PrivateKey` with `.userPresence` access control, persist its representation, and write a flow that signs a payload only after `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` succeeds. Confirm by eye that Face ID / passcode is prompted before signing, and that the signature verifies. Write `notes/enclave.md` stating the two threats this answers (key extraction; unlocked-device misuse).

**Acceptance criteria.**

- A key generated with `[.privateKeyUsage, .userPresence]`, persisted and reloaded.
- A sign flow that authenticates with `LAContext` before signing; the signature verifies against the public key.
- `notes/enclave.md` names the two threats.
- Runs on a **device** (note in the file that the Simulator has no Enclave). 0 warnings. Committed.

**Hint.** `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .userPresence], &error)`. `evaluatePolicy` is `async throws` and returns `Bool`. The Enclave enforces user presence in hardware; the explicit `LAContext` call gives you the prompt and a clean failure path.

**Estimated time.** 50 minutes.

---

## Problem 6 — Verify a signature in `swift-crypto` (server side)

**Problem statement.** In a Vapor route (or a Linux Swift package using `swift-crypto`), implement `verify(keyID:timestamp:signatureBase64:canonical:)` that rebuilds a `P256.Signing.PublicKey` from an enrolled raw representation, reconstructs the canonical string, and verifies the signature — rejecting an unknown key, a stale timestamp, and a wrong signature. Write tests for all three rejection paths plus the success path.

**Acceptance criteria.**

- Uses `apple/swift-crypto` (the client's CryptoKit twin); `P256.Signing.PublicKey(rawRepresentation:)` + `isValidSignature`.
- Four tests: success; unknown `keyID`; stale timestamp (> 5 min); tampered signature/payload — each asserting the right outcome.
- A one-sentence note that the client and server canonical-string formats must match byte-for-byte.
- 0 warnings. Committed.

**Hint.** Generate a `P256.Signing.PrivateKey` in the test to act as the "device," sign a canonical string, then feed its public key's `rawRepresentation` and the signature into your verifier. For the stale test, sign with a timestamp 400 s in the past. For the tamper test, flip a byte of the signature DER.

**Estimated time.** 50 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings, code is idiomatic Swift/CryptoKit, the threat statement (where asked) is correct, and tamper/rejection paths are actually tested. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. `==` MAC comparison instead of `isValidAuthenticationCode`, a missing threat statement). |
| 3 | Works, but misses one criterion (e.g. no tamper test, pin computed only one way, signature never actually verified). |
| 2 | Compiles and partially works; a core idea is wrong (filters out CA validation while pinning; reuses a GCM nonce; uses the raw ECDH secret as a key). |
| 1 | Does not build, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any secret marked `.public` in a log or placed in a URL query string; **−2** for a security control with no named threat where one was requested; **−2** for pinning that *replaces* rather than *augments* CA validation; **−1** for any suppressed Swift 6 concurrency warning (`@unchecked Sendable`, `nonisolated(unsafe)`) on a security type.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — pinning-augments-validation / rejects-a-valid-cert (problems 1, 2) and the CryptoKit primitives done right: nonce, HKDF, verify-the-signature (problems 3, 4, 6) — so re-run exercises 01 and 02 before resubmitting.
