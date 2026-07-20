# Week 23 — Resources

Every primary resource on this page is **free**. Apple's developer documentation, the WWDC sessions, and the open-source repos are all free without anything beyond the developer account you already hold. A few paid books are listed at the bottom and clearly marked. This week is integration and delivery, so the references skew toward architecture, sync, on-call discipline, and the submission pipeline rather than any single new API.

## The contract — read this first

- **The capstone specification.** Your source of truth for what you are building this week and shipping next week:
  [`SYLLABUS.md` § Capstone](../../SYLLABUS.md#capstone) — the spec, the deliverables, the chaos-drill menu, and the 100-point rubric.
- **The track README** for the capstone preview and the twelve capabilities the whole course earns:
  [`README.md`](../../README.md)

## Architecture and decision records

- **Architecture Decision Records (ADRs)** — the original Michael Nygard format you will use for the four capstone ADRs:
  <https://github.com/joelparkerhenderson/architecture-decision-record>
- **Apple — "Architecting your app for SwiftData / SwiftUI."** The data-layer-behind-a-thin-wrapper pattern your Week 11 ADR defends:
  <https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app>
- **Point-Free — The Composable Architecture.** Read the README and the "when should I use TCA" discussion before you write the architecture ADR; the honest answer for the capstone is often "plain `@Observable`," and you should be able to say why:
  <https://github.com/pointfreeco/swift-composable-architecture>
- **Google SRE Book — "Postmortem Culture: Learning from Failure"** and **"Being On-Call."** The runbook and the (next-week) postmortem inherit this discipline; blameless, specific, action-oriented:
  <https://sre.google/sre-book/postmortem-culture/> and <https://sre.google/sre-book/being-on-call/>

## Sync, CloudKit, and conflict resolution

- **"Syncing model data across a person's devices"** — the SwiftData + CloudKit story and its schema constraints (all relationships optional, no `.unique`):
  <https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices>
- **CloudKit framework reference** — `CKRecord`, `CKRecord.systemFields`, the server-record-changed conflict error, and zone-based sync:
  <https://developer.apple.com/documentation/cloudkit>
- **"Resolving record conflicts"** — Apple's guidance on the `serverRecordChanged` error and the three-record merge (client, server, ancestor):
  <https://developer.apple.com/documentation/cloudkit/ckerror/code/serverrecordchanged>
- **Designing for offline first** — Martin Kleppmann's writing on conflict-free replication is the deepest free reading on why last-writer-wins loses edits and what to do instead:
  <https://www.inkandswitch.com/local-first/>

## StoreKit 2 and server-side validation

- **StoreKit 2 — `Transaction`, `Product`, and `Transaction.currentEntitlements`:**
  <https://developer.apple.com/documentation/storekit/transaction>
- **App Store Server Notifications V2** — how your Vapor backend learns about renewals, refunds, and billing retries without polling:
  <https://developer.apple.com/documentation/appstoreservernotifications>
- **Validating signed transactions and notifications** — the `JWSTransaction` verification your Vapor backend performs:
  <https://developer.apple.com/documentation/appstoreserverapi>

## TestFlight, archiving, and the release candidate

- **"Distributing your app for beta testing and releases"** — the archive → upload → TestFlight flow:
  <https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases>
- **App Store Connect — TestFlight overview** (internal vs external testing, build processing, the encryption-compliance question):
  <https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview/>
- **fastlane `pilot`** — the lane your Week 22 CI uses to push a build to TestFlight; this week you drive it for the RC:
  <https://docs.fastlane.tools/actions/pilot/>
- **App Store Connect API** — programmatic build upload and TestFlight management, used with API keys in your CI secrets:
  <https://developer.apple.com/documentation/appstoreconnectapi>

## WWDC sessions (free, watch the ones that match your weak spots)

- **"Demystify SwiftUI performance"** (WWDC23) — re-watch before the review; "renders exactly once" is a question the reviewer asks:
  <https://developer.apple.com/videos/play/wwdc2023/10160/>
- **"Meet StoreKit for SwiftUI"** (WWDC23) and **"What's new in StoreKit and In-App Purchase"** — the subscription path you defend:
  <https://developer.apple.com/videos/play/wwdc2023/10013/>
- **"Bring your app to Siri"** / **"Design App Shortcuts"** — the App Intent surface in your capstone:
  <https://developer.apple.com/videos/play/wwdc2024/10133/>
- **"Update Live Activities with push notifications"** (WWDC23) — the push-driven Live Activity you trace in the review:
  <https://developer.apple.com/videos/play/wwdc2023/10185/>

## On-call and incident readiness

- **PagerDuty — Incident Response documentation** (free, vendor-neutral). The communication template in your runbook borrows its severity levels and roles:
  <https://response.pagerduty.com/>
- **"How to write a runbook"** — Atlassian's incident-management handbook chapter; the structure your `production-runbook.md` follows:
  <https://www.atlassian.com/incident-management/devops/runbooks>

## Interview preparation (the system-design pack)

- **"System Design Interview" prompts adapted to mobile** — the six prompts in the capstone career pack are mobile-flavoured; the canonical web references still teach the decomposition skill:
  Grokking-style decomposition is fine, but for the *mobile* answers, name Apple frameworks (CloudKit, APNs, StoreKit, BackgroundTasks, SwiftData) — your capstone *is* the reference solution for the offline-journaling and multi-device prompts.
- **Apple — Human Interface Guidelines** (for the "why this UX decision" interview questions):
  <https://developer.apple.com/design/human-interface-guidelines/>

## Tools you'll use this week

- **Xcode 16+** — Organizer (for archives and crash reports), the scheme editor (Release configuration), and the distribution flow.
- **`xcodebuild` + `xcbeautify` + fastlane** — the Week 22 CI pipeline that produces and uploads the RC; you do not archive by hand this week if you can help it.
- **`git tag`** — tag the release candidate (`v1.0.0-rc1`) so the build in TestFlight maps to an exact commit. A build you cannot trace to a commit is a build you cannot debug.
- **A Mermaid renderer** (GitHub renders it inline) — for the one-page architecture diagram in your repo README.

## Free books (chapter-level)

- **The Google SRE Book and SRE Workbook** (free online) — the "Postmortem Culture," "Being On-Call," and "Service Level Objectives" chapters are the on-call discipline behind this week's runbook and next week's chaos drill:
  <https://sre.google/books/>

## Paid books (optional, clearly marked)

- **"Thinking in SwiftUI" — objc.io** (paid). The clearest treatment of state ownership and view identity; the reviewer's "renders exactly once" question comes straight from it.
- **"App Architecture" — objc.io** (paid). Older (UIKit-era) but the chapter on layered architecture and dependency boundaries maps cleanly onto the capstone's `NotesCore` / app-target split.

---

*If a link 404s, please open an issue so we can replace it.*
