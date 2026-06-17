# Challenge 1 — The architecture-review sign-off

> **Estimated time:** ~90–120 minutes including prep. **This is the assessed architecture sign-off for the capstone.** No solution is provided — only the agenda and the bar, because in a real review nobody hands you the answer key.

You will deliver the **live architecture review** for your capstone — the Offline-First Cross-Device Productivity Suite — and earn the sign-off that lets it proceed to Week 24's App Review submission. "Live" is the operative word. The reviewer (a cohort lead, a peer panel, or a recorded camera a hiring manager will eventually watch) does not read your diagram and award points. They watch you trace one write through the running system on two devices, they ask the staff-engineer questions, and they decide whether they would trust this design in front of users.

This is harder than the exercises in two specific ways: (1) you must trace a real write through every hop **live, on two devices**, narrating the mechanism and the failure mode at each, and (2) you must **surface your own biggest risks before the reviewer finds them** — the move that separates an engineer who built an app from one who has operated one.

## What you deliver

Run the hour from Lecture 1, §5. Bring the five artifacts from §4:

- **The one-page architecture diagram** (Mermaid in your repo README), every arrow labeled with protocol and direction (sync vs async).
- **The four ADRs** (`docs/adr/0001`–`0004`): architecture, sync primary, conflict policy, StoreKit validation.
- **The production runbook** (`production-runbook.md`): on-call surface, five outages, three rollbacks, comms template, 3 AM walk.
- **The test + perf evidence**: the green Swift Testing + XCUITest + snapshot run from CI, and the Instruments evidence (no hitches in a 60-second scroll, no hangs in five minutes of use).
- **The known-limitations list**: the three things you'd fix before real traffic, prioritized, with the cost of each.

## The agenda you run (the hour)

| Minutes | Segment | What happens |
|--------:|---------|--------------|
| 0–5 | Context | What the app is for, who uses it, on how many devices, the consequence of a lost sync. |
| 5–15 | Diagram walk | The one-page diagram, left to right; establish the shape, not the mechanism. |
| 15–35 | **Trace one write** | One note edit, live, on two devices, through all eight hops (Exercise 1). The heart of the review. |
| 35–50 | Failure modes | Off the happy path: offline, CloudKit/Vapor disagreement, conflict, the data-loss window at each hop. |
| 50–58 | Ops & runbook | The 3 AM walk, the three rollbacks, the killswitch, what pages you. |
| 58–60 | Risk list | The reviewer tags each risk accept/fix-now/fix-later with an owner. You write them down. |

## Acceptance criteria (the reviewer checks every one)

### The live demo

- [ ] **Trace one write on two devices, live.** Edit a note offline on device 1; bring it online; show it land on device 2, resolved correctly; show the Widget reload and (if shared) the Live Activity update. Narrate the mechanism and the failure mode at each of the eight hops.
- [ ] **A concurrent edit is resolved deterministically.** Edit the same note on both devices; show the merge converge to the same result on both, and point at the `ConflictResolver` test (Exercise 2) that proves order-independence.

### The artifacts

- [ ] **The diagram is one page** and every arrow is labeled. Hand it to someone who has never seen the system; they can trace one write out loud. If they stall on an unlabeled edge, you fix it before the review, not during.
- [ ] **The four ADRs exist**, each with context, options, a decision, and honest consequences. The reviewer reads *why* for every hard choice.
- [ ] **The runbook answers the 3 AM question in one first check**, not "I'd look at the logs."
- [ ] **The test suite is green** in CI (zero failures across unit, UI, snapshot) and the perf evidence shows no hitches/hangs.

### The defense

- [ ] **You surface your own three biggest risks before being asked** (Lecture 1, §7): last-writer-wins / no external push prober / single-region Vapor — or the honest equivalents for your build, each with the cost to fix.
- [ ] **You answer the question bank** (Lecture 1, §6) without bluffing. "I'm not certain of the exact mechanism, but my mental model is X, and here's why it matters" is a strong answer; a confident guess is a weak one.
- [ ] **No credential in the repo.** `grep -ri "BEGIN PRIVATE KEY\|aps.*key\|asc_api_key" .` returns nothing.

### The output

- [ ] **A tagged risk list** is produced and committed as the README's "Known limitations and next steps" section, each item owned and tagged accept/fix-now/fix-later.
- [ ] **Every "fix now" item is fixed** before you lock the release candidate (Lecture 2, §3).

## How you are graded

This challenge is the capstone's **architecture-sign-off gate** (the SYLLABUS "final architecture sign-off"). The single hardest part is the live trace — a system you cannot walk a write through, on two devices, in front of a reviewer, is a system you have not integrated. The second hardest is the self-named-risk move: candidates who pretend the design is flawless read as junior; candidates who name the bodies read as senior.

## What "open-ended" means here

There is no single right architecture. Within the capstone spec, you make and defend choices: plain `@Observable` vs TCA, CloudKit-primary vs Vapor-primary sync, last-writer-wins vs field-merge, the StoreKit validation path, the watchOS connectivity strategy. The challenge is not to match a reference; it is to make defensible choices, prove them in the trace and the tests, and explain the tradeoffs in the review. The ADRs and the self-named risks are where you demonstrate that you understand the choices you made — which is, in the end, the entire point of the capstone.

## Where this reappears

This review is the rehearsal for two things in Week 24: **demo day** (the same trace-one-write walk, recorded as the 5-minute video) and the **senior-iOS mock interview** (the same skill — trace data flow, name failure modes, defend tradeoffs with evidence, be honest about what you don't know — applied to a system you design on the spot instead of one you built). Nail the review and the hardest parts of the final week are already in your hands.
