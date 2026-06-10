# Mini-Project — Notes Pro v1 (Phase III Integration Project)

This is the **Phase III integration project** — the capstone of Production iOS. You take the hardened, instrumented, single-platform app you've built across Phases I–III and turn it into a *product*: it reaches users (an APNs push when a note is shared with you), decrypts private content on-device (a Notification Service Extension), charges users (a `notes_pro_monthly` StoreKit 2 subscription behind a paywall), validates the purchase server-side, and reports back from the field (MetricKit telemetry). By the end you have **Notes Pro v1**, proven end to end on a physical device, and you clear the **Phase III gate**.

This is a *compounding* project, and it pulls together more of the track than any single week so far. The push pipeline reaches the user; the NSE decrypts with the **CryptoKit from Week 17**; the receipt validation verifies a signature the **same way you verified request signatures in Week 17**; the subscription gate protects a feature; MetricKit instruments the **performance work from Week 15**. Three production pipelines — push out, purchase in, telemetry home — built on top of the secure, networked, persistent app you already have. The discipline throughout is the README's promise: **every pipeline proven end to end on hardware, including its failure path.**

---

## Where you're starting from

Your Phase III app (Notes v1 + the Week 13–17 hardening) has, roughly:

- A SwiftData-persisted, navigable notes app (Phases I–II).
- A `NotesClient` actor with retry, offline handling, **certificate pinning**, and **Secure Enclave request signing** (Weeks 13, 17).
- A Vapor backend with notes routes, device enrolment, and signature verification (Phases I, Week 17).
- The app running on a **physical device** with Apple Developer membership (Week 15+).

If you don't have a clean checkpoint, build the minimal version first; the pipeline work is the same.

## What you're building toward

By the end you have:

- **APNs push on share**: when another user shares a note with you, the backend sends a push and you receive it on device.
- A **Notification Service Extension** that decrypts an encrypted payload with AES-GCM (the shared key in an App Group Keychain) before the notification is shown — the note title never transits APNs in cleartext.
- A **`notes_pro_monthly` subscription** behind a `Paywall` view, with localized pricing, verified purchase, and an entitlement gate derived from `currentEntitlements`.
- **Server-side validation**: the client sends the signed transaction to Vapor, which re-verifies Apple's signature and grants a server entitlement; an App Store Server Notifications V2 webhook handles refund/renewal/expiry.
- A **MetricKit collector** shipping daily metric and diagnostic payloads to the backend.
- A proven **end-to-end run on a physical device**, including the failure paths (stale token, refund).

---

## Milestone 1 — The push pipeline: register, store, send (≈ 2 h)

Wire registration (lecture 1, §2) and have the backend store the device token against the user. Then add a Vapor APNs sender so that sharing a note triggers a push.

```swift
// CLIENT: register and ship the token over the pinned, signed NotesClient.
func application(_ app: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    let hex = token.map { String(format: "%02x", $0) }.joined()
    Task { try? await NotesClient.shared.registerPushToken(hex) }
}
```

On the server, when `POST /notes/:id/share` runs, look up the recipient's token and send a push via APNSwift (or Vapor's APNS), signing the JWT from your `.p8`. Decisions to defend:

- **Auth key, not certificate.** One `.p8`, no annual expiry; sign a JWT per request (lecture 1, §3). Document the rotation order (new key first) in a comment — it's the Phase IV chaos drill.
- **`mutable-content: 1`** in the payload, so the NSE (Milestone 2) gets to decrypt before display.
- **Match `apns-push-type: alert`** to the visible payload, and use `api.sandbox.push.apple.com` for development builds.

**Prove it:** share a note from a second account (or a test script) and watch the push arrive on the device. Then send to a deliberately corrupted token and confirm APNs returns `BadDeviceToken` — and that your backend logs it and expires the token (the failure path).

## Milestone 2 — The Notification Service Extension that decrypts (≈ 2 h)

Add a Notification Service Extension target. The backend encrypts the note title with a per-recipient key (shared with the device); the extension decrypts it before the notification is shown.

```swift
import UserNotifications
import CryptoKit

class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
        contentHandler = handler
        let mutable = request.content.mutableCopy() as! UNMutableNotificationContent
        bestAttempt = mutable

        guard let b64 = request.content.userInfo["encryptedTitle"] as? String,
              let combined = Data(base64Encoded: b64),
              let key = sharedKey() else { handler(mutable); return }

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            mutable.body = String(decoding: try AES.GCM.open(box, using: key), as: UTF8.self)
        } catch {
            mutable.body = "New shared note"   // fail safe; never leak
        }
        handler(mutable)
    }

    override func serviceExtensionTimeWillExpire() {
        if let h = contentHandler, let b = bestAttempt { h(b) }   // budget exceeded: best effort
    }

    private func sharedKey() -> SymmetricKey? {
        // Keychain item in the App Group access group, readable by app + extension.
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "com.crunch.notes.push-key",
            kSecAttrAccessGroup as String: "group.com.crunch.notes",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data else { return nil }
        return SymmetricKey(data: d)
    }
}
```

Decisions to defend:

- **App Group Keychain** for the shared decryption key — the extension is a separate process and can't read the app's default Keychain (lecture 1, §5). Enable the App Group capability on both targets.
- **`serviceExtensionTimeWillExpire` delivers a best effort** — never leave the handler uncalled, or the OS shows the raw ciphertext.
- **Decryption failure fails safe** — a generic body, never the error or the ciphertext on the lock screen (the Week 17 threat-model habit: a notification is a leak surface).

**Prove it:** receive a shared-note push and confirm the decrypted title shows. Then send a push with a tampered ciphertext and confirm the safe fallback body shows (not a crash, not a leak).

## Milestone 3 — The StoreKit 2 catalog and paywall (≈ 1.5 h)

Define `notes_pro_monthly` (in App Store Connect and/or a `.storekit` config), fetch it, and present a `Paywall`.

```swift
struct Paywall: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            Text("Notes Pro").font(.largeTitle.bold())
            Text("Unlimited tags, shared notes, and priority sync.")
            ForEach(store.subscriptions) { product in
                Button {
                    Task { try? await store.purchase(product) }
                } label: {
                    // displayPrice is LOCALIZED by the App Store — never hardcode.
                    Text("\(product.displayName) — \(product.displayPrice)/mo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Restore Purchases") { Task { try? await AppStore.sync() } }
        }
        .padding()
        .task { await store.loadProducts() }
    }
}
```

Decisions to defend:

- **Render `displayPrice`**, never a hardcoded price — the App Store localizes currency and format per region (this matters for the capstone's five-region TestFlight).
- **A Restore button** that calls `AppStore.sync()` and re-derives the gate — required by App Review, and correct because the gate comes from `currentEntitlements`.

## Milestone 4 — Purchase, verify, finish, gate (≈ 1.5 h)

Implement the purchase flow with all four guards (lecture 2, §2), the entitlement listener (§3), and the gate.

```swift
@MainActor @Observable
final class Store {
    private(set) var ownedIDs: Set<String> = []
    var hasProAccess: Bool { ownedIDs.contains("notes_pro_monthly") }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        guard case .success(let verification) = result else { return }
        let transaction = try checkVerified(verification)      // verify
        try await NotesClient.shared.validateTransaction(transaction.jsonRepresentation)  // server
        await transaction.finish()                             // finish
        await refreshEntitlements()                            // derive gate
    }

    func startListener() -> Task<Void, Never> {
        Task(priority: .background) {
            for await update in Transaction.updates {           // renewals, refunds, cross-device
                guard let t = try? self.checkVerified(update) else { continue }
                try? await NotesClient.shared.validateTransaction(t.jsonRepresentation)
                await t.finish()
                await self.refreshEntitlements()
            }
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let t = try? checkVerified(result), t.revocationDate == nil { owned.insert(t.productID) }
        }
        ownedIDs = owned
    }

    func checkVerified<T>(_ r: VerificationResult<T>) throws -> T {
        switch r { case .verified(let s): return s; case .unverified: throw StoreError.failedVerification }
    }
    enum StoreError: Error { case failedVerification }
}
```

Gate a feature (e.g. "share a note" or "more than 3 tags") on `store.hasProAccess`, showing the `Paywall` when locked. Start the `Transaction.updates` listener at launch.

## Milestone 5 — Server-side validation and the notifications webhook (≈ 2 h)

On Vapor, validate the transaction the client sends and stand up the App Store Server Notifications V2 webhook (lecture 2, §4–5).

```swift
import AppStoreServerLibrary
import Vapor

// Validate the signed transaction the client posts.
func validate(_ req: Request) async throws -> HTTPStatus {
    let signed = req.body.string ?? ""
    let verifier = SignedDataVerifier(/* roots, bundleID, env */)
    let txn = try verifier.verifyAndDecodeTransaction(signedTransactionInfo: signed)
    try await EntitlementStore.grant(productID: txn.productId,
                                     originalTransactionID: txn.originalTransactionId,
                                     expiresAt: txn.expiresDate, on: req.db)
    return .ok
}

// Handle server notifications (refund/renew/expire) keyed on originalTransactionId.
func notification(_ req: Request) async throws -> HTTPStatus {
    let signed = try req.content.decode(SignedPayload.self).signedPayload
    let n = try SignedDataVerifier(/* ... */).verifyAndDecodeNotification(signedPayloadNotification: signed)
    switch n.notificationType {
    case .refund, .expired, .revoke: try await EntitlementStore.revoke(originalTransactionID: n.originalTransactionID, on: req.db)
    case .didRenew, .subscribed:     try await EntitlementStore.extend(/* new expiry */ on: req.db)
    case .didFailToRenew:            try await EntitlementStore.markGrace(originalTransactionID: n.originalTransactionID, on: req.db)
    default: break
    }
    return .ok
}
```

**Prove it:** complete a sandbox purchase on device, confirm the server granted the entitlement, then refund it (Transaction Manager or sandbox) and confirm the webhook revoked it. (The full three-transition workup is the challenge.)

## Milestone 6 — MetricKit + the end-to-end run (≈ 1 h)

Register the MetricKit collector (exercise 3) at launch and ship payloads to the backend. Then do the **Phase III gate run** on a physical device:

1. Receive a real APNs push for a shared note; the NSE shows the decrypted title.
2. Open the paywall, complete a **sandbox** subscription purchase; the gate flips; the server validates it.
3. Refund the purchase; the gate flips back and the server revokes (the failure path).
4. Confirm the MetricKit collector is registered (a real payload arrives within ~24h; for the gate, prove the collector is wired and the upload path fires).

Record this as a clip or screenshots in the repo README — the push, the purchase, the validation, and the refund-revoke. "Three pipelines, proven on hardware, including the refund" is the deliverable and the Phase III gate.

---

## Acceptance criteria

- [ ] **Push on share** works on a physical device, sent from your Vapor backend with a JWT-signed APNs request; a stale token is detected and the token expired (failure path proven).
- [ ] A **Notification Service Extension** decrypts an AES-GCM payload (key in an App Group Keychain) and fails safe on a bad payload; `serviceExtensionTimeWillExpire` delivers a best effort.
- [ ] A **`notes_pro_monthly`** subscription is fetched, shown in a `Paywall` with **localized `displayPrice`**, and a **Restore** button calls `AppStore.sync()`.
- [ ] The purchase flow **checks the `VerificationResult`**, **calls `finish()`**, and the gate is **derived from `currentEntitlements`** (checks `revocationDate`); a `Transaction.updates` listener runs from launch.
- [ ] **Server-side validation** re-verifies the signed transaction; an **App Store Server Notifications V2 webhook** revokes on refund and extends on renewal.
- [ ] A **MetricKit collector** is registered and ships payloads to the backend.
- [ ] A **sandbox purchase + refund** is proven end to end on a physical device: gate on, server granted, refund, gate off, server revoked.
- [ ] Build with **0 warnings, 0 errors**, including Swift 6 strict-concurrency.

## Stretch goals

- **Silent push to refresh.** Add a `content-available` push that wakes the app to pull new shared notes, and observe the OS throttling — a preview of Week 21's background work.
- **Communication notification.** Make the shared-note push a communication notification (with the sharer's avatar via `INSendMessageIntent`), so it renders with the richer iOS messaging UI.
- **Family Sharing.** Mark the subscription Family Shareable and test that a family member's `Transaction.ownershipType == .familyShared` grants access — and that your server entitlement handles the family case.
- **Introductory offer.** Add a 7-day free trial introductory offer and render the offer terms in the paywall from `product.subscription?.introductoryOffer`.

## What this milestone earns you

You can now ship a real push pipeline and a real subscription with server-side validation — the literal "skill earned" line for the week, and the **Phase III gate**. More than that: you composed three production pipelines onto a secure, networked app and proved each on hardware including its failure path. That "prove the pipeline, not the demo" discipline is the entire ethos of Phase IV: the capstone's chaos drills (APNs key rotation, subscription edge cases, offline-edit conflict) are nothing but these pipelines under deliberate stress. Notes Pro v1 is the second of your three portfolio apps, and the one that proves you can take money and reach users — the part that makes an app a product. Phase III is done; Phase IV makes it an ecosystem.
