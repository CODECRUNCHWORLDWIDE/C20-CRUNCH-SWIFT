# Week 18 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership (though *running* this week's code requires the $99 membership you've had since Week 15). The WWDC sessions are free on the Developer site and on YouTube. The open-source repos are public on GitHub. A handful of paid books are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **User Notifications — framework landing page.** `UNUserNotificationCenter`, authorization, categories, the service extension:
  <https://developer.apple.com/documentation/usernotifications>
- **"Setting up a remote notification server."** Apple's canonical APNs guide — tokens, auth keys, the JWT, the request headers:
  <https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server>
- **"Modifying content in newly delivered notifications" (Notification Service Extension).** The NSE article — central to lecture 1:
  <https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications>
- **StoreKit — framework landing page.** `Product`, `Transaction`, `Product.PurchaseResult`, `Transaction.currentEntitlements`:
  <https://developer.apple.com/documentation/storekit>
- **"Meet StoreKit 2" reading + "Implementing a store in your app."** The end-to-end StoreKit 2 build, the same shape as the mini-project:
  <https://developer.apple.com/documentation/storekit/in-app_purchase>
- **MetricKit — framework landing page.** `MXMetricManager`, `MXMetricPayload`, `MXDiagnosticPayload`:
  <https://developer.apple.com/documentation/metrickit>

## The types you'll use (reference, skim don't memorize)

- **`UNUserNotificationCenter`:** <https://developer.apple.com/documentation/usernotifications/unusernotificationcenter>
- **`UNNotificationServiceExtension`:** <https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension>
- **`Product` and `Product.products(for:)`:** <https://developer.apple.com/documentation/storekit/product>
- **`Product.PurchaseResult` and `Product.purchase(options:)`:** <https://developer.apple.com/documentation/storekit/product/purchaseresult>
- **`Transaction` (`currentEntitlements`, `updates`, `latest(for:)`, `jsonRepresentation`):** <https://developer.apple.com/documentation/storekit/transaction>
- **`VerificationResult`:** <https://developer.apple.com/documentation/storekit/verificationresult>
- **`MXMetricManagerSubscriber`:** <https://developer.apple.com/documentation/metrickit/mxmetricmanagersubscriber>
- **`MXDiagnosticPayload`:** <https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload>

## WWDC sessions (free, watch in this order)

- **"Meet StoreKit 2" (WWDC21)** — the async StoreKit 2 API; `Product`, `Transaction`, verification, entitlements:
  <https://developer.apple.com/videos/play/wwdc2021/10114/>
- **"Explore in-app purchase integration and migration" (WWDC22)** — moving from StoreKit 1, `Transaction.updates`, the listener pattern:
  <https://developer.apple.com/videos/play/wwdc2022/10007/>
- **"Meet the App Store Server Notifications V2"** — the webhook for refunds, renewals, and expirations; central to the edge-case challenge:
  <https://developer.apple.com/videos/play/wwdc2021/10174/>
- **"Rich notifications" / "Push notifications console"** — the modern UserNotifications surface and the Xcode Push Notifications Console for testing:
  <https://developer.apple.com/videos/play/wwdc2022/10092/>
- **"Diagnose performance issues with the Xcode Organizer" + "What's new in MetricKit"** — the MetricKit payload shape and how it feeds the Organizer:
  <https://developer.apple.com/videos/play/wwdc2020/10081/>

## APNs & the push pipeline

- **APNs request headers (`apns-topic`, `apns-push-type`, `apns-priority`, `apns-expiration`):** <https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns>
- **The `aps` payload keys (`alert`, `badge`, `sound`, `content-available`, `mutable-content`, `interruption-level`):** <https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification>
- **"Establishing a token-based connection to APNs"** — how to build and sign the JWT from your `.p8` auth key:
  <https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns>
- **`apple/swift-server/APNSwift` (or Vapor's APNS package)** — the server-side APNs client your Vapor backend uses to send pushes: <https://github.com/swift-server-community/APNSwift>

## StoreKit testing & server validation

- **"Testing in-app purchases with sandbox":** <https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox>
- **The `.storekit` configuration file** — local testing without App Store Connect, in Xcode and the Simulator: <https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode>
- **App Store Server API:** <https://developer.apple.com/documentation/appstoreserverapi>
- **App Store Server Notifications V2 (the webhook):** <https://developer.apple.com/documentation/appstoreservernotifications>
- **`apple/app-store-server-library-swift`** — Apple's official library for verifying signed transactions and decoding server notifications on your backend: <https://github.com/apple/app-store-server-library-swift>

## MetricKit & telemetry

- **"Improving your app's performance" (the metrics that matter):** <https://developer.apple.com/documentation/xcode/improving-your-app-s-performance>
- **`MXMetricPayload` and the metric categories (CPU, memory, disk, launch, hang, hitch, animation):** <https://developer.apple.com/documentation/metrickit/mxmetricpayload>
- **`MXCrashDiagnostic` / `MXHangDiagnostic`** — the diagnostic payloads you symbolicate: <https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic>

## Community writing (current, opinionated, correct)

- **Hacking with Swift — StoreKit 2 and UserNotifications articles.** Paul Hudson keeps these current per OS release; the StoreKit 2 purchase-and-verify walkthrough is clean:
  <https://www.hackingwithswift.com/>
- **RevenueCat's engineering blog** — the most production-grade writing on subscription edge cases (refunds, grace periods, billing retry) in the ecosystem, even if you don't use their SDK:
  <https://www.revenuecat.com/blog/>
- **Donny Wals — StoreKit 2 and notifications articles** — practical, current, opinionated about the failure modes:
  <https://www.donnywals.com/>
- **Apple Developer Forums — StoreKit and Notifications categories** — where Apple engineers answer the hard sandbox and server-notification questions:
  <https://developer.apple.com/forums/tags/storekit>

## Open-source projects to read this week

You learn more from one hour reading a real store than from three hours of tutorials. Pick one and trace the purchase → verify → finish → gate flow:

- **`apple/sample-backyard-birds`** — Apple's full SwiftData + StoreKit 2 sample; the `Store` actor, the `Transaction.updates` listener, and the entitlement gate are exemplary:
  <https://github.com/apple/sample-backyard-birds>
- **`apple/app-store-server-library-swift`** — read the verification code to see exactly what your backend checks on a signed transaction:
  <https://github.com/apple/app-store-server-library-swift>
- **`swift-server-community/APNSwift`** — read how the JWT is built and signed; the same `ES256` signing you did by hand in Week 17 lives here for the server:
  <https://github.com/swift-server-community/APNSwift>

## Tools you'll use this week

- **A physical iPhone or iPad** — push, sandbox purchases, and MetricKit payloads all need real hardware. The Simulator can test push payloads via drag-and-drop `.apns` files and StoreKit flows via a `.storekit` config, but the *gate* (a real push, a sandbox purchase, a delivered MetricKit payload) is on device.
- **The Xcode Push Notifications Console** (Window ▸ Developer Tools) — send test pushes to a device token without standing up a server; great for fast iteration before the real Vapor sender.
- **A `.storekit` configuration file** — for testing the purchase flow in the Simulator with synthetic products, including forcing refunds, renewals, and billing failures from Xcode's transaction manager.
- **A sandbox Apple ID** — created in App Store Connect, for real sandbox purchases on device. (Sign in under Settings ▸ Developer ▸ Sandbox Apple Account, not your real Apple ID.)
- **`curl` / a JWT tool** — to send a raw APNs push from the command line in exercise 1, signing the JWT from your `.p8` auth key.

## Free reading (chapter-level)

- **Apple's StoreKit "Implementing a store" article group** is effectively a free book; read the four article pages in order.
- **The App Store Server Notifications V2 reference** (linked above) is the definitive, free explanation of every subscription state transition — read the notification-type table end to end.

## Paid books (optional, clearly marked)

- **"In-App Purchases by Tutorials" — Kodeco / raywenderlich.com** (paid). The most complete walkthrough of StoreKit 2 subscriptions and server validation in book form; worth it if you ship subscriptions at work.
- **"Pushing the Limits" / push-focused chapters in iOS books** (paid). Less essential — Apple's APNs docs are good — but useful for the operational stories (token rotation, silent-push throttling).

---

*If a link 404s, please open an issue so we can replace it.*
