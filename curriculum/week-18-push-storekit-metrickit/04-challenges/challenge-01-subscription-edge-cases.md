# Challenge 1 — The subscription edge cases: refund, downgrade, billing retry (with evidence)

**Time.** 90–150 minutes.
**Deliverable.** A report (`SUBSCRIPTIONS.md`) with a table of the three transitions — refund, downgrade, billing-retry recovery — showing for each the App Store Server Notification type that fired, the expected client-gate and server-entitlement behaviour, and what you actually observed, plus the relevant code, committed to your Week 18 repo.

## The premise

A purchase that unlocks a feature is a demo. A *subscription* is a state machine that keeps changing after the sale — usually when your app isn't even running — and getting those post-sale transitions right is what separates an app that quietly leaks revenue (or locks out paying customers) from one that's actually a business. The three transitions that bite hardest are **refund**, **downgrade**, and **billing-retry recovery**, and almost every subscription app ships at least one of them wrong on the first try. The skill this challenge builds is not "subscriptions exist" — it's **drive each transition deliberately, observe what your client and server do, and prove they do the right thing within minutes.** A transition you've never driven is a transition you've shipped on faith.

You will reproduce all three in the StoreKit sandbox (or the `.storekit` transaction manager), and for each prove two things: the *client* gate reflects it (derived from `currentEntitlements`), and the *server* entitlement reflects it (driven by the App Store Server Notification).

## Setup

Start from your `Store` and the Vapor receipt-validation + server-notification webhook from the mini-project (or build the minimal versions). You need:

- A `notes_pro_monthly` and a `notes_pro_yearly` product in the same subscription group ("pro"), in a `.storekit` config and/or App Store Connect sandbox.
- The client gate derived from `currentEntitlements` (exercise 2).
- A Vapor `EntitlementStore` keyed on `originalTransactionId`, updated by both the validation route and the App Store Server Notifications V2 webhook (lecture 2, §4–5).
- A way to inspect the server entitlement (a debug endpoint, a log line, or a DB query).

For driving the transitions you have two tools: **Xcode's StoreKit Transaction Manager** (Debug ▸ StoreKit, with a `.storekit` config) for refunds, renewals, and forced billing failures locally; and the **sandbox environment on a device** with a sandbox Apple ID for the real end-to-end including server notifications (App Store Connect lets you point sandbox notifications at your webhook URL).

## Transition 1 — Refund

**Drive it.** Purchase `notes_pro_monthly`, confirm the gate is on. Then refund it: in the Transaction Manager, refund the transaction; in sandbox, use the refund tooling. Apple fires a `REFUND` (CONSUMPTION/REFUND) notification to your webhook.

**Prove the client.** After the refund, the transaction in `currentEntitlements` gains a non-nil `revocationDate`. Re-derive the gate (`refreshEntitlements`) — `hasProAccess` must flip to **false**. If it stays true, your gate isn't checking `revocationDate`, which is the bug.

**Prove the server.** Your webhook receives `REFUND`, looks up the entitlement by `originalTransactionId`, and **revokes immediately.** Query the server entitlement: it must be revoked. If your server doesn't process `REFUND`, you're serving premium content to someone who got their money back — the canonical revenue-leak bug.

## Transition 2 — Downgrade (yearly → monthly)

**Drive it.** Subscribe to `notes_pro_yearly`, then switch to `notes_pro_monthly` within the group (the system "manage subscription" flow, or the Transaction Manager's plan change). Apple fires `DID_CHANGE_RENEWAL_PREF`.

**Prove the timing.** A downgrade within a group takes effect at the **next renewal**, not immediately — the user keeps yearly access through the period they paid for. The trap is flipping the plan *now*: that shortchanges a user who's paid through the year. Your server should record the *pending* renewal preference and only apply the plan change when the renewal (`DID_RENEW` with the new product) arrives.

**Prove client + server.** The client gate stays **true** throughout (they still have Pro, just a pending plan change). The server records the pending downgrade and, at the simulated renewal, switches the active product to monthly. Show both the "pending" state and the post-renewal state.

## Transition 3 — Billing retry / grace period recovery

**Drive it.** Force a renewal to fail (Transaction Manager ▸ enable a billing failure, or the sandbox's accelerated renewal with a failure). Apple fires `DID_FAIL_TO_RENEW` and the subscription enters a **grace period** (if you've enabled billing grace period in App Store Connect — do so). Then let the retry succeed (clear the failure) and Apple fires `DID_RENEW`.

**Prove the grace behaviour.** During the grace period the user must **keep access** — revoking on the first failure locks out a paying customer over a transient card issue. Your server marks the entitlement "billing retry / grace" but does *not* revoke. The client gate stays **true** (the entitlement is still active, within grace).

**Prove the recovery.** When the retry succeeds (`DID_RENEW`), the server clears the retry flag and extends the expiry. Only if grace expires with no recovery does `EXPIRED` arrive and you revoke. Show the grace state, the recovery, and (optionally) the expiry-with-no-recovery branch.

## Acceptance criteria

- [ ] All three transitions are driven and observed: **refund**, **downgrade**, **billing-retry recovery**.
- [ ] `SUBSCRIPTIONS.md` has a table: for each transition, the **notification type** that fired, the **expected** client-gate and server-entitlement behaviour, and the **observed** behaviour — with timing (the server reflected each within minutes).
- [ ] The client gate is **derived from `currentEntitlements`** (checks `revocationDate`), proven to flip on refund and stay correct through downgrade and grace.
- [ ] The server entitlement is driven by the **App Store Server Notifications V2 webhook**, proven to revoke on refund, defer the downgrade to renewal, and keep access through grace.
- [ ] A 4–6 sentence reflection on which transition is most dangerous to get wrong, and why (the refund revenue leak vs the grace-period lockout).
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "I tested refunds and they work." A great submission says:

> I drove all three transitions in the StoreKit Transaction Manager with the webhook pointed at my Vapor sandbox. On REFUND, the client transaction gained a revocationDate and my gate (derived from currentEntitlements) flipped to false on the next refresh; the server received the REFUND notification and revoked the entitlement keyed on originalTransactionId within ~3 s — without that, I'd be serving Pro to a refunded user, the most expensive bug here. On the yearly→monthly downgrade, I deliberately did NOT apply the change immediately: the client stayed Pro and the server recorded a pending renewal preference, applying monthly only when the simulated DID_RENEW arrived, so the user kept the yearly access they'd paid for. On billing failure, with grace period enabled, the server marked the entitlement "grace, retrying" and kept access — revoking on the first DID_FAIL_TO_RENEW would have locked out a paying customer over an expired card — and on the recovering DID_RENEW it cleared the flag and extended expiry. The refund is the most dangerous to get wrong (direct revenue leak); the grace-period lockout is the most damaging to trust.

Three transitions, both sides, honest about the stakes. That's the senior-engineer answer, and it's exactly the Phase IV chaos-drill writeup in miniature.

## Where this reappears

This *is* the rehearsal for the Phase IV capstone's **subscription edge-cases chaos drill** (one of the three drills you can pick): trigger a real refund, a downgrade, and a billing-retry recovery, and prove the server reflects each within five minutes. You've now done it in the sandbox; the capstone does it under the full system. The "drive the transition, observe both sides, prove the timing" discipline is the chaos-drill method, applied to money.
