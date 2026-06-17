# Week 17 — Security, App Transport Security, CryptoKit, Secure Enclave

Welcome to Week 17 of **C20 · Crunch Swift**. For four weeks your `NotesClient` has talked to the Vapor backend over HTTPS and trusted whatever certificate the operating system trusted. That is the right default for most apps, most of the time. This week you stop trusting the default. By Friday your client pins the server's certificate so a corporate proxy or a forged CA can't read your traffic, your private key lives in the Secure Enclave where even a jailbroken device can't extract it, and every outbound request carries a hardware-backed signature the Vapor backend verifies with the matching public key.

Security on Apple platforms is not a library you import and a box you tick. It is a set of decisions about *where each secret lives* and *who can reach it* — and Apple gives you genuinely good primitives to make those decisions with: the Keychain for credentials, `LocalAuthentication` for Face ID / Touch ID gating, **CryptoKit** for symmetric and asymmetric cryptography with a Swift-native API that makes the safe thing the easy thing, and the **Secure Enclave** — a separate hardware security processor on every modern iPhone, iPad, and Apple Silicon Mac — for keys that must never exist in main memory or leave the device. The throughline this week is the same one a security reviewer applies: *what is the threat, and which primitive answers it?* A certificate-pinning failure answers "a network attacker with a forged cert." A Secure Enclave key answers "an attacker who has root on the device." Face ID gating answers "an attacker who has the unlocked phone for thirty seconds." You will learn to name the threat before you reach for the tool, because reaching for the tool first is how people ship encryption that protects nothing.

The mental shift this week is from "HTTPS means I'm secure" to "HTTPS means the bytes are encrypted in transit to *whoever holds the private key for the certificate the OS trusted* — and I get to decide whether that's good enough." It usually is. When it isn't — a banking app, a health app, anything where a man-in-the-middle is a real adversary — you **pin**: you ship the app knowing exactly which public key the server should present, and you reject the connection if it presents any other, even one signed by a perfectly valid CA. You will also learn the asymmetry that underpins all of this: the Secure Enclave can *generate* and *use* a private key (sign with it, derive shared secrets with it) but can never *export* it. The private key bits never touch your process's memory. You hold a handle; the hardware does the math. That property — "the key exists but you can't read it" — is the single most important idea in hardware-backed security, and we spend real time on why it changes the threat model.

We close the week by hardening the `NotesClient` end to end. You will add **certificate pinning** via a `URLSession` delegate so the client only talks to *your* server's key, generate a **Secure Enclave P-256 key** on first launch, **sign every outbound request** with it, and verify that signature in the Vapor backend using the device's enrolled public key. That is request-level authentication that survives a stolen bearer token: even with the token, an attacker can't forge a request, because they can't reproduce the signature without the Enclave key, which they can't extract. You will also scrub sensitive values out of your logs — because the fastest way to leak a secret in 2026 is still to `print()` it — and store credentials in the Keychain with the right accessibility class, the skill you first met in Week 14 and now make a habit.

## Learning objectives

By the end of this week, you will be able to:

- **Explain** App Transport Security — what it enforces by default (TLS 1.2+, forward secrecy, no arbitrary loads), how `Info.plist` exceptions weaken it, and why "Allow Arbitrary Loads" is a red flag in code review.
- **Pin** a server certificate (or, better, its public key) in a `URLSession` `URLSessionDelegate`, validating the server trust against a known key and rejecting any other — including a valid-but-wrong CA.
- **Distinguish** the threats each primitive answers: ATS (passive eavesdropper), pinning (active MITM with a forged or rogue-CA cert), Keychain access control + `LocalAuthentication` (attacker with the unlocked device), Secure Enclave (attacker with root / a device image).
- **Use** CryptoKit correctly: hash with `SHA256`, encrypt with `AES.GCM` using a `SymmetricKey`, agree on a shared secret with `Curve25519.KeyAgreement`, and sign/verify with `Curve25519.Signing` and `P256.Signing` — and explain why nonce reuse in GCM is catastrophic and how CryptoKit prevents it.
- **Generate** a Secure Enclave `P256` private key with an access control flag (`SecureEnclave.P256.Signing.PrivateKey`), persist its *representation* (not the key) in the Keychain, and reload it across launches — while understanding that the key bits never leave the hardware.
- **Sign** an outbound request with a Secure Enclave key and **verify** the signature server-side with the enrolled public key, building request-level authentication on top of TLS.
- **Gate** a sensitive key operation behind Face ID / Touch ID using `LAContext` and a Keychain `SecAccessControl` with `.biometryCurrentSet`, and handle the failure and fallback paths correctly.
- **Scrub** secrets from logs with `OSLog` privacy qualifiers (`.private` by default, `.public` only deliberately), and recognise the common ways apps leak credentials (URL query tokens, `print`, crash logs, pasteboard).

## Prerequisites

This week assumes you have completed **C20 weeks 1–16**, or have equivalent fluency. Specifically:

- You can read and write idiomatic Swift — value vs reference types, optionals, error handling with `throws`/`Result`, generics — Weeks 1–2. CryptoKit's API leans hard on typed values (`SymmetricKey`, `SealedBox`, `Signature`) and `throws`; you should be comfortable with both.
- You understand `Sendable`, `@MainActor`, and actor isolation — Week 4. The `NotesClient` is an `actor`; the signing key and the `URLSession` delegate live inside that isolation, and the Swift 6 compiler will hold you to it.
- You have the `URLSession`-based `NotesClient` from Week 13 and the Keychain work from Week 14 checked into Git. This week's mini-project hardens that exact client — pinning and signing slot into the request pipeline you already built.
- You have a Vapor backend from Phase I you can run and edit. The server-side signature verification this week is a small Vapor route; you'll write the matching Swift with `swift-crypto` (CryptoKit's open-source twin) on the server.

**Toolchain & membership.** Xcode 16+ on macOS (Apple Silicon recommended), targeting iOS 18 / iOS 17 minimum. **The Secure Enclave requires a physical device** — the Simulator has no Enclave, so the signing parts of the mini-project run on a real iPhone or iPad (or an Apple Silicon Mac, which has one). Per the syllabus, **Apple Developer Program membership is required from Week 15 onward**; you have it by now, and you'll need it to run on device. CryptoKit, ATS, pinning, and Keychain all work in the Simulator; only the `SecureEnclave.*` types require real hardware.

## Topics covered

- **App Transport Security.** The default policy (TLS 1.2+, ECDHE forward secrecy, SHA-256+ certificates), the `NSAppTransportSecurity` `Info.plist` keys, `NSAllowsArbitraryLoads` and why it's almost always wrong, per-domain `NSExceptionDomains`, and `NSPinnedDomains` (the declarative pinning Apple added so you don't always hand-roll a delegate).
- **Certificate vs public-key pinning.** What TLS server-trust evaluation does, where you hook it (`urlSession(_:didReceive:completionHandler:)`), pinning the leaf certificate vs pinning the SubjectPublicKeyInfo (SPKI) hash, why SPKI pinning survives certificate renewal, and the operational footgun of pinning (you must ship a backup pin and rotate before expiry or you brick the app).
- **CryptoKit fundamentals.** `SymmetricKey` generation and sizing, `SHA256`/`SHA512` hashing, `HMAC` for authenticated MACs, and the typed-value design (you can't accidentally pass a hash where a key goes).
- **AES-GCM authenticated encryption.** `AES.GCM.seal` / `open`, the `SealedBox` (nonce + ciphertext + tag), why GCM is authenticated encryption (AEAD), why **nonce reuse is catastrophic** for GCM, and how CryptoKit's random-nonce default and combined-representation API keep you safe.
- **Asymmetric cryptography.** `Curve25519.KeyAgreement` (X25519 ECDH) to derive a shared secret, HKDF to turn that secret into a symmetric key, and `Curve25519.Signing` / `P256.Signing` for detached signatures. Signing vs encryption — different keys, different purposes.
- **The Secure Enclave.** What it is (a separate hardware security processor with its own boot ROM and AES engine), the `SecureEnclave.P256.Signing.PrivateKey` and `.KeyAgreement.PrivateKey` types, the `.dataRepresentation` that is an *encrypted, device-bound blob* (not the key), and why the private key never enters your address space.
- **Access control & biometrics.** `SecAccessControl` flags (`.privateKeyUsage`, `.biometryCurrentSet`, `.devicePasscode`), gating a signing operation behind `LAContext` (Face ID / Touch ID), and the difference between `.biometryAny` and `.biometryCurrentSet` (re-enrolment invalidates the latter — a feature, not a bug).
- **Keychain as the key store.** Persisting a Secure Enclave key's `dataRepresentation` in the Keychain, choosing the accessibility class (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` vs `WhenUnlocked`), access groups for sharing between an app and its extension, and why you never persist a raw symmetric key in `UserDefaults`.
- **Request signing end to end.** Building a canonical request representation, signing it with the Enclave key, attaching the signature and a key id, and verifying server-side with `swift-crypto` against the enrolled public key — request-level auth that a stolen bearer token can't defeat.
- **Sensitive-data hygiene.** `OSLog` privacy qualifiers, scrubbing tokens from URLs and logs, the pasteboard and screenshot leak surfaces, and the "what shows up in a crash report" question.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                            | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | ATS & the threat model; pinning (cert vs SPKI); `URLSession` delegate |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | CryptoKit: hashing, `AES.GCM`, key agreement, signatures         |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Secure Enclave; access control; Face ID gating; the challenge    |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | Request signing end to end; server-side verify; log scrubbing    |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — pin the `NotesClient`, generate the Enclave key    |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; sign + verify a round trip on device     |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                       |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                  | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | Apple's CryptoKit / Security / LocalAuthentication docs, the WWDC crypto sessions, the ATS and pinning references, and the canonical writing on Secure Enclave and key management |
| [lecture-notes/01-ats-pinning-and-the-threat-model.md](./02-lecture-notes/01-ats-pinning-and-the-threat-model.md) | The threat model first, then ATS end to end, certificate vs public-key pinning, the `URLSession` delegate hook, and the operational discipline pinning demands |
| [lecture-notes/02-cryptokit-secure-enclave-and-request-signing.md](./02-lecture-notes/02-cryptokit-secure-enclave-and-request-signing.md) | CryptoKit (hash, AES-GCM, key agreement, signatures), the Secure Enclave model, biometric-gated access control, and the full request-signing / server-verify flow |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-pin-a-certificate.md](./03-exercises/exercise-01-pin-a-certificate.md) | Build a pinning `URLSession` delegate, pin a server's SPKI hash, and prove it rejects a wrong-but-valid certificate |
| [exercises/exercise-02-cryptokit-roundtrips.swift](./03-exercises/exercise-02-cryptokit-roundtrips.swift) | Hash, AES-GCM seal/open, X25519 key agreement + HKDF, and Ed25519/P-256 sign/verify — with tests that prove tamper detection |
| [exercises/exercise-03-secure-enclave-sign-and-verify.swift](./03-exercises/exercise-03-secure-enclave-sign-and-verify.swift) | Generate a Secure Enclave P-256 key, persist its representation, sign a payload, and verify with the public key |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the challenge |
| [challenges/challenge-01-mitm-then-pin.md](./04-challenges/challenge-01-mitm-then-pin.md) | Stand up an mitmproxy MITM, watch it read your unpinned traffic, then add SPKI pinning and prove the same proxy is now locked out — with evidence |
| [quiz.md](./05-quiz.md) | 13 questions on the threat model, ATS, pinning, CryptoKit, the Secure Enclave, and key management |
| [homework.md](./06-homework.md) | Six practice problems for the week |
| [mini-project/README.md](./07-mini-project/00-overview.md) | Full spec: pin the `NotesClient`, generate a Secure Enclave key, sign every request, and verify it in the Vapor backend |

## The "name the threat first" promise

Week 16 gave you "accessibility is engineering, not charity." Week 17 adds the discipline a security reviewer actually checks:

> **No cryptographic primitive goes into the codebase without a one-sentence threat statement.** Before you add pinning, write down the attacker it stops (active MITM with a rogue or proxy CA). Before you move a key into the Secure Enclave, write down the attacker it stops (root on the device, a stolen device image). Before you gate an operation behind Face ID, write down the attacker it stops (someone holding the unlocked phone). If you can't name the threat, you're adding ceremony, not security — and ceremony that looks like security is worse than nothing, because it tells the team they're protected when they aren't.

You will *practise* this by annotating every security control in the mini-project with the threat it answers, in a `THREATS.md`. "I added encryption" is not an engineering statement. "I added AES-GCM with a Secure-Enclave-derived key so a forensic image of the device can't decrypt the cache" is.

## A note on what's not here

Week 17 is the *on-device and in-transit security* week. It deliberately does **not** cover:

- **Server-side security in depth.** We write the one Vapor route that verifies a signature, but auth tokens, rate limiting, OWASP, and the full backend threat model belong to the web-backend tracks (C16/C17). We secure the *client* and the *channel*.
- **Jailbreak detection and obfuscation.** Anti-tamper, code obfuscation, and jailbreak detection are an arms race with poor ROI for most apps and are out of scope. We rely on the platform's hardware guarantees (the Secure Enclave) rather than trying to out-cleverness a rooted device.
- **Passkeys / WebAuthn and Sign in with Apple.** These are real, modern auth primitives, but they're an authentication topic; our focus is cryptographic key management and channel integrity. We flag where passkeys would slot in and move on.

The point of Week 17 is narrow and deep: the threat model, the channel (ATS + pinning), the primitives (CryptoKit), the hardware (Secure Enclave), and the one end-to-end flow that ties them together — a request your server can prove came from a specific device, signed by a key no attacker can extract.

## Up next

Continue to **Week 18 — Push notifications, StoreKit 2, MetricKit telemetry** once you have shipped this week's mini-project and proven a signed round trip on a physical device. Week 18 is the Phase III integration project — "Notes Pro v1" — and it builds directly on the secure client you hardened this week: the push payloads you decrypt in a Notification Service Extension use the CryptoKit primitives from this week, and the StoreKit receipt validation uses the same `Curve25519.Signing` verification flow you wrote for request signing. Security is not a week you do and forget; it is the substrate the next two phases stand on. Earn the threat-model reflex here.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
