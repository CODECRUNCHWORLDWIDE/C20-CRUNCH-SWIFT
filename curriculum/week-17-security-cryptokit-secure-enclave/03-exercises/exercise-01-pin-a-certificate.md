# Exercise 1 — Pin a certificate (and prove it rejects a wrong one)

**Goal.** Build the smallest possible real pinning client: extract a server's SubjectPublicKeyInfo (SPKI) hash with `openssl`, ship it in a `URLSession` delegate, and prove the delegate accepts a connection to the right server and *rejects* a connection to a different valid HTTPS server. This is the channel half of the week distilled to one exercise — if you can do this, you can stop an active MITM; everything else this week is the secrets half.

**Estimated time.** 45 minutes.

**Prerequisites.** Xcode 16+, an iOS 18 Simulator (iOS 17 works — pinning needs no Enclave, so the Simulator is fine here). `openssl` on the command line (`brew install openssl` if you don't have it). You do *not* need the Week 13 `NotesClient` for this drill; we build a throwaway client so the focus stays on the delegate.

---

## Step 1 — Extract the SPKI hash you'll pin

Pick a public HTTPS host you can reach (use `www.apple.com` for the drill; in real life it's your own server). Pull its certificate, extract the public key, and SHA-256 the SPKI:

```bash
openssl s_client -connect www.apple.com:443 -servername www.apple.com < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Copy the base64 string it prints — that's your **pin for `www.apple.com`**. Now do the same for a *second*, different host (e.g. `www.example.com`) and keep that hash too; you'll use it to prove a mismatch is rejected.

Write both pins into a scratch note. The threat statement to record (the week's discipline): *"This pin stops an active MITM presenting a valid-but-wrong certificate from impersonating www.apple.com."*

## Step 2 — Build the pinning delegate

Create `PinningDelegate.swift`:

```swift
import Foundation
import CryptoKit

/// Rejects any TLS connection whose leaf SPKI SHA-256 isn't in `pinnedHashes`,
/// even if the certificate chains to a trusted CA. Pinning is IN ADDITION to
/// standard CA validation, never instead of it.
final class PinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedHashes: Set<String>

    init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Standard CA validation first — pinning does not replace it.
        var cfError: CFError?
        guard SecTrustEvaluateWithError(trust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let hash = Self.leafSPKISHA256Base64(trust),
              pinnedHashes.contains(hash) else {
            // The miss path. This is the line that stops the MITM.
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private static func leafSPKISHA256Base64(_ trust: SecTrust) -> String? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first,
              let key = SecCertificateCopyKey(leaf),
              let der = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            return nil
        }
        return Data(SHA256.hash(data: der)).base64EncodedString()
    }
}
```

> **Note on the hash discipline.** `SecKeyCopyExternalRepresentation` returns the *raw* key, not the full ASN.1-wrapped SPKI that the `openssl` one-liner in Step 1 hashes. So the value this delegate computes will *not* equal the `openssl` value out of the box — that mismatch is the lesson. You have two correct options: (a) compute your pin from inside the app by logging `leafSPKISHA256Base64(trust)` once and pinning *that* value (client-consistent), or (b) prepend the correct ASN.1 SPKI header in `leafSPKISHA256Base64` so it matches `openssl` (spec-consistent). Pick one and make both ends agree. Production code uses a vetted library (TrustKit) precisely to avoid this footgun. For this drill, use option (a): log the hash, then pin it.

## Step 3 — Capture the real pin (option a)

Temporarily pin *nothing* and log what the delegate computes, so your pin and your delegate agree by construction:

```swift
import Foundation

func probePin(host: String) async {
    // An EMPTY pinned set means every connection is rejected — but the delegate
    // logs the hash it computed before rejecting. Run once to capture the value.
    let delegate = PinningDelegate(pinnedHashes: [])
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    var request = URLRequest(url: URL(string: "https://\(host)/")!)
    request.httpMethod = "HEAD"
    do {
        _ = try await session.data(for: request)
    } catch {
        print("rejected (expected with empty pin set): \(error.localizedDescription)")
    }
}
```

Add a `print` of the computed hash inside `leafSPKISHA256Base64` (or the delegate), run `await probePin(host: "www.apple.com")` from a button, read the console, and copy that hash. That is the value your delegate will recognise. (Then remove the temporary `print`.)

## Step 4 — Prove accept and reject

Now wire two requests and assert the behaviour:

```swift
func testPinning() async {
    let applePin = "<the hash you captured for www.apple.com>"
    let delegate = PinningDelegate(pinnedHashes: [applePin])
    let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)

    // ACCEPT: the pinned host connects.
    do {
        var r = URLRequest(url: URL(string: "https://www.apple.com/")!)
        r.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: r)
        print("apple.com: connected, status \((response as? HTTPURLResponse)?.statusCode ?? -1)  ✅")
    } catch {
        print("apple.com: FAILED (should have connected): \(error.localizedDescription)  ❌")
    }

    // REJECT: a different valid HTTPS host is refused, because its SPKI isn't pinned.
    do {
        var r = URLRequest(url: URL(string: "https://www.example.com/")!)
        r.httpMethod = "HEAD"
        _ = try await session.data(for: r)
        print("example.com: connected (SHOULD HAVE BEEN REJECTED)  ❌")
    } catch {
        print("example.com: rejected by pinning  ✅  (\(error.localizedDescription))")
    }
}
```

`www.example.com` is a perfectly valid, CA-trusted HTTPS site. Standard ATS would happily connect to it. Your pinned session **rejects** it, because its SPKI isn't the one you pinned. That rejection — of a *valid* certificate — is exactly the property that stops a MITM presenting a *valid rogue-CA* certificate.

## Step 5 — Add the declarative pin too (optional, illuminating)

To see what `NSPinnedDomains` does for you with zero delegate code, add this to `Info.plist` (Xcode ▸ target ▸ Info, or edit the raw plist), using the same captured hash:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>www.apple.com</key>
        <dict>
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string><!-- your apple.com SPKI hash --></string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
```

Make a plain `URLSession.shared` request (no delegate) to `www.apple.com` and to `www.example.com`. The system enforces the pin for you. This is the form you'd ship when your needs are simple — the delegate is for when you need logging, a kill switch, or custom failure handling.

---

## Acceptance criteria

- [ ] You extracted an SPKI hash with the `openssl` one-liner and recorded a one-sentence threat statement for the pin.
- [ ] A `PinningDelegate` that runs standard CA validation (`SecTrustEvaluateWithError`) **and** an SPKI pin check, cancelling the challenge on a miss.
- [ ] The pinned host (`www.apple.com`) **connects**; a different valid HTTPS host (`www.example.com`) is **rejected**.
- [ ] Build with **0 warnings, 0 errors**.
- [ ] (Stretch) You also pinned `www.apple.com` declaratively via `NSPinnedDomains` and confirmed `URLSession.shared` enforces it.

## What you just proved

You proved the central claim of lecture 1: pinning rejects a *valid* certificate that isn't *your* key, which is precisely how it stops an active MITM whose forged certificate is valid-but-wrong. You also felt the operational footgun — the SPKI hash-encoding mismatch — that makes people reach for a vetted library, and you saw the declarative `NSPinnedDomains` alternative. The mini-project takes this delegate and drops it into the real `NotesClient`.

---

## Hints (read only if stuck > 10 min)

- **Both hosts connect (pinning isn't rejecting anything).** Your delegate's miss path is returning `.performDefaultHandling` instead of `.cancelAuthenticationChallenge`, or you pinned an empty/wrong set so it never matches *or* never rejects. The miss must *cancel*.
- **Both hosts are rejected (even apple.com).** Your captured pin doesn't match what the delegate computes — the ASN.1 SPKI-header issue from the Step 2 note. Use option (a): log the delegate's computed hash and pin exactly that.
- **`SecTrustCopyCertificateChain` returns nil.** It's available on iOS 15+/macOS 12+; if you're on an older deployment target, raise it. Don't fall back to the deprecated `SecTrustGetCertificateAtIndex` unless you must.
- **The error on rejection is `-1202` / "cancelled."** That's the expected failure for a cancelled server-trust challenge. It's the *right* error — pinning rejected the connection.
- **`NSPinnedDomains` doesn't seem to enforce.** It applies to system-evaluated connections (`URLSession.shared`, sessions without a server-trust delegate). If you also installed your custom delegate on that session, your delegate takes precedence. Test them separately.
