# Challenge 1 — MITM your own app, then pin it shut (with evidence)

**Time.** 60–120 minutes.
**Deliverable.** A short report (`MITM.md`) with a "before" screenshot (the proxy reading your plaintext request/response) and an "after" screenshot (the connection refused after pinning), plus the pinning code, committed to your Week 17 repo.

## The premise

Every senior engineer should, at least once, *be the man in the middle.* It is one thing to read that ATS "only verifies the cert chains to a trusted CA" and that a corporate proxy can decrypt your traffic. It is another to install a proxy's CA, watch your own app's bearer token scroll past in cleartext in the proxy log, and feel the gap that pinning closes. The skill this challenge builds is not "pinning exists" — it's **demonstrate the attack, then demonstrate the defence, with evidence for both.** A defence you've never seen defeat an attack is a defence you're trusting on faith.

You will MITM your unpinned app with `mitmproxy`, capture the proxy reading your traffic, then add SPKI pinning and prove the *same* proxy is now refused — without changing anything on the server.

## What to build

Start from the `Scratch` pinning app from exercise 1, or your `NotesClient`. You need an app that makes an HTTPS request you can recognise in a proxy log — ideally one carrying a (fake) bearer token, so the leak is visceral:

```swift
func fetchProtected() async throws -> Data {
    var request = URLRequest(url: URL(string: "https://httpbin.org/headers")!)
    request.httpMethod = "GET"
    request.setValue("Bearer SECRET-TOKEN-42", forHTTPHeaderField: "Authorization")
    let (data, _) = try await URLSession.shared.data(for: request)
    return data   // httpbin echoes your headers back, so you'll SEE the token both ways
}
```

`httpbin.org/headers` echoes the request headers in the response, so the proxy capture will show your `Authorization` header in *both* directions — a clear, visceral demonstration of "the proxy can read everything."

### Step 1 — Stand up mitmproxy

Install and run `mitmproxy` (free, open-source):

```bash
brew install mitmproxy
mitmproxy --listen-port 8080      # or `mitmweb` for a browser UI
```

`mitmproxy` generates its own CA on first run (stored in `~/.mitmproxy/`). That CA is the rogue root that, once trusted, lets the proxy present valid-looking certificates for *any* domain.

### Step 2 — Point the Simulator at the proxy and trust the CA

Configure the booted Simulator (or your Mac) to route through the proxy and to trust mitmproxy's CA — this is exactly the "corporate MDM installs a root CA" scenario from lecture 1:

```bash
# Route the Simulator's traffic through the proxy (set HTTP proxy in the
# Simulator's Wi-Fi settings, or set it on the host the Simulator inherits).
# Then install the mitmproxy CA so the OS TRUSTS the proxy's certificates:
xcrun simctl keychain booted add-root-cert ~/.mitmproxy/mitmproxy-ca-cert.pem
```

(On a physical device you'd install the CA via Settings ▸ Profile and enable full trust under Settings ▸ General ▸ About ▸ Certificate Trust Settings — the same flow an attacker would social-engineer.)

### Step 3 — Capture the attack (the "before")

Run the **unpinned** app and call `fetchProtected()`. In the `mitmproxy` window you will see the request appear in full: the URL, the method, **and your `Authorization: Bearer SECRET-TOKEN-42` header in cleartext.** The response — httpbin echoing the header back — is equally readable. The proxy is sitting in the middle of your "encrypted" HTTPS, reading and able to rewrite everything.

Screenshot this. Annotate the token in the capture. This is your **"before" evidence** — proof that ATS alone does not stop an active attacker who controls a trusted CA.

For extra impact, use a mitmproxy script or the interactive editor to *modify* the response before it reaches the app, demonstrating that the attacker can rewrite, not just read.

### Step 4 — Add SPKI pinning (the defence)

Now pin the *real* server's public key, using the delegate from exercise 1. Capture `httpbin.org`'s genuine SPKI hash (with the `openssl` one-liner, *not* through the proxy — you want the real key, not mitmproxy's):

```bash
openssl s_client -connect httpbin.org:443 -servername httpbin.org < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | openssl enc -base64
```

Pin that hash in your `PinningDelegate` and route the request through a session that uses it:

```swift
let delegate = PinningDelegate(pinnedHashes: ["<httpbin's REAL spki hash>"])
let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
let (data, _) = try await session.data(for: request)
```

### Step 5 — Capture the defence (the "after")

With the proxy *still running and still trusted*, run the **pinned** app and call the request again. Now the connection is **refused** — the proxy presents its own (CA-trusted, valid) certificate, but its SPKI is mitmproxy's key, not the pin you shipped. Your delegate's standard CA validation passes (the cert *is* valid), but the pin check fails, and `.cancelAuthenticationChallenge` kills the connection. The request throws; nothing reaches the proxy log in cleartext, because the TLS handshake never completes against the proxy's key.

Screenshot the `mitmproxy` window showing the handshake failure (or the absence of a completed flow), and the app's thrown error. This is your **"after" evidence** — the *same proxy*, the *same trusted CA*, now locked out by pinning alone.

## Acceptance criteria

- [ ] A working MITM: with the unpinned app, the `mitmproxy` capture shows your request **and the `Authorization` header in cleartext** in both directions.
- [ ] You extracted the *real* server SPKI hash with `openssl` (not through the proxy), and pinned it.
- [ ] With the pinned app and the proxy still trusted and running, the connection is **refused** — the pinning rejects the proxy's valid-but-wrong certificate.
- [ ] `MITM.md` records: the before capture, the after capture, the SPKI hash you pinned, and a 4–6 sentence explanation of *why* ATS allowed the proxy and *why* pinning didn't.
- [ ] Pinning is **in addition to** CA validation (you didn't disable `SecTrustEvaluateWithError` to make the demo work).
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "pinning blocked the proxy." A great submission says:

> With the mitmproxy CA installed and trusted, ATS accepted the proxy's certificate for httpbin.org because it chained to a now-trusted root — the captured flow shows `Authorization: Bearer SECRET-TOKEN-42` in cleartext, and I rewrote the response body to prove the attacker can modify, not just read. After pinning httpbin's real SPKI hash (`pBQ...=`, extracted directly, not through the proxy), the same proxy was refused: standard CA validation still passed (mitmproxy's cert is technically valid), but the leaf SPKI was mitmproxy's key, not the pinned key, so the delegate cancelled the challenge with `-1202`. Pinning works precisely because it collapses the trust set from "any CA the OS trusts" — which now includes the attacker's — down to "the one key I shipped." The cost is operational: if I rotate httpbin's key without shipping a new pin, my own app breaks, which is why production pins ship a backup.

Demonstrated attack, demonstrated defence, honest about the operational cost. That's the senior-engineer answer.

## Cleanup (do this — a trusted rogue CA is a real risk)

When you're done, **remove the mitmproxy CA** so you don't leave your Simulator/device trusting an attacker's root:

```bash
# Reset the Simulator's trusted certs, or specifically:
xcrun simctl keychain booted reset
```

On a physical device, delete the profile in Settings and turn off the trust toggle. Leaving a proxy CA trusted is exactly the vulnerability you just demonstrated — don't leave it armed.

## Where this reappears

The "see the failure, then prove the fix" workflow is the chaos-drill discipline Phase IV's final week formalises (APNs key rotation, subscription edge cases, offline-edit conflicts). The threat you defeated here — an active MITM — is the canonical reason banking and health apps pin, and the operational cost you felt (rotate-or-brick) is why pinning is a deliberate, calibrated choice rather than a default. You'll cite this capture in your security writeup for the capstone.
