# Week 18 — Push notifications, StoreKit 2, MetricKit telemetry

Welcome to Week 18 of **C20 · Crunch Swift** — the last week of Phase III, and the **Phase III integration project**. For seventeen weeks your app has been something the user opens. This week it becomes something that reaches *out* to the user (a push notification when a note is shared), takes *money* from the user (a StoreKit 2 subscription behind a paywall), and reports *back* to you (MetricKit telemetry from the field). Those are the three pipelines every shipped iOS app eventually needs, and they're the three this week builds end to end. By Sunday you have "Notes Pro v1": a note shared with you triggers an APNs push, a Notification Service Extension decrypts the payload, a `notes_pro_monthly` subscription gates a premium feature behind a paywall, and the server validates the receipt — all instrumented with MetricKit so you can see crashes and hangs from real devices.

The throughline this week is **the pipeline as a contract between your app, Apple's servers, and your backend.** Push is not "send a notification" — it's a five-party dance between your app, APNs, your Vapor backend, the device token, and (for encrypted payloads) a Notification Service Extension. StoreKit 2 is not "show a buy button" — it's a contract where Apple is the merchant of record, the `Transaction` is a cryptographically-signed receipt, and your backend must verify it server-side because a jailbroken client can lie. MetricKit is not "log an error" — it's the OS aggregating power, performance, and crash data across all your users and handing you a daily payload you ship to your backend. Each pipeline has a happy path that's easy and a set of failure modes (a stale device token, a refunded subscription, a payload that never arrives) that separate a demo from a shipped app. We teach the happy path fast and spend the real time on the failures, because the failures are what page you at 3 AM.

The mental shift this week is from "my app, in my hands" to "my app, in a pipeline I don't fully control." APNs can drop a push and never tell you. A user can refund a subscription a month after buying it, and your server finds out via a server notification, not the app. A crash happens on a device you'll never see, and MetricKit is your only window into it. You stop thinking "did my code run?" and start thinking "is the pipeline healthy, and how would I know if it weren't?" That is the production-engineering mindset Phase III has been building toward, and Week 18 is where it all has to work at once.

We close Phase III by shipping **Notes Pro v1** end to end and proving each pipeline on a physical device: register for push and receive a real APNs notification, decrypt an encrypted payload in a Notification Service Extension (using the CryptoKit you learned last week), complete a **sandbox** subscription purchase, gate a feature behind it, validate the transaction against the Vapor backend, and collect a MetricKit payload. This is the Phase III gate: a real push pipeline, a real subscription with server-side validation, and a build you could submit to TestFlight. After this week the app *is* a product — it reaches users, charges them, and reports home.

## Learning objectives

By the end of this week, you will be able to:

- **Register** for remote notifications, obtain and handle a device token, send it to your backend, and explain why APNs auth keys (`.p8`, token-based) beat the legacy `.p12` certificates (one key for all apps, no annual expiry, JWT-signed).
- **Construct** an APNs payload — the `aps` dictionary, `alert`/`badge`/`sound`, `content-available` for silent pushes, `mutable-content` for service-extension modification, `interruption-level` and `relevance-score` — and send it from a Vapor backend with a signed JWT.
- **Build** a **Notification Service Extension** that intercepts a `mutable-content` push, decrypts an encrypted payload with CryptoKit, and rewrites the notification before it's shown — within the extension's tight time budget.
- **Model** a StoreKit 2 product catalog (`Product`, `Product.SubscriptionInfo`), fetch products with `Product.products(for:)`, and present a paywall that shows localized prices the App Store returns.
- **Purchase** with the StoreKit 2 async API (`product.purchase()`), handle the `Product.PurchaseResult` (`.success`/`.userCancelled`/`.pending`), verify the `VerificationResult<Transaction>`, and `finish()` the transaction — and explain why you never trust an unverified transaction.
- **Observe** entitlements with `Transaction.currentEntitlements` and `Transaction.updates`, gate a feature behind an active subscription, and keep the gate correct across launches, restores, and renewals.
- **Validate** a transaction server-side: send `Transaction.jsonRepresentation` (or the signed JWS) to the Vapor backend, verify Apple's signature, and handle the App Store Server Notifications V2 webhook for refunds, billing retries, and downgrades.
- **Instrument** the app with **MetricKit**: register an `MXMetricManagerSubscriber`, receive daily `MXMetricPayload` and `MXDiagnosticPayload` (crashes, hangs, disk writes), and ship the payloads to your backend for aggregation.

## Prerequisites

This week assumes you have completed **C20 weeks 1–17**, or have equivalent fluency. Specifically:

- You can write Swift `async/await` and reason about actor isolation — Weeks 3–4. StoreKit 2 is an *async* framework end to end (`product.purchase()`, `for await` over `Transaction.updates`); the whole API assumes you're fluent in structured concurrency.
- You have the hardened, request-signing `NotesClient` and the CryptoKit fluency from **Week 17**. The Notification Service Extension decrypts its payload with the *same* `AES.GCM` you used last week, and the receipt validation verifies a signature the *same* way you verified request signatures.
- You ran the app on a **physical device** in Weeks 15–17 and have **Apple Developer Program membership** (required since Week 15). Push notifications, StoreKit sandbox testing, and MetricKit payloads all require real hardware and a configured App Store Connect record — none of this works in the Simulator the way it does on device (with narrow exceptions noted below).
- You have a Vapor backend you can run and edit, with the device-enrolment and signature-verification routes from Week 17. This week adds an APNs sender, a receipt-validation route, and an App Store Server Notifications webhook to it.

**Toolchain & membership.** Xcode 16+ on macOS, targeting iOS 18 / iOS 17 minimum. **A physical device and Apple Developer membership are required.** Push needs the Push Notifications capability and an APNs auth key from App Store Connect. StoreKit needs an App Store Connect app record with a configured subscription (or a local `.storekit` configuration file for Simulator testing — useful, but the *gate* is a sandbox purchase on device). MetricKit delivers payloads on a real device on a ~24h cadence; the **StoreKit `.storekit` config file** lets you test purchase *flows* in the Simulator without App Store Connect, and you'll use it for fast iteration before the device sandbox test.

## Topics covered

- **APNs architecture.** The token (`deviceToken`), `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`, auth keys (`.p8`) vs certificates (`.p12`), the JWT you sign with the auth key, the `apns-topic` / `apns-push-type` / `apns-priority` headers, and why a token can silently go stale.
- **The `UserNotifications` framework.** `UNUserNotificationCenter`, requesting authorization (`requestAuthorization(options:)`), `UNNotificationCategory` and actions, foreground presentation (`willPresent`), tap handling (`didReceive`), and provisional authorization.
- **Payloads.** The `aps` dictionary, `alert` (title/subtitle/body), `badge`, `sound`, `thread-id`, `content-available` (silent/background), `mutable-content` (service-extension), `interruption-level` (`passive`/`active`/`time-sensitive`/`critical`), `relevance-score`, and custom keys alongside `aps`.
- **Notification Service Extension (NSE).** The extension target, `didReceive(_:withContentHandler:)`, the ~30s time budget and `serviceExtensionTimeWillExpire`, decrypting an encrypted payload with CryptoKit, downloading and attaching media, and the App Group shared container for keys.
- **StoreKit 2 catalog.** `Product`, `Product.products(for:)`, `Product.SubscriptionInfo` and `.subscriptionGroupID`, `displayPrice` (localized by the App Store), `subscriptionPeriod`, introductory/promotional offers, and the `.storekit` configuration file for testing.
- **StoreKit 2 purchase flow.** `product.purchase(options:)`, `Product.PurchaseResult` (`.success(VerificationResult)`/`.userCancelled`/`.pending`), the `VerificationResult` and `checkVerified`, `transaction.finish()`, and why an unverified transaction is worthless.
- **Entitlements & lifecycle.** `Transaction.currentEntitlements` (the source of truth for "what does this user own"), `Transaction.updates` (the long-running listener you start at launch), `Transaction.latest(for:)`, restore (`AppStore.sync()`), and gating a feature on an active entitlement.
- **Server-side validation.** Sending `Transaction.jsonRepresentation` / the signed JWS to your backend, verifying Apple's signature, the App Store Server API, and **App Store Server Notifications V2** (the webhook for `REFUND`, `DID_RENEW`, `EXPIRED`, `GRACE_PERIOD`, `DID_CHANGE_RENEWAL_PREF`).
- **Subscription edge cases.** Refunds (`Transaction.revocationDate`), billing retry and grace period, upgrade/downgrade/crossgrade within a subscription group, Family Sharing (`Transaction.ownershipType`), and Ask to Buy / pending (`.pending`).
- **MetricKit.** `MXMetricManager`, `MXMetricManagerSubscriber`, `didReceive([MXMetricPayload])` (CPU, memory, disk, launch, hang, hitch metrics), `didReceive([MXDiagnosticPayload])` (crash, hang, disk-write-exception diagnostics), the ~24h delivery cadence, and shipping payloads to a backend.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                            | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | APNs architecture; auth keys vs certs; payloads; the NSE         |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | StoreKit 2: catalog, purchase flow, verification, entitlements   |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | Server-side receipt validation; subscription edge cases; challenge |  1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | MetricKit telemetry; payloads to backend; the integration begins |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — Notes Pro v1: push + NSE + paywall                 |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; sandbox purchase + validation on device  |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, Phase III gate prep, push                          |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                  | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Apple's UserNotifications / StoreKit / MetricKit docs, the WWDC sessions, the APNs and App Store Server reference, and the canonical writing on subscriptions and telemetry |
| [lecture-notes/01-apns-and-the-notification-service-extension.md](./lecture-notes/01-apns-and-the-notification-service-extension.md) | The push pipeline end to end: tokens, auth keys, the JWT, payloads, and a Notification Service Extension that decrypts an encrypted payload with CryptoKit |
| [lecture-notes/02-storekit2-server-validation-and-metrickit.md](./lecture-notes/02-storekit2-server-validation-and-metrickit.md) | StoreKit 2 catalog/purchase/entitlements, server-side receipt validation, the subscription edge cases (refund/downgrade/billing retry), and MetricKit telemetry |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-register-and-receive-a-push.md](./exercises/exercise-01-register-and-receive-a-push.md) | Register for remote notifications, get a device token, and send yourself a real APNs push from the command line with a signed JWT |
| [exercises/exercise-02-storekit-purchase-flow.swift](./exercises/exercise-02-storekit-purchase-flow.swift) | Fetch a product, run the purchase flow, verify the transaction, observe entitlements, and gate a feature — tested against a `.storekit` config |
| [exercises/exercise-03-metrickit-collector.swift](./exercises/exercise-03-metrickit-collector.swift) | Build an `MXMetricManagerSubscriber`, receive payloads, serialize them, and ship them to a backend endpoint |
| [challenges/README.md](./challenges/README.md) | Index of the challenge |
| [challenges/challenge-01-subscription-edge-cases.md](./challenges/challenge-01-subscription-edge-cases.md) | Reproduce a refund, a downgrade, and a billing-retry recovery in the StoreKit sandbox, and prove your entitlement gate and server reflect each within minutes — with evidence |
| [quiz.md](./quiz.md) | 14 questions on APNs, the NSE, StoreKit 2 purchase/verify/entitlements, server validation, edge cases, and MetricKit |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for "Notes Pro v1": APNs push on share, an NSE that decrypts, a `notes_pro_monthly` paywall, server-side validation, and MetricKit |

## The "prove the pipeline, not the demo" promise

Week 17 gave you "name the threat first." Week 18 adds the discipline a production reviewer actually checks:

> **Every pipeline must be proven end to end on a physical device, including its failure path — not demonstrated on the happy path.** A push that arrived once in the Simulator is not a working push pipeline. Register on a real device, send a real APNs push, and watch it arrive. Complete a *sandbox* purchase on device, verify the transaction, and watch the gate flip. Then *break* each one — let a token go stale, refund the purchase, drop the network mid-receipt-validation — and prove you detect and recover. A pipeline you've only seen succeed is a pipeline you haven't tested.

You will *prove* this on a physical device: a real APNs push you sent yourself, a sandbox subscription you actually bought, a transaction your Vapor backend actually validated, and a MetricKit payload that actually arrived. "It worked in the Simulator" is not the bar. The pipeline, on hardware, including the refund — that's the Phase III gate.

## A note on what's not here

Week 18 is the *push, purchase, and telemetry pipelines* week. It deliberately does **not** cover:

- **Live Activities and ActivityKit.** Push-to-start Live Activities are an APNs *use case*, but the ActivityKit framework, Dynamic Island layouts, and the real-time update model are Week 21. We build the push pipeline that Week 21's Live Activity will later ride on.
- **Widgets and App Intents.** WidgetKit and App Intents (Week 20) are a different surface; a subscription can *gate* a widget, but we don't build widgets this week.
- **The full backend.** We write the APNs sender, the receipt-validation route, and the server-notification webhook, but the backend's scaling, observability, and on-call belong to the cloud tracks. We build the *client-facing* halves of each pipeline and the minimal Vapor to close the loop.

The point of Week 18 is to make three production pipelines real and proven: push out, purchase in, telemetry home — each on a physical device, each including its failure path.

## Up next

Continue to **Week 19 — Multi-platform: iOS, iPadOS, macOS, watchOS, visionOS** once you have shipped Notes Pro v1 and cleared the Phase III gate (a proven push, a sandbox purchase with server validation, and a TestFlight-ready build). Week 19 opens Phase IV — Capstone & Polish — and takes the single-platform app you've hardened, monetized, and instrumented across Phases I–III and asks it to run on *five* Apple platforms from one codebase. The push pipeline you built this week becomes the watchOS notification; the subscription gate you built this week protects the feature on every platform. Phase III made the app a product; Phase IV makes it an ecosystem. Earn the "prove the pipeline" reflex here — Phase IV's chaos drills are nothing but pipelines under stress.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
