# Lecture 1 — The threat model first, then App Transport Security and pinning

> "Encryption without a named adversary is decoration. The first question in any security review is never 'what algorithm' — it's 'who are we keeping out, and what can they do?'"

This is the lecture that stops you from cargo-culting security. The temptation, the first time someone hands you a "make this secure" ticket, is to reach for the biggest hammer — AES everything, pin everything, biometric-gate everything — and ship a wall of ceremony that *feels* secure and protects against threats nobody has. We do the opposite. We start with the threat model: a small, explicit list of who the adversary is and what they can do. Then, and only then, we pick the primitive that answers each threat. By the end of this lecture you should be able to look at any "add encryption" ticket and reply with a question: *against whom?*

We will build the threat model first, then walk the channel — App Transport Security, which protects the bytes in transit by default — and then the place you go past the default when the default isn't enough: certificate and public-key pinning. Lecture 2 takes the model down into CryptoKit and the Secure Enclave. Hold the threat model as you read both; it is the thing that turns a list of APIs into engineering judgement.

---

## 1. The threat model — five adversaries, ranked by capability

A threat model does not need to be a fifty-page document. For a mobile client it fits on an index card. Here are the five adversaries this week's primitives answer, ordered from weakest to strongest. Memorise the *ordering*, because the primitive you reach for depends on which one you're defending against, and reaching past the threat wastes effort while reaching short of it leaves a hole.

| # | Adversary | What they can do | The primitive that answers it |
|---|-----------|------------------|-------------------------------|
| 1 | **Passive network eavesdropper** | Read traffic on the wire (open Wi-Fi, a tap) | **TLS / ATS** — encrypts the channel |
| 2 | **Active network attacker (MITM)** | Present a forged or rogue-CA certificate, sit between client and server | **Certificate / public-key pinning** |
| 3 | **Thief with the unlocked device** | Open the app, read what's on screen, copy from the pasteboard for ~30 seconds | **Face ID / passcode gating** on sensitive actions |
| 4 | **Thief with the locked device + time** | Take the device, attempt to extract data at rest | **Keychain data-protection classes**; encryption at rest |
| 5 | **Attacker with root / a forensic image** | Read your process memory, dump files, pull keys out of storage | **Secure Enclave** — keys that never enter memory or leave hardware |

Two things fall out of this table immediately.

**First: most apps only need adversaries 1 and 4.** TLS plus the right Keychain accessibility class covers the common case. A note-taking app does not need a Secure Enclave key to protect grocery lists from a forensic examiner. *Know your row.* Adding adversary-5 defences to an adversary-1 problem is the over-engineering that makes a codebase look hardened while wasting review time and adding fragility (pinning that bricks the app on cert rotation, biometric prompts users learn to dismiss).

**Second: the adversaries are cumulative in capability but not in defence.** Pinning (row 2) does nothing against root on the device (row 5) — the attacker who owns the device can disable your pinning. The Secure Enclave (row 5) does nothing against a MITM (row 2) — a signed request still goes over a channel an active attacker can redirect. You compose defences; you don't substitute them. Our mini-project deliberately stacks rows 2 and 5: pinning so a proxy can't read or forge traffic, *and* a Secure Enclave signature so even a stolen bearer token can't forge a request. Each answers a different adversary; neither makes the other redundant.

The discipline this week enforces — the README's "name the threat first" promise — is that **no security control enters the codebase without a one-sentence threat statement.** "I added pinning to stop an active MITM with a corporate-proxy or rogue-CA certificate from reading or forging traffic" is an engineering statement. "I added pinning" is ceremony. Write the sentence. If you can't, you don't yet know what you're building.

---

## 2. App Transport Security — what you get for free, and how people throw it away

App Transport Security (ATS) is the policy, on by default since iOS 9, that forces your app's network connections to meet a baseline of transport security. You do not turn ATS *on*; it is on. You can only weaken it, and the entire skill here is *knowing when weakening it is defensible and recognising when it's a red flag in review.*

What ATS enforces by default, on every `URLSession` / `URLRequest` your app makes:

- **TLS 1.2 or later.** No SSLv3, no TLS 1.0/1.1. (TLS 1.3 is preferred and negotiated when the server supports it.)
- **Forward secrecy.** The negotiated cipher suite must use ephemeral key exchange (ECDHE), so a future compromise of the server's long-term key can't decrypt past recorded traffic.
- **A certificate signed with SHA-256 or better**, with at least a 2048-bit RSA or 256-bit ECC key.
- **No cleartext HTTP.** `http://` URLs fail unless you add an explicit exception.

This is genuinely good. It means that for the *passive eavesdropper* (adversary 1) you are protected with zero code. The bytes on the wire are encrypted to the server's certificate, and a SHA-1 cert or a TLS-1.0 downgrade — both historically exploitable — simply won't connect.

### How ATS is weakened, and the review red flags

Weakening lives in `Info.plist` under the `NSAppTransportSecurity` dictionary. The keys, from "almost always wrong" to "sometimes defensible":

```xml
<!-- THE RED FLAG. Disables ATS globally. In a code review this needs a -->
<!-- written justification and an expiry date, or it gets rejected. -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

`NSAllowsArbitraryLoads = true` turns ATS off for the whole app — cleartext HTTP, TLS 1.0, SHA-1 certs, all allowed. People add it to silence a connection error during development and forget to remove it. It is the single most common security regression in shipped iOS apps. Apple's App Review will also ask you to justify it. In code review, treat it as a defect unless there is a written reason and a removal date.

The defensible weakenings are *per-domain* and *narrow*:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <!-- A legacy third-party API you don't control that only speaks TLS 1.1. -->
        <!-- Scoped to ONE domain, justified, with a plan to drop it. -->
        <key>legacy.partner-api.example.com</key>
        <dict>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
    </dict>
</dict>
```

The rule: an ATS exception is acceptable when it is **scoped to a specific domain you don't control**, **as narrow as possible**, and **documented with a reason**. A blanket `NSAllowsArbitraryLoads` is acceptable essentially never in production. When you see one, the question in review is "which domain, and why can't this be an `NSExceptionDomains` entry instead?"

### ATS does *not* stop an active attacker

Here is the crucial limit, and the bridge to the rest of the lecture. ATS verifies that the server presents a certificate that **chains to a CA the operating system trusts.** That is exactly the right check for adversary 1. But it is *not* enough for adversary 2, the active MITM, because the set of "CAs the OS trusts" is large and not entirely in your control:

- A corporate device-management profile can install a custom root CA, and then a corporate proxy can decrypt all your "encrypted" traffic — with a certificate ATS happily accepts, because it chains to that installed root.
- A user can be socially engineered into installing a malicious profile.
- A CA can be compromised or coerced into issuing a certificate for your domain to someone else (this has happened, repeatedly, in the history of the web PKI).

In every one of those cases, ATS says "valid certificate, proceed," and the attacker reads — or rewrites — your traffic. ATS protects the *channel*; it does not let you assert *which specific key the server must hold.* For that, you pin.

---

## 3. Pinning — asserting which key your server is allowed to present

Pinning is the practice of shipping your app with knowledge of *exactly which public key (or certificate) your server should present*, and rejecting any TLS connection that presents a different one — **even a valid one signed by a trusted CA.** It collapses the trust set from "any of the hundreds of CAs the OS trusts" down to "the one key I put in my app." That is precisely what stops adversary 2: a proxy's rogue-CA certificate is valid (ATS would accept it) but it is *not your key*, so a pinning client rejects it.

There are two things you can pin, and the choice matters operationally.

### Certificate pinning vs public-key (SPKI) pinning

- **Certificate pinning** ships a hash of the *whole leaf certificate*. Simple, but brittle: when the certificate is renewed — which happens routinely, often annually, and with short-lived certs every 90 days — the hash changes and your pinned app stops connecting until you ship an update. Miss the renewal and you brick every installed copy.
- **Public-key pinning (SPKI pinning)** ships a hash of the certificate's **SubjectPublicKeyInfo** — the public key, not the whole cert. The key survives certificate renewal *as long as you renew with the same key pair* (which is normal practice; you rotate keys far less often than certs). So SPKI pinning lets the cert renew freely while the pin stays valid. **This is what you should pin.** When this lecture says "pin," it means SPKI pin.

You compute the SPKI hash from the server's certificate once, offline, and bake it into the app. Here is the `openssl` one-liner that extracts the SubjectPublicKeyInfo and SHA-256 hashes it (run it against your server, or against the cert file):

```bash
# Pull the cert from the live server, extract its public key (SPKI),
# DER-encode it, SHA-256 it, and base64 it. This is the pin you ship.
openssl s_client -connect notes.example.com:443 -servername notes.example.com < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
# -> e.g. "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="
```

That base64 string is your pin. Note the operational discipline that comes with it, because pinning is the one security control that can *take your own app down*:

1. **Always ship a backup pin.** Pin the current key *and* a next key you've pre-generated. If you must rotate the key under incident pressure, the backup is already trusted and you don't brick the fleet.
2. **Rotate before expiry.** A pinned app with no valid pin for the server's current key cannot connect. There is no remote fix without an app update going through review. Treat pin rotation like a certificate-expiry calendar event with weeks of lead time.
3. **Have a kill switch.** Some apps gate pinning behind a remote flag so they can disable it (falling back to standard ATS) if a rotation goes wrong. That weakens the guarantee but is a pragmatic escape hatch; decide deliberately.

Pinning is a sharp tool. It stops adversary 2 cold, and it can cut your own users off if you mismanage rotation. Both facts are true; respect both.

### The declarative option: `NSPinnedDomains`

Before you hand-roll a delegate, know that Apple gives you a *declarative* pinning option in `Info.plist` via `NSPinnedDomains`. You list the domain and the SPKI hashes (current + backup), and the OS enforces the pin inside its own TLS stack — no delegate code:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>notes.example.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=</string>
                </dict>
                <!-- backup pin (the pre-generated next key) -->
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>YourBackupPinBase64Here==</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
```

`NSPinnedDomains` is the right default when your needs are simple: it's enforced by the system, it composes with the rest of ATS, and there's no delegate to get wrong. The reason this week *also* teaches the delegate approach is that (a) you'll meet codebases that hand-roll it, (b) the delegate gives you logging, custom failure handling, and the ability to pin in cases the declarative form doesn't cover, and (c) writing it once makes you understand exactly what `NSPinnedDomains` is doing for you. Ship the declarative form when you can; understand the delegate so you can debug either.

---

## 4. The `URLSession` delegate — pinning by hand

When you do hand-roll pinning, the hook is the authentication-challenge delegate method. TLS server-trust evaluation surfaces to your `URLSession` as a challenge with `NSURLAuthenticationMethodServerTrust`; you inspect the server's trust object, extract its public key, hash it, compare to your pins, and either *use* the credential (connection proceeds) or *cancel* it (connection rejected).

```swift
import Foundation
import CryptoKit

/// A URLSession delegate that pins the server's SubjectPublicKeyInfo (SPKI).
/// It rejects any connection whose leaf public-key hash is not in `pinnedSPKIHashes`,
/// even if the certificate is otherwise valid and CA-trusted.
final class PinningDelegate: NSObject, URLSessionDelegate {

    /// Base64-encoded SHA-256 hashes of the SPKI we trust (current + backup).
    private let pinnedSPKIHashes: Set<String>

    init(pinnedSPKIHashes: Set<String>) {
        self.pinnedSPKIHashes = pinnedSPKIHashes
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle the server-trust challenge; defer everything else (client
        // certs, HTTP auth) to the system's default handling.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 1. First, let the system do the standard chain-of-trust evaluation.
        //    Pinning is IN ADDITION to CA validation, never INSTEAD of it — we
        //    still want a well-formed, unexpired, hostname-matching cert.
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 2. Extract the leaf certificate's public key and compute its SPKI hash.
        guard let pinHash = Self.spkiSHA256Base64(for: serverTrust) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 3. Compare against our pinned set. Match -> proceed; no match -> reject.
        if pinnedSPKIHashes.contains(pinHash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            // This is the line that stops the MITM. A proxy's rogue-CA cert is
            // valid (step 1 passed) but its public key is not one we pinned.
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Compute the base64 SHA-256 of the leaf certificate's SubjectPublicKeyInfo.
    /// This is the value the `openssl` one-liner produces, so client and pin agree.
    private static func spkiSHA256Base64(for trust: SecTrust) -> String? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first,
              let publicKey = SecCertificateCopyKey(leaf),
              let spki = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        // SecKeyCopyExternalRepresentation gives the raw key; for a fully spec-correct
        // SPKI pin you prepend the ASN.1 algorithm header for the key type. In production
        // use a vetted helper (TrustKit) or pin the value your server-side tooling emits;
        // here we hash the external representation to keep the mechanics visible.
        let digest = SHA256.hash(data: spki)
        return Data(digest).base64EncodedString()
    }
}
```

Wire it into a session and the rest of your `NotesClient` is unchanged — pinning is invisible to the call sites:

```swift
let delegate = PinningDelegate(pinnedSPKIHashes: [
    "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",  // current key
    "YourBackupPinBase64Here=="                       // backup key
])
let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
// session.data(for:) now rejects any server whose SPKI isn't pinned.
```

Four things a reviewer checks in this code, and you should too:

1. **Pinning is *in addition to* CA validation, not instead of it.** Step 1 still runs `SecTrustEvaluateWithError`. A common mistake is to skip the standard evaluation and *only* check the pin — that accepts an expired or hostname-mismatched cert as long as the key matches, which is a regression. Pin **and** validate.
2. **You compare the *leaf* key.** The chain's first certificate is the server's leaf. Pinning an intermediate CA's key is a different (broader) decision; pin the leaf SPKI unless you have a specific reason.
3. **`.cancelAuthenticationChallenge`, not `.performDefaultHandling`, on a miss.** Returning default handling on a pin failure silently falls back to "trust the CA chain" — which defeats the whole point. A miss must *cancel*.
4. **The hash computation must match how you generated the pin.** The subtlety in `spkiSHA256Base64` (the ASN.1 SPKI header) is exactly why production code uses a vetted library or pins the value the *same tool* emits on both ends. Mismatched encoding means your correct server fails its own pin — a self-inflicted outage. The exercise has you reconcile the two so they agree.

---

## 5. Where pinning sits in the actor-isolated client

Your `NotesClient` from Week 13 is an `actor`. The `URLSession` and its pinning delegate live inside that isolation. The delegate itself is a reference type that the URL loading system calls back on its own queue, so it must be safe to call from outside the actor — which is fine, because it holds only immutable pinned hashes (a `let Set<String>`) and computes a pure function. That immutability is what makes it `Sendable`-safe under Swift 6 without `@unchecked`:

```swift
actor NotesClient {
    private let session: URLSession

    init(pinnedSPKIHashes: Set<String>) {
        let delegate = PinningDelegate(pinnedSPKIHashes: pinnedSPKIHashes)
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }

    func fetchNotes() async throws -> [NoteDTO] {
        var request = URLRequest(url: URL(string: "https://notes.example.com/notes")!)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NotesClientError.badStatus
        }
        return try JSONDecoder().decode([NoteDTO].self, from: data)
    }
}
```

The pinning is entirely below `fetchNotes()` — the call site doesn't know or care. That's the goal: security controls that don't leak into business logic. (If your `PinningDelegate` held *mutable* state — say a cache it wrote to from the delegate queue — you'd have a concurrency problem, which is why we keep it immutable.)

---

## 6. Keychain accessibility — naming the adversary for data at rest

Before the decision table, one detour that belongs in the channel lecture only because it's the *other* place people pick a security control without naming the threat: the Keychain accessibility class. You met the Keychain in Week 14; this week you put a Secure Enclave key's representation in it (lecture 2). The accessibility class you choose is, like pinning, a direct answer to a specific adversary — and like pinning, the wrong choice is either a leak or a self-inflicted outage.

The Keychain encrypts items at rest, and *when* an item is decryptable is governed by its accessibility attribute. The four that matter, mapped to the threat model from §1:

| Accessibility | Decryptable when | Answers adversary |
|---------------|------------------|-------------------|
| `kSecAttrAccessibleWhenUnlocked` | Device is currently unlocked | 4 (thief with locked device + time) — item is locked when the screen is locked |
| `kSecAttrAccessibleAfterFirstUnlock` | Any time after the first unlock since boot | Weaker than `WhenUnlocked`; survives backgrounding, needed for background work |
| `…ThisDeviceOnly` (suffix on either) | …and **never syncs to iCloud / restores to another device** | 5 (forensic image moved to another device) — the item is useless off this device |
| `…WhenPasscodeSetThisDeviceOnly` | …and **only if a device passcode is set** | A device with no passcode can't hold the item at all |

Two rules fall out, and they're the data-at-rest equivalent of "pin SPKI, ship a backup":

1. **Default to `…ThisDeviceOnly` for anything you wouldn't want restored onto a *different* device.** A signing key, an auth token, an encryption key — none of these should ride an iCloud backup to a new phone. The `ThisDeviceOnly` suffix is the "never leaves this device" guarantee, and it's the right answer for the adversary-5 case (a forensic examiner who images the device and tries to extract the item elsewhere).
2. **Use `AfterFirstUnlock` for items a background task needs, `WhenUnlocked` for items only the foreground touches.** A background refresh that runs while the screen is locked can't read a `WhenUnlocked` item — it'll fail with `errSecInteractionNotAllowed`. That failure is a footgun people "fix" by downgrading to `AfterFirstUnlock` *globally*, weakening items that didn't need it. Scope the downgrade to the items the background actually touches.

The mini-project stores the Enclave key's representation with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: after first unlock (so signing works even if the app wakes in the background), this device only (so an imaged device can't carry the representation elsewhere — though, as lecture 2 explains, the Enclave binding makes it inert anyway; the accessibility class is defence in depth). Every one of those words is a threat-model decision. When you write the line, you should be able to say which adversary each clause answers — the same discipline as the pin.

---

## 7. The decision table — when to pin, and how

| Situation | Reach for |
|-----------|-----------|
| App talks to third-party APIs you don't control | **ATS defaults**; don't pin keys you don't own |
| App talks to *your* backend, standard threat model | **ATS defaults** — usually sufficient |
| Banking / health / anything where MITM is a real adversary | **Pin** (SPKI), with a backup pin and a rotation calendar |
| You want pinning with minimal code and simple needs | **`NSPinnedDomains`** in `Info.plist` (declarative) |
| You need pin-failure logging, a kill switch, or custom logic | **`URLSession` delegate** (hand-rolled) |
| You're tempted to add `NSAllowsArbitraryLoads` | **Stop.** Scope it to a domain or fix the server |

The recurring judgement: pin when an active MITM is a *named* adversary for your app, and not before. Pinning a grocery-list app is the over-engineering this lecture warns against. Pinning a payments app and *not* shipping a backup pin is the under-engineering that causes a 3 AM outage. The skill is calibration, and calibration comes from the threat model — which is why we started there.

---

## 7. Recap — the channel half of the week

You now own the channel half of this week's security story:

1. **Threat model first.** Five adversaries, ranked. Name the one you're defending against before you pick a primitive. ATS answers the passive eavesdropper; pinning answers the active MITM; the Secure Enclave (lecture 2) answers root-on-device. Don't reach past your adversary; don't fall short of it.
2. **ATS is on by default and good.** TLS 1.2+, forward secrecy, no cleartext. You can only weaken it, and `NSAllowsArbitraryLoads` is a review red flag. Per-domain exceptions are sometimes defensible; the global off-switch almost never is.
3. **Pin the public key (SPKI), not the certificate**, so cert renewal doesn't brick the app. Always ship a backup pin and treat rotation as a calendar event. Prefer `NSPinnedDomains` when simple; hand-roll the `URLSession` delegate when you need control — and always pin *in addition to* CA validation, never instead of it.

In lecture 2 we go down to the cryptographic primitives — CryptoKit's hashing, AES-GCM authenticated encryption, key agreement, and signatures — and then to the hardware: the Secure Enclave, where a private key can exist and be used but never read. We'll tie it together with the flow the mini-project ships: a request your Vapor server can prove came from a specific device, signed by a key no attacker can extract. Bring the threat model. We're about to spend it.
