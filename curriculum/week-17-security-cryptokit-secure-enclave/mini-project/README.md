# Mini-Project — Harden the NotesClient: pinning + Secure Enclave request signing

This week the `NotesClient` stops trusting the network and starts proving who it is. You will take the `URLSession`-based client from Week 13 and harden it end to end: **pin** the Vapor server's public key so a proxy or rogue CA can't read or forge traffic, generate a **Secure Enclave P-256 key** on first launch, **sign every outbound request** with it, and **verify** that signature in the Vapor backend with the device's enrolled public key. The result is request-level authentication that survives a stolen bearer token — and a key no attacker can extract, because it lives in hardware.

This is a *compounding* project. It is not a new app. You start from the Week 13 `NotesClient` (with the Keychain credential storage from Week 14) and you wrap its request pipeline with two new layers — pinning below, signing above — without changing the call sites. The point of the week is to feel how *cleanly* security composes onto a well-structured client: `fetchNotes()` doesn't change; what it sits on top of does. And the discipline throughout is the README's promise — **every control gets a one-sentence threat statement**, recorded in a `THREATS.md`.

---

## Where you're starting from

Your Week 13 client has, roughly:

- An `actor NotesClient` holding a `URLSession`, with structured errors, retry-with-jitter, and offline detection.
- Methods like `fetchNotes() async throws -> [NoteDTO]` and `createNote(_:) async throws`.
- A bearer token stored in the Keychain (Week 14) with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- A Vapor backend you can run and edit, with the notes routes from Phase I.

If you don't have a clean Week 13 checkpoint, build the minimal version first; the hardening is the same either way.

## What you're building toward

By the end you have:

- A **pinned** `URLSession` (SPKI pinning via a delegate, or `NSPinnedDomains`) so the client only talks to your server's key.
- A **Secure Enclave P-256 signing key**, generated once, gated behind user presence, persisted as a device-bound representation in the Keychain.
- A one-time **device enrolment** (`POST /devices`) that registers the public key with the Vapor backend.
- **Every request signed**: a canonical representation signed by the Enclave key, attached as headers (`X-Device-Key-ID`, `X-Request-Timestamp`, `X-Request-Signature`).
- **Server-side verification**: a Vapor middleware that reconstructs the canonical string, looks up the enrolled public key, and verifies the signature with `swift-crypto` — rejecting unsigned, mis-signed, or replayed requests.
- A `THREATS.md` naming the adversary each control answers.
- A proven **signed round trip on a physical device** (the Enclave requires real hardware).

---

## Milestone 1 — Pin the client (≈ 1.5 h)

Drop the `PinningDelegate` from exercise 1 into the `NotesClient` and pin your Vapor server's SPKI. Record the threat first.

```swift
actor NotesClient {
    private let session: URLSession
    private let baseURL: URL

    init(baseURL: URL, pinnedSPKIHashes: Set<String>) {
        self.baseURL = baseURL
        let delegate = PinningDelegate(pinnedHashes: pinnedSPKIHashes)
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }
    // ...existing methods, unchanged — pinning is below them...
}
```

Decisions to defend in review:

- **SPKI, not certificate.** Pin the public key so your TLS cert can renew without bricking the app. (If your dev server uses a self-signed cert, pin *that* key; in production pin the real one and ship a backup pin.)
- **Pinning is in addition to CA validation.** The delegate still runs `SecTrustEvaluateWithError`. Don't disable it to make a self-signed dev cert work — instead, add the dev cert's key to the pinned set, or pin only in release.
- **Threat statement (write it in `THREATS.md`):** *"SPKI pinning stops an active MITM (corporate proxy or rogue CA) from reading or forging traffic to our backend."*

## Milestone 2 — Generate and store the Secure Enclave key (≈ 1.5 h)

On first launch, generate a P-256 signing key in the Enclave, gated behind user presence, and persist its representation in the Keychain. This runs on a **physical device** — `SecureEnclave.isAvailable` is `false` in the Simulator.

```swift
import CryptoKit
import Security

struct DeviceIdentity {
    static let account = "com.crunch.notes.device-key"

    /// Load the existing key, or generate one on first launch.
    static func loadOrCreate() throws -> SecureEnclave.P256.Signing.PrivateKey {
        if let existing = try? load() { return existing }
        let key = try generate()
        try save(key)
        return key
    }

    static func generate() throws -> SecureEnclave.P256.Signing.PrivateKey {
        guard SecureEnclave.isAvailable else { throw IdentityError.noEnclave }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .userPresence],   // require Face ID / passcode to sign
            &error
        ) else { throw IdentityError.accessControl }
        return try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
    }

    static func save(_ key: SecureEnclave.P256.Signing.PrivateKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.dataRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityError.keychain(status) }
    }

    static func load() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { throw IdentityError.notFound }
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }
}

enum IdentityError: Error { case noEnclave, accessControl, keychain(OSStatus), notFound }
```

**Threat statement:** *"The Secure Enclave key stops an attacker with root or a forensic device image from extracting the signing key — it never exists outside the hardware, and its stored representation is device-bound and inert if copied."*

## Milestone 3 — Enrol the public key with the backend (≈ 1 h)

A one-time enrolment: the client derives a `keyID` (a SHA-256 of the public key) and POSTs the public key to the server, which stores `keyID -> publicKey`. This happens over the *pinned* channel from Milestone 1.

```swift
func enrolDevice() async throws {
    let key = try DeviceIdentity.loadOrCreate()
    let publicRaw = key.publicKey.rawRepresentation              // 64 bytes (x||y)
    let keyID = Data(SHA256.hash(data: publicRaw)).base64EncodedString()

    var request = URLRequest(url: baseURL.appending(path: "devices"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
        EnrolPayload(keyID: keyID, publicKey: publicRaw.base64EncodedString())
    )
    let (_, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 201 else { throw NotesClientError.enrolFailed }
    // Persist the keyID locally so every future request can identify this device.
    UserDefaults.standard.set(keyID, forKey: "deviceKeyID")
}

struct EnrolPayload: Codable { let keyID: String; let publicKey: String }
```

On the Vapor side, `POST /devices` decodes the payload, rebuilds a `P256.Signing.PublicKey(rawRepresentation:)`, and stores it keyed by `keyID`. (For a single-user dev backend, an in-memory dictionary or a Fluent row is fine.)

## Milestone 4 — Sign every request (≈ 2 h)

Wrap the request-building so every outbound request is signed with the Enclave key. The canonical string is a contract shared with the server — keep it explicit.

```swift
func signedRequest(method: String, path: String, body: Data) throws -> URLRequest {
    let key = try DeviceIdentity.loadOrCreate()
    let keyID = UserDefaults.standard.string(forKey: "deviceKeyID") ?? ""
    let timestamp = Int(Date().timeIntervalSince1970)
    let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()

    // The canonical string: method, path, timestamp, body hash — newline-joined.
    // The server reconstructs this EXACTLY to verify. Any drift = signature fails.
    let canonical = "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
    let signature = try key.signature(for: Data(canonical.utf8))   // Enclave signs

    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = method
    request.httpBody = body.isEmpty ? nil : body
    request.setValue(keyID, forHTTPHeaderField: "X-Device-Key-ID")
    request.setValue(String(timestamp), forHTTPHeaderField: "X-Request-Timestamp")
    request.setValue(signature.derRepresentation.base64EncodedString(),
                     forHTTPHeaderField: "X-Request-Signature")
    return request
}
```

Route your existing methods through it — `fetchNotes()` builds a signed `GET /notes`, `createNote(_:)` a signed `POST /notes` with the encoded body. The signing is uniform; the call sites barely change.

**Threat statement:** *"Request signing stops an attacker with a stolen bearer token from forging requests — they can't reproduce the signature without the Enclave key, and they can't replay an old request because the signed timestamp is checked server-side."*

## Milestone 5 — Verify server-side and reject the bad cases (≈ 2 h)

Write a Vapor middleware that verifies the signature on protected routes. It must reject: a missing signature, a wrong signature, an unknown `keyID`, and a stale timestamp (replay).

```swift
import Crypto   // swift-crypto — same API as CryptoKit
import Vapor

struct SignatureMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let keyID = req.headers.first(name: "X-Device-Key-ID"),
              let tsString = req.headers.first(name: "X-Request-Timestamp"),
              let timestamp = Int(tsString),
              let sigB64 = req.headers.first(name: "X-Request-Signature"),
              let sigData = Data(base64Encoded: sigB64) else {
            throw Abort(.unauthorized, reason: "missing signature headers")
        }

        // Replay defence: reject timestamps more than 5 minutes from now.
        guard abs(Int(Date().timeIntervalSince1970) - timestamp) <= 300 else {
            throw Abort(.unauthorized, reason: "stale request")
        }

        guard let publicKey = try await DeviceKeyStore.publicKey(forID: keyID, on: req.db) else {
            throw Abort(.unauthorized, reason: "unknown device")
        }

        let body = req.body.data.map { Data(buffer: $0) } ?? Data()
        let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
        let canonical = "\(req.method.string)\n\(req.url.path)\n\(timestamp)\n\(bodyHash)"

        let signature = try P256.Signing.ECDSASignature(derRepresentation: sigData)
        guard publicKey.isValidSignature(signature, for: Data(canonical.utf8)) else {
            throw Abort(.unauthorized, reason: "bad signature")
        }
        return try await next.respond(to: req)
    }
}
```

Register it on the protected route group (`notes.grouped(SignatureMiddleware())`). Now an unsigned or mis-signed request gets a 401 *before* it touches your handler.

## Milestone 6 — The signed round trip + log hygiene (≈ 1 h)

The acceptance bar for the week, on a **physical device**:

1. Cold-launch the app on a real iPhone/iPad. First launch generates the Enclave key and enrols it.
2. Create a note. The request is signed; Face ID / passcode prompts (user presence). The Vapor middleware verifies it and the note is created.
3. **Prove the negative:** temporarily strip the signature headers (a debug toggle) and confirm the server returns **401**. Then restore signing and confirm **success**. A defence you haven't watched reject a bad request is untested.
4. **Replay test:** capture a valid request, wait 6 minutes, replay it, confirm the server rejects it (stale timestamp).
5. Audit your logs: confirm no `OSLog` line marks a token, signature, or key `.public`. Tokens redact by default; keep them that way.

Record this as a short clip or screenshots in your repo's README — the signed round trip, the 401 on a stripped signature, and the replay rejection. "The server proved the request came from this device, and rejected the forgeries" is the deliverable.

---

## Acceptance criteria

- [ ] The `NotesClient` uses a **pinned** `URLSession` (SPKI pin, in addition to CA validation), with a backup pin documented.
- [ ] A **Secure Enclave P-256 key** is generated once, gated behind `.userPresence`, and persisted as a device-bound representation in the Keychain.
- [ ] A one-time **enrolment** registers the public key with the Vapor backend.
- [ ] **Every protected request is signed** with the Enclave key (canonical string + `X-Request-Signature` / `X-Device-Key-ID` / `X-Request-Timestamp`).
- [ ] A Vapor **`SignatureMiddleware`** verifies the signature with `swift-crypto` and rejects missing, wrong, unknown-key, and **stale (replay)** requests with 401.
- [ ] **No secret is logged `.public`** — tokens, signatures, and keys are redacted (or never logged).
- [ ] A `THREATS.md` names the adversary each of the three controls (pinning, Enclave key, signing) answers.
- [ ] **The signed round trip is proven on a physical device**, including the 401 on a stripped signature and the replay rejection.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict-concurrency.

## Stretch goals

- **Biometric re-auth on a high-value action.** Require a fresh Face ID (`LAContext.evaluatePolicy`) before deleting all notes, separate from the per-request user-presence gate. Threat: someone with the unlocked phone for thirty seconds.
- **Encrypt the offline cache at rest.** AES-GCM the SwiftData export (or a sensitive blob) with a key derived from the Enclave (`SecureEnclave.P256.KeyAgreement` → HKDF → `SymmetricKey`). Threat: a forensic image of the device file system.
- **Key rotation drill.** Generate a *new* Enclave key, enrol it, sign with both during a transition window, then retire the old `keyID` server-side. Document the rollout order (new key first, never break in-flight requests) — a preview of the capstone's APNs-rotation chaos drill.
- **`NSPinnedDomains` instead of the delegate.** Re-implement the pin declaratively and compare: what did you lose (logging, kill switch) and gain (less code, system-enforced)?

## What this milestone earns you

You can now pin a TLS cert, generate a hardware-backed key, and sign requests end to end — the literal "skill earned" line for the week. More than that: you composed three distinct defences against three distinct adversaries onto a client whose business logic never noticed, and you *proved* each one by watching it reject the attack it was built to stop. That "name the threat, pick the primitive, prove the rejection" discipline is the security substrate Phase III's push/StoreKit week (Week 18) and the Phase IV capstone stand on. The CryptoKit you used here is the exact CryptoKit you'll use next week to decrypt a push payload in a Notification Service Extension and to verify a StoreKit receipt signature. Security wasn't a detour; it was the foundation.
