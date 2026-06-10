# Lecture 2 — CryptoKit, the Secure Enclave, and request signing end to end

Lecture 1 secured the *channel*. This lecture secures the *secrets* and builds the one end-to-end flow that ties the week together: a request your server can prove came from a specific device, signed by a key that no attacker — not even one with root — can extract. We get there in three moves. First CryptoKit, Apple's Swift-native cryptography library, which is designed so the safe thing is the easy thing and the unsafe thing is hard to even spell. Then the Secure Enclave, the hardware that makes "the key exists but you can't read it" a real property and not a hope. Then request signing, which composes the two into authentication that survives a stolen bearer token.

The design philosophy to hold throughout: **CryptoKit gives you typed, misuse-resistant primitives.** You cannot accidentally pass a hash where a key is expected, or feed a nonce twice, or compare a MAC with a timing-leaky `==`, because the types won't let you. That is deliberate. The history of cryptographic vulnerabilities in production software is overwhelmingly *misuse* — right algorithm, wrong nonce; right cipher, leaked key; right signature, no verification — not broken math. CryptoKit's job is to make the misuses unrepresentable. Your job is to use it as intended and not reach around it.

---

## 1. CryptoKit's shape — typed values, not byte buffers

Older crypto APIs (CommonCrypto, OpenSSL) hand you `UnsafePointer<UInt8>` and a pile of integer flags, and trust you to get the modes, paddings, and lengths right. CryptoKit hands you *Swift types*: a `SymmetricKey` is not a `Data`, a `SHA256.Digest` is not a `SymmetricKey`, an `AES.GCM.SealedBox` carries its own nonce and authentication tag. The compiler enforces that you wire them together correctly. Everything in this lecture flows from that.

### Hashing

```swift
import CryptoKit
import Foundation

let message = Data("the quick brown fox".utf8)

// SHA-256 digest. Note: a Digest is its OWN type, not Data — you can't pass it
// where a key goes. To turn it into bytes for transport, wrap it in Data.
let digest = SHA256.hash(data: message)
let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
// hexDigest is the familiar 64-hex-char SHA-256.

// SHA-1 still exists, but it's namespaced under `Insecure` ON PURPOSE — you
// have to type `Insecure.SHA1` to use it, which is a speed bump that makes
// you ask "why am I reaching for a broken hash?"
let legacy = Insecure.SHA1.hash(data: message)   // for interop only, never for security
```

The `Insecure` namespace is the philosophy in miniature: SHA-1 and MD5 are reachable (you sometimes need them for legacy interop), but you must *spell out* that they're insecure. The safe default (`SHA256`, `SHA512`) is the short name.

### HMAC — an authenticated tag, compared in constant time

When you need to prove a message wasn't tampered with *and* came from someone who holds a shared key, you use an HMAC. The important detail: CryptoKit's `isValidAuthenticationCode` compares in **constant time**, so an attacker can't learn the correct MAC byte-by-byte from timing. Never compare MACs with `==`.

```swift
let key = SymmetricKey(size: .bits256)
let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)

// Verify — constant-time comparison, not `Data(mac) == receivedMac`.
let ok = HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: message, using: key)
```

### Generating and sizing symmetric keys

```swift
// 256-bit AES key, generated from the system CSPRNG. You don't seed it; you
// don't reach for `arc4random`; CryptoKit uses the right randomness source.
let aesKey = SymmetricKey(size: .bits256)

// If you must persist or transport a symmetric key, extract its bytes via
// withUnsafeBytes -> Data. (You almost always DERIVE keys instead; see §3.)
let keyBytes = aesKey.withUnsafeBytes { Data($0) }
```

---

## 2. AES-GCM — authenticated encryption, and why nonce reuse is catastrophic

For encrypting data at rest (a cached note, a credential blob), the primitive is **AES in GCM mode** — Authenticated Encryption with Associated Data (AEAD). GCM gives you two guarantees at once: **confidentiality** (the ciphertext reveals nothing about the plaintext) and **authenticity** (any tampering with the ciphertext is detected on decryption). The second is what makes it "authenticated" — a non-authenticated mode like CBC encrypts but lets an attacker flip bits in ways you won't notice.

```swift
import CryptoKit
import Foundation

let key = SymmetricKey(size: .bits256)
let plaintext = Data("a note worth protecting".utf8)

// SEAL: encrypt + authenticate. CryptoKit generates a fresh random nonce for you.
let sealedBox = try AES.GCM.seal(plaintext, using: key)

// The SealedBox bundles nonce + ciphertext + tag. `.combined` is the wire form
// you store or transmit — one blob that carries everything `open` needs.
let onDisk: Data = sealedBox.combined!

// OPEN: decrypt + verify. If the ciphertext or tag was altered by even one bit,
// `open` THROWS — it does not return garbage. Tamper detection is built in.
let reopened = try AES.GCM.SealedBox(combined: onDisk)
let recovered = try AES.GCM.open(reopened, using: key)
assert(recovered == plaintext)
```

### Why nonce reuse is catastrophic — and how CryptoKit prevents it

GCM's security depends on **never using the same (key, nonce) pair twice.** If you encrypt two different messages with the same key and the same nonce, an attacker who sees both ciphertexts can XOR them to recover the XOR of the plaintexts — and, worse, can forge the authentication tag, defeating the authenticity guarantee entirely. This is not a theoretical weakness; it is the failure mode that has broken real deployments (the most famous being a 2016 disclosure of GCM nonce reuse across major HTTPS sites).

CryptoKit defends you in two ways:

1. **`AES.GCM.seal(_:using:)` generates a fresh random nonce every call.** You don't pass one; you can't accidentally reuse one. The 96-bit nonce space is large enough that random nonces don't collide in practice for any sane message count.
2. **If you *do* supply a nonce** (there's an overload that takes one, for protocols that require deterministic nonces), the type is `AES.GCM.Nonce` and it's your explicit responsibility — the API makes the dangerous path the verbose path.

The lesson for this week: **use the no-nonce-argument `seal`.** Let CryptoKit pick the nonce. The only reason to supply your own is a specific interop protocol, and then you need a counter discipline you can prove never repeats. For app-level "encrypt this blob at rest," the default is correct and safe.

---

## 3. Asymmetric crypto — key agreement and signatures

Symmetric keys assume both sides already share a secret. Often they don't, and you need *asymmetric* (public-key) cryptography: each party has a private key it keeps and a public key it shares. CryptoKit gives you two curve families for two distinct jobs. **Do not mix them up** — a signing key is not an encryption key, and using one for the other is a textbook misuse.

### Key agreement (X25519) — deriving a shared secret over an insecure channel

`Curve25519.KeyAgreement` implements X25519 ECDH: two parties exchange public keys and each independently computes the *same* shared secret without ever transmitting it. You then run that secret through a KDF (HKDF) to get a symmetric key for AES-GCM.

```swift
// Each side generates an ephemeral key agreement key pair.
let alicePrivate = Curve25519.KeyAgreement.PrivateKey()
let bobPrivate = Curve25519.KeyAgreement.PrivateKey()

// They exchange PUBLIC keys (safe to send in the clear).
let alicePublic = alicePrivate.publicKey
let bobPublic = bobPrivate.publicKey

// Each computes the SAME shared secret from their own private + the other's public.
let aliceShared = try alicePrivate.sharedSecretFromKeyAgreement(with: bobPublic)
let bobShared   = try bobPrivate.sharedSecretFromKeyAgreement(with: alicePublic)
// aliceShared == bobShared, and an eavesdropper who saw both public keys cannot derive it.

// NEVER use the raw shared secret as a key. Run it through HKDF to get a
// uniformly-random symmetric key bound to a context ("salt"/"info").
let symmetricKey = aliceShared.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data("notes-app-v1".utf8),
    sharedInfo: Data(),
    outputByteCount: 32
)
// Now use `symmetricKey` with AES.GCM. This is the standard "ECDH -> HKDF -> AES-GCM" pattern.
```

The discipline: **the raw ECDH output is not a key.** It's a point on a curve; its bytes aren't uniformly random. HKDF turns it into a proper symmetric key and lets you bind it to a context string so the same shared secret yields *different* keys for different purposes. CryptoKit's `hkdfDerivedSymmetricKey` does this in one call.

### Signatures (Ed25519 / P-256) — proving authorship

`Curve25519.Signing` (Ed25519) and `P256.Signing` (NIST P-256, ECDSA) produce *detached signatures*: the holder of the private key signs a message, and anyone with the public key can verify that this exact message was signed by that exact key. Verification is the half people forget — a signature you don't verify is decoration.

```swift
// Ed25519 — fast, modern, the default choice for app-level signing.
let signingKey = Curve25519.Signing.PrivateKey()
let publicKey = signingKey.publicKey

let payload = Data("transfer $100 to Bob".utf8)
let signature = try signingKey.signature(for: payload)

// Verify with the PUBLIC key. Returns Bool — and you MUST check it.
let valid = publicKey.isValidSignature(signature, for: payload)
assert(valid)

// Tamper with the payload by one byte and verification fails:
let tampered = Data("transfer $900 to Bob".utf8)
assert(publicKey.isValidSignature(signature, for: tampered) == false)
```

Why does this week use **P-256** for the request-signing flow rather than Ed25519, when Ed25519 is otherwise the nicer choice? Because **the Secure Enclave supports P-256 and not Ed25519.** The Enclave's hardware key generation is fixed to the NIST P-256 curve (`SecureEnclave.P256.*`). So when we want a *hardware-backed* signing key — the whole point of the mini-project — we use P-256. For software keys with no Enclave requirement, Ed25519 (`Curve25519.Signing`) is the better default. The curve choice is driven by where the key lives.

---

## 4. The Secure Enclave — "the key exists but you can't read it"

The Secure Enclave is a separate hardware security processor present on every modern iPhone, iPad, Apple Watch, and Apple Silicon Mac. It has its own boot ROM, its own AES engine, and — critically — its own isolated memory that the main application processor cannot read. Keys generated *inside* the Enclave never leave it. Your app's process never sees the private key bytes. You hold a *handle*; the hardware does the cryptographic math on your behalf and hands back only the result (a signature, a shared secret).

This is the property that answers adversary 5 from lecture 1 — root on the device, a forensic image. A normal software key, even one in the Keychain, is *decryptable* by something with sufficient access to the device's storage and the unlock state. A Secure Enclave key is *not present in storage at all* in a usable form; what's stored is an encrypted blob the Enclave alone can interpret, bound to that specific device. Image the disk, pull the blob, move it to another device — it's inert. The key cannot be extracted because it never existed outside the hardware.

### Generating and persisting a Secure Enclave key

```swift
import CryptoKit
import Foundation

enum EnclaveKeyError: Error { case unavailable, accessControl(OSStatus), notFound }

/// Generate a P-256 signing key INSIDE the Secure Enclave. The private key
/// material never enters this process; `key` is a handle.
func makeEnclaveSigningKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
    // The Simulator has no Enclave; this returns false there. Check it.
    guard SecureEnclave.isAvailable else { throw EnclaveKeyError.unavailable }

    // Access control: require the key be usable only when the device is unlocked,
    // bound to THIS device, and gated on biometrics/passcode for use.
    var error: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .userPresence],   // require user presence (Face ID / passcode) to sign
        &error
    ) else {
        throw EnclaveKeyError.accessControl(errSecParam)
    }

    return try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
}
```

Now the subtle part: the key handle itself isn't `Codable` and you can't store the private bytes (there are none to store). What you persist is the key's **`dataRepresentation`** — an *encrypted, device-bound blob* that the Enclave can later rehydrate back into a usable handle on the *same device*. You keep this blob in the Keychain:

```swift
import Security

/// Persist the Enclave key's encrypted representation in the Keychain.
/// This blob is NOT the private key — it's a device-bound ciphertext only this
/// device's Enclave can turn back into a usable key.
func storeEnclaveKey(_ key: SecureEnclave.P256.Signing.PrivateKey, tag: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: tag,
        kSecValueData as String: key.dataRepresentation,
        // After-first-unlock, this-device-only: survives reboots once unlocked,
        // never syncs to iCloud, never leaves this device.
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    SecItemDelete(query as CFDictionary)               // overwrite if present
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw EnclaveKeyError.accessControl(status) }
}

/// Reload the key handle from its stored representation. The private key is
/// reconstructed INSIDE the Enclave; this process still never sees the bytes.
func loadEnclaveKey(tag: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: tag,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
        throw EnclaveKeyError.notFound
    }
    return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
}
```

The mental model to lock in: **you are storing a recipe the Enclave can follow to rebuild the key, not the key.** Move that blob to another device and it's useless, because it's bound to this device's Enclave. That binding is the security property. (`SecureEnclave.isAvailable` is `false` in the Simulator — which is why the mini-project's signing parts run on a physical device. Build the rest in the Simulator; sign on hardware.)

---

## 5. Access control and biometrics — gating the *use* of a key

Generating the key with `.userPresence` (or the more specific `.biometryCurrentSet`) means *using* it — signing — requires the user to authenticate. The Enclave enforces this in hardware: it won't perform the signature unless `LocalAuthentication` confirms the user is present. You drive that with an `LAContext`:

```swift
import LocalAuthentication

/// Sign `payload` with the Enclave key, prompting Face ID / Touch ID first.
func signWithBiometrics(
    payload: Data,
    key: SecureEnclave.P256.Signing.PrivateKey
) async throws -> P256.Signing.ECDSASignature {
    let context = LAContext()
    context.localizedReason = "Sign your note request"

    // Confirm a biometric/passcode before the protected key operation.
    let authed = try await context.evaluatePolicy(
        .deviceOwnerAuthentication,             // biometrics, falling back to passcode
        localizedReason: "Authenticate to sign this request"
    )
    guard authed else { throw EnclaveKeyError.unavailable }

    // The Enclave performs the ECDSA signature; we only ever see the result.
    return try key.signature(for: payload)
}
```

Two access-control flags to distinguish, because the choice is a security decision:

- **`.biometryAny`** — any enrolled fingerprint/face works. The key survives the user adding a new finger or re-enrolling Face ID.
- **`.biometryCurrentSet`** — the key is invalidated if the enrolled biometric set *changes* (a new finger added, Face ID re-enrolled). This is stronger: if an attacker who has your unlocked phone *adds their own fingerprint*, a `.biometryCurrentSet` key becomes unusable, because the set changed. For a high-value signing key, `.biometryCurrentSet` is the right call — the invalidation is a feature, not a bug.

The threat this answers (lecture 1, adversary 3): someone with your unlocked device for thirty seconds. Without biometric gating, they can use your signing key freely. With `.userPresence` / `.biometryCurrentSet`, they're stopped at the Face ID prompt — and if they try to enrol their own face, the key dies.

---

## 6. Request signing end to end — the flow the mini-project ships

Now we compose everything into the week's deliverable: a request your Vapor server can prove came from a specific, enrolled device, signed by a Secure Enclave key no attacker can extract. This is **request-level authentication layered on top of TLS** — it survives a stolen bearer token, because the token alone can't reproduce the signature.

### The client side — sign a canonical request representation

The thing you sign must be a **canonical** representation of the request — deterministic, so the server can reconstruct the exact same bytes and verify. Sign the method, path, a timestamp (to prevent replay), and a hash of the body:

```swift
import CryptoKit
import Foundation

struct SignedRequest {
    let request: URLRequest
    let keyID: String
    let signatureBase64: String
}

/// Build the canonical string the server will independently reconstruct.
func canonicalString(method: String, path: String, timestamp: Int, bodyHash: String) -> String {
    // Order and format are a CONTRACT shared with the server. Any mismatch =
    // signature fails. Keep it simple and explicit.
    "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
}

func signRequest(
    method: String,
    path: String,
    body: Data,
    keyID: String,
    key: SecureEnclave.P256.Signing.PrivateKey
) throws -> SignedRequest {
    let timestamp = Int(Date().timeIntervalSince1970)
    let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
    let canonical = canonicalString(method: method, path: path, timestamp: timestamp, bodyHash: bodyHash)

    // The Enclave signs the canonical bytes; the private key never leaves hardware.
    let signature = try key.signature(for: Data(canonical.utf8))

    var request = URLRequest(url: URL(string: "https://notes.example.com\(path)")!)
    request.httpMethod = method
    request.httpBody = body
    request.setValue(keyID, forHTTPHeaderField: "X-Device-Key-ID")
    request.setValue(String(timestamp), forHTTPHeaderField: "X-Request-Timestamp")
    request.setValue(signature.derRepresentation.base64EncodedString(), forHTTPHeaderField: "X-Request-Signature")

    return SignedRequest(request: request, keyID: keyID, signatureBase64: signature.derRepresentation.base64EncodedString())
}
```

On first launch, the client generates its Enclave key, derives a `keyID` (e.g. a hash of the public key), and **enrols the public key** with the server over the (pinned) TLS channel — a one-time `POST /devices` carrying the public key's `rawRepresentation`. The server stores `keyID -> publicKey`. From then on, every request carries the signature, and the server looks up the enrolled public key by `keyID` to verify.

### The server side — verify with `swift-crypto`

On Linux there's no CryptoKit, but `swift-crypto` is the identical API. The Vapor route reconstructs the canonical string from the request it received and checks the signature against the enrolled public key:

```swift
// Vapor route handler (server side). `swift-crypto` mirrors CryptoKit exactly.
import Crypto   // swift-crypto
import Vapor

func verifySignedRequest(_ req: Request) throws -> Bool {
    guard let keyID = req.headers.first(name: "X-Device-Key-ID"),
          let tsString = req.headers.first(name: "X-Request-Timestamp"),
          let timestamp = Int(tsString),
          let sigBase64 = req.headers.first(name: "X-Request-Signature"),
          let sigData = Data(base64Encoded: sigBase64) else {
        return false
    }

    // 1. Replay defence: reject stale timestamps (e.g. > 5 minutes old).
    guard abs(Int(Date().timeIntervalSince1970) - timestamp) <= 300 else { return false }

    // 2. Look up the enrolled public key for this device.
    guard let publicKey = try DeviceKeyStore.publicKey(forID: keyID) else { return false }

    // 3. Reconstruct the EXACT canonical string the client signed.
    let body = req.body.data.map { Data(buffer: $0) } ?? Data()
    let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
    let canonical = "\(req.method.string)\n\(req.url.path)\n\(timestamp)\n\(bodyHash)"

    // 4. Verify. Same `isValidSignature` call as on the client.
    let signature = try P256.Signing.ECDSASignature(derRepresentation: sigData)
    return publicKey.isValidSignature(signature, for: Data(canonical.utf8))
}
```

What this buys you, concretely: an attacker who steals the user's bearer token still cannot forge a request, because they don't have the Enclave key and can't produce a valid `X-Request-Signature`. They can't extract the key (it's in hardware). They can't replay an old request (the timestamp is signed and the server rejects stale ones). They can't MITM-inject (the channel is pinned, lecture 1). Three adversaries, three composed defences, one request.

---

## 7. Sensitive-data hygiene — the leaks that aren't cryptographic

The fastest way to leak a secret in 2026 is still to `print()` it. All the Enclave keys in the world don't help if your token shows up in a log aggregator. CryptoKit and the Enclave protect *keys*; you protect *everything else* with hygiene.

`OSLog` is privacy-aware: interpolated values are **redacted by default** in release builds, and you opt *in* to showing them with `.public`. The discipline is to never mark a secret `.public`:

```swift
import OSLog

let log = Logger(subsystem: "com.crunch.notes", category: "auth")

let token = "secret-bearer-token"
let userID = "user-42"

// WRONG — leaks the token to Console.app, sysdiagnose, and any log capture.
log.error("auth failed for token \(token, privacy: .public)")

// RIGHT — the token is redacted by default; mark only non-sensitive values .public.
log.error("auth failed for user \(userID, privacy: .public), token \(token)")
// In a release build this logs: "auth failed for user user-42, token <private>"
```

The leak surfaces a reviewer checks for, beyond logs:

- **Tokens in URLs.** A token in a query string (`?token=...`) ends up in server access logs, proxy logs, and `Referer` headers. Put secrets in headers or the body, never the URL.
- **The pasteboard.** Copying a secret to the general pasteboard exposes it to every app (and, with Universal Clipboard, every device). Use `UIPasteboard` expiry / local-only flags for sensitive copies, or don't copy at all.
- **Screenshots / app switcher.** The OS snapshots your UI for the app switcher. A screen showing a secret gets snapshotted; blur or hide sensitive views on `scenePhase` change to `.inactive`.
- **Crash logs.** A secret in a stack-trace variable can land in a crash report. Don't hold raw secrets in long-lived properties named in a way that ends up symbolicated.

None of these are cryptography. All of them are how real apps leak. The threat-model habit applies here too: a token in a log answers no adversary and arms several.

---

## 8. Recap

This lecture built the secrets half of the week and the flow that ties it to lecture 1's channel half:

1. **CryptoKit makes the safe thing easy.** Typed values stop you passing a hash where a key goes; `AES.GCM.seal` picks a fresh nonce so you can't reuse one; `isValidAuthenticationCode` and `isValidSignature` compare safely. Use it as intended; don't reach around it. Nonce reuse in GCM is catastrophic, and the API is shaped to prevent it.
2. **Key agreement and signatures are different jobs with different keys.** X25519 → HKDF → AES-GCM derives a shared symmetric key over an insecure channel; Ed25519 / P-256 sign and verify authorship. Verify every signature — an unverified signature is decoration. Use P-256 when the key must live in the Enclave.
3. **The Secure Enclave makes "the key exists but you can't read it" real.** The private key never enters your process; you persist a device-bound encrypted *representation*, gate its use behind biometrics, and the hardware does the math. That answers the root-on-device adversary.
4. **Request signing composes it all.** Sign a canonical request representation with the Enclave key, enrol the public key with the server over the pinned channel, and verify with `swift-crypto`. The result is authentication a stolen bearer token can't defeat.
5. **Hygiene catches the non-cryptographic leaks.** `OSLog` redacts by default; never mark a secret `.public`; keep tokens out of URLs, the pasteboard, screenshots, and crash logs.

The exercises drill each primitive — pin a cert, round-trip every CryptoKit operation with tamper tests, generate and use a Secure Enclave key. The challenge stands up a real MITM and proves pinning locks it out. The mini-project ships the whole flow on a physical device: a pinned, request-signing `NotesClient` whose signatures your Vapor backend verifies. Name the threat, pick the primitive, compose the defences. That's the week.
