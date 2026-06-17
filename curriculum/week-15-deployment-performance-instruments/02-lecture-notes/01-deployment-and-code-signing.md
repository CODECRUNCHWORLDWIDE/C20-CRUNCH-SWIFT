# Lecture 1 — Deployment and code signing, demystified

> "Code signing is not hard because the concept is hard. It is hard because it's a four-piece PKI puzzle that Xcode assembles for you silently, so the first time you have to assemble it by hand you've never seen the pieces."

This is the lecture where the app leaves the Simulator and runs on a device you can hold. The blocker is **code signing** — Apple's system for proving that a given app, built by a given developer, is allowed to run on a given device. Almost every iOS developer's first device deployment ends in a red signing error they don't understand, not because they did something wrong, but because nobody ever showed them the four pieces and how they fit. We are going to show you the four pieces, fit them together, deploy, and then decode the errors so the next time one appears you read it instead of googling it.

The framing for the whole lecture: **code signing answers three "who/what/where" questions** — *who* built this (a certificate proving you're a registered developer), *what* is it (an App ID identifying the app), and *where* may it run (a provisioning profile binding the who + what + a list of device UDIDs + entitlements into one permission slip). Hold those three and the errors stop being mysterious.

---

## 1. Why code signing exists at all

iOS runs only signed code. This is a security property, not bureaucracy: the device will not launch an executable unless it carries a valid cryptographic signature from a trusted source, and the OS verifies that signature at launch every time. This is what stops a random downloaded binary from running on your phone, what lets Apple revoke a malicious developer's apps fleet-wide, and what ties an app's entitlements (push, iCloud, the Keychain) to a verified identity so a malicious app can't claim capabilities it wasn't granted.

Contrast this with the platforms you may have come from. On a Linux server you `chmod +x` a binary and run it; on a Mac you can run unsigned command-line tools all day. iOS made the opposite bet: *nothing* runs unsigned, ever, on any device, including yours during development. That bet is why iOS malware is comparatively rare and why the App Store can be a meaningful trust boundary — and it's why you, the developer, have to participate in the signing system even just to run your own code on your own phone. The friction you're about to learn is the developer-facing cost of a guarantee that benefits a billion users. Worth keeping in mind when the red errors appear: the system isn't being obstinate, it's being a security system, and you're inside it now.

The cost of that security is the four-piece puzzle you now have to assemble. The good news: for *development on a device you own*, Xcode's "Automatically manage signing" assembles it for you, and you mostly only need to understand the pieces when it breaks (and it breaks — on a new device, a new entitlement, a team change, or CI). So we learn the pieces, then let Xcode drive, then know what to do when it stalls.

### Why bother going on-device at all

Beyond honest performance numbers (the subject of lecture 2), a whole class of features simply *does not exist* in the Simulator, and you can only build and test them on real hardware:

- **The camera and real sensors** — the Simulator has no camera, no real accelerometer/gyroscope, no barometer, no LiDAR.
- **Real push notifications to a physical Lock Screen**, and Live Activities rendering on an actual Lock Screen / Dynamic Island (Phase IV).
- **Bluetooth (BLE) and NFC** — no real radios in the Simulator.
- **Biometrics against real hardware** — Face ID / Touch ID via the Secure Enclave (Week 17) behaves differently than the Simulator's simulated biometrics.
- **True thermal and battery behavior** — the device throttles and drains; the Simulator doesn't.

So deployment isn't only a prerequisite for profiling; it's the gate to half of what makes an iOS app an iOS app. The syllabus puts the membership requirement here, at Week 15, precisely because this is where the course stops being "things a Mac can fake" and starts being "things only the device can do." Getting signing right is the toll for that whole second half of the platform.

---

## 2. The four pieces

### Piece 1 — The signing certificate (who you are)

A **signing certificate** is an X.509 certificate issued by Apple to you, paired with a **private key** that lives in your Mac's login Keychain. Together they are your *signing identity*. When you build, Xcode uses the private key to sign the app; the device (and Apple) verify the signature against the certificate. The certificate proves "this build was signed by a registered Apple developer holding this key."

Two kinds matter:

- **Apple Development** — for running on devices during development. This is the one you'll use this week.
- **Apple Distribution** — for App Store / TestFlight / enterprise distribution. Phase IV.

The private key is the crown jewel: if you lose it (new Mac, wiped Keychain), you can't sign with that certificate and must create a new one. This is why teams export the identity (a `.p12` file: certificate + private key) and why CI needs it installed in its Keychain. The certificate without the private key is useless; the private key is what does the signing.

### Piece 2 — The App ID (what the app is)

An **App ID** identifies your app to Apple's systems. It's the bundle identifier (`com.crunch.notes`) registered in your developer account, plus the set of **capabilities** the app is allowed to use (Push, iCloud/CloudKit, App Groups, Keychain Sharing, Sign in with Apple, …). The App ID is *where capabilities are granted* — when you checked "iCloud" in Week 14, Xcode enabled the CloudKit capability on your App ID.

App IDs come in two shapes: **explicit** (`com.crunch.notes`, matches exactly one app, required for most real capabilities) and **wildcard** (`com.crunch.*`, matches many, but can't carry capabilities like push or App Groups). Real apps use explicit App IDs.

### Piece 3 — Entitlements (what the app may do)

**Entitlements** are the key-value permissions baked into the signed app — `aps-environment` for push, `com.apple.developer.icloud-services` for CloudKit, `com.apple.security.application-groups` for App Groups, `keychain-access-groups` for Keychain sharing. They live in your target's `.entitlements` file, and — this is the crucial linkage — **the entitlements in your build must be a subset of the capabilities enabled on your App ID, and the provisioning profile must authorize them.** Claim an entitlement your App ID doesn't grant and the build fails to sign. This is why "enable the capability in Xcode" (which updates the App ID and the entitlements file together) is the right move, not hand-editing the entitlements plist.

### Piece 4 — The provisioning profile (the permission slip)

A **provisioning profile** is the document that ties everything together into one permission slip the device checks at launch. It bundles:

- the **App ID** (which app),
- the allowed **signing certificates** (which developers),
- the **device UDIDs** allowed to run it (for development/ad-hoc profiles — App Store profiles have no device list),
- the **entitlements** authorized.

At install/launch, the device checks: is this app's signature from a certificate in the profile? Is *this device's* UDID in the profile? Do the app's entitlements match the profile's? All yes → runs. Any no → the launch is refused (or the install fails). The profile is embedded in the app bundle as `embedded.mobileprovision`.

The mental model in one line: **certificate = who, App ID = what, device list = where, entitlements = may-do — and the provisioning profile is the stapled-together permission slip carrying all four.**

To anchor the four pieces with a real-world analogy that survives interviews:

- The **certificate** is your *passport* — issued by an authority (Apple), proving who you are, with a private key only you hold (the passport you can't forge).
- The **App ID** is the *name of the event* you're attending — a specific, registered identity, with a list of what that event permits.
- The **entitlements** are the *wristbands* — the specific permissions (backstage, bar, VIP) you were granted for this event.
- The **provisioning profile** is the *ticket* — it staples your passport, the event name, the guest list (device UDIDs), and your wristbands into one document the door (the device) checks on entry.

Show up with a valid passport but no ticket, or a ticket for a different event, or a ticket whose guest list doesn't include you, and the door turns you away — which is exactly the shape of every signing error. The analogy is silly but it sticks, and "the profile is the ticket stapling the passport, the event, the guest list, and the wristbands" is a genuinely useful sentence to have ready.

And the lifecycle maps too: passports expire (certificates), the guest list can be updated (register a device), and a lost passport is replaced but the old one is voided (revoke and re-issue a cert). When you hit the lifecycle realities in §7.5, this is the same picture playing forward in time.

---

## 3. How the four pieces combine at build and launch

Here's the whole flow, drawn once:

```text
BUILD TIME (on your Mac):
  Xcode compiles the app  ──┐
  Your private key  ────────┤── codesign ──> signed .app
  Provisioning profile  ────┘                 (embeds embedded.mobileprovision
                                                + the entitlements)

INSTALL/LAUNCH TIME (on the device):
  Device receives the signed .app
  ├─ Is the signature from a cert listed in the embedded profile?   ── must be YES
  ├─ Is THIS device's UDID in the profile's device list?            ── must be YES (dev profile)
  ├─ Do the app's entitlements match the profile's authorizations?  ── must be YES
  └─ Is the cert still valid / not revoked?                          ── must be YES
  All YES -> app launches. Any NO -> "could not be installed" / launch refused.
```

Every signing error you'll ever see is one of those checks failing. "No profiles for 'com.crunch.notes' were found" → no profile binds that App ID to your cert+device. "Provisioning profile doesn't include the currently selected device" → your device's UDID isn't in the profile. "Provisioning profile doesn't support the App Groups capability" → you claimed an entitlement the profile doesn't authorize. Once you can name the four pieces, the error tells you which one is wrong.

---

## 4. Automatic signing — what Xcode does for you

In Xcode, target ▸ **Signing & Capabilities** ▸ **Automatically manage signing**, with your **Team** selected. With that checked, on every build Xcode:

1. Ensures you have an **Apple Development** certificate (creates one and its key in your Keychain if not).
2. Ensures the **App ID** exists for your bundle id, with the capabilities you've enabled.
3. Registers the **connected device's UDID** to your account.
4. Creates/updates a **development provisioning profile** binding all of the above.
5. Signs the build with your cert and the profile.

For development on devices you own, this is genuinely all you need, and you should use it. The reason to understand the pieces anyway is that automatic signing fails informatively only if you know what it's trying to do:

- "**Failed to register bundle identifier**" — the App ID is taken (someone else's account, or a typo). Change the bundle id.
- "**No signing certificate found**" — your account has no Development cert and Xcode couldn't create one (often a free account hitting its limit, or a Keychain issue). Let Xcode create one, or do it in the developer portal.
- "**Device not registered**" — plug the device in, unlock it, trust the Mac; Xcode registers it.

### Manual signing — when automatic isn't enough

You move to manual signing (uncheck the box, pick a specific profile) when:

- **CI** needs a specific, reproducible profile and a cert installed non-interactively (fastlane `match` manages this — Phase IV).
- A **shared team** wants everyone signing with the same distribution identity rather than each developer's own.
- You need a **specific entitlement configuration** automatic signing won't produce.

Manual signing is the same four pieces; you just select them by hand instead of letting Xcode generate them. Know it exists; use automatic for this week.

---

## 5. Deploying to your device, step by step

The actual deployment, assuming a paid account and automatic signing:

1. **Connect the device** (cable, or set up wireless debugging once over cable). Unlock it. On the device, tap **Trust This Computer** if prompted.
2. In Xcode, select your **Team** under Signing & Capabilities, with Automatically manage signing on.
3. In the scheme/run-destination picker at the top, **select your device** (not a Simulator).
4. **Build and run** (⌘R). Xcode signs, installs, and launches on the device.
5. **First-run trust:** for a *free* account you'd hit "Untrusted Developer" and have to trust the certificate in Settings ▸ General ▸ VPN & Device Management. For a *paid* account deploying via Xcode this is usually handled, but if you see it: Settings ▸ General ▸ VPN & Device Management ▸ your developer profile ▸ Trust.

That's it — your code is now running on real silicon. Confirm it's a real device by checking the device name in Xcode's debug bar and, importantly, **switch your scheme to Release** (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Build Configuration ▸ Release) before you profile, because Debug builds are unoptimized and lie about performance — which is the whole subject of lecture 2.

### The device-side trust flow, the first time

The very first time a new developer identity's build lands on a device, the OS doesn't yet trust that developer. With a *paid* account deploying through Xcode, this is usually negotiated for you, but you should recognize the flow because you'll hit it on a fresh device or a teammate's phone:

1. The build installs but won't launch; tapping the icon shows **"Untrusted Developer."**
2. On the device: **Settings ▸ General ▸ VPN & Device Management** (older iOS: *Profiles & Device Management*).
3. Under **Developer App**, tap your developer identity, then **Trust**.
4. The app now launches; the trust persists for that identity on that device.

This is the device's *user-consent* layer on top of the cryptographic signing: even a validly-signed development build asks the device owner to explicitly trust the developer before running, so a build pushed to a device the owner didn't intend can't silently execute. It's a small ceremony, but it's the user's veto in the trust chain — worth understanding rather than blindly tapping through.

### Why on-device, and why Release

The Simulator runs your ARM (or translated) code on the Mac's CPU and memory subsystem. It is *useful* for UI iteration and *useless* for performance truth: a Mac's CPU is multiples faster than an iPhone's, with far more memory bandwidth and no thermal throttling on the same time scale. A scroll that's smooth in the Simulator can hitch on the device; a launch that's instant on the Mac can be sluggish on a cold device. And a **Debug** build disables compiler optimizations and adds runtime checks, so even on the device a Debug build mismeasures. **Performance numbers come from a Release build on a physical device. Full stop.** Every measurement in lecture 2 and the mini-project assumes that setup.

### Wireless debugging — set it up once

After the first cable connection, you can run and profile over Wi-Fi, which is genuinely better for performance work because the cable can subtly affect thermal and power behavior. In Xcode: **Window ▸ Devices and Simulators**, select your connected device, check **Connect via network**. Unplug; the device stays available in the run-destination picker (look for the globe icon). Both the Mac and the device must be on the same network. This matters for Instruments captures during a long profiling session where you don't want a cable tethering the phone to the desk.

---

## 5.4 The build pipeline behind ⌘R, on the command line

Xcode's "build and run" is a friendly front end over `xcodebuild`, and seeing the command-line shape demystifies what's happening and prepares you for CI (Phase IV). The same build Xcode runs is roughly:

```bash
# Build a signed app for a connected device, automatic signing.
xcodebuild \
  -scheme Notes \
  -configuration Release \
  -destination 'platform=iOS,name=My iPhone' \
  -allowProvisioningUpdates \
  build

# List the destinations Xcode can see (devices + simulators):
xcodebuild -scheme Notes -showdestinations

# Inspect the toolchain:
xcodebuild -version          # Xcode + build version
xcrun --sdk iphoneos --show-sdk-version
```

The `-allowProvisioningUpdates` flag is the command-line equivalent of "Automatically manage signing" — it lets `xcodebuild` register the device, create the cert, and generate the profile non-interactively. `-configuration Release` is the flag that matters for this week: it builds optimized, which is the only build you profile.

You will not run `xcodebuild` by hand much this week — ⌘R is fine for iterating on a device — but knowing the build is *just a command* with a scheme, a configuration, and a destination is the mental model that makes CI legible later. The GitHub Actions pipeline in Phase IV is this command, plus `xcbeautify` to read the output, plus fastlane to handle the distribution identity. Same build, automated.

## 5.5 What `codesign` actually does, and what's in the bundle

It helps to see the mechanics under "build and run," because the abstract four pieces become concrete files. When you build, Xcode runs the `codesign` tool, which:

1. Computes a cryptographic hash of every file in the `.app` bundle (the executable, the resources, the embedded frameworks) and writes them into a **`_CodeSignature/CodeResources`** manifest.
2. Signs that manifest with your **private key**, embedding the signature and your **certificate**.
3. Copies the **provisioning profile** into the bundle as **`embedded.mobileprovision`**.
4. Embeds the **entitlements** into the executable's signature.

So a signed `.app` physically contains: your compiled binary, the resources, `_CodeSignature/CodeResources` (the signed hash manifest), `embedded.mobileprovision` (the permission slip), and the entitlements baked into the signature. You can inspect a signed build:

```bash
# What identity signed it, and is the signature valid?
codesign -dvvv /path/to/YourApp.app

# What entitlements did it claim?
codesign -d --entitlements :- /path/to/YourApp.app

# What's in the embedded provisioning profile (it's a signed plist)?
security cms -D -i /path/to/YourApp.app/embedded.mobileprovision
```

This is worth doing once, because it makes "the entitlements must match the profile" tangible: you can literally print both and compare. When a capability mysteriously doesn't work on-device, `codesign -d --entitlements` on the installed build tells you whether the entitlement actually made it into the signature — often it didn't, because the App ID didn't grant it, and now you've found the broken piece without guessing.

The device-side check at launch is the mirror of this: the OS re-hashes the bundle, verifies the hash manifest against the embedded certificate, checks the certificate against the embedded profile, checks this device's UDID against the profile's device list, and checks the entitlements against the profile's authorizations. Tamper with any file in the bundle after signing and the hash mismatch fails the launch — that's the integrity guarantee signing buys.

---

## 5.6 Where the pieces live — the developer portal and account anatomy

The four pieces aren't abstractions; each has a home in your Apple Developer account, and knowing where helps when automatic signing can't do something and you have to look. The **Certificates, Identifiers & Profiles** section of the developer portal (developer.apple.com/account) holds:

- **Certificates** — your Development and Distribution certs, with expiry dates and the option to revoke and re-issue.
- **Identifiers** — your App IDs, each showing its enabled capabilities. This is where you'd see that the CloudKit capability is on `com.crunch.notes` from Week 14.
- **Devices** — the registered device UDIDs, with the per-year limit and the once-a-year removal window.
- **Profiles** — the provisioning profiles, each listing its App ID, certificates, devices, and entitlements.

**App Store Connect** (appstoreconnect.apple.com) is the *other* portal, and people conflate the two. The developer portal is about *signing* (certs, IDs, profiles); App Store Connect is about *distribution* (your app's listing, TestFlight builds, App Review, sales, MetricKit aggregation in the Organizer). This week you live almost entirely in the developer portal's signing world (and mostly let Xcode drive it). App Store Connect becomes central in Phase IV when you ship to TestFlight and submit for review.

The relationship: a **Distribution** certificate + an **App Store** provisioning profile (no device list — App Store builds run on *any* device once Apple counter-signs them) lets you *upload* a build to App Store Connect, where TestFlight and App Review take over. That's the other half of the signing story we're naming-but-not-driving this week. The symmetry is clean: **Development** cert + profile + device list = runs on *your registered devices* (this week); **Distribution** cert + App Store profile = uploadable to Apple for distribution to *anyone* (Phase IV).

## 6. Entitlements you've already met, in signing terms

You've enabled several capabilities across the course without dwelling on the signing consequence. In light of this lecture:

- **Week 14's iCloud/CloudKit** added the `com.apple.developer.icloud-services` and container entitlements to your App ID and entitlements file. That's why CloudKit needed the paid account — entitlements require a registered, signed App ID, which a free account can't carry for iCloud.
- **Week 14's App Groups** added `com.apple.security.application-groups`. The shared container only works because the entitlement is in both targets' profiles.
- **Week 14's Keychain access group** added `keychain-access-groups`. Sharing a Keychain item across targets is an entitlement-gated capability.
- **Week 18's push** will add `aps-environment`. Push literally cannot work without the entitlement, the App ID capability, and a profile that authorizes it — push-not-arriving is very often a signing problem, not a server problem.

Seeing these as *entitlements that must be granted on the App ID and authorized by the profile* is the unifying view. When a capability "doesn't work," check the chain: capability enabled on the App ID? entitlement in the build? profile authorizes it? cert valid? That chain is this lecture.

A practical rule that saves hours: **always toggle capabilities through Xcode's Signing & Capabilities tab, never by hand-editing the `.entitlements` plist.** The tab does three things atomically — adds the entitlement to your `.entitlements` file, enables the capability on your App ID in the portal, and regenerates the provisioning profile to authorize it. Hand-edit the plist and you get the entitlement in the build but *not* the App ID grant or the profile authorization, so the build fails to sign with the cryptic "doesn't support this capability." The tab keeps all three in sync; the plist edit breaks two of them. When in doubt, remove and re-add the capability in the tab to force a clean regeneration of the whole chain.

---

## 7. The common errors, decoded

A field guide to the signing errors you *will* see, mapped to the piece at fault:

| Error (paraphrased) | The piece at fault | The fix |
|---|---|---|
| "No profiles for 'X' were found" | No provisioning profile binds this App ID + your cert + device | Let automatic signing create one; ensure the device is connected and the App ID is registered |
| "Doesn't include the currently selected device" | Device UDID not in the profile's device list | Register the device (automatic signing does this on connect); regenerate the profile |
| "No signing certificate 'Apple Development' found" | No development cert / private key in your Keychain | Let Xcode create one, or import your `.p12` |
| "Doesn't support the [App Groups/iCloud/Push] capability" | Entitlement claimed but App ID/profile don't grant it | Enable the capability in Signing & Capabilities (updates App ID + entitlements together) |
| "Failed to register bundle identifier" | App ID taken or invalid | Change the bundle id to a unique reverse-DNS string |
| "A valid provisioning profile for this executable was not found" | Profile/cert/device chain broken at install | Clean, let automatic re-sign; check the device is trusted |
| "The certificate used to sign ... has either expired or been revoked" | Cert lifecycle | Create a fresh certificate; profiles re-issue against it |

The discipline: **read the error as "which of the four pieces is wrong," not as a wall of red.** "Doesn't support the App Groups capability" is not cryptic once you know an entitlement must be authorized by the profile — it's telling you exactly which piece to fix.

### A worked troubleshooting flow

When a device deploy fails, work the chain top-down — it almost always resolves in under a minute once you stop staring and start checking pieces:

1. **Is the device connected, unlocked, and trusted?** A locked device or an untrusted Mac fails before signing even starts. Plug in, unlock, tap *Trust*.
2. **Is a Team selected** under Signing & Capabilities, with Automatically manage signing on? No team → no identity → nothing signs.
3. **Does the bundle id resolve to a registerable App ID?** A duplicate or invalid bundle id fails registration. Make it a unique reverse-DNS string under your team.
4. **Did the device register?** Xcode registers on connect, but a flaky connection can skip it — Window ▸ Devices and Simulators should show your device with no warning triangle.
5. **Do the capabilities match?** If you added a capability (iCloud, App Groups) and the build won't sign, the App ID may not have it yet — toggle the capability off and on in Signing & Capabilities to force Xcode to update the App ID and regenerate the profile.
6. **Clean and rebuild.** A stale `DerivedData` or a cached bad profile causes ghost failures; Product ▸ Clean Build Folder (⇧⌘K) clears them.

If all six pass and it still fails, the developer portal (§5.6) is where you look directly — check the cert isn't expired, the device is listed, the profile includes both. But nine times out of ten, the chain above resolves it, because nine times out of ten it's an unlocked-device / no-team / capability-mismatch, not a deep PKI problem.

---

## 7.5 Lifecycle and team realities

The four pieces have lifecycles, and the lifecycle is where teams get bitten:

- **Certificates expire** (Development certs after ~1 year). When yours expires, builds stop signing until you (or Xcode, automatically) issue a new one. Profiles reference certificates, so a new cert means profiles re-issue against it — automatic signing handles this; manual signing means you regenerate profiles by hand.
- **Profiles expire** (typically 1 year for development). An expired profile fails the launch check. Again, automatic signing regenerates; manual doesn't.
- **The private key is irreplaceable, the certificate is not.** Lose the Mac (and the Keychain) and you lose the private key; the certificate is then dead weight (it can't sign without its key). You create a *new* certificate. This is why teams export the identity as a `.p12` (cert + private key, password-protected) and store it securely — so a new machine or CI box can sign as the same identity. **Never commit a `.p12` or its password to Git.** This is the most common credential leak in iOS repos.
- **Multiple developers, one account.** Each developer can have their *own* Development certificate (automatic signing makes one per machine), all listed in the development profile, so any of them can build. For *distribution*, teams usually share *one* Distribution identity managed centrally (fastlane `match` stores it encrypted in a private repo — Phase IV) so the App Store build is signed consistently regardless of who runs the build.
- **Device limits.** A development account can register a finite number of devices (100 per device class per membership year), and you can only *remove* registrations once a year. This rarely bites a solo developer but matters for a team testing across many devices — don't register every phone in the office casually.

The takeaway for this week: as a solo developer on your own device with automatic signing, the lifecycle is invisible — Xcode renews certs and profiles for you. You learn it now so that the day you join a team with a shared distribution identity, a CI pipeline, and an expiring profile, the words "the distribution cert expired, re-issue it and let the profiles re-sign" mean something concrete.

---

## 7.6 What each piece actually protects against — the threat model

It's worth closing the signing material with *why* — because once you see the threat each piece defends, the system stops feeling like arbitrary friction and starts feeling like the security property it is. This is the same "name the threat" discipline you applied to the Keychain in Week 14, now applied to code distribution.

- **The certificate (who) defends against impersonation.** Without a signing identity tied to a verified Apple developer account, anyone could publish an app claiming to be you, or push a malicious update to your users. The cert chain back to Apple's root means a build's origin is provable, and Apple can *revoke* a compromised or malicious developer's certificate, instantly invalidating every app signed with it — the fleet-wide kill switch.
- **The App ID + entitlements (what / may-do) defend against privilege escalation.** Entitlements gate powerful capabilities — push, iCloud access to a user's data, Keychain sharing, background execution. Binding them to a registered App ID means an app can't simply *declare* "I can read the shared Keychain" or "I can receive push" and have the OS believe it; the capability had to be granted on the App ID and authorized by the profile. An app gets exactly the powers it was provisioned for, no more.
- **The device list (where) defends against uncontrolled distribution.** A development/ad-hoc profile lists specific device UDIDs, so a development build *cannot* be installed on a random phone — it runs only on devices you registered. This is what stops a leaked development build from spreading. (App Store profiles drop the device list precisely because Apple's review + counter-signature is the control there instead.)
- **The signature over the bundle (integrity) defends against tampering.** Because `codesign` hashes every file and signs the manifest, the OS detects any post-signing modification — you can't patch a competitor's app, re-inject code, and re-run it without breaking the signature. The launch-time hash check is what makes the bundle tamper-evident.

So the four pieces together answer: *this build came from a verified developer (cert), is allowed exactly these powers (entitlements), may run only here (device list), and hasn't been altered since signing (the hashed signature).* That's not bureaucracy — it's the trust model that lets a billion devices run third-party code safely. You're learning the developer side of a system whose user-facing promise is "apps can't lie about who made them or what they're allowed to do."

## 8. Recap — the four pieces and the on-device habit

Code signing is four pieces and one flow:

- **Certificate** (+ private key) — *who* built it; lives in your Keychain; signs the build.
- **App ID** — *what* the app is; registered in your account; where capabilities are granted.
- **Entitlements** — *what it may do*; baked into the build; must be a subset of the App ID's capabilities.
- **Provisioning profile** — the permission slip stapling App ID + cert + device UDIDs + entitlements, embedded in the bundle, checked by the device at launch.

For development on a device you own, **automatic signing assembles all four for you**; you understand them so that when one breaks, the red error tells you which piece, not nothing. You deployed to a real device, trusted the developer profile, and — critically — switched to a **Release build on the device**, because that's the only configuration that tells the performance truth.

A one-screen reference to keep next to you the first few deploys:

- **Build won't sign** → no team selected, or a capability claimed that the App ID doesn't grant. Check Signing & Capabilities; toggle the capability to regenerate.
- **"No profiles found"** → the App ID + cert + device chain has no profile. Connect the device, let automatic signing build one.
- **"Device not included"** → register the device (connect it; Window ▸ Devices and Simulators).
- **"Untrusted Developer" on the phone** → Settings ▸ General ▸ VPN & Device Management ▸ your identity ▸ Trust.
- **Capability silently not working at runtime** → `codesign -d --entitlements :- YourApp.app` to confirm the entitlement actually made it into the signature.
- **About to profile** → switch the scheme to **Release**, run on the **device**, never the Simulator.
- **Inspect anything** → the developer portal (certs/IDs/devices/profiles) is the source of truth when Xcode's automatic management isn't enough.

A small mindset note before we move on. Most engineers treat code signing as an enemy — a wall of red text between them and running their app. The reframe that makes the rest of your iOS career calmer is to treat it as a *system you can reason about*. Every signing failure is one of four pieces being wrong, and the error names the piece if you can read it. You will never again be the developer who deletes DerivedData, restarts Xcode, and prays; you'll be the one who reads "doesn't support the App Groups capability," recognizes it as an entitlement-not-authorized problem, toggles the capability to regenerate the profile, and moves on in thirty seconds. That calm is the deliverable of this lecture as much as the deployment itself.

And remember the throughline to Week 14: signing and the Keychain are the same kind of thinking — *name the threat each control defends, and pick the control deliberately.* Week 14 you chose `…AfterFirstUnlockThisDeviceOnly` because you could name what it protects. This week you understand the provisioning profile because you can name what *it* protects. Security on Apple's platforms is a sequence of these "name the threat, pick the control" decisions, and you're now fluent in two of them.

In lecture 2 we use that on-device Release build to do the actual work of the week: profile Notes v1 with Instruments, pick the right instrument for the hang vs the hitch vs the leak, read the flame graph, and fix a real performance bug with a number to prove it. The device is the truth-teller; Instruments is how you read what it's saying.

Take a breath after you get that first build running on your phone. It's a real milestone — your code, on real Apple silicon, that you signed and trusted yourself. Then switch to Release and go find out how it actually performs.
