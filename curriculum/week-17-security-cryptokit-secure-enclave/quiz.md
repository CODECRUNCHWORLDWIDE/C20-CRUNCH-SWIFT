# Week 17 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 18. Answer key with explanations at the bottom — don't peek.

---

**Q1.** Which adversary does **certificate/public-key pinning** defend against that plain ATS does not?

- A) A passive eavesdropper reading traffic on open Wi-Fi.
- B) An active man-in-the-middle presenting a valid certificate signed by a CA the OS trusts (e.g. a corporate proxy or rogue CA).
- C) An attacker with root on the device.
- D) A thief holding the unlocked phone.

---

**Q2.** What does App Transport Security enforce by **default**, with zero code?

- A) Certificate pinning to your server's key.
- B) TLS 1.2+, forward secrecy (ECDHE), SHA-256+ certificates, and no cleartext HTTP.
- C) End-to-end encryption of request bodies.
- D) Biometric authentication before any network call.

---

**Q3.** Why pin the **public key (SPKI)** rather than the whole **certificate**?

- A) The certificate hash is more secure.
- B) The public key survives certificate renewal (as long as the key pair is reused), so routine cert rotation doesn't brick the app; a certificate pin breaks on every renewal.
- C) You can't compute a hash of a certificate.
- D) Public-key pinning doesn't require shipping a backup pin.

---

**Q4.** In a `URLSession` pinning delegate, what must you do **in addition to** comparing the SPKI hash?

- A) Nothing — the pin check replaces CA validation.
- B) Run the standard CA chain evaluation (`SecTrustEvaluateWithError`) too, so an expired or hostname-mismatched cert is still rejected; pin *and* validate.
- C) Disable ATS for the domain.
- D) Return `.performDefaultHandling` on a pin miss.

---

**Q5.** Why is **nonce reuse** catastrophic for AES-GCM?

- A) It makes encryption slower.
- B) Reusing a (key, nonce) pair lets an attacker recover the XOR of plaintexts and forge authentication tags, destroying both confidentiality and authenticity.
- C) It causes `seal` to throw.
- D) It has no security impact; the nonce is public anyway.

---

**Q6.** How does CryptoKit's `AES.GCM.seal(_:using:)` (no nonce argument) protect you?

- A) It reuses a fixed nonce for determinism.
- B) It generates a fresh random nonce per call, so you can't accidentally reuse one.
- C) It refuses to encrypt more than once.
- D) It stores the nonce in `UserDefaults`.

---

**Q7.** You derive a shared secret with `Curve25519.KeyAgreement`. Can you use it directly as an AES key?

- A) Yes, the shared secret is already a uniform key.
- B) No — the raw ECDH output is a curve point, not uniformly random; run it through HKDF (`hkdfDerivedSymmetricKey`) first, which also binds it to a context.
- C) No — you must hash it with SHA-1.
- D) Yes, but only for `AES.GCM`, not `ChaChaPoly`.

---

**Q8.** Why does the Secure Enclave request-signing flow use **P-256** rather than Ed25519?

- A) P-256 is more secure than Ed25519.
- B) The Secure Enclave's hardware key generation supports the NIST P-256 curve, not Ed25519, so a hardware-backed key must be P-256.
- C) Ed25519 can't produce detached signatures.
- D) `swift-crypto` doesn't support Ed25519.

---

**Q9.** What exactly is stored when you persist a `SecureEnclave.P256.Signing.PrivateKey.dataRepresentation` in the Keychain?

- A) The raw private key bytes.
- B) A device-bound *encrypted blob* that only this device's Enclave can turn back into a usable key — not the private key, which never leaves the hardware.
- C) The public key.
- D) A reference to a file on disk.

---

**Q10.** A signing key is generated with `.biometryCurrentSet`. An attacker with the unlocked phone adds their own fingerprint. What happens to the key?

- A) Nothing; the key still works.
- B) The key is invalidated because the enrolled biometric set changed — `.biometryCurrentSet` ties the key to the current set, so re-enrolment kills it.
- C) The key is exported to the new fingerprint.
- D) The app crashes.

---

**Q11.** What stops a stolen **bearer token** from being used to forge a request in the mini-project's design?

- A) Nothing — a stolen token is always game over.
- B) Every request is also signed by the Secure Enclave key, which the attacker can't reproduce (they can't extract the key) and can't replay (the signed timestamp is checked server-side).
- C) The token is encrypted with AES.
- D) The server rate-limits requests.

---

**Q12.** You write `log.error("token \(token, privacy: .public)")`. What's wrong?

- A) Nothing; `.public` is the safe default.
- B) `OSLog` redacts interpolated values by default; marking a secret `.public` deliberately *leaks* it into Console.app, sysdiagnose, and any log capture. Never mark a secret `.public`.
- C) `.public` makes the log slower.
- D) `error` is the wrong log level.

---

**Q13.** Where does the request-signing flow defend against **replay** (resending a captured valid request)?

- A) It doesn't; signatures don't prevent replay.
- B) The signed canonical string includes a timestamp, and the server rejects requests whose timestamp is too far from now (e.g. > 5 minutes) — a replayed old request is stale.
- C) Pinning prevents replay.
- D) The Enclave detects duplicate signatures.

---

## Answer key

**Q1 — B.** ATS verifies the cert chains to a trusted CA, which a proxy's rogue-CA cert *does*. Pinning collapses trust to one specific key, rejecting a valid-but-wrong certificate — that's the active-MITM defence. (Lecture 1, §1–3.)

**Q2 — B.** ATS is on by default and enforces TLS 1.2+, forward secrecy, modern certs, and no cleartext. You can only weaken it. It does **not** pin or encrypt bodies or require biometrics. (Lecture 1, §2.)

**Q3 — B.** SPKI pinning survives certificate renewal when the key pair is reused, so routine rotation doesn't brick the app. A certificate pin breaks on every renewal. (You should ship a backup pin regardless, so D is wrong.) (Lecture 1, §3.)

**Q4 — B.** Pinning is *in addition to* CA validation, never instead of it. Skipping `SecTrustEvaluateWithError` would accept an expired/mismatched cert as long as the key matches. A miss must `.cancelAuthenticationChallenge`, not `.performDefaultHandling`. (Lecture 1, §4.)

**Q5 — B.** Reusing a (key, nonce) pair in GCM leaks the XOR of plaintexts and enables tag forgery — both confidentiality and authenticity collapse. This is a real, exploited failure mode. (Lecture 2, §2.)

**Q6 — B.** The no-argument `seal` picks a fresh random nonce each call, making accidental reuse impossible. Supplying your own nonce is the verbose, explicit path for protocols that demand it. (Lecture 2, §2.)

**Q7 — B.** The raw ECDH output is a curve point, not a uniform key. HKDF turns it into a proper symmetric key and binds it to a context (salt/info) so the same secret yields different keys for different purposes. (Lecture 2, §3.)

**Q8 — B.** The Secure Enclave generates P-256 keys in hardware; it does not support Ed25519. So a hardware-backed signing key is P-256. For software keys with no Enclave requirement, Ed25519 is the nicer default. (Lecture 2, §3–4.)

**Q9 — B.** `dataRepresentation` is a device-bound encrypted blob — a recipe only this device's Enclave can follow to rebuild the key. The private key never exists outside the hardware, so copying the blob to another device is inert. (Lecture 2, §4.)

**Q10 — B.** `.biometryCurrentSet` invalidates the key when the enrolled biometric set changes. An attacker adding a finger kills the key — the invalidation is a feature. `.biometryAny` would survive the change. (Lecture 2, §5.)

**Q11 — B.** Request signing layers on top of the token: the Enclave signature can't be forged (key unextractable) or replayed (timestamp checked). A stolen token alone can't produce a valid `X-Request-Signature`. (Lecture 2, §6.)

**Q12 — B.** `OSLog` redacts by default; `.public` opts *in* to showing the value, which leaks the secret to every log capture surface. Never mark a secret `.public`. (Lecture 2, §7.)

**Q13 — B.** The signed canonical string includes a timestamp; the server rejects stale timestamps (e.g. > 5 min), so a captured-and-replayed request is refused. Signatures alone don't stop replay — the timestamp does. (Lecture 2, §6.)

---

*Score 11+? On to Week 18. Below 9? Re-read both lecture notes and re-run exercises 1 and 2 — the pinning-rejects-a-valid-cert idea and the GCM/nonce/HKDF distinctions are the two clusters this week is graded on.*
