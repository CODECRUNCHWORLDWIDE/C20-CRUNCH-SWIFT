# Challenge 1 — Ship, survive, and present

> **Estimated time:** the bulk of the week's mini-project hours plus the Friday demo-day slot. **This is the assessed capstone delivery — the Phase IV gate and the end of C20.** No solution is provided; in production nobody hands you the answer key.

You will take the capstone — the Offline-First Cross-Device Productivity Suite, locked as a release candidate last week — and **ship it, prove it survives a real failure, and present it.** Three things, in order, none optional: ship it through Apple's pipeline to five regions; survive a documented chaos drill; present it at demo day and defend it under the senior-iOS question set.

This is harder than any prior challenge because it is *real*: a real submission to a real review queue, a real failure injected into a running system, and a real presentation defended live. The grader does not read your code and award points. They confirm the app is live in TestFlight in five regions, watch your trace-one-write walkthrough, read your chaos-drill postmortem, and ask the questions a hiring panel asks.

## What you deliver

Mapped onto the capstone deliverables in `SYLLABUS.md` § Capstone:

- **The app, shipped.** Submitted to App Review (or Beta App Review), live in **TestFlight external beta in five regions (US, UK, IN, BR, JP)**, passing review on the first attempt — or landing the resubmission with a documented fix.
- **The chaos drill, survived.** **One** drill from the menu (offline-edit conflict, subscription edge cases, or APNs auth-key rotation), driven against the live system, measured, and documented in `postmortem.md`.
- **The walkthrough.** A **five-minute video** tracing one write through the app on three platforms, plus the Widget, App Intent, Live Activity, subscription, and offline-first sync.
- **Demo day.** A live presentation, defended under the staff-iOS question set.
- **The portfolio.** Three case studies (Notes v1, Notes Pro v1, the capstone), the production runbook, and the interview-prep pack.

## Acceptance criteria (the grader checks every one)

### Shipped

- [ ] **Live in TestFlight external beta in five regions** (US, UK, IN, BR, JP), with the build link in the README.
- [ ] **Passed App Review (or Beta App Review) on the first attempt** — or a documented resubmission with the specific fix. The readiness audit (Exercise 1) is committed and was all-PASS before submission.
- [ ] **The app launches clean** on a fresh device and the core functionality is reachable; a demo account is in the review notes.
- [ ] **In-app account deletion** works end to end (if accounts exist).

### Survived

- [ ] **One chaos drill executed against the live system**, with a measured timeline (steady state, fault, detect, recover, data verdict).
- [ ] **`postmortem.md`** — blameless, naming a real surprise, with the measured timeline and owned, tagged action items. For the conflict drill: convergence proven, zero loss for non-overlapping edits. For the subscription drill: each transition reflected server-side within five minutes. For the rotation drill: recovery proven with a documented silent-failure window.
- [ ] **Every "fix-now" action item** is addressed, or a 1.0.1 is planned with the killswitch holding the line.

### Demonstrated

- [ ] **A five-minute walkthrough video** (link in the README) tracing one write end to end and naming the mechanism at each hop.
- [ ] **Demo day delivered** — you present, you trace a write live, you answer the staff-iOS questions, you surface your own biggest risk first.
- [ ] **The portfolio assembled** — three `case-study.md` files (problem framing, key decisions, hardest bug, production metric, screenshot strip), the runbook, and the interview-prep pack.
- [ ] **The senior-iOS mock interview completed**, with a retrospective naming the one question you fumbled and the better answer.

### Non-negotiables

- [ ] **No credential in the repo.** `grep -ri "BEGIN PRIVATE KEY\|aps.*key\|asc_api_key" .` returns nothing.
- [ ] **No data lost in the drill.** The data-correctness verdict is "no loss" (or a documented, expected, bounded loss for same-field LWW conflicts).

## How you are graded

This challenge maps to the **Capstone (30%)** and **Career engineering pack (10%)** lines of the assessment matrix, and it is the **Phase IV gate**: the capstone accepted into TestFlight, the chaos-drill postmortem signed off, the portfolio published, and the mock interview completed. Against the capstone's 100-point rubric in `SYLLABUS.md`, this week earns the **TestFlight in 5+ regions (5)** and **chaos-drill postmortem and runbook (10)** lines directly, and validates the multi-platform, offline-first, StoreKit, Widgets/Intents/Live-Activity, and accessibility/Instruments lines you built in prior weeks. Minimum to pass the capstone: **70 / 100**.

The single hardest gate is the chaos drill: a system you cannot break on purpose and recover is a system you have not proven you can operate. The second hardest is landing App Review on the first try — which the readiness audit (Exercise 1) and submitting early (Lecture 1) are designed to ensure.

## What "open-ended" means here

You choose which chaos drill to run (pick the one that exercises your capstone's riskiest contract), which regions' testers to recruit, how to structure the walkthrough, and how to frame the case studies. The challenge is not to match a reference; it is to ship a real app cleanly, prove it survives a real failure, and present it like an engineer who has done this before. The postmortem's honesty and the self-named risks at demo day are where you demonstrate that you understand the system you built — which is, in the end, the entire point of C20.

## This is the end

When the grader confirms your app is live in five regions, watches your walkthrough, reads a postmortem that names a real surprise, and hears you defend the system under questions — you have completed C20 · Crunch Swift. You started on Linux with Swift the language; you finish having shipped a multi-platform SwiftUI app through Apple's gate, survived a documented chaos drill, and assembled a portfolio a senior iOS engineer respects. That is the launch. Go present it.
