# Challenge 1 — Universal links, end to end

> **Estimated time:** 90–120 minutes. Worth more than its time-cost suggests: universal links are the single most-failed iOS wiring task, and getting them right — and *proving* it warm and cold — is a senior-interview-grade skill. This is the canonical "make a real link open my app" exercise.

You already have a custom-scheme deep link from Exercise 3: `notes://open/<id>` opens the right note through `onOpenURL`. That is fine for plumbing you control, but a user cannot tap `notes://` in Safari, and any app can claim the `notes://` scheme. This challenge upgrades to a **universal link** — `https://notes.example.com/open/<id>` — the kind a human taps in Messages, Mail, or Safari, which falls back to your website when the app is not installed and which cannot be spoofed because the OS verifies you own the domain.

The deliberate constraint: **do it with no paid Apple Developer account, no public domain, and no TLS certificate.** The simulator lets you associate a domain locally. You will learn the real mechanism while staying entirely on your machine.

## What "done" looks like

`https://notes.example.com/open/22222222-2222-2222-2222-222222222222`, fired at the booted simulator, opens the app and pushes "Ship Week 9" — and it works whether the app was already running (warm) or had been killed (cold). The exact same `DeepLink.path(for:)` decoder from Exercise 3 handles it; you add only the *transport* and the *association*, not new decode logic.

## Acceptance criteria

- [ ] The app declares the `applinks:notes.example.com` Associated Domain in `Signing & Capabilities`.
- [ ] A valid `apple-app-site-association` (AASA) file exists with the correct `appIDs` (`<TeamID>.<BundleID>`) and a `components` entry matching `/open/*`.
- [ ] The app handles the universal link through `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` (already wired in Exercise 3) and routes it through the same `DeepLink.path(for:)` decoder.
- [ ] `DeepLink.path(for:)` accepts the `https://notes.example.com/open/<id>` form and **rejects** any other host (you must not open the app for `https://evil.example.com/open/<id>`).
- [ ] **Warm proof:** with the app running, the universal link pushes the correct note. Transcript captured.
- [ ] **Cold proof:** with the app terminated, the universal link cold-launches the app *and* lands on the correct note. Transcript captured.
- [ ] A `PROOF.md` documents both transcripts and explains in one or two sentences why the cold path needs no special-case code.
- [ ] Build succeeds with 0 warnings, 0 errors.

## Recommended approach

### Step 1 — Find your Team ID and confirm the bundle ID

The AASA's `appIDs` is `<TeamID>.<BundleID>`. Even with a free/personal team, Xcode assigns a Team ID.

```bash
# After at least one build, the provisioning info is in the build product:
codesign -dvvv "$(find ~/Library/Developer/Xcode/DerivedData -name 'Ex03DeepLink.app' -type d | head -1)" 2>&1 | grep TeamIdentifier
```

Or read it from **Xcode → Settings → Accounts → (your account) → Manage Certificates**, or from the target's **Signing & Capabilities** pane (the Team dropdown). Note both values; you need `TEAMID.com.crunchlabs.Ex03DeepLink`.

### Step 2 — Add the Associated Domains entitlement

In the target's **Signing & Capabilities** tab: **+ Capability → Associated Domains**. Add one entry:

```
applinks:notes.example.com
```

For local-only simulator testing you can append the `?mode=developer` query that tells the OS to bypass Apple's CDN and fetch the AASA from your declared domain directly:

```
applinks:notes.example.com?mode=developer
```

This is the simulator/dev path. Without it, iOS asks Apple's CDN for the AASA, which cannot reach a domain that only exists on your machine.

### Step 3 — Author the AASA file

Create `apple-app-site-association` (no extension). Replace `TEAMID`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.crunchlabs.Ex03DeepLink"],
        "components": [
          {
            "/": "/open/*",
            "comment": "Opens a specific note by id"
          }
        ]
      }
    ]
  }
}
```

The rules that bite people:

- The file has **no extension** — it is literally named `apple-app-site-association`.
- It must be served at **`/.well-known/apple-app-site-association`**, over **HTTPS**, with **`Content-Type: application/json`**, and with **no redirects**.
- `appIDs` is `TeamID.BundleID`. A wrong Team ID fails silently — the OS just refuses to associate, with no user-visible error.
- The JSON must be valid (run it through `python3 -m json.tool < apple-app-site-association`).

### Step 4 — Serve the AASA locally and point the simulator at it

The simulator resolves `notes.example.com` via the Mac's `/etc/hosts` and trusts a locally served file when the entitlement uses `?mode=developer`. Two sub-steps:

**(a) Map the domain to localhost.** Add to `/etc/hosts`:

```
127.0.0.1   notes.example.com
```

**(b) Serve the file over HTTPS.** `python3 -m http.server` is HTTP-only. The simplest TLS-capable local server is a one-liner with a self-signed cert; the simulator in developer mode is lenient about the cert for an associated domain. Generate a cert and serve:

```bash
mkdir -p site/.well-known
cp apple-app-site-association site/.well-known/apple-app-site-association

# self-signed cert for notes.example.com
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem \
  -days 7 -subj "/CN=notes.example.com" \
  -addext "subjectAltName=DNS:notes.example.com"

# minimal HTTPS server that sets the right Content-Type
python3 - <<'PY'
import http.server, ssl, os
os.chdir("site")
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        if self.path.endswith("apple-app-site-association"):
            self.send_header("Content-Type", "application/json")
        super().end_headers()
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("../cert.pem", "../key.pem")
httpd = http.server.HTTPServer(("127.0.0.1", 443), H)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
print("serving https://notes.example.com/.well-known/apple-app-site-association")
httpd.serve_forever()
PY
```

(Port 443 may need `sudo`; or serve on 8443 and add the port to the domain string as `notes.example.com:8443` in the entitlement — both work in the simulator.)

Confirm the file is reachable:

```bash
curl -k https://notes.example.com/.well-known/apple-app-site-association
# should print your JSON with Content-Type: application/json
```

### Step 5 — Force the simulator to (re)fetch the association

iOS evaluates the AASA at install time. After installing/reinstalling the app on the booted simulator, you can force a refresh and watch the SWC daemon:

```bash
# Reinstall to trigger a fresh AASA fetch
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'Ex03DeepLink.app' -type d | head -1)"

# Watch the association daemon evaluate your domain
log stream --predicate 'subsystem == "com.apple.swc"' --info
```

A successful association logs an `applinks` match for `notes.example.com`.

### Step 6 — Prove it warm

```bash
xcrun simctl launch  booted com.crunchlabs.Ex03DeepLink     # app is running
xcrun simctl openurl booted https://notes.example.com/open/22222222-2222-2222-2222-222222222222
```

The app foregrounds and pushes "Ship Week 9". Capture the transcript.

### Step 7 — Prove it cold

```bash
xcrun simctl terminate booted com.crunchlabs.Ex03DeepLink   # kill the process
xcrun simctl openurl   booted https://notes.example.com/open/33333333-3333-3333-3333-333333333333
```

iOS cold-launches the app and lands on "Call the bank". Same `apply(url)`, no cold-launch branch. Capture the transcript.

### Step 8 — Guard the host

Confirm the decoder rejects a foreign host. Add a test and a manual fire:

```bash
xcrun simctl openurl booted https://evil.example.com/open/22222222-2222-2222-2222-222222222222
# Nothing should happen — DeepLink.path(for:) returns nil for the wrong host.
```

## Deliverables

- The updated app (entitlement + universal-link handling routed through the shared decoder).
- The `apple-app-site-association` file you served (with the Team ID redacted is fine).
- `PROOF.md` with:
  - The warm transcript (Step 6).
  - The cold transcript (Step 7).
  - One sentence on why cold needs no special code (hint: `onContinueUserActivity` / `onOpenURL` are delivered after the scene connects in both lifecycles).
  - One sentence on the security difference between this and the custom scheme (the AASA proves domain ownership; a custom scheme proves nothing).

## Stretch

- Extend the AASA `components` to support `/open/<id>/tag/<tagID>` and prove a two-level universal link from cold launch. Your `DeepLink.path(for:)` already returns an array — confirm the AASA `components` glob (`/open/*`) still matches the deeper path, or add a second `components` entry.
- Add an `appclips` section to the AASA and read Apple's App Clips docs to see how the same association mechanism drives a different feature. (No implementation required — understand the shared substrate.)

## Common failure modes (read before you debug for an hour)

| Symptom | Cause |
|---|---|
| Link opens Safari instead of the app | Association failed — wrong Team ID, AASA unreachable, or `?mode=developer` missing in the simulator |
| `curl` shows HTML or a redirect | Server is redirecting `/.well-known/...`; AASA must be served with no redirects |
| `curl` shows the JSON but the app still doesn't open | `Content-Type` is not `application/json`, or the app was installed *before* the AASA was reachable — reinstall to refetch |
| Works warm, not cold | Handler is on a conditionally-rendered child view; move it to the always-present root |
| The wrong note opens | Decoder bug, not a links bug — your Exercise 3 unit tests would have caught it; run them |
