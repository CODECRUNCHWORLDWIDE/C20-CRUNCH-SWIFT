// Exercise 2 — A typed KeychainStore over the SecItem C API
//
// Goal: Wrap the stringly-typed, C-shaped Keychain API (SecItemAdd /
//       SecItemCopyMatching / SecItemUpdate / SecItemDelete) in ONE clean,
//       typed Swift store with an upserting `set`, the correct accessibility
//       class baked in as the default, and typed errors. Then prove the full
//       round-trip: store a token, read it back, overwrite it, delete it.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This file is a SWIFT TESTING suite (`import Testing` / `@Test`, shipped with
// Xcode 16). Drop it into a test target of any iOS 17+/macOS 14+ app or Swift
// package. The Keychain is a REAL system store even in tests/Simulator, so each
// test uses a unique service name and cleans up after itself — no in-memory
// fake is needed, and using the real Keychain is the point.
//
//   1. Add this file to your test target.
//   2. Run with Cmd-U.
//   3. The tests assert the round-trip, the upsert (set twice = one item,
//      latest value), itemNotFound after delete, and the accessibility default.
//
// On the SIMULATOR the Keychain works without any entitlement. On a DEVICE,
// add the "Keychain Sharing" capability only if you use an access group; the
// default (no access group) needs no entitlement.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency).
//   [ ] All tests pass.
//   [ ] `set` UPSERTS — calling it twice for one account leaves one item with
//       the latest value, never a duplicate and never an errSecDuplicateItem.
//   [ ] `get` throws `.itemNotFound` (not a crash) when the item is absent.
//   [ ] The default accessibility is kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
//   [ ] You can explain, in one sentence, why a token goes in the Keychain and
//       not UserDefaults.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import Security
import Testing

// ----------------------------------------------------------------------------
// Typed errors — the C API hands back OSStatus codes; we keep them but name the
// two cases callers actually branch on.
// ----------------------------------------------------------------------------

enum KeychainError: Error, Equatable {
    case status(OSStatus)
    case unexpectedData
    case itemNotFound
}

// ----------------------------------------------------------------------------
// The store. Construct one per logical "service" (e.g. "com.crunch.notes.auth").
// ----------------------------------------------------------------------------

struct KeychainStore {
    let service: String
    var accessGroup: String? = nil
    // The correct default for an auth token: readable after first unlock (so a
    // background refresh works while locked), and never restored to another
    // device from a backup (ThisDeviceOnly).
    var accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private func baseQuery(account: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    /// Upsert. The raw API forces you to handle "exists" vs "doesn't" yourself:
    /// SecItemAdd errors with errSecDuplicateItem if the item is present, so we
    /// try update first and fall back to add.
    func set(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String:      data,
            kSecAttrAccessible as String: accessibility,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return                                   // updated an existing item
        case errSecItemNotFound:
            query.merge(attributes) { $1 }           // add a brand-new item
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        default:
            throw KeychainError.status(updateStatus)
        }
    }

    func get(account: String) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.status(status)
        }
    }

    /// Delete is idempotent: "already gone" is success, not an error.
    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
}

// String convenience for tokens/passwords.
extension KeychainStore {
    func setString(_ value: String, account: String) throws {
        try set(Data(value.utf8), account: account)
    }
    func getString(account: String) throws -> String {
        guard let s = String(data: try get(account: account), encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return s
    }
}

// ----------------------------------------------------------------------------
// Tests — each uses a UNIQUE service so concurrent runs don't collide, and
// cleans up in a defer.
// ----------------------------------------------------------------------------

struct KeychainStoreTests {

    /// A store on a unique service for one test, with guaranteed cleanup.
    private func makeStore() -> KeychainStore {
        KeychainStore(service: "com.crunch.notes.test.\(UUID().uuidString)")
    }

    @Test("Store, read back, and the value round-trips")
    func roundTrip() throws {
        let store = makeStore()
        defer { try? store.delete(account: "primary") }

        try store.setString("token-abc-123", account: "primary")
        let read = try store.getString(account: "primary")
        #expect(read == "token-abc-123")
    }

    @Test("set is an UPSERT: setting twice leaves one item with the latest value")
    func upsert() throws {
        let store = makeStore()
        defer { try? store.delete(account: "primary") }

        try store.setString("old-token", account: "primary")
        try store.setString("new-token", account: "primary")   // would errSecDuplicateItem with a naive add

        #expect(try store.getString(account: "primary") == "new-token")
    }

    @Test("get throws .itemNotFound (not a crash) when the item is absent")
    func missingItem() throws {
        let store = makeStore()
        #expect(throws: KeychainError.itemNotFound) {
            try store.getString(account: "does-not-exist")
        }
    }

    @Test("delete removes the item and is idempotent")
    func deleteIdempotent() throws {
        let store = makeStore()
        try store.setString("token", account: "primary")
        try store.delete(account: "primary")

        #expect(throws: KeychainError.itemNotFound) {
            try store.getString(account: "primary")
        }
        // Deleting again must NOT throw — "already gone" is success.
        #expect(throws: Never.self) {
            try store.delete(account: "primary")
        }
    }

    @Test("Two accounts under one service are independent")
    func multipleAccounts() throws {
        let store = makeStore()
        defer {
            try? store.delete(account: "access")
            try? store.delete(account: "refresh")
        }
        try store.setString("access-tok", account: "access")
        try store.setString("refresh-tok", account: "refresh")

        #expect(try store.getString(account: "access") == "access-tok")
        #expect(try store.getString(account: "refresh") == "refresh-tok")
    }

    @Test("The default accessibility is AfterFirstUnlockThisDeviceOnly")
    func accessibilityDefault() {
        let store = KeychainStore(service: "irrelevant")
        // The CFString constant compares by reference identity for these globals.
        #expect(store.accessibility == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }
}

// ----------------------------------------------------------------------------
// WHY a token goes in the Keychain, not UserDefaults (write it before reading):
//
//   UserDefaults is an UNENCRYPTED plist in Library/Preferences that is backed
//   up to iCloud/iTunes in plaintext — a token there is readable by anyone with
//   the backup. The Keychain is hardware-encrypted, per-item access-controlled,
//   and (with ...ThisDeviceOnly) never written to a restorable backup. The
//   Keychain is the ONLY storage on iOS designed to hold a secret.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `errSecDuplicateItem` from SecItemAdd means the item already exists. That's
//   exactly why `set` tries SecItemUpdate FIRST and only adds on
//   errSecItemNotFound. A naive add-only `set` fails the `upsert` test.
//
// - The dictionary keys are CFString constants you bridge with `as String`.
//   Miss a cast (e.g. `kSecClass` without `as String`) and you get a runtime
//   type error, not a compile error — this is why the wrapper exists.
//
// - `SecItemCopyMatching` returns the data via an inout `CFTypeRef?`; you must
//   pass `kSecReturnData: true` AND `kSecMatchLimit: kSecMatchLimitOne` or you
//   get back attributes/an array instead of the raw Data.
//
// - On a DEVICE with an access group, add the "Keychain Sharing" capability and
//   set `accessGroup`. On the SIMULATOR with no access group, no entitlement is
//   needed and these tests run as-is.
//
// - Don't compare CFString accessibility constants with ==/Equatable in general;
//   for these specific global constants the identity comparison in the test
//   works because they're the same singleton CFString the system vends.
//
// ----------------------------------------------------------------------------
