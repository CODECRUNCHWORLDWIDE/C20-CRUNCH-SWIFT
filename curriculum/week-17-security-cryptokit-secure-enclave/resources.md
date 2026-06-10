# Week 17 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **CryptoKit — framework landing page.** The type list (`SymmetricKey`, `AES.GCM`, `Curve25519`, `SHA256`, `SecureEnclave`) and the article index — read this before you write a single `import CryptoKit`:
  <https://developer.apple.com/documentation/cryptokit>
- **"Performing Common Cryptographic Operations."** Apple's canonical CryptoKit walkthrough — hashing, signing, encrypting, key agreement, all in one article:
  <https://developer.apple.com/documentation/cryptokit/performing-common-cryptographic-operations>
- **"Storing CryptoKit Keys in the Keychain."** How to persist a key (or a Secure Enclave key's representation) — central to the mini-project:
  <https://developer.apple.com/documentation/cryptokit/storing-cryptokit-keys-in-the-keychain>
- **"Preventing Insecure Network Connections" (App Transport Security).** The ATS reference: what it enforces, the `Info.plist` keys, and `NSPinnedDomains`:
  <https://developer.apple.com/documentation/security/preventing-insecure-network-connections>
- **"Performing Manual Server Trust Authentication."** The `URLSession` delegate hook where certificate/public-key pinning lives:
  <https://developer.apple.com/documentation/foundation/url_loading_system/handling_an_authentication_challenge/performing_manual_server_trust_authentication>

## The types you'll use (reference, skim don't memorize)

- **`SymmetricKey`:** <https://developer.apple.com/documentation/cryptokit/symmetrickey>
- **`AES.GCM` and `AES.GCM.SealedBox`:** <https://developer.apple.com/documentation/cryptokit/aes/gcm>
- **`SHA256` / `SHA512` / `Insecure.SHA1` (and why SHA-1 is in `Insecure`):** <https://developer.apple.com/documentation/cryptokit/sha256>
- **`HMAC`:** <https://developer.apple.com/documentation/cryptokit/hmac>
- **`Curve25519.KeyAgreement` (X25519) and `Curve25519.Signing` (Ed25519):** <https://developer.apple.com/documentation/cryptokit/curve25519>
- **`P256` (NIST P-256, `.Signing` and `.KeyAgreement`):** <https://developer.apple.com/documentation/cryptokit/p256>
- **`HKDF` (key derivation):** <https://developer.apple.com/documentation/cryptokit/hkdf>
- **`SecureEnclave` (`P256.Signing.PrivateKey`, `.KeyAgreement.PrivateKey`, `.isAvailable`):** <https://developer.apple.com/documentation/cryptokit/secureenclave>
- **`SecAccessControl` / `SecAccessControlCreateWithFlags`:** <https://developer.apple.com/documentation/security/secaccesscontrol>
- **`LAContext` (LocalAuthentication):** <https://developer.apple.com/documentation/localauthentication/lacontext>

## WWDC sessions (free, watch in this order)

- **"Cryptography and Your Apps" (WWDC19)** — the introduction to CryptoKit; the design philosophy ("make the safe thing the easy thing") and the Secure Enclave types:
  <https://developer.apple.com/videos/play/wwdc2019/709/>
- **"Protect mutable state with Swift actors" (WWDC21)** — not crypto, but the isolation rules that govern where your signing key and `URLSession` delegate live; relevant because the `NotesClient` is an actor:
  <https://developer.apple.com/videos/play/wwdc2021/10133/>
- **"What's new in privacy" (most recent WWDC)** — the platform privacy posture that frames sensitive-data hygiene; watch the current year's edition:
  <https://developer.apple.com/videos/all-videos/?q=privacy>
- **"Explore the Apple platform security model"** — the system-level view of the Secure Enclave, data protection classes, and how Keychain accessibility maps to hardware:
  <https://support.apple.com/guide/security/welcome/web>

## App Transport Security & pinning

- **ATS `Info.plist` key reference (`NSAppTransportSecurity`):** <https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity>
- **`NSPinnedDomains` — declarative pinning without a delegate:** <https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nspinneddomains>
- **`urlSession(_:didReceive:completionHandler:)` — the server-trust challenge:** <https://developer.apple.com/documentation/foundation/urlsessiondelegate/urlsession(_:didreceive:completionhandler:)>
- **OWASP — Certificate and Public Key Pinning** (the cross-platform reference on *why* and the rotation footguns): <https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning>

## The Secure Enclave (the hardware story)

The Secure Enclave is the reason "the key exists but you can't read it" is possible. Read enough to be able to explain it on a whiteboard.

- **Apple Platform Security — Secure Enclave** (the authoritative description of the hardware): <https://support.apple.com/guide/security/secure-enclave-sec59b0b31ff/web>
- **Data Protection classes** (how Keychain accessibility maps to when the key material is decryptable): <https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web>
- **`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and friends** — the accessibility constants reference: <https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly>

## Server-side crypto (the Vapor half)

Your Vapor backend verifies the request signature. On Linux there is no CryptoKit, but there is its open-source twin.

- **`apple/swift-crypto`** — the same API as CryptoKit, cross-platform; this is what your Vapor route imports to verify a `P256.Signing` signature: <https://github.com/apple/swift-crypto>
- **`swift-crypto` docs** mirror CryptoKit's; the `P256.Signing.PublicKey.isValidSignature(_:for:)` call is identical on server and client.

## Tools you'll use this week

- **`mitmproxy`** (free, open-source) — the man-in-the-middle proxy for the challenge. You install its CA on the Simulator/device, watch it read unpinned HTTPS, then prove pinning locks it out: <https://mitmproxy.org/>
- **`openssl`** — to extract a server's SubjectPublicKeyInfo and compute the SPKI SHA-256 hash you pin against. The one-liner is in lecture 1.
- **`security` (macOS CLI)** — inspect and manipulate Keychain items; `security find-certificate`, `security cms`. Useful for debugging what's actually stored.
- **A physical iPhone or iPad (or Apple Silicon Mac)** — the Secure Enclave parts require real hardware; the Simulator has no Enclave. `SecureEnclave.isAvailable` returns `false` in the Simulator, which is itself a useful thing to observe.
- **Xcode 16+** — `xcrun simctl` for installing the mitmproxy CA on a booted Simulator; Console.app and the Xcode console for reading `OSLog` privacy-redacted output.

## Community writing (current, opinionated, correct)

- **Hacking with Swift — CryptoKit and Keychain articles.** Paul Hudson keeps these current per OS release; the AES-GCM and Secure Enclave examples are clean:
  <https://www.hackingwithswift.com/>
- **Quinn "The Eskimo!" on the Apple Developer Forums** — the definitive answers on Keychain, server trust, and the Secure Enclave; search his posts in the **Privacy & Security** and **Network** categories:
  <https://developer.apple.com/forums/profile/eskimo>
- **OWASP Mobile Application Security (MAS)** — the cross-platform standard for what "secure mobile app" actually means; the MASVS verification requirements are a good checklist:
  <https://mas.owasp.org/>
- **Frederik Wallner / Rob Napier — "iOS cryptography done right" writing** — practical, correct, opinionated about the common mistakes (nonce reuse, pinning without rotation).

## Open-source projects to read this week

You learn more from one hour reading a real secured client than from three hours of tutorials. Pick one and trace how they pin and where the key lives:

- **`apple/swift-crypto`** — read `Sources/Crypto/Signatures/ECDSA.swift` to see exactly what `isValidSignature` checks; the same code runs on your client and your Vapor server:
  <https://github.com/apple/swift-crypto>
- **`TrustKit/TrustKit`** — the canonical Objective-C/Swift pinning library; even if you hand-roll your delegate, reading how TrustKit handles SPKI pinning and backup pins is instructive:
  <https://github.com/datatheorem/TrustKit>
- **`hyperoslo/Keychain`-style wrappers** — read one small Keychain wrapper to see the `SecItemAdd`/`SecItemCopyMatching` ceremony the wrapper hides, so you understand what you're actually calling.

## Free reading (chapter-level)

- **Apple Platform Security guide** (linked above) is effectively a free book on the hardware security model; read the **Secure Enclave**, **Data Protection**, and **Keychain** sections end to end.
- **CryptoKit's article group** in the developer docs (the four "Performing…" / "Storing…" articles) is a free, sample-driven mini-book.

## Paid books (optional, clearly marked)

- **"iOS Application Security" — David Thiel, No Starch Press** (paid). The most complete single book on the iOS attack surface; the Keychain and transport-security chapters age well.
- **"Serious Cryptography" — Jean-Philippe Aumasson, No Starch Press** (paid). Not iOS-specific, but the clearest explanation in print of *why* GCM nonce reuse is catastrophic and what AEAD guarantees — the conceptual backing for this week's CryptoKit work.

---

*If a link 404s, please open an issue so we can replace it.*
