# Mini-Project — The Capstone Delivery: Ship, Survive, Present

> Take the locked release candidate from Week 23 and deliver it: submit to App Review early in the week and land on the first try, ship to TestFlight external beta in **five regions (US, UK, IN, BR, JP)**, run **one** chaos drill from the menu against the live system, write the blameless `postmortem.md`, record the **five-minute walkthrough video**, present at **demo day**, and assemble the **portfolio** (three case studies, the runbook, the interview-prep pack). This is the culmination of the entire capstone — and the end of C20.

This is the capstone's final mile. It is **not new development** — the app is feature-frozen at the Week 23 RC. The work this week is *delivery*: through Apple's pipeline, through a real failure, and through a presentation you defend live. By the design of this track, twenty-three weeks of compounding work meets Apple's gatekeepers and a deliberate failure scenario, and you prove you can ship and operate, not just build.

The full capstone specification — the technical bar, the deliverables, the chaos-drill menu, and the 100-point rubric — is in [`SYLLABUS.md` § Capstone](../../../SYLLABUS.md#capstone). Week 23's mini-project covered the build-and-defend half; this one covers the ship-and-survive half. Together they deliver the capstone the whole track was building toward: a cross-device productivity suite, live in TestFlight, resilient under a documented failure, and demonstrable in five minutes.

**Estimated time:** ~15 hours of the week's schedule (Monday through Saturday mini-project blocks), on top of the exercises and the Friday demo day.

---

## What you deliver, in order

The week has a deliberate sequence. Each step unblocks the next; do them in order.

### 1. Submit to App Review — Monday

Run the readiness audit (Exercise 1) until every row is PASS, then submit. Submit *Monday* because the review queue is an external dependency you do not control: submit early and a rejection costs you days you have; submit late and it costs you demo day. Flip the locked RC to external TestFlight with the Beta App Review info (demo account + notes). The build link goes in the README.

The readiness audit pre-empts the rejections that actually happen. Before you submit, confirm:

- **No crash on a fresh device** (2.1) and no placeholder content.
- **Screenshots match the build** and read at 1x (2.3).
- **No external-purchase links** for the subscription (3.1.1).
- **Core functionality reachable** without a login wall, and a **demo account in the notes** (4.2).
- **App Privacy label matches the code**; **in-app account deletion** ships (5.1.1).
- **Privacy-policy and support URLs resolve** (5.1.2).

Each is a five-minute check and a multi-day rejection if missed. Walk in clean.

### 2. Roll out to five regions — Tuesday

Once Beta App Review passes, stage the rollout: enable the US group, confirm it is healthy (install on a real device, complete a sandbox purchase, sync across two devices), then widen to UK and IN, then BR and JP. Recruit a handful of real testers per region so the per-group crash and feedback data is meaningful. Read the crash and feedback streams daily.

Stage it — US first, then widen — for the same blast-radius reason as the architecture review: a bad build hits one group, not five, and you catch it before it is everywhere. The per-region segmentation is also observability: if the subscription breaks only in JP (a storefront/currency issue), you see it isolated instead of buried in a global average. Beta crash reports come from *real* devices in *real* conditions — older OS versions, lower-memory devices, locales you never set — so read each as "what condition did this device have that mine didn't."

### 3. Run the chaos drill — Wednesday

Run the drill mid-week, while the beta cohort is live, so the postmortem reflects a real system under real conditions rather than a simulator. Pick **one** drill from the menu and run it against the live system:

- **Offline-edit conflict** — two devices edit the same note offline, reconnect within 60s, prove convergence and zero loss. (Exercise 2 is the deterministic proof; the live drill measures real CloudKit latency.)
- **Subscription edge cases** — refund, downgrade, billing-retry recovery; prove the server reflects each within five minutes and the client follows. (Exercise 3 is the deterministic proof.)
- **APNs auth-key rotation** — rotate the key new-first, retire old, prove recovery; this is the Week 23 runbook's 3 AM scenario run on purpose.

Establish steady state first (a `/health` prober), inject one failure, watch your observability, measure detection and recovery separately, and reverse the fault. The output is a measured timeline.

### 4. Write the postmortem — Thursday

Fill in `postmortem.md` from the measured timeline: summary, timeline, what you expected, what happened, the gap (the surprise), the data-correctness verdict, the user impact, and the action items (tagged accept/fix-now/fix-later, each owned). Blameless tone — system gaps, not human blame. Address every "fix-now" item, or plan a 1.0.1 with the killswitch holding the line.

A strong postmortem names a *surprise* — recovery succeeding is the least interesting part. If the drill recovered but you discovered you had no *detection* path without a user report, that gap is the finding, and "add a synthetic prober" is the action item. Run the blameless test on every action item: replace the person with the system component ("I forgot X" → "the process had no enforced X"); if the rewritten sentence points at a fix, it belongs in the postmortem.

### 5. Record the walkthrough and present — Friday

Record the five-minute video tracing one write through the app on three platforms, plus the Widget, App Intent, Live Activity, subscription, and offline-first sync — narrating the *mechanism* at each hop. Then present at demo day: trace a write live, answer the staff-iOS questions, and surface your own biggest risk first.

The five-minute structure that fits (Lecture 2, §5):

- **0:00–0:30** — what it is; show it on iPhone, iPad, and Mac side by side.
- **0:30–2:30** — trace one write: edit offline, sync, resolve a conflict, reload the Widget, update the Live Activity.
- **2:30–3:30** — the platform surface: the App Intent, the Lock Screen Widget, the watchOS companion.
- **3:30–4:30** — the subscription: the paywall, a sandbox purchase, the server-side validation.
- **4:30–5:00** — the resilience: the chaos drill and its postmortem finding.

Pre-stage the data so you are not typing on camera, and keep a fallback recording of the sync step in case live sync stalls.

### 6. Assemble the portfolio and mock interview — Saturday

Write the three `case-study.md` files, finalize the runbook and interview-prep pack, and complete the senior-iOS mock interview with a written retrospective.

---

## Picking the right chaos drill

You run one drill, so pick the one that exercises your capstone's *riskiest* contract — the part you are least sure of, where a real failure would hurt most:

- **Pick the offline-edit conflict** if your sync and conflict resolution are the parts you are least certain about. It is the most common real failure for a multi-device app, and it directly proves the determinism contract your whole sync story rests on.
- **Pick the subscription edges** if your monetisation is new and you want to prove the server-authoritative entitlement holds through a refund, a downgrade, and a billing retry. This is the drill that protects revenue and prevents the "I paid and got nothing" / "I refunded and still have Pro" support tickets.
- **Pick the APNs rotation** if your push pipeline is load-bearing (shared-note notifications, Live Activity updates) and you want to validate the runbook's 3 AM procedure on purpose, in daylight, before it happens at 3 AM for real.

There is no wrong choice, only an *unjustified* one. Whichever you pick, the postmortem should say *why* you picked it — "this is the contract I was least sure of" is a perfectly good reason and reads as self-aware.

## The drill execution discipline

Whichever drill you run, the execution is the same five steps (Lecture 2, §3):

1. **Establish steady state.** Start a `/health` prober (and a test-push or sync probe) *before* injecting anything, so you have a baseline and a clock.
2. **Inject one failure.** Change exactly one thing — do not rotate a key *and* deploy a new build at once, or you cannot attribute the recovery.
3. **Watch your observability.** The MetricKit collector, the structured Vapor logs, the per-region beta crash stream, the prober. A drill you cannot observe teaches you nothing.
4. **Measure detection and recovery separately.** When you *knew* (detection) and when it was *healthy* (recovery) are different numbers; the gap is your observability quality.
5. **Reverse the failure.** Leave the system in steady state — a drill that leaves a retired key or a stuck conflict is an outage, not a drill.

The output is a measured timeline (t0, t_fault, t_detect, t_recover, recovery_seconds, data verdict), which is the spine of the postmortem.

---

## The deliverables, mapped to the rubric

Each deliverable maps onto the capstone's 100-point rubric in `SYLLABUS.md`. This week earns the ship-and-survive lines and validates the build-quality lines from prior weeks.

```text
capstone-repo/
├── README.md                  # overview, Mermaid architecture diagram, TestFlight link,
│                              #   known-limitations section, build link per region
├── docs/
│   ├── adr/0001-0004.md        # the four ADRs (Week 23)
│   ├── trace-one-write.md      # the eight-hop trace (Week 23, Exercise 1)
│   └── app-review-readiness.md # the audit (Exercise 1), all PASS
├── production-runbook.md       # the on-call runbook (Week 23)
├── postmortem.md               # THE chaos-drill postmortem (this week)
├── portfolio/
│   ├── notes-v1/case-study.md
│   ├── notes-pro-v1/case-study.md
│   └── capstone/case-study.md
├── interview-prep/
│   ├── system-design.md        # the six mobile prompts (Week 23, Homework)
│   └── mock-interview-retro.md  # the retrospective (this week)
└── (the app sources + the Vapor backend, from the integrated workspace)
```

---

## Rules

- **Feature-frozen.** The app is locked at the Week 23 RC. New code is limited to: pre-empting an App Review rejection, the chaos-drill drivers and any fix the drill surfaces, the killswitch toggles, and the account-deletion path if it was missing. No new features the day before submission — that is the feature that crashes on review.
- **Submit early.** Monday, not Friday. The queue is an external dependency.
- **One drill, done thoroughly.** Pick the drill that exercises your riskiest contract. A second drill is a stretch goal.
- **Blameless postmortem.** System gaps, not human blame. Every action item must survive the "replace the person with the component" test.
- **No credentials in the repo.** The auth token is in the Keychain; the APNs key and App Store Connect API key are in CI secrets.
- **No data lost in the drill.** The verdict is "no loss," or a documented, expected, bounded loss for same-field LWW conflicts.

---

## Acceptance criteria

### Shipped (rubric: TestFlight in 5+ regions, 5 pts)

- [ ] Live in TestFlight external beta in five regions (US, UK, IN, BR, JP); links in the README.
- [ ] Passed App Review / Beta App Review on the first attempt, or a documented resubmission with the specific fix.
- [ ] The readiness audit (Exercise 1) is committed and was all-PASS before submission.
- [ ] In-app account deletion works end to end (if accounts exist); a demo account is in the review notes.

### Survived (rubric: chaos-drill postmortem and runbook, 10 pts)

- [ ] One chaos drill executed against the live system with a measured timeline.
- [ ] `postmortem.md` — blameless, naming a real surprise, with the timeline, data verdict, user impact, and owned/tagged action items.
- [ ] Every "fix-now" action item addressed (or a 1.0.1 planned with the killswitch).

### Demonstrated (rubric: career pack, 10% of course)

- [ ] A five-minute walkthrough video tracing one write end to end, naming the mechanism at each hop.
- [ ] Demo day delivered and defended under the staff-iOS question set, biggest risk surfaced first.
- [ ] Three `case-study.md` files (problem framing, key decisions, hardest bug, production metric, screenshot strip).
- [ ] The runbook and interview-prep pack finalized; the senior-iOS mock interview completed with a retrospective.

### Validated from prior weeks (rubric: the build-quality lines)

- [ ] Multi-platform parity (iPhone + iPad + Mac + watchOS + visionOS) — demonstrated in the walkthrough.
- [ ] Offline-first sync and deterministic conflict resolution — proven in the drill.
- [ ] StoreKit 2 subscription with server-side validation — demonstrated in the walkthrough.
- [ ] Widgets + App Intents + Live Activity working end to end.
- [ ] Accessibility clean and Instruments-tuned (no hitches in a 60s scroll, no hangs in 5 min).
- [ ] The Vapor backend deployed and healthy (`/health` returns 200).

---

## The non-negotiables

Two things will fail the capstone regardless of how good everything else is, and they are deliberately harsh because in a real launch they are incidents:

- **A credential in the repo.** The auth token belongs in the Keychain; the APNs key and App Store Connect API key belong in CI secrets. `grep -ri "BEGIN PRIVATE KEY\|aps.*key\|asc_api_key" .` must return nothing. A leaked signing key or push key is a security incident, not a style nit.
- **Data lost in the drill.** The chaos drill's data-correctness verdict must be "no loss" — or, for the offline-conflict drill, a documented, expected, *bounded* loss for same-field last-writer-wins conflicts (and even that should be honest in the postmortem, not hidden). A drill that silently eats user edits is the exact failure the drill exists to catch.

Everything else — a slightly late submission, a region that took an extra day, a 1.0.1 fix — is recoverable. These two are not.

## What "done" looks like

A grader opens your repo, reads the README, and follows the TestFlight link to a build live in five regions. They read your committed readiness audit and see it was all-PASS before you submitted, and your review history shows a first-attempt pass. They watch your five-minute walkthrough and see one write trace through five platforms, the Widget, the App Intent, the Live Activity, the subscription, and offline sync — narrated by mechanism. They read your `postmortem.md` and find a measured timeline, a real surprise, a "no data lost" verdict, and owned action items. They watch your demo day and hear you name your own biggest risk before they ask. They read three case studies that say what was hard, what you decided, and what the number was. Every one of those passes. That is the capstone delivered. That is C20.

---

## What this completes

- **The Phase IV gate:** the capstone accepted into TestFlight, the chaos-drill postmortem signed off, the portfolio published, and the senior-iOS mock interview completed.
- **The course.** There is no Week 25. After you ship, survive, and present, you have completed C20 · Crunch Swift. You have written Swift 6 under strict concurrency, shipped a multi-platform SwiftUI app with SwiftData and CloudKit, validated a StoreKit subscription server-side, driven a Live Activity from a push, tuned a hitch in Instruments, rotated an APNs key under a chaos drill, and landed an app through App Review on the first try.
- **The portfolio you walk into interviews with.** Three deployed apps, a TestFlight history, a runbook, a chaos-drill postmortem, and an interview-prep pack — the closest thing the job market has to an Apple-engineer certification.

Ship it, survive the drill, present it. You earned the launch.

---

## Submission

When the capstone delivery is done:

1. Confirm the app is live in TestFlight external beta in five regions, with the links in the README.
2. Confirm App Review (or Beta App Review) passed — or the resubmission landed with a documented fix.
3. Confirm `postmortem.md` is committed with a measured timeline, a named surprise, and owned action items.
4. Confirm the five-minute walkthrough is recorded and linked, and demo day is delivered.
5. Confirm the three case studies, the runbook, and the interview-prep pack are committed, and the mock-interview retrospective is written.
6. Confirm there are no credentials in the repo and no data was lost in the drill.
7. Post the repo URL and the TestFlight link in your cohort tracker.

That is the Phase IV gate cleared and the course complete. You have shipped a real app through Apple's pipeline, proven it survives a real failure, and assembled the portfolio that demonstrates you can build, ship, and operate. There is no Week 25 — the recommended next tracks (C21 Crunch Droid for Android, or C18/C19 to operate the backend at fleet scale) are in the [track README](../../../README.md). But first: present this one. You earned it.
