# Week 24 — Resources

Every primary resource on this page is **free**. The App Review guidelines, the TestFlight and App Store Connect documentation, and the WWDC sessions are all free with the developer account you hold. This is the ship-and-survive week, so the references skew toward Apple's submission pipeline, chaos engineering, and the postmortem discipline.

## The contract — read this first

- **The capstone specification.** Your source of truth for what ships this week, including the chaos-drill menu and the 100-point rubric:
  [`SYLLABUS.md` § Capstone](../../SYLLABUS.md#capstone)
- **The track README** for the portfolio and career-pack deliverables that close the course:
  [`README.md`](../../README.md)

## App Review — read these before you submit

- **App Store Review Guidelines** — the document App Review actually enforces. Read 2.3 (accurate metadata), 3.1 (in-app purchase rules), 4.2 (minimum functionality), and 5.1.1 (privacy, including account deletion) closely:
  <https://developer.apple.com/app-store/review/guidelines/>
- **"Preparing your app for submission"** — the checklist Apple itself publishes:
  <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-for-review/>
- **App Privacy details** — the nutrition label, what to declare, and the data-type taxonomy:
  <https://developer.apple.com/app-store/app-privacy-details/>
- **Account deletion requirement (5.1.1(v))** — apps that support account creation must offer in-app account deletion; this is a common rejection:
  <https://developer.apple.com/support/offering-account-deletion-in-your-app/>
- **"Avoiding common app rejections"** — Apple's own list of the rejections it sees most:
  <https://developer.apple.com/app-store/review/#common-app-rejections>

## TestFlight and the App Store Connect API

- **TestFlight overview** — internal vs external testing, the Beta App Review, beta groups, public links:
  <https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview/>
- **"Add external testers"** and the five-region rollout — beta groups and territories:
  <https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-external-testers/>
- **App Store Connect API** — programmatic builds, TestFlight, and expedited-review requests with API keys:
  <https://developer.apple.com/documentation/appstoreconnectapi>
- **fastlane `pilot`** — the lane that promotes the build to external testing:
  <https://docs.fastlane.tools/actions/pilot/>
- **Expedited App Review** — when and how to request it (sparingly; it is a finite resource):
  <https://developer.apple.com/contact/app-store/?topic=expedite>

## StoreKit subscription edge cases (for the chaos drill)

- **App Store Server Notifications V2** — how your backend learns about refunds, downgrades, and billing retries:
  <https://developer.apple.com/documentation/appstoreservernotifications>
- **Testing subscription renewals and edge cases in the sandbox** — refund, downgrade, billing-retry simulation:
  <https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox>
- **`Transaction` and `Transaction.currentEntitlements`** — the on-device view the server reconciles against:
  <https://developer.apple.com/documentation/storekit/transaction>
- **Refund handling and `Transaction.revocationDate`:**
  <https://developer.apple.com/documentation/storekit/transaction/revocationdate>

## APNs auth-key rotation (for the drill)

- **"Establishing a token-based connection to APNs"** — the auth-key (`.p8`) model and how rotation works:
  <https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns>
- **App Store Connect — Keys** — where you create and revoke APNs auth keys:
  <https://developer.apple.com/help/account/manage-keys/create-a-private-key/>

## Chaos engineering and the postmortem

- **Google SRE Book — "Postmortem Culture: Learning from Failure."** The structure your postmortem follows; blameless, specific, action-oriented:
  <https://sre.google/sre-book/postmortem-culture/>
- **Google SRE Workbook — "Example Postmortem."** A concrete template to model yours on:
  <https://sre.google/workbook/postmortem-culture/>
- **Principles of Chaos Engineering** — the discipline behind "inject a failure on purpose and measure the system's response":
  <https://principlesofchaos.org/>

## WWDC sessions (free)

- **"What's new in App Store Connect"** (most recent) — the submission and TestFlight tooling changes:
  <https://developer.apple.com/videos/play/wwdc2024/10063/>
- **"Explore App Store Connect for spatial computing"** and the multi-platform submission notes (if you ship the visionOS target):
  <https://developer.apple.com/videos/play/wwdc2024/10103/>
- **"Meet StoreKit for SwiftUI"** — re-watch the subscription lifecycle before the subscription drill:
  <https://developer.apple.com/videos/play/wwdc2023/10013/>

## Demo day and the portfolio

- **Apple — Human Interface Guidelines** (for the "why this UX" demo questions):
  <https://developer.apple.com/design/human-interface-guidelines/>
- **The career-engineering pack** from the SYLLABUS — the three case studies, the interview-prep drills, and the production runbook template:
  [`SYLLABUS.md` § Career engineering pack](../../SYLLABUS.md#career-engineering-pack)

## Tools you'll use this week

- **Xcode 16+ Organizer** — for archives, the distribution flow, and reading beta crash reports symbolicated.
- **App Store Connect** (web) — submission, TestFlight groups, metadata, App Privacy, the Keys section for APNs.
- **`xcrun simctl`** — drive the offline-conflict drill with two booted simulators (`xcrun simctl ... terminate` / network-condition toggles).
- **The StoreKit Configuration file / sandbox** — to drive the subscription edge cases without real money where possible, and a real sandbox purchase where the drill requires it.
- **A screen recorder** (QuickTime, or the simulator's built-in recording) — for the five-minute walkthrough.

## Free books (chapter-level)

- **The Google SRE Book and SRE Workbook** (free online) — the "Postmortem Culture" chapter is the spine of this week's postmortem; the Workbook's example postmortem is the template:
  <https://sre.google/books/>

## Paid resources (optional, clearly marked)

- **"App Store Optimization" guides** (various, paid) — keyword and screenshot strategy. Useful if you intend to actually publish, not just complete the capstone; not required for the course.

---

*If a link 404s, please open an issue so we can replace it.*
