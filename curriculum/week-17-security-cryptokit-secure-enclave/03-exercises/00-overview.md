# Week 17 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones.

## Index

1. **[Exercise 1 — Pin a certificate (and prove it rejects a wrong one)](./exercise-01-pin-a-certificate.md)** — extract a server's SPKI hash with `openssl`, build a `URLSession` pinning delegate, and prove it accepts the right key and rejects a valid-but-wrong one. The channel half of the week, in one exercise. (~45 min)
2. **[Exercise 2 — CryptoKit round-trips with tamper tests](./exercise-02-cryptokit-roundtrips.swift)** — hash, AES-GCM seal/open, X25519 key agreement + HKDF, and Ed25519/P-256 sign/verify, each with a test that proves tampering is *detected*. You produce passing tests and explain why each tamper fails. (~50 min)
3. **[Exercise 3 — Generate a Secure Enclave key, sign, and verify](./exercise-03-secure-enclave-sign-and-verify.swift)** — create a `SecureEnclave.P256.Signing.PrivateKey`, persist its representation, reload it, sign a payload, and verify with the public key. Runs on a **physical device** (the Simulator has no Enclave). (~45 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste. Muscle memory is the entire point of these drills — and for security code, the muscle memory of "verify the signature, check the pin, mark the log private" is exactly what stops the bug.
- Run it. Exercises 2 is pure CryptoKit and runs **anywhere** (Simulator, macOS, a Swift package test target). Exercise 3 needs a **physical device** because `SecureEnclave.isAvailable` is `false` in the Simulator — observe that fact, then deploy to hardware.
- The `.swift` exercises are written as Swift Testing suites (`import Testing`, `@Test`, `#expect`). Drop them into a test target of an iOS 17+/macOS 14+ app or a Swift package.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must **build with zero warnings** and pass its stated acceptance criteria. Under Swift 6 strict concurrency, a `Sendable` warning is a bug this week — and a suppressed warning (`@unchecked Sendable`, `nonisolated(unsafe)`) on a security type is worse than a bug, it's a footgun the next reader trusts.

## A security-specific working rule

For every primitive you touch this week, write down — in a comment or a scratch note — the **one-sentence threat statement** it answers (the README's "name the threat first" promise). Exercise 1 stops an active MITM. Exercise 2's signatures stop tampering and forgery. Exercise 3's Enclave key stops key extraction by an attacker with the device. If you can't name the threat, you don't yet understand why you're typing the code.

There are no solutions checked in. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-17` to compare.
