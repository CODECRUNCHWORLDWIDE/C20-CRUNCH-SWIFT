// Exercise 2 — CryptoKit round-trips with tamper tests
//
// Goal: Exercise every CryptoKit primitive you'll use this week — hashing,
//       AES-GCM authenticated encryption, X25519 key agreement + HKDF, and
//       Ed25519/P-256 signatures — and, crucially, prove that TAMPERING is
//       DETECTED. A crypto round-trip that succeeds isn't interesting; one that
//       correctly FAILS on a flipped bit is the whole point.
//
// Estimated time: 50 minutes.
//
// HOW TO USE THIS FILE
//
// This is a SWIFT TESTING suite (`import Testing` / `@Test`, shipped with
// Xcode 16). It is PURE CryptoKit — no Secure Enclave, no UI — so it runs
// ANYWHERE: an iOS Simulator, a macOS target, or a Swift package test target.
//
//   1. Add this file to a test target (iOS 17+/macOS 14+) or `swift test` package.
//   2. Run with Cmd-U (or `swift test`).
//   3. Read the assertions. Every "tamper" test proves a modified message is
//      rejected — that detection IS the security property.
//
// If your project still uses XCTest, the conversion is mechanical: replace
// `@Test func x() throws` with `func testX() throws` inside an `XCTestCase`,
// and `#expect(a == b)` with `XCTAssertEqual(a, b)`.
//
// ACCEPTANCE CRITERIA
//
//   [ ] Builds with 0 warnings (including Swift 6 strict-concurrency warnings).
//   [ ] All tests pass — including the tamper tests that assert FAILURE.
//   [ ] You can explain, in one sentence each: why GCM detects tampering, why
//       nonce reuse would be catastrophic, and why the raw ECDH secret must
//       go through HKDF before use.
//
// Inline hints are at the bottom. Don't peek until you've tried for 15 minutes.

import Foundation
import CryptoKit
import Testing

// ----------------------------------------------------------------------------
// 1. Hashing — SHA-256 is deterministic; one byte changes the whole digest.
// ----------------------------------------------------------------------------

struct HashingTests {

    @Test("SHA-256 is deterministic for the same input")
    func deterministic() {
        let a = SHA256.hash(data: Data("hello".utf8))
        let b = SHA256.hash(data: Data("hello".utf8))
        #expect(a == b)
    }

    @Test("One flipped byte avalanches the whole digest")
    func avalanche() {
        let a = Data(SHA256.hash(data: Data("hello".utf8)))
        let b = Data(SHA256.hash(data: Data("hellp".utf8)))   // 'o' -> 'p'
        #expect(a != b)
        #expect(a.count == 32)   // SHA-256 is always 32 bytes
    }

    @Test("SHA-1 lives under `Insecure` on purpose")
    func sha1IsNamespaced() {
        // You must spell out `Insecure` — the API makes the broken hash awkward.
        let legacy = Data(Insecure.SHA1.hash(data: Data("hello".utf8)))
        #expect(legacy.count == 20)   // SHA-1 is 20 bytes; here for interop only
    }
}

// ----------------------------------------------------------------------------
// 2. AES-GCM — authenticated encryption. Round-trips, and DETECTS tampering.
// ----------------------------------------------------------------------------

struct AESGCMTests {

    @Test("Seal then open recovers the plaintext")
    func roundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("a note worth protecting".utf8)

        // No nonce argument: CryptoKit generates a fresh random nonce. Don't
        // supply your own unless a protocol forces it.
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let combined = sealed.combined!          // nonce + ciphertext + tag, one blob

        let reopened = try AES.GCM.SealedBox(combined: combined)
        let recovered = try AES.GCM.open(reopened, using: key)
        #expect(recovered == plaintext)
    }

    @Test("Tampering with the ciphertext makes open() throw")
    func tamperDetected() throws {
        let key = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(Data("important".utf8), using: key)
        var bytes = sealed.combined!
        bytes[bytes.count - 1] ^= 0x01           // flip one bit in the auth tag

        let tamperedBox = try AES.GCM.SealedBox(combined: bytes)
        // GCM is AEAD: a tampered ciphertext/tag fails authentication and THROWS.
        // It never returns garbage plaintext.
        #expect(throws: (any Error).self) {
            _ = try AES.GCM.open(tamperedBox, using: key)
        }
    }

    @Test("The wrong key cannot open the box")
    func wrongKeyFails() throws {
        let key = SymmetricKey(size: .bits256)
        let other = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(Data("secret".utf8), using: key)

        #expect(throws: (any Error).self) {
            _ = try AES.GCM.open(sealed, using: other)
        }
    }
}

// ----------------------------------------------------------------------------
// 3. X25519 key agreement + HKDF — derive a SHARED key without transmitting it.
// ----------------------------------------------------------------------------

struct KeyAgreementTests {

    @Test("Both parties derive the SAME symmetric key from exchanged public keys")
    func sharedSecretMatches() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()

        // Each side: own private + other's public -> same shared secret.
        let aliceShared = try alice.sharedSecretFromKeyAgreement(with: bob.publicKey)
        let bobShared = try bob.sharedSecretFromKeyAgreement(with: alice.publicKey)

        // NEVER use the raw secret as a key — HKDF it into a uniform symmetric key.
        let salt = Data("notes-app-v1".utf8)
        let aliceKey = aliceShared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: salt, sharedInfo: Data(), outputByteCount: 32)
        let bobKey = bobShared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: salt, sharedInfo: Data(), outputByteCount: 32)

        #expect(aliceKey == bobKey)
    }

    @Test("Derived key actually works end to end with AES-GCM")
    func derivedKeyEncrypts() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let shared = try alice.sharedSecretFromKeyAgreement(with: bob.publicKey)
        let key = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data("v1".utf8), sharedInfo: Data(), outputByteCount: 32)

        let sealed = try AES.GCM.seal(Data("hi bob".utf8), using: key)

        // Bob derives the identical key and opens it.
        let bobShared = try bob.sharedSecretFromKeyAgreement(with: alice.publicKey)
        let bobKey = bobShared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data("v1".utf8), sharedInfo: Data(), outputByteCount: 32)
        let opened = try AES.GCM.open(sealed, using: bobKey)
        #expect(opened == Data("hi bob".utf8))
    }
}

// ----------------------------------------------------------------------------
// 4. Signatures — Ed25519 and P-256. Verify, and DETECT a tampered payload.
// ----------------------------------------------------------------------------

struct SignatureTests {

    @Test("Ed25519: a valid signature verifies; a tampered payload does not")
    func ed25519() throws {
        let key = Curve25519.Signing.PrivateKey()
        let payload = Data("transfer $100 to Bob".utf8)
        let signature = try key.signature(for: payload)

        // Verify — you MUST check this Bool; an unverified signature is decoration.
        #expect(key.publicKey.isValidSignature(signature, for: payload))

        // Change one digit and verification fails — proof of integrity.
        let tampered = Data("transfer $900 to Bob".utf8)
        #expect(key.publicKey.isValidSignature(signature, for: tampered) == false)
    }

    @Test("P-256: sign/verify works (this is the Enclave-compatible curve)")
    func p256() throws {
        // Software P-256 here; the Enclave uses the SAME curve in exercise 3.
        let key = P256.Signing.PrivateKey()
        let payload = Data("GET\n/notes\n1700000000\nabc".utf8)
        let signature = try key.signature(for: payload)

        #expect(key.publicKey.isValidSignature(signature, for: payload))

        // The DER representation is what you put on the wire (an X-Request-Signature header).
        let der = signature.derRepresentation
        let rebuilt = try P256.Signing.ECDSASignature(derRepresentation: der)
        #expect(key.publicKey.isValidSignature(rebuilt, for: payload))
    }

    @Test("A different key's public key cannot verify the signature")
    func wrongVerifier() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let imposter = Curve25519.Signing.PrivateKey()
        let payload = Data("hello".utf8)
        let sig = try signer.signature(for: payload)

        #expect(signer.publicKey.isValidSignature(sig, for: payload))
        #expect(imposter.publicKey.isValidSignature(sig, for: payload) == false)
    }
}

// ----------------------------------------------------------------------------
// WHY each tamper test matters (write these in your own words before reading):
//
//   - GCM detects tampering because it's AEAD: the authentication TAG is
//     computed over the ciphertext, so any change to the ciphertext (or tag)
//     fails the tag check and `open` throws instead of returning garbage.
//
//   - Nonce reuse is catastrophic for GCM because reusing a (key, nonce) pair
//     lets an attacker recover the XOR of two plaintexts AND forge tags, which
//     destroys both confidentiality and authenticity. CryptoKit's no-argument
//     `seal` picks a fresh random nonce so you can't reuse one by accident.
//
//   - The raw ECDH shared secret is a curve point, not uniformly-random bytes,
//     so it isn't safe to use directly as a key. HKDF turns it into a uniform
//     key AND lets you bind it to a context (salt/info) so the same secret
//     yields different keys for different purposes.
//
// ----------------------------------------------------------------------------
// HINTS (read only if stuck > 15 min)
// ----------------------------------------------------------------------------
//
// - `sealed.combined` is an Optional (it's nil only for detached forms you
//   didn't request). Force-unwrap it in tests, or `try #require(sealed.combined)`.
//
// - `SHA256.hash` returns a `SHA256.Digest`, not `Data`. Wrap with `Data(digest)`
//   to compare bytes or count length.
//
// - `hkdfDerivedSymmetricKey` requires BOTH sides to pass the SAME salt and
//   sharedInfo, or they derive different keys and the AES-GCM open fails. If
//   `derivedKeyEncrypts` fails, your salts differ between the two derivations.
//
// - `#expect(throws:)` is the Swift Testing way to assert a throw. The form
//   `#expect(throws: (any Error).self) { try ... }` asserts "some error."
//
// - Strict-concurrency warning? These suites hold no shared mutable state and
//   don't cross actor boundaries, so they should be clean. If you see one, you
//   probably captured something into a closure that escapes; keep it local.
//
// ----------------------------------------------------------------------------
