# Exercise 1 — Register for and receive a real push

**Goal.** Stand up the smallest real push pipeline: request notification authorization, obtain a device token, and send yourself an actual APNs push from the command line with a JWT signed from your `.p8` auth key. When the banner appears on your device, you've proven the whole pipeline — app, APNs, token, payload — end to end. This is the push half of the week distilled to one exercise.

**Estimated time.** 45 minutes.

**Prerequisites.** Xcode 16+, a **physical iPhone or iPad** (push registration doesn't fully work in the Simulator), and **Apple Developer Program membership** (you've had it since Week 15). You'll need to create an **APNs auth key** (`.p8`) in App Store Connect and note your **Key ID** and **Team ID**.

---

## Step 1 — Enable the Push Notifications capability

In Xcode: select your app target ▸ **Signing & Capabilities** ▸ **+ Capability** ▸ **Push Notifications**. This adds the entitlement that lets your app register with APNs. Confirm your team and bundle id are set (the bundle id is your `apns-topic`).

## Step 2 — Create an APNs auth key

In **App Store Connect** ▸ Users and Access ▸ **Keys** (or **Integrations** ▸ App Store Connect API depending on layout) ▸ **Apple Push Notifications service (APNs)** ▸ create a key. Download the `.p8` **once** (you can't re-download it) and note:

- The **Key ID** (10 characters, shown next to the key).
- Your **Team ID** (top-right of your developer account, 10 characters).

Store the `.p8` somewhere safe. The threat-model habit from Week 17 applies: this key can send pushes to *all* your apps, so treat it like a credential.

## Step 3 — Register in the app and print the token

Wire registration (lecture 1, §2). For this drill, print the token so you can copy it:

```swift
import SwiftUI
import UserNotifications

@main
struct PushScratchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ app: UIApplication,
                     didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            let granted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted == true {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
        return true
    }

    func application(_ app: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Hex-encode — do NOT use deviceToken.description (gives <a1b2...> with brackets).
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("DEVICE TOKEN: \(hex)")
    }

    func application(_ app: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("registration failed: \(error.localizedDescription)")
    }

    // Show the banner even when the app is foregrounded, so you SEE the push arrive.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }
}
```

Run on the **device**, accept the permission prompt, and copy the `DEVICE TOKEN` from the Xcode console.

## Step 4 — Send a push from the command line

You'll sign a JWT with your `.p8` and `POST` a payload to APNs. The cleanest way without writing a JWT library is a small helper script, but you can also use a one-liner tool. Here's the shape with `curl` (you supply the signed JWT in `$AUTH_JWT` — generate it with a tiny script or a tool like `jwt`):

```bash
# Variables you fill in:
TEAM_ID="ABCDE12345"
KEY_ID="FGHIJ67890"
P8_PATH="./AuthKey_FGHIJ67890.p8"
BUNDLE_ID="com.yourname.PushScratch"
DEVICE_TOKEN="<the hex token from the console>"

# Sign an ES256 JWT: header {alg:ES256, kid:KEY_ID}, claims {iss:TEAM_ID, iat:now}.
# (A 10-line Python/Swift script with your .p8 produces $AUTH_JWT; APNs accepts
#  the same JWT for ~1 hour, so generate once and reuse.)

curl -v \
  --header "apns-topic: $BUNDLE_ID" \
  --header "apns-push-type: alert" \
  --header "apns-priority: 10" \
  --header "authorization: bearer $AUTH_JWT" \
  --data '{"aps":{"alert":{"title":"It works","body":"Your push pipeline is live"},"sound":"default"}}' \
  --http2 \
  "https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN"
```

Note the host: `api.sandbox.push.apple.com` for development builds (run from Xcode), `api.push.apple.com` for production/TestFlight. Using the wrong host is the #1 reason a correctly-formed push silently fails — the token is environment-specific.

A 200 response with no body means **delivered to APNs**. Within seconds the banner should appear on your device — including in the foreground, because of the `willPresent` handler.

## Step 5 — Prove the failure path (the part people skip)

A pipeline you've only seen succeed isn't tested. Do two negative cases:

1. **Stale token.** Change one character of the device token and send again. APNs returns `400 BadDeviceToken` (or `410 Unregistered` for a truly retired token). *Nothing arrives, and you can see why.* This is the silent failure your backend must detect by reading APNs's response and expiring dead tokens.
2. **Wrong environment.** Send a development-build token to `api.push.apple.com` (production). APNs returns `400 BadDeviceToken` — the token doesn't exist in that environment. This is why the sandbox/production host split matters.

Record both responses. "I sent to a bad token and got `BadDeviceToken`" is proof you understand the failure mode, not just the happy path.

## Step 6 — (Optional) the Push Notifications Console

For faster iteration without `curl`/JWT, use **Xcode ▸ Window ▸ Developer Tools ▸ Push Notifications Console**: paste your token, compose a payload, and send. It handles the JWT for you. Great for iterating on payloads — but note it tests the *payload and delivery*, not your *backend's* token storage and signing, which is why the mini-project's bar is a push from your Vapor.

---

## Acceptance criteria

- [ ] The Push Notifications capability is enabled and the app registers, printing a hex device token (not the bracketed `description`).
- [ ] You created a `.p8` auth key and recorded your Key ID and Team ID.
- [ ] A `curl` (or Console) push with a signed JWT reaches your **physical device** — the banner appears.
- [ ] You sent to the correct host for your build (`sandbox` for a Xcode run build).
- [ ] You proved **two failure paths**: a corrupted token returns `BadDeviceToken`, and the wrong environment host also fails — and you can explain each.
- [ ] Build with **0 warnings, 0 errors**.

## What you just proved

You proved lecture 1's central claim: push is a best-effort pipeline, not a function call. You watched it succeed (banner on a real device) *and* fail (a one-character token change returns `BadDeviceToken` with nothing delivered). That failure is the silent one your backend must detect by reading APNs responses and expiring stale tokens. The mini-project takes this and adds the Notification Service Extension that decrypts an encrypted payload before it's shown.

---

## Hints (read only if stuck > 10 min)

- **No token, `didFailToRegister` fires.** You're on the Simulator (use a device), or the Push Notifications capability isn't enabled, or there's no network. Registration needs APNs reachability.
- **200 from APNs but no banner.** Check the host (sandbox vs production must match the build), check the token is current, and confirm the payload's `apns-push-type` matches (`alert` for a visible alert). A `content-available`-only payload shows nothing by design.
- **`403 InvalidProviderToken` / `ExpiredProviderToken`.** Your JWT is wrong: check the `kid` (Key ID), `iss` (Team ID), that it's signed with the matching `.p8`, and that `iat` is recent (JWTs older than ~1h are rejected).
- **`BadDeviceToken` on a token you know is right.** Almost always the environment: a token from a development (Xcode) build only works against `api.sandbox.push.apple.com`. TestFlight/App Store builds use production.
- **Foreground push doesn't show.** You didn't implement `willPresent` returning presentation options, or the center delegate isn't set. Both are required to show a banner while the app is open.
