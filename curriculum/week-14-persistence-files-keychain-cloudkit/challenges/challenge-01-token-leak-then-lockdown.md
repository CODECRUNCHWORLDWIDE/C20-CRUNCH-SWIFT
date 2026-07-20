# Challenge 1 — Plant a token leak, then lock it down (with the threat model)

**Time.** 60–120 minutes.
**Deliverable.** A `THREAT-MODEL.md` documenting the leak, the proof you read it out of the plist, the Keychain fix, and the attacker each step defends against — plus the before/after code, committed to your Week 14 repo.

## The premise

The single most common security bug in shipped iOS apps is an auth token in `UserDefaults`. It works perfectly — one line to write, one line to read — and it is a plaintext secret in a backed-up file. The skill this challenge builds is not "know `UserDefaults` is wrong for secrets." It's **plant the leak, prove it by extracting the token from disk yourself, fix it in the Keychain, prove the fix, and write down which specific attacker each step stops.** A security claim you can't demonstrate is a guess.

You will store a token the wrong way, read it back out of the app's preferences plist from the command line (the thing an attacker with a backup does), then store it the right way and show that the same extraction now fails.

## What to build

Start from any SwiftUI app (the `FilesScratch` from exercise 1, or your Notes app). You need a "login" that produces a token and stores it.

### Step 1 — Plant the leak (the WRONG way)

Store the token in `UserDefaults`, as a too-common login flow does:

```swift
import Foundation

enum InsecureAuth {
    static func login() -> String {
        // Pretend this came back from the Vapor /login endpoint.
        let token = "eyJ-FAKE-JWT-\(UUID().uuidString)"
        UserDefaults.standard.set(token, forKey: "authToken")   // <- the leak
        return token
    }
}
```

Run the app, trigger the login, and confirm the app behaves normally. So far it looks fine. The bug is invisible until you look at the disk.

### Step 2 — Prove the leak: read the token off disk

This is the part that makes it real. The attacker model: someone with access to the device backup (an unencrypted iTunes/Finder backup, a stolen-and-jailbroken device, a malicious backup-reader app). You play that attacker against your own Simulator.

```bash
# Find the app's data container.
DATA=$(xcrun simctl get_app_container booted com.yourname.YourApp data)

# UserDefaults is an UNENCRYPTED plist. Find it and print it.
PLIST="$DATA/Library/Preferences/com.yourname.YourApp.plist"
plutil -p "$PLIST"
# You will see your token in PLAINTEXT, e.g.:
#   "authToken" => "eyJ-FAKE-JWT-…"
```

Replace `com.yourname.YourApp` with your actual bundle id. Copy the printed token into `THREAT-MODEL.md` as evidence: *"Here is my auth token, extracted from the preferences plist with one command, no encryption, no jailbreak."* That plist is in the device backup; an attacker with the backup has your token.

### Step 3 — Lock it down (the RIGHT way)

Move the token to the Keychain, using the `KeychainStore` from exercise 2 with the correct accessibility class:

```swift
import Foundation

enum SecureAuth {
    static let keychain = KeychainStore(service: "com.crunch.notes.auth")
    // default accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    static func login() throws -> String {
        let token = "eyJ-FAKE-JWT-\(UUID().uuidString)"
        try keychain.setString(token, account: "primary")   // hardware-encrypted, device-bound
        return token
    }

    static func currentToken() -> String? {
        try? keychain.getString(account: "primary")
    }

    static func logout() {
        try? keychain.delete(account: "primary")             // ThisDeviceOnly: gone for good
    }
}
```

Run the login through `SecureAuth` instead. Then remove the `UserDefaults` write entirely (and clean up any previously-leaked value: `UserDefaults.standard.removeObject(forKey: "authToken")` once, on upgrade).

### Step 4 — Prove the fix

Run the same extraction from step 2:

```bash
plutil -p "$DATA/Library/Preferences/com.yourname.YourApp.plist"
# The "authToken" key is GONE. The plist no longer contains the secret.

# Where IS it now? The Keychain — which simctl/plutil cannot trivially dump,
# because it's a separate, encrypted, access-controlled store, not a file in
# the app sandbox. That's the entire point.
```

Confirm the token is no longer in the plist, and note that the Keychain is *not* sitting as a readable file in the sandbox container — it's the system keychain database, encrypted and access-controlled. The same one-command extraction that worked in step 2 now returns nothing.

### Step 5 (optional, for the stretch) — accessibility class consequences

Write a short experiment in `THREAT-MODEL.md` comparing accessibility classes for *this* token:

- Why `…AfterFirstUnlock` (not `…WhenUnlocked`): a background refresh task or push handler may run while the screen is locked; `WhenUnlocked` would make those reads fail.
- Why `…ThisDeviceOnly`: the token must not be restored to a *new* device from a backup — a restored user should re-authenticate, and a thief with a backup must not transplant the session. `ThisDeviceOnly` keeps the item out of restorable backups.
- What would break if you instead used the (deprecated) `…Always`: the token would be readable *before* first unlock, so an attacker with brief physical access to a powered-off-then-on device could read it before the user ever unlocks. That's why Apple deprecated it.

## Acceptance criteria

- [ ] `InsecureAuth` stores the token in `UserDefaults`; you extracted it in **plaintext** from the preferences plist with `plutil -p` and pasted the evidence into `THREAT-MODEL.md`.
- [ ] `SecureAuth` stores the token in the Keychain via your `KeychainStore` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- [ ] After the fix, the same `plutil -p` extraction shows the token is **gone** from the plist.
- [ ] The old `UserDefaults` value is cleaned up on upgrade (`removeObject`).
- [ ] `THREAT-MODEL.md` names the attacker each step defends against: who can read the `UserDefaults` plist (anyone with the backup), and what the Keychain + accessibility class stops (backup extraction, restore-to-new-device, pre-unlock read).
- [ ] (Stretch) The accessibility-class comparison for `…AfterFirstUnlock` vs `…WhenUnlocked` vs `…ThisDeviceOnly` vs deprecated `…Always`.
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "I moved the token to the Keychain." A great submission says:

> The token was stored in `UserDefaults`. I extracted it in plaintext with a single `plutil -p` against the preferences plist in the app's backup container — no jailbreak, no encryption to defeat. That plist is in every unencrypted iTunes/Finder backup, so any attacker with the user's backup (a stolen laptop, a shared computer, a malicious sync) has the session token. I moved it to the Keychain with `…AfterFirstUnlockThisDeviceOnly`: hardware-encrypted, readable by background refresh after first unlock, and — critically — `ThisDeviceOnly`, so it is excluded from restorable backups and never transplants to a new device. The same extraction now returns nothing, because the Keychain is a separate encrypted store, not a sandbox file. I chose `AfterFirstUnlock` over `WhenUnlocked` so background token refresh works while the screen is locked, and avoided the deprecated `…Always` because it's readable before first unlock.

Demonstrated, not asserted; specific about the attacker; specific about why *that* accessibility class. That's the senior-engineer answer.

## Where this reappears

The "where does this secret physically live, and who can read it" instinct is exactly what Phase III's security week (Week 17 — CryptoKit, the Secure Enclave, certificate pinning) builds on, and what App Review checks. The token you locked down here is the same one your `NotesClient` attaches to every request — and the same one the Secure Enclave will eventually *sign* requests with. Secret storage done right is the floor every later security feature stands on.
