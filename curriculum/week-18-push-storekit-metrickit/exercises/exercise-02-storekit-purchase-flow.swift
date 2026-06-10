// Exercise 2 — The StoreKit 2 purchase flow, verified and gated
//
// Goal: Wire the full StoreKit 2 happy path AND its critical guards: fetch a
//       product, run `product.purchase()`, CHECK the VerificationResult, call
//       `finish()`, derive the entitlement gate from `currentEntitlements`
//       (never a cached Bool), and prove the gate flips on purchase and flips
//       BACK on refund. Verification and finish() are the two lines people
//       forget; this exercise makes you not forget.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// StoreKit 2 testing runs in the SIMULATOR against a `.storekit` CONFIGURATION
// FILE — synthetic products, no App Store Connect, and an Xcode "Transaction
// Manager" where you can force refunds, renewals, and billing failures.
//
//   1. Create a StoreKit Configuration File: File ▸ New ▸ File ▸ StoreKit
//      Configuration File. Add an auto-renewable subscription with product ID
//      "notes_pro_monthly" in a subscription group "pro".
//   2. Edit your test target's scheme ▸ Run ▸ Options ▸ StoreKit Configuration
//      and select that file (or set it on the app scheme to run interactively).
//   3. The `@Test` cases below use `SKTestSession` (the StoreKitTest framework)
//      to drive purchases programmatically and to FORCE a refund.
//
// This is the fast iteration path. The mini-project's GATE is a real sandbox
// purchase on a device — but you debug the flow here first.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] A purchase verifies, finishes, and flips the gate to true.
//   [ ] An unverified transaction is rejected (checkVerified throws).
//   [ ] A forced refund flips the gate back to false (entitlement re-derived).
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import StoreKit
import StoreKitTest
import Testing

// ----------------------------------------------------------------------------
// The store under test. The gate is DERIVED from currentEntitlements, never
// cached as a Bool — that's the whole correctness point.
// ----------------------------------------------------------------------------

@MainActor
@Observable
final class Store {
    enum StoreError: Error { case failedVerification }

    private let proIDs: Set<String> = ["notes_pro_monthly"]
    private(set) var ownedProductIDs: Set<String> = []

    /// The gate the UI reads. Always derived; never a stored flag.
    var hasProAccess: Bool { !ownedProductIDs.isDisjoint(with: proIDs) }

    func products() async throws -> [Product] {
        try await Product.products(for: proIDs).sorted { $0.price < $1.price }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)   // GUARD 1: verify
            await transaction.finish()                          // GUARD 2: finish
            await refreshEntitlements()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Recompute owned IDs from current entitlements, excluding refunded ones.
    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.revocationDate == nil {   // a refunded txn has a revocationDate
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.failedVerification   // NEVER trust this
        }
    }
}

// ----------------------------------------------------------------------------
// Tests — driven by SKTestSession so they run without App Store Connect.
// ----------------------------------------------------------------------------

@MainActor
struct StoreKitFlowTests {

    /// A fresh test session loaded from the .storekit config, clearing any
    /// prior transactions so each test starts owning nothing.
    func freshSession() async throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.clearTransactions()
        session.resetToDefaultState()
        return session
    }

    @Test("A purchase verifies, finishes, and flips the gate to true")
    func purchaseFlipsGate() async throws {
        let session = try await freshSession()
        defer { session.clearTransactions() }

        let store = Store()
        await store.refreshEntitlements()
        #expect(store.hasProAccess == false)            // starts locked

        let product = try #require(try await store.products().first)
        let transaction = try await store.purchase(product)

        #expect(transaction != nil)
        #expect(store.hasProAccess == true)             // gate flipped on
        #expect(store.ownedProductIDs.contains("notes_pro_monthly"))
    }

    @Test("A forced refund flips the gate back to false")
    func refundFlipsGateBack() async throws {
        let session = try await freshSession()
        defer { session.clearTransactions() }

        let store = Store()
        let product = try #require(try await store.products().first)
        _ = try await store.purchase(product)
        #expect(store.hasProAccess == true)

        // Force a refund via the test session — this is the edge case the
        // challenge reproduces. The transaction gets a revocationDate.
        let identifier = try #require(await Transaction.currentEntitlements
            .compactMap { try? store.checkVerified($0) }
            .first(where: { $0.productID == "notes_pro_monthly" })?.id)
        try await session.refundTransaction(identifier: identifier)

        // Re-derive the gate from entitlements: the refunded txn is excluded.
        await store.refreshEntitlements()
        #expect(store.hasProAccess == false)            // gate flipped back off
    }

    @Test("currentEntitlements is the source of truth across a fresh Store")
    func entitlementSurvivesNewStoreInstance() async throws {
        let session = try await freshSession()
        defer { session.clearTransactions() }

        let store1 = Store()
        let product = try #require(try await store1.products().first)
        _ = try await store1.purchase(product)
        #expect(store1.hasProAccess == true)

        // A BRAND NEW Store (simulating a relaunch) derives the same gate from
        // entitlements — proving we didn't depend on a cached in-memory flag.
        let store2 = Store()
        await store2.refreshEntitlements()
        #expect(store2.hasProAccess == true)
    }
}

// ----------------------------------------------------------------------------
// WHY verify + finish + derive matter (write these in your own words first):
//
//   - checkVerified: `.unverified` means StoreKit couldn't validate Apple's
//     signature on the transaction — a forged/tampered receipt. Granting on it
//     gives away the product for free. Never trust an unverified transaction.
//
//   - finish(): until you finish a transaction, StoreKit thinks the product is
//     undelivered and re-presents it via Transaction.updates every launch. The
//     classic bug is "my purchase keeps coming back" — a missing finish().
//
//   - derive the gate: caching `hasPro = true` drifts the instant the sub is
//     refunded, expires, or is restored elsewhere. currentEntitlements is the
//     live truth; recompute the gate from it on every relevant change.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `SKTestSession(configurationFileNamed:)` takes the file name WITHOUT the
//   `.storekit` extension. If it throws "not found," check the file is in the
//   TEST target's resources and the name matches exactly ("Products" here).
//
// - `Transaction.currentEntitlements` is an ASYNC SEQUENCE — iterate with
//   `for await`, not a plain `for`. Each element is a `VerificationResult`.
//
// - A refunded transaction is NOT removed from currentEntitlements; it gains a
//   non-nil `revocationDate`. That's why `refreshEntitlements` filters on it.
//   If your gate doesn't flip back, you're not checking revocationDate.
//
// - The whole Store is `@MainActor`; StoreKit's APIs are happy to be awaited
//   from the main actor in tests. Don't `Task.detached` — you'll fight isolation.
//
// - `session.refundTransaction(identifier:)` takes the Transaction's `id`
//   (UInt64), not the productID. Pull it from currentEntitlements first.
//
// ----------------------------------------------------------------------------
