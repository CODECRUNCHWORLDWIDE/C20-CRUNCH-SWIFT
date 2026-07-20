# Week 24 — TestFlight, App Review, Chaos Drill, Demo Day

Welcome to the final week of **C20 · Crunch Swift**. You do not learn a new framework. You ship — to real users, through Apple's pipeline — and then you prove the system survives the kind of failure that takes apps down in production.

Last week you locked a release candidate in TestFlight internal testing, signed off the architecture, wrote the ADRs and the production runbook, and prepared the App Store Connect record. This week the build leaves your hands. You flip TestFlight to **external beta in five regions** (US, UK, IN, BR, JP), submit to **App Review** and land it on the first try, run a **chaos drill** against the live system, write the **postmortem**, record the **five-minute walkthrough**, and present at **demo day**. By Sunday you have shipped a real app through Apple's submission pipeline and survived a documented failure — the two things that separate "I built an app once" from "I have operated an app in production."

The week has a deliberate rhythm. Submit early — App Review and build processing both take hours to days, and you do not want the chaos drill or demo day blocked on a queue. Run the chaos drill mid-week, while the beta cohort is live, so the postmortem reflects a real system under real conditions. Record the walkthrough and present last, when the app is in five regions and the drill is documented. The crunch this curriculum is named to avoid is the team that submits on Friday and prays; you submit Monday, so that if App Review rejects you, you have the week to land the resubmission instead of the weekend.

This is the capstone's final mile. Everything you built across twenty-three weeks now meets Apple's gatekeepers and a real failure scenario. Treat it like a launch, because it is one.

## Learning objectives

By the end of this week, you will be able to:

- **Submit** an app to App Review and pass on the first attempt — by knowing what App Review actually enforces (the guidelines with teeth), what it never checks, and how to pre-empt the common rejections (privacy, account deletion, IAP rules, metadata mismatch).
- **Ship** a TestFlight external beta to five regions, manage beta groups and the Beta App Review, read beta crash reports, and use the App Store Connect API for programmatic build management.
- **Execute** a chaos drill from the capstone menu — offline-edit conflict, subscription edge cases, or APNs auth-key rotation — driving the failure, measuring detection and recovery, and proving the system recovered.
- **Write** a blameless postmortem that an incident review would accept: the timeline, what you expected, what happened, the gap, the user impact, and the action items.
- **Record** a five-minute walkthrough video a hiring manager can watch and a peer can reproduce — tracing one write through the app on three platforms, the Widget, the App Intent, the Live Activity, the subscription, and the offline-first sync.
- **Present** the capstone at demo day and answer the senior-iOS questions live — the architecture review and the mock interview wearing one hat.
- **Assemble** the portfolio: three case studies (Notes v1, Notes Pro v1, the capstone), the runbook, and the interview-prep pack — the closest thing the job market has to an Apple-engineer certification.

## Prerequisites

This week assumes you completed Week 23 with the capstone build-sprint deliverables in hand. Specifically, you need:

- **A locked release candidate** in TestFlight internal testing — a Release-configuration, App-Store-signed build, tagged `v1.0.0-rc1`, with the full Swift Testing + XCUITest + snapshot suite green behind it.
- **A signed-off architecture** — the Friday review's risk list, with every "fix now" item fixed and the rest in the README's known-limitations section.
- **The four ADRs and the production runbook** committed to the repo.
- **A prepared App Store Connect record** — the app created, bundle ID and capabilities matching, the export-compliance answer set, the App Privacy nutrition label drafted, and a first metadata pass.
- **A deployed Vapor backend** at a public URL with a `/health` endpoint, structured logging, and the StoreKit validation + APNs sender paths working — because the chaos drills exercise it.
- **An Apple Developer Program membership** and a physical iPhone or iPad for the device-only verification (real-device push, Live Activities on a Lock Screen, a sandbox subscription purchase).

If the RC is not locked from last week, this week becomes a sprint — and a sprint the same week you run a chaos drill and present is exactly the crunch the build-sprint week front-loaded its work to avoid. Lock it last week; ship it this week.

## Topics covered

- **App Store Connect metadata.** The app record, screenshots (1290×2796 and the other required device sizes), description, keywords, the support and privacy-policy URLs, age rating, and the metadata that reviewers actually read.
- **The App Privacy details.** The nutrition label derived from what the app collects; the account-deletion requirement; the "data used to track you" distinction; matching the label to the code.
- **App Review — what it really checks.** The actually-enforced guidelines: privacy and account deletion (5.1.1), IAP rules (3.1 — no external purchase links for digital goods), minimum functionality (4.2), metadata accuracy (2.3), and crashes on review. What it never checks. How to land on the first try.
- **TestFlight external beta.** Internal vs external testing, the Beta App Review gate, beta groups, the five-region rollout, public links, and reading beta crash reports and feedback.
- **The App Store Connect API.** Programmatic build upload and TestFlight management with API keys; expedited review requests; the "1.0.1 the day after launch" pattern.
- **Chaos drills.** The three capstone drills: the offline-edit conflict (two devices editing offline, reconnecting within 60 s); the subscription edge cases (refund, downgrade, billing retry); the APNs auth-key rotation (new key first, retire old, prove recovery). Driving the failure, measuring detection and recovery, verifying no data loss.
- **The blameless postmortem.** The Google SRE structure: timeline, expected vs actual, the gap, user impact, action items tagged accept/fix-now/fix-later. Blameless tone.
- **Demo day and the walkthrough video.** The five-minute trace-one-write narration; presenting under questions; the portfolio assembly.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract; the final week deserves whatever it takes to ship clean.

| Day       | Focus                                                          | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|----------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | App Review reality; metadata + privacy; SUBMIT early           |    2h    |    1h     |     0h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Tuesday   | TestFlight external in 5 regions; beta groups; crash reports   |    1h    |    2h     |     0h     |    0.5h   |   1h     |     2h       |    0h      |     6.5h    |
| Wednesday | The chaos drill: drive the failure, measure recovery          |    1h    |    2h     |     1h     |    0.5h   |   1h     |     1.5h     |    0.5h    |     7h      |
| Thursday  | Write the postmortem; respond to any App Review feedback       |    0h    |    1.5h   |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     6.5h    |
| Friday    | Record the 5-minute walkthrough; demo day                     |    0h    |    0h     |     0h     |    0.5h   |   1h     |     2.5h     |    0.5h    |     4.5h    |
| Saturday  | Portfolio assembly; senior-iOS mock interview                  |    0h    |    0h     |     0h     |    0h     |   0h     |     2.5h     |    0.5h    |     3h      |
| Sunday    | Quiz, course retrospective, final push                        |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                | **4h**   | **6.5h**  | **2h**     | **3.5h**  | **5h**   | **15h**      | **2.5h**   | **36h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | The App Review guidelines, TestFlight and App Store Connect API docs, the chaos-drill and postmortem references, and the demo-day prep |
| [lecture-notes/01-app-review-and-shipping-to-testflight.md](./lecture-notes/01-app-review-and-shipping-to-testflight.md) | What App Review really checks, the common rejections and how to pre-empt them, the metadata and privacy details, and the five-region TestFlight external rollout |
| [lecture-notes/02-the-chaos-drill-the-postmortem-and-demo-day.md](./lecture-notes/02-the-chaos-drill-the-postmortem-and-demo-day.md) | The three chaos drills end to end, the blameless postmortem structure, the five-minute walkthrough, and demo day |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-app-review-readiness-audit.md](./exercises/exercise-01-app-review-readiness-audit.md) | Audit the capstone against the actually-enforced App Review guidelines before you submit |
| [exercises/exercise-02-offline-conflict-chaos-drill.swift](./exercises/exercise-02-offline-conflict-chaos-drill.swift) | Drive and verify the offline-edit-conflict chaos drill, asserting convergence and zero data loss |
| [exercises/exercise-03-subscription-edge-cases.swift](./exercises/exercise-03-subscription-edge-cases.swift) | Reproduce and verify the StoreKit subscription edge cases: refund, downgrade, billing retry |
| [challenges/README.md](./challenges/README.md) | Index of the final challenge |
| [challenges/challenge-01-ship-survive-and-present.md](./challenges/challenge-01-ship-survive-and-present.md) | Ship to App Review and five-region beta, survive the chaos drill, and present at demo day |
| [quiz.md](./quiz.md) | 13 questions, answer key at the bottom |
| [homework.md](./homework.md) | The final week's deliverables with a rubric |
| [mini-project/README.md](./mini-project/README.md) | The capstone delivery brief — ship, survive, present |

## The "land on the first try" promise

C20 has carried one recurring marker through every phase. The final week's marker is the one that means you are done:

> **The capstone is live in TestFlight in five regions, it cleared App Review (or Beta App Review) on the first attempt, it survived a documented chaos drill with no data lost, and you can demonstrate it end to end in five minutes.** Not "it's on my phone." Not "it builds." Live, reviewed, resilient, and demonstrable — the four things a senior engineer's launch actually delivers.

You will *prove* this by submitting early, pre-empting the common rejections (Exercise 1), driving a real failure and recovering from it (Exercises 2–3 and the chaos drill), and presenting under questions at demo day. "I clicked submit" is not the bar. "It passed, it survived, and here's the five-minute walkthrough" is the bar.

## A note on what's not here

This is the final week, and it deliberately does **not** add new app features. The app is feature-frozen at the Week 23 release candidate. New code this week is limited to: pre-empting an App Review rejection, the chaos-drill drivers and any fix the drill surfaces, and the feature-flag killswitch toggles. The discipline of a launch week is *stop building features and start shipping* — a feature added the day before submission is the feature that crashes on review. If the chaos drill surfaces a real bug, you fix that bug; you do not add scope.

## Up next

There is no Week 25. After you ship the capstone, survive the chaos drill, publish the portfolio, and clear the senior-iOS mock interview, you have completed **C20 · Crunch Swift**. You have written Swift 6 under strict concurrency, shipped a multi-platform SwiftUI app with SwiftData and CloudKit sync, validated a StoreKit subscription server-side, driven a Live Activity from a push, tuned a hitch in Instruments, rotated an APNs key under a chaos drill, and landed an app through App Review on the first try. The recommended next steps — **C21 Crunch Droid** for Android with the same rigour, or **C18 / C19** to operate the Vapor backend at fleet scale — are in the [track README](../../README.md) and the Crunch Labs Charter. But first: ship this one, survive the drill, and present it. You earned the launch.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
