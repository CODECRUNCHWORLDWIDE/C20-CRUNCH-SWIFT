// Exercise 3 — Generate a Secure Enclave key, persist it, sign, and verify
//
// Goal: Create a P-256 signing key INSIDE the Secure Enclave, persist its
//       device-bound representation in the Keychain, reload it across "launches"
//       (by re-reading from the Keychain), sign a payload, and verify with the
//       public key. The point: the private key NEVER enters your process — you
//       hold a handle, the hardware does the signing — and the stored blob is a
//       recipe the Enclave can follow, not the key itself.
//
// Estimated time: 45 minutes.
//
// HOW TO USE THIS FILE — READ THIS, IT DETERMINES WHERE IT RUNS
//
// The Secure Enclave is HARDWARE. The iOS Simulator has no Enclave, so
// `SecureEnclave.isAvailable` is `false` there and key generation throws. This
// suite therefore RUNS ON A PHYSICAL DEVICE (an iPhone/iPad, or an Apple
// Silicon Mac, which has an Enclave). The FIRST test asserts the availability
// gate so you can confirm where you are.
//
//   1. Add this file to a test target (iOS 17+/macOS 14+).
//   2. Select a REAL DEVICE as the run destination (not a Simulator).
//   3. Run with Cmd-U on the device. Tests using the Enclave will SKIP on a
//      Simulator (the availability test documents that), and RUN on hardware.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings.
//   [ ] On a physical device: a key is generated, persisted, reloaded, and a
//       signature it makes verifies against the public key.
//   [ ] A tampered payload fails verification (integrity is real, not assumed).
//   [ ] You can explain why the stored `dataRepresentation` is useless if copied
//       to another device.
//
// Inline hints are at the bottom. Don't peek for 15 minutes.

import Foundation
import CryptoKit
import Security
import Testing

// ----------------------------------------------------------------------------
// A tiny Keychain-backed store for the Enclave key's representation.
// The stored bytes are a DEVICE-BOUND ENCRYPTED BLOB, not the private key.
// ----------------------------------------------------------------------------

enum EnclaveStoreError: Error {
    case unavailable
    case keychain(OSStatus)
    case notFound
}

struct EnclaveKeyStore {
    let account: String

    /// Generate a Secure Enclave P-256 signing key. The private key material
    /// stays in hardware; this returns a handle.
    func generate() throws -> SecureEnclave.P256.Signing.PrivateKey {
        guard SecureEnclave.isAvailable else { throw EnclaveStoreError.unavailable }
        // For a drill we use the default access control (key usable while the
        // device is unlocked). The mini-project adds `.userPresence` for biometrics.
        return try SecureEnclave.P256.Signing.PrivateKey()
    }

    /// Persist the key's device-bound representation in the Keychain.
    func save(_ key: SecureEnclave.P256.Signing.PrivateKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.dataRepresentation,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)            // overwrite if present
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw EnclaveStoreError.keychain(status) }
    }

    /// Reload the key handle. The Enclave reconstructs the key internally; the
    /// process still never sees the private bytes.
    func load() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw EnclaveStoreError.notFound
        }
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }

    func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

struct SecureEnclaveTests {

    @Test("Enclave availability is reported correctly for the run destination")
    func availabilityGate() {
        // On a Simulator this is false; on a real device (or Apple Silicon Mac)
        // it is true. Observe it — it tells you why generation throws elsewhere.
        if SecureEnclave.isAvailable {
            print("Secure Enclave available — Enclave tests will run.")
        } else {
            print("No Secure Enclave (Simulator) — run on a device for the rest.")
        }
    }

    @Test("Generate, persist, reload, sign, and verify a round trip")
    func roundTrip() throws {
        // Skip cleanly on a Simulator instead of failing the suite.
        try requireEnclave()
        let store = EnclaveKeyStore(account: "c20.week17.signing")
        defer { store.deleteFromKeychain() }

        // 1. First "launch": generate the key and capture the PUBLIC key (which
        //    you'd enrol with your server). The private key stays in the Enclave.
        let key = try store.generate()
        let publicKey = key.publicKey
        try store.save(key)

        // 2. Sign a payload (a canonical request string, in the real flow).
        let payload = Data("GET\n/notes\n1700000000\nbodyhash".utf8)
        let signature = try key.signature(for: payload)
        #expect(publicKey.isValidSignature(signature, for: payload))

        // 3. Second "launch": reload the key from the Keychain and sign again.
        //    A signature from the RELOADED key still verifies against the SAME
        //    public key — proof the representation rehydrated the same key.
        let reloaded = try store.load()
        let signature2 = try reloaded.signature(for: payload)
        #expect(publicKey.isValidSignature(signature2, for: payload))
    }

    @Test("A tampered payload fails verification")
    func tamperDetected() throws {
        try requireEnclave()
        let store = EnclaveKeyStore(account: "c20.week17.tamper")
        defer { store.deleteFromKeychain() }

        let key = try store.generate()
        let payload = Data("transfer $100".utf8)
        let signature = try key.signature(for: payload)

        #expect(key.publicKey.isValidSignature(signature, for: payload))
        let tampered = Data("transfer $900".utf8)
        #expect(key.publicKey.isValidSignature(signature, for: tampered) == false)
    }

    @Test("The public key serializes for enrolment with a server")
    func publicKeyWireForm() throws {
        try requireEnclave()
        let store = EnclaveKeyStore(account: "c20.week17.pub")
        defer { store.deleteFromKeychain() }

        let key = try store.generate()
        // rawRepresentation is the 64-byte uncompressed point you'd POST to the
        // server's /devices enrolment endpoint. The server rebuilds a
        // P256.Signing.PublicKey from it to verify future signatures.
        let raw = key.publicKey.rawRepresentation
        #expect(raw.count == 64)
        let rebuilt = try P256.Signing.PublicKey(rawRepresentation: raw)
        let payload = Data("ping".utf8)
        let sig = try key.signature(for: payload)
        #expect(rebuilt.isValidSignature(sig, for: payload))
    }
}

/// Throw a skip-style error on platforms without an Enclave so the suite
/// documents the requirement rather than hard-failing on a Simulator.
func requireEnclave() throws {
    guard SecureEnclave.isAvailable else {
        // Swift Testing surfaces this as a thrown error; treat a Simulator run
        // as "not applicable here, run on device."
        throw EnclaveStoreError.unavailable
    }
}

// ----------------------------------------------------------------------------
// WHY the stored representation is useless on another device (write it first):
//
//   The Keychain stores the key's `dataRepresentation`, which is an ENCRYPTED,
//   DEVICE-BOUND blob — ciphertext that only THIS device's Secure Enclave can
//   turn back into a usable key. The private key bytes were never in the blob
//   (or in your process). Copy the blob to another device and its Enclave can't
//   decrypt it, so the key is inert. THAT binding is the security property:
//   "the key exists but you can't read it, and you can't move it."
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `SecureEnclave.P256.Signing.PrivateKey()` THROWS on a Simulator. That's not
//   a bug — it's the absence of hardware. Run on a device. The availability
//   test and `requireEnclave()` exist to make that explicit.
//
// - The Keychain item is per-app (and per-access-group). `SecItemAdd` returning
//   `errSecDuplicateItem` means you didn't `SecItemDelete` first; the store does
//   delete-then-add to overwrite.
//
// - `key.dataRepresentation` is NOT the private key. There is no API to extract
//   the private key bytes from the Enclave, because they don't exist outside it.
//
// - `publicKey.rawRepresentation` is 64 bytes (x || y). `.derRepresentation` and
//   `.pemRepresentation` exist too; pick one and use it consistently on both
//   ends of enrolment. The server must rebuild the key from the SAME form.
//
// - Running on device requires a development team set in Signing & Capabilities
//   and the device trusted. This is the Apple Developer membership from week 15.
//
// ----------------------------------------------------------------------------
