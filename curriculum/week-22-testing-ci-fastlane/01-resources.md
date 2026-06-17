# Week 22 — Resources

Every primary resource on this page is **free**. Apple's developer documentation is free without a paid membership. The WWDC sessions are free. fastlane and GitHub Actions are open/free for public repos and have generous free macOS-runner minutes. A handful of paid resources are listed at the bottom and clearly marked.

## Required reading (work it into your week)

- **Swift Testing — documentation.** The `@Test`/`#expect` framework that ships with Xcode 16; read this before writing a test this week:
  <https://developer.apple.com/documentation/testing>
- **"Migrating a test from XCTest" / Swift Testing overview:**
  <https://developer.apple.com/documentation/testing/migratingfromxctest>
- **XCUITest — "User interface tests":**
  <https://developer.apple.com/documentation/xctest/user-interface-tests>
- **`xcodebuild` man page / "Building from the command line with Xcode":**
  <https://developer.apple.com/library/archive/technotes/tn2339/_index.html>
- **fastlane docs — getting started for iOS:**
  <https://docs.fastlane.tools/getting-started/ios/setup/>
- **fastlane `match` — codesigning for teams/CI:**
  <https://docs.fastlane.tools/actions/match/>
- **GitHub Actions — "Building and testing Swift" / macOS runners:**
  <https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-swift>

## The tools you'll touch (reference, skim don't memorize)

- **`#expect` and `#require`:** <https://developer.apple.com/documentation/testing/expectations>
- **Parameterized tests (`arguments:`):** <https://developer.apple.com/documentation/testing/parameterizedtesting>
- **Test traits / tags (`@Suite`, `.tags`):** <https://developer.apple.com/documentation/testing/traits>
- **`XCUIApplication` / `XCUIElement`:** <https://developer.apple.com/documentation/xctest/xcuiapplication>
- **`swift-snapshot-testing` (pointfreeco):** <https://github.com/pointfreeco/swift-snapshot-testing>
- **`xcbeautify`:** <https://github.com/cpisciotta/xcbeautify>
- **fastlane `gym`:** <https://docs.fastlane.tools/actions/gym/>
- **fastlane `pilot` / `upload_to_testflight`:** <https://docs.fastlane.tools/actions/upload_to_testflight/>
- **App Store Connect API key in fastlane (`app_store_connect_api_key`):** <https://docs.fastlane.tools/app-store-connect-api/>
- **`setup-xcode` action (select the Xcode version on a runner):** <https://github.com/maxim-lobanov/setup-xcode>

## WWDC sessions (free, watch in this order)

- **"Meet Swift Testing"** (WWDC24) — the new framework, `@Test`/`#expect`/`#require`:
  <https://developer.apple.com/videos/play/wwdc2024/10179/>
- **"Go further with Swift Testing"** (WWDC24) — parameterized tests, tags, traits, and organising a suite:
  <https://developer.apple.com/videos/play/wwdc2024/10195/>
- **"Migrate your app's tests to Swift Testing" / what's new in testing** (WWDC24) — coexisting with XCTest:
  <https://developer.apple.com/videos/play/wwdc2024/10195/>
- **"Get the most out of Xcode Cloud"** (WWDC23) — even if you use GitHub Actions, the CI concepts (signing, secrets, gating) transfer:
  <https://developer.apple.com/videos/play/wwdc2023/10267/>
- **"Author fast and reliable tests for Xcode Cloud"** (WWDC23) — test reliability and flakiness, applicable to any CI:
  <https://developer.apple.com/videos/play/wwdc2023/10266/>
- **"Testing in Xcode"** (WWDC19) — still the clearest XCUITest + test-plan walkthrough:
  <https://developer.apple.com/videos/play/wwdc2019/413/>

## CI code signing (the part everyone gets stuck on)

Signing on a machine that isn't yours is the hard problem of iOS CI. Read these until `match` is reflex.

- **fastlane `match` docs** (above) and the **codesigning guide:** <https://docs.fastlane.tools/codesigning/getting-started/>
- **"Using App Store Connect API keys"** — the `.p8` + key id + issuer id for non-interactive auth:
  <https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api>
- **GitHub Actions encrypted secrets:** <https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions>
- **A temporary keychain on CI** (the `create_keychain` / `match` `keychain_name` pattern): in the fastlane match docs.

## Community writing (current, opinionated, correct)

- **fastlane GitHub (issues + examples).** Real Fastfiles in the wild are the best teacher:
  <https://github.com/fastlane/fastlane>
- **Point-Free — `swift-snapshot-testing` README + discussions.** The canonical snapshot-testing reference:
  <https://github.com/pointfreeco/swift-snapshot-testing>
- **Antoine van der Lee (SwiftLee) — Swift Testing, XCUITest, and CI articles.** Production-grade and current:
  <https://www.avanderlee.com/>
- **Pol Piella — CI and fastlane on GitHub Actions notes:**
  <https://www.polpiella.dev/>
- **Rudrank Riyam / "Testing Swift" writing and the Swift Testing community threads on the Swift Forums:**
  <https://forums.swift.org/c/related-projects/swift-testing/>

## Open-source projects to read this week

- **Any well-run open-source iOS app with `.github/workflows/*.yml` + a `fastlane/Fastfile`.** Read how they structure the test workflow and the ship lane. `pointfreeco/isowords` is a strong, real example with tests, snapshots, and CI:
  <https://github.com/pointfreeco/isowords>
- **The fastlane `examples` repo and the `match` example** — minimal, copyable Fastfiles.

## Tools you'll use this week

- **Xcode 16+** — Swift Testing target template, XCUITest target, test plans, and the result bundle viewer.
- **fastlane** via **Bundler** — a `Gemfile` pins the version so CI and your laptop run the same fastlane: `bundle install`, then `bundle exec fastlane <lane>`.
- **`xcbeautify`** — `brew install xcbeautify` (or via Mint). Pipe `xcodebuild ... | xcbeautify`.
- **`gh` CLI** — create the repo, set secrets (`gh secret set MATCH_PASSWORD`), and watch runs (`gh run watch`).
- **GitHub Actions** — free macOS-runner minutes for public repos (private repos get a monthly allowance). The `macos-14`/`macos-15` images ship recent Xcodes.
- **A private "certificates" Git repo** for `match` (or an S3/GCS bucket) — separate from your app repo, holding the encrypted certs and profiles.

## Free books (chapter-level, not whole books)

- **Apple's "Swift Testing" and "XCTest" documentation groups** in the Developer app and on the docs site are effectively a free book; read the Swift Testing "Essentials" group and the XCUITest section end to end.
- **The fastlane docs site** is a free, complete book on iOS automation; read getting-started + match + gym + pilot.

## Paid books (optional, clearly marked)

- **"iOS Test-Driven Development" / "Advanced iOS App Architecture" — Kodeco** (paid) — testing discipline and architecture-for-testability.
- **"Continuous Delivery for Mobile with fastlane" — Doron Katz** (paid) — older but the most complete single treatment of fastlane + CI signing.

---

*If a link 404s, please open an issue so we can replace it.*
