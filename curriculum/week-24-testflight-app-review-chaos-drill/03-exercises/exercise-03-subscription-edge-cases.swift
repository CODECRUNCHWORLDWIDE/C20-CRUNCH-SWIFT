// Exercise 3 — The StoreKit subscription edge cases, modeled
//
// Goal: Model the three subscription transitions that break real apps — REFUND,
//       DOWNGRADE, and BILLING-RETRY recovery — and prove that the SERVER's
//       entitlement is authoritative and the client's UX follows it. This is
//       the logic behind the subscription chaos drill (Lecture 2, §2, Drill B):
//       the server reflects each App Store Server Notification, and the client
//       gates on the server's record, never on a stale local Transaction.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite. Drop it into a test target. It models the
// server-side entitlement state machine and the App Store Server Notifications
// that drive it, plus a client whose `isPro` reads the SERVER record (not a
// local cache). No StoreKit, no network — the point is the LOGIC: each
// notification produces the correct entitlement, and the client follows.
//
// The LIVE drill (StoreKit sandbox + your Vapor backend) is what the capstone
// requires; this proves the state machine is correct first.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U (or `swift test`).
//   3. Read the assertions: refund de-entitles; downgrade changes the plan;
//      billing-retry recovery re-entitles; the client always follows the server.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] All tests pass.
//   [ ] The entitlement is a SERVER fact; the client reads it, never overrides it.
//   [ ] Each of refund / downgrade / billing-retry produces the correct state.
//   [ ] You can explain why a client-only entitlement check is unsafe.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import Testing

// ----------------------------------------------------------------------------
// The subscription model. The server's authoritative record of a user's
// entitlement, driven by App Store Server Notifications.
// ----------------------------------------------------------------------------

enum Plan: String, Sendable, Equatable {
    case none
    case monthly
    case yearly
}

/// The App Store Server Notification types this drill exercises (a subset).
enum ServerNotification: Sendable {
    case subscribed(Plan)
    case refunded                 // REFUND -> Transaction gains a revocationDate
    case changeRenewalPref(Plan)  // DID_CHANGE_RENEWAL_PREF (downgrade) -> effective next period
    case failedToRenew            // DID_FAIL_TO_RENEW -> entering billing retry
    case renewed                  // DID_RENEW after a failure -> billing-retry recovery
    case expired                  // EXPIRED -> grace/retry exhausted
}

/// The server's entitlement record. This is the AUTHORITATIVE source of truth.
struct Entitlement: Sendable, Equatable {
    var plan: Plan = .none
    var isActive: Bool = false
    /// The plan that takes effect at the next renewal (downgrades are deferred).
    var pendingPlan: Plan? = nil
    var inBillingRetry: Bool = false
}

// ----------------------------------------------------------------------------
// The server: applies notifications to the entitlement. This is the state
// machine your Vapor backend implements when it processes a verified
// App Store Server Notification V2.
// ----------------------------------------------------------------------------

actor SubscriptionServer {
    private(set) var entitlement = Entitlement()

    func apply(_ notification: ServerNotification) {
        switch notification {
        case .subscribed(let plan):
            entitlement.plan = plan
            entitlement.isActive = true
            entitlement.inBillingRetry = false
            entitlement.pendingPlan = nil

        case .refunded:
            // A refund revokes access immediately. The user is de-entitled NOW,
            // regardless of when the client's local Transaction last refreshed.
            entitlement.isActive = false
            entitlement.plan = .none
            entitlement.pendingPlan = nil

        case .changeRenewalPref(let newPlan):
            // A downgrade takes effect at the NEXT renewal, not immediately —
            // the user keeps the current (higher) plan until the period ends.
            entitlement.pendingPlan = newPlan

        case .failedToRenew:
            // Entering billing retry: the user stays entitled during the grace
            // window while Apple retries the charge.
            entitlement.inBillingRetry = true

        case .renewed:
            // Billing-retry recovery (or a normal renewal). Re-entitle and apply
            // any pending downgrade now that a new period has started.
            entitlement.isActive = true
            entitlement.inBillingRetry = false
            if let pending = entitlement.pendingPlan {
                entitlement.plan = pending
                entitlement.pendingPlan = nil
            }

        case .expired:
            entitlement.isActive = false
            entitlement.plan = .none
            entitlement.inBillingRetry = false
            entitlement.pendingPlan = nil
        }
    }

    func current() -> Entitlement { entitlement }
}

// ----------------------------------------------------------------------------
// The client: gates Pro features on the SERVER's entitlement. It NEVER decides
// entitlement locally — the local StoreKit Transaction is at most a UX hint.
// ----------------------------------------------------------------------------

struct ProGate {
    /// The ONLY question the client asks the server's record.
    static func isPro(_ e: Entitlement) -> Bool { e.isActive }
}

// ----------------------------------------------------------------------------
// The test suite
// ----------------------------------------------------------------------------

@Suite("Subscription edge cases: the server is authoritative, the client follows")
struct SubscriptionEdgeCaseTests {

    @Test("Refund de-entitles immediately; the client follows")
    func refundDeEntitles() async {
        let server = SubscriptionServer()
        await server.apply(.subscribed(.monthly))
        #expect(ProGate.isPro(await server.current()) == true)   // paying -> Pro

        await server.apply(.refunded)
        let after = await server.current()
        #expect(after.isActive == false)
        #expect(ProGate.isPro(after) == false)   // refunded -> paywall returns
    }

    @Test("Downgrade is deferred to the next renewal, then applied")
    func downgradeDeferredThenApplied() async {
        let server = SubscriptionServer()
        await server.apply(.subscribed(.yearly))
        await server.apply(.changeRenewalPref(.monthly))   // user downgrades yearly -> monthly

        // Still on yearly until the period ends — the user paid for it.
        let mid = await server.current()
        #expect(mid.plan == .yearly)
        #expect(mid.pendingPlan == .monthly)
        #expect(ProGate.isPro(mid) == true)

        // At the next renewal, the pending downgrade takes effect.
        await server.apply(.renewed)
        let after = await server.current()
        #expect(after.plan == .monthly)
        #expect(after.pendingPlan == nil)
        #expect(ProGate.isPro(after) == true)   // still Pro, just on the cheaper plan
    }

    @Test("Billing-retry recovery: entitled through the grace window, re-entitled on renew")
    func billingRetryRecovery() async {
        let server = SubscriptionServer()
        await server.apply(.subscribed(.monthly))
        await server.apply(.failedToRenew)   // charge failed -> billing retry

        // During billing retry the user stays entitled (Apple's grace window).
        let during = await server.current()
        #expect(during.inBillingRetry == true)
        #expect(ProGate.isPro(during) == true)

        // The retry succeeds -> recovered, no longer in retry.
        await server.apply(.renewed)
        let after = await server.current()
        #expect(after.inBillingRetry == false)
        #expect(ProGate.isPro(after) == true)
    }

    @Test("Retry exhaustion expires the subscription; the client follows")
    func retryExhaustionExpires() async {
        let server = SubscriptionServer()
        await server.apply(.subscribed(.monthly))
        await server.apply(.failedToRenew)
        await server.apply(.expired)   // grace exhausted

        let after = await server.current()
        #expect(after.isActive == false)
        #expect(ProGate.isPro(after) == false)
    }

    @Test("THE CONTRACT: the client never overrides the server's de-entitlement")
    func clientNeverOverridesServer() async {
        let server = SubscriptionServer()
        await server.apply(.subscribed(.yearly))
        await server.apply(.refunded)

        // Even if a STALE local Transaction still 'looks' valid on the device,
        // the gate reads the SERVER record, which says de-entitled. The client
        // cannot grant Pro the server has revoked.
        let serverSays = await server.current()
        #expect(ProGate.isPro(serverSays) == false)
    }
}

// ----------------------------------------------------------------------------
// WHY a client-only entitlement check is unsafe (write it before reading):
//
//   `Transaction.currentEntitlements` on the device reflects what the device
//   last refreshed — which can be minutes stale and is forgeable on an
//   instrumented/jailbroken device. If the client alone decides entitlement, a
//   refunded user keeps Pro until their device happens to refresh, and a
//   determined user can spoof it entirely. Making the SERVER authoritative — it
//   verifies the signed transaction and processes App Store Server Notifications
//   — means entitlement flips the moment Apple tells the server, and the client
//   merely displays the server's truth. UX hint on the client; gate on the
//   server.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - The downgrade is the subtle one. A downgrade does NOT take effect
//   immediately — the user paid for the current period, so they keep the higher
//   plan until it ends. Model it as `pendingPlan`, applied on the next `.renewed`.
//   (Apple defers downgrades; upgrades are immediate. This drill covers the
//   downgrade.)
//
// - During billing retry the user STAYS entitled. Apple gives a grace/retry
//   window; revoking access the instant a charge fails would punish users for
//   an expired card before the retry even runs. `inBillingRetry = true` but
//   `isActive` stays true until `.expired`.
//
// - The server is an `actor`, so the tests `await` its methods. That's correct:
//   notification processing serializes, so two notifications never race the
//   entitlement record.
//
// - For the LIVE drill: in the StoreKit sandbox, complete a subscription, then
//   trigger a refund, a plan change, and a declined-then-recovered renewal.
//   Time how long until your Vapor backend's entitlement record reflects each
//   (the bar is < 5 minutes), and confirm the app's paywall/plan follows.
//
// ----------------------------------------------------------------------------
