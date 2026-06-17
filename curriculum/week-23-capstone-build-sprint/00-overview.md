# Week 23 — Capstone Build Sprint

Welcome to the penultimate week of **C20 · Crunch Swift**. You do not learn a new Apple framework this week. You integrate.

Everything you have built since Week 1 — the Vapor service and shared codable types from Phase I, the SwiftUI + SwiftData notes app from Phase II, the networking layer with offline write-replay, the Keychain and CloudKit sync, the Instruments-tuned scroll, the accessibility pass, the StoreKit 2 subscription and the APNs pipeline from Phase III, the multi-platform targets, the Widgets, the App Intents, and the Live Activity from Phase IV — gets assembled into one running system: the **Offline-First Cross-Device Productivity Suite**, the capstone specified in [`SYLLABUS.md` § Capstone](../../SYLLABUS.md#capstone). This week you build it to the bar. Next week you ship it through App Review, run a chaos drill, and present it at demo day.

The capstone is not a new app. It is the **integration** of twenty-two weeks of compounding work into one system you can stand up, demonstrate on five Apple platforms, defend in an architecture review, and submit to Apple. By the design of this track, the mini-projects compound — by Week 10 you were extending the Week 8 notes app, not starting fresh; by Week 18 you were adding push and IAP to the same codebase. Week 23 is where the compounding pays off. If you kept your architecture clean, your tests green, and your modules separable every week, this week is assembly, hardening, and proof. If you took shortcuts, this is where you pay for them.

The week has a rhythm the SYLLABUS prescribes: **instructors run a daily 30-minute review.** You integrate and harden early in the week, run the architecture sign-off mid-week, then lock the build and prepare the App Store Connect metadata at the end so that Week 24 is a submission week, not a scramble. The deliverables you produce this week — the architecture diagram, the architectural decision records (ADRs), the `production-runbook.md`, and the `interview-prep` system-design pack — are the artifacts a senior reviewer reads before they decide whether to trust your system in front of users.

This is the week the course has been building toward. Treat it like a release candidate.

## Learning objectives

By the end of this week, you will be able to:

- **Integrate** every prior-phase artifact into one multi-platform system that builds from a single Xcode workspace, runs on iPhone, iPad, Mac, watchOS, and visionOS, and is backed by your deployed Vapor service.
- **Defend** a production architecture in a live review: walk one write through the whole system — local edit → SwiftData → CloudKit / Vapor sync → conflict resolution → push → Live Activity — and answer the staff-iOS-engineer question set without flinching.
- **Write** the architectural decision records that justify your hard choices: plain `@Observable` vs TCA, CloudKit-primary vs Vapor-primary sync, the conflict-resolution policy, and the StoreKit validation path.
- **Author** a `production-runbook.md` that answers "it is 3 AM and the push pipeline is silently broken — what do you check, what do you roll back, who do you page" for the five most likely capstone outages.
- **Lock** a release-candidate build: bump the version and build number, run the full Swift Testing + XCUITest + snapshot suite green, archive, and upload to TestFlight internal testing via the CI pipeline you built in Week 22.
- **Prepare** App Store Connect for next week: the app record, the encryption-compliance answer, the App Privacy nutrition label, and a first pass at metadata and screenshots — so Week 24 submits rather than scrambles.
- **Assemble** the `interview-prep` system-design pack: answer the six mobile-system-design prompts using the actual Apple frameworks your capstone uses, so the system you built becomes the system you can whiteboard.

## Prerequisites

This week assumes you have completed C20 Weeks 1–22 and that those mini-projects produced working, version-controlled code. Specifically, you need:

- **Notes v1** (Phase II, Week 12) — the SwiftUI iPhone + iPad + Mac app with SwiftData persistence, value-typed navigation, deep links, search, and tag filtering. Checked into Git.
- **Notes Pro v1** (Phase III, Week 18) — the same app extended with the `NotesClient` networking actor (offline write-replay, retries with jitter, certificate pinning), Keychain credential storage, CloudKit sync with a conflict-resolution policy, a StoreKit 2 subscription validated against the Vapor backend, an APNs pipeline, and a Notification Service Extension.
- **The Phase IV additions** (Weeks 19–22) — the macOS-native, watchOS, and visionOS targets; the Home Screen and Lock Screen Widgets; the `AddNote` App Intent surfaced to Shortcuts and Siri; the shared-edit Live Activity driven by an APNs push; and the GitHub Actions CI pipeline with `xcodebuild` + `xcbeautify` + fastlane that uploads to TestFlight.
- **A deployed Vapor backend** — the `notes-api` from Phase I, deployed to a public URL (Fly.io, Railway, a Linux VPS, or your own cloud box), with Postgres, structured logging, and a health endpoint.
- **An Apple Developer Program membership** ($99/yr), an App Store Connect app record (or the ability to create one), and a physical iPhone or iPad for the device-only features (push to a real Lock Screen, Live Activities).

If any of those is missing or broken, this week will expose it. That is the point of an integration sprint.

## Topics covered

- **Capstone integration.** Composing the Phase I–IV artifacts into one Xcode workspace: the shared `NotesCore` SwiftPM package, the five app targets, the Widget and NSE app extensions, and the Vapor backend as a separate deployable.
- **The architecture review, iOS edition.** The agenda, the artifact set (diagram, ADRs, runbook), the trace-one-write walk, and the staff-engineer question bank: state ownership, sync correctness, conflict resolution, the offline write-replay window, blast radius of a bad release, and what pages you at 3 AM.
- **Architectural decision records (ADRs).** The format, and the four capstone decisions worth recording: the architecture (plain SwiftUI `@Observable` vs MVVM vs TCA), the sync primary (CloudKit vs Vapor), the conflict-resolution policy (last-writer-wins vs field-merge vs CRDT-lite), and the StoreKit validation flow.
- **The production runbook.** The on-call surface (APNs, CloudKit, Vapor, StoreKit server notifications, App Store Connect API), the five most likely outages and their detection, the rollback procedures for a TestFlight build / an App Store build / a Vapor deploy, and the beta-cohort incident communication template.
- **Release-candidate discipline.** Version and build-number bumps, the green-test gate, archiving, code signing for distribution, and the TestFlight internal upload — driven by the Week 22 CI pipeline, not by hand.
- **App Store Connect preparation.** The app record, bundle ID and capabilities, the export-compliance / encryption answer, the App Privacy nutrition label derived from what your app actually collects, and a first metadata pass.
- **The interview-prep system-design pack.** Turning the capstone into six whiteboard answers: offline-first journaling, photo sync for a family, a Live Activity for a delivery order, a push pipeline that survives an APNs outage, multi-device conflict resolution, and a StoreKit subscription with server validation — each naming the real frameworks.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract; the capstone deserves whatever it takes.

| Day       | Focus                                                          | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Final integration; the iOS architecture-review playbook        |    2h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Tuesday   | Trace one write end to end; write the four capstone ADRs       |    1h    |    2h     |     0h     |    0.5h   |   1h     |     2h       |    0h      |     6.5h    |
| Wednesday | The production runbook; the 3 AM walk; daily review            |    1h    |    1.5h   |     1h     |    0.5h   |   1h     |     1.5h     |    0.5h    |     7h      |
| Thursday  | Lock the RC: green tests, archive, TestFlight internal upload  |    0h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     6h      |
| Friday    | App Store Connect prep; live architecture review (sign-off)    |    0h    |    0h     |     0h     |    0.5h   |   1h     |     2.5h     |    0.5h    |     4.5h    |
| Saturday  | Mini-project deep work; interview-prep system-design pack      |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0.5h    |     3.5h    |
| Sunday    | Quiz, retrospective, push the RC tag                           |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                | **4h**   | **6.5h**  | **2h**     | **3.5h**  | **5h**   | **15.5h**    | **2.5h**   | **36.5h**   |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./00-overview.md) | This overview (you are here) |
| [resources.md](./01-resources.md) | iOS architecture-review references, ADR templates, runbook patterns, the capstone spec, and the interview-prep system-design sources |
| [lecture-notes/01-integrating-the-capstone-and-the-architecture-review.md](./02-lecture-notes/01-integrating-the-capstone-and-the-architecture-review.md) | How the Phase I–IV artifacts compose into one workspace; how an iOS architecture review runs; the trace-one-write walk and the staff-engineer question bank |
| [lecture-notes/02-adrs-the-production-runbook-and-the-release-candidate.md](./02-lecture-notes/02-adrs-the-production-runbook-and-the-release-candidate.md) | Writing the four capstone ADRs; authoring the production runbook and the 3 AM walk; locking a release-candidate build and uploading to TestFlight internal |
| [exercises/README.md](./03-exercises/00-overview.md) | Index of the three exercises |
| [exercises/exercise-01-trace-one-write-end-to-end.md](./03-exercises/exercise-01-trace-one-write-end-to-end.md) | Trace a single note edit through every hop and document the failure mode at each |
| [exercises/exercise-02-conflict-resolution-policy.swift](./03-exercises/exercise-02-conflict-resolution-policy.swift) | Implement and unit-test the capstone's deterministic conflict-resolution merge |
| [exercises/exercise-03-killswitch-feature-flag.swift](./03-exercises/exercise-03-killswitch-feature-flag.swift) | Build the remote feature-flag killswitch the runbook depends on, with a cached offline default |
| [challenges/README.md](./04-challenges/00-overview.md) | Index of the weekly challenge |
| [challenges/challenge-01-architecture-review-sign-off.md](./04-challenges/challenge-01-architecture-review-sign-off.md) | Deliver the live architecture review and earn the final sign-off |
| [quiz.md](./05-quiz.md) | 13 questions, answer key at the bottom |
| [homework.md](./06-homework.md) | The week's capstone deliverables with a rubric |
| [mini-project/README.md](./07-mini-project/00-overview.md) | The full capstone integration brief — the build sprint, end to end |

## The "trace one write" promise

C20 has carried one recurring marker through every phase, and Week 23 is where it cashes out. Week 8 promised "renders exactly once." Week 10 promised "survives a cold launch." Week 13 promised "replays writes when the server returns." Week 23 promises the integration of all of them:

> **One write, traced through every hop, with no data lost and no race.** Edit a note on the iPhone while offline. It lands in SwiftData immediately and the list re-renders once. When the network returns, the `NotesClient` replays the write to the Vapor backend and CloudKit syncs it to the iPad and the Mac. A simultaneous edit on the iPad is resolved by your documented conflict policy — deterministically, the same way every time. The Widget timeline reloads. If the note was shared, an APNs push drives a Live Activity on the other device. You can point at the code for every one of those hops, and you can name what breaks at each.

You will *prove* this in Exercise 1 and demonstrate it live in the architecture review. "It works on my iPhone" is not the bar. "I can trace one write through five platforms and a Linux backend, and I can tell you the data-loss window at every hop" is the bar.

## Stretch goals

If you finish the regular work early and want to push further:

- Make the conflict-resolution policy a **field-level merge** instead of last-writer-wins for the note body, and prove with a test that two non-overlapping edits both survive a concurrent merge. (This is the difference between a one-star "the update ate my edit" review and a clean merge.)
- Add a **synthetic health prober** to the Vapor backend that hits the `/health` endpoint and the APNs sandbox from outside your network every minute, so a silent push outage pages you before a user notices. (The runbook's biggest blind spot is the thing you do not measure.)
- Write a **second ADR** for a decision you are unsure about (e.g. watchOS connectivity via `WatchConnectivity` vs CloudKit directly) and present both options with a recommendation in the review.
- Record the **5-minute walkthrough video** this week instead of next, so Week 24 is purely submission and chaos drill. Rehearsing the trace-one-write walk on camera now makes the demo-day version a re-take, not a first take.

## Up next

Continue to **Week 24 — TestFlight, App Review, chaos drill, demo day** once you have a signed-off architecture, a locked release-candidate build in TestFlight internal testing, a written runbook, and the App Store Connect record prepared. Week 24 is the final week of C20: you ship the capstone to TestFlight external beta in five regions (US, UK, IN, BR, JP), submit to App Review and land it, run the chaos drill, write the postmortem, record the walkthrough, and present at demo day. Everything next week assumes the build is ready *this* week. Lock it now so next week is a submission, not a sprint.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
