# Week 23 Homework

This is the build-sprint homework, and it is not "more problems" — it is the set of capstone deliverables that the integration build itself does not already produce. Each one is a concrete artifact a staff reviewer or a hiring manager will read. The full set should take about **5 hours** spread across the week. Work in your capstone repo so each deliverable is a commit you can point to.

Each problem includes a **statement**, **deliverable**, **acceptance criteria**, a **hint**, and an **estimated time**. The rubric at the bottom is how the week is graded.

---

## Problem 1 — The one-page architecture diagram

**Statement.** Draw the capstone architecture as a single-page Mermaid diagram in `diagram.md`. Boxes are components, arrows are data flow, every arrow labeled with the protocol and whether it is sync or async. If it doesn't fit on one page, your mental model is too detailed — abstract until it does.

**Deliverable.** `diagram.md` with a Mermaid `flowchart` that renders in GitHub.

**Acceptance criteria.**

- [ ] Shows the five client targets, the data layer (SwiftData + SyncEngine + NotesClient + ConflictResolver), the shared `NotesCore` package, CloudKit, APNs, StoreKit, and the Vapor + Postgres backend.
- [ ] Every arrow is labeled (e.g. `CloudKit private DB`, `HTTPS retry+jitter`, `APNs push`, `gRPC`/`WebSocket`), with sync vs async distinguished.
- [ ] Renders without syntax errors in the GitHub Mermaid preview.
- [ ] Hand it to someone who hasn't seen the system; they can trace one write off it without your narration.

**Hint.** Start from the integration map in Lecture 1, §1. A skeleton:

```mermaid
flowchart LR
  iphone[iPhone] & ipad[iPad] & mac[Mac] & watch[watchOS] & vision[visionOS]
  iphone -->|@Query / @Bindable| data[Data layer: SwiftData + SyncEngine]
  data -->|CloudKit private DB| ck[(CloudKit)]
  data -->|HTTPS retry+jitter| vapor[Vapor + Postgres]
  ck -.->|push sync| ipad
  vapor -->|APNs push| nse[NSE -> Live Activity]
  vapor -->|JWS verify| storekit[App Store Server API]
  core[[NotesCore shared package]] --- data
  core --- vapor
```

**Estimated time.** 45 minutes.

---

## Problem 2 — The four ADRs

**Statement.** Write the four architectural decision records under `docs/adr/`, following the Lecture 2, §1 template: architecture (plain `@Observable` vs MVVM vs TCA), sync primary (CloudKit vs Vapor), conflict-resolution policy, and StoreKit validation flow. Each is one page: context, options, decision, consequences.

**Deliverable.** `docs/adr/0001-architecture.md` through `docs/adr/0004-storekit-validation.md`.

**Acceptance criteria.**

- [ ] Four ADRs, each with the four sections and a `Status: Accepted` + date header.
- [ ] ADR-0001 names a *threshold* at which you'd switch architectures (the sentence that makes it a decision, not a default).
- [ ] ADR-0002 records the CloudKit schema constraint as a consequence (e.g. losing `.unique` on `Tag.name`).
- [ ] ADR-0003 states the resolver is a pure function of (local, remote, ancestor) and links to Exercise 2's test; if you shipped last-writer-wins, it honestly records that a concurrent edit is lost.
- [ ] ADR-0004 distinguishes the authoritative server entitlement from the client-side UX hint.

**Hint.** The hardest part is the *consequences* section — it must be honest about what got *worse*. "I chose CloudKit-primary; the consequence is I gave up the `.unique` constraint and enforce tag uniqueness in app code" is exactly the kind of honest trade a reviewer respects. (Lecture 2, §1.)

**Estimated time.** 75 minutes.

---

## Problem 3 — The production runbook

**Statement.** Write `production-runbook.md` following Lecture 2, §2: the on-call surface table, the five most likely outages, the three rollback procedures, the beta-cohort comms template, and the 3 AM walk with a single first check.

**Deliverable.** `production-runbook.md`.

**Acceptance criteria.**

- [ ] The on-call surface table covers APNs, CloudKit, Vapor, StoreKit / Server Notifications, and the App Store Connect API, each with "what breaks" and "how you detect it."
- [ ] Five outages, each with symptom → likely cause → first action.
- [ ] Three rollbacks (TestFlight build, App Store build via killswitch, Vapor deploy), each with a mechanism and a rough time.
- [ ] A SEV-N comms template that leads with user impact and an ETA.
- [ ] A 3 AM walk that opens with one bisecting first check, not "look at the logs."

**Hint.** The strongest runbooks are honest about the *detection* gaps. If you don't have a synthetic APNs prober, your detection for "silent push outage" is "a user reports it" — say so, and put the prober in the known-limitations list. A named gap is more credible than a pretended coverage. (Lecture 2, §2.1.)

**Estimated time.** 60 minutes.

---

## Problem 4 — The known-limitations section

**Statement.** After Friday's architecture review (Challenge 1), turn the risk list into a "Known limitations and next steps" section in your repo README. List the three things you'd fix before real traffic, prioritized, each tagged accept/fix-now/fix-later, with the cost of each.

**Deliverable.** A "Known limitations and next steps" section in the repo README.

**Acceptance criteria.**

- [ ] At least three limitations, each with a tag and a cost-to-fix (engineer-time or dollars).
- [ ] Every "fix now" item is actually fixed before the RC is locked (cross-reference the commit).
- [ ] The tone is honest, not defensive — these are next steps, not apologies.
- [ ] At least one limitation names something you did *not* instrument (the most credible kind).

**Hint.** The honest self-named risks for this capstone are usually last-writer-wins dropping a concurrent edit, no external push prober, and single-region Vapor (Lecture 1, §7–8). Name yours, not the template's. Hiring managers read the limitations section first, because it is where they learn whether you can think.

**Estimated time.** 45 minutes.

---

## Problem 5 — Lock the release candidate

**Statement.** Drive the `release_candidate` fastlane lane (Lecture 2, §3) to upload a Release-signed build to TestFlight internal testing, tag the commit `v1.0.0-rc1`, and record the result in `docs/release-candidate.md`: the build number, the TestFlight link, the test-suite result, and the export-compliance answer.

**Deliverable.** `docs/release-candidate.md` plus the tag and the TestFlight internal build.

**Acceptance criteria.**

- [ ] The full Swift Testing + XCUITest + snapshot suite is green (zero failures) — paste the summary.
- [ ] A Release-configuration build is in TestFlight internal testing (link recorded).
- [ ] The commit is tagged `v1.0.0-rc1` and the doc maps the build number to the tag.
- [ ] `ITSAppUsesNonExemptEncryption` is set and the value is justified in one sentence.
- [ ] The build installs and runs on a real device, behaving like the debug build.

**Hint.** If the upload is rejected as a duplicate, you reused a `(version, build)` pair — bump the build number from `latest_testflight_build_number(version: "1.0.0") + 1`. If signing fails in CI, the distribution certificate or App Store provisioning profile isn't available to the runner; that's a `match`/keychain issue, not a code issue. (Lecture 2, §3.)

**Estimated time.** 60 minutes (plus build-processing wait).

---

## Problem 6 — The interview-prep system-design pack

**Statement.** Turn your capstone into whiteboard answers. Pick **three** of the six mobile system-design prompts and write a one-page reference solution each, naming the actual Apple frameworks your capstone uses: (a) "design a multi-device journaling app," (b) "design a push pipeline that survives an APNs outage," (c) "design offline photo sync for a family," (d) "design a Live Activity for a food-delivery order," (e) "design multi-device conflict resolution," (f) "design a StoreKit subscription with server validation."

**Deliverable.** `interview-prep/system-design.md` with three one-page answers.

**Acceptance criteria.**

- [ ] Three prompts answered, each opening with requirements clarification (scale, consistency, offline behaviour, consequence of data loss) *before* the design.
- [ ] Each names real Apple frameworks (SwiftData, CloudKit, APNs, StoreKit, BackgroundTasks, ActivityKit), not generic "a database / a queue."
- [ ] At least one answer reuses your capstone as the reference solution and says so.
- [ ] Each names one failure mode and how the design handles it.

**Hint.** The most common system-design mistake is jumping to a solution before establishing requirements (Lecture 1, §6 — the same mistake as the review). Spend the first paragraph on "how many devices, what consistency, what's the offline expectation, what happens if a sync loses an edit," then design. Your capstone *is* the reference answer for prompts (a) and (e) — you built and defended it.

**Estimated time.** 50 minutes.

---

## Rubric

Graded out of 100. This homework is the deliverable scaffolding for the capstone, so the weights mirror the capstone's emphasis on integration, defense, and a shippable build.

| Problem | Artifact | Points | What earns full marks |
|---|---|---:|---|
| 1 | `diagram.md` | 15 | One page, all components, every arrow labeled sync/async, renders in GitHub, traceable by a stranger. |
| 2 | four ADRs | 20 | Each has context/options/decision/consequences; ADR-0001 names a switch threshold; consequences are honest about what got worse. |
| 3 | `production-runbook.md` | 20 | On-call surface + five outages + three rollbacks + comms template + one-line-first-check 3 AM walk; detection gaps named honestly. |
| 4 | known-limitations | 15 | Three+ tagged, costed limitations; fix-now items fixed; at least one names an un-instrumented gap. |
| 5 | `docs/release-candidate.md` | 20 | Green suite + Release build in TestFlight internal + tagged commit + justified encryption answer + runs on device. |
| 6 | `interview-prep/system-design.md` | 10 | Three prompts, requirements-first, real frameworks named, a failure mode each. |

**Passing the week** requires ≥70 on this rubric *and* a passing architecture-review sign-off (Challenge 1) *and* a locked release candidate. The three are scored together: a perfect homework with no signed-off architecture, or with an RC that won't build green, does not pass — because the whole point of the sprint is a build that is *ready to ship next week*.

**Deductions.** Any credential found in the repo: −20 and a required fix. A non-deterministic conflict resolver (Exercise 2's order-independence test fails): −15 and a required fix. An ADR that records no consequences (a decision with no honest trade): −5 each. A runbook 3 AM walk that opens with "look at the logs": −5. These are the production-shop non-negotiables; the deductions are deliberately harsh because in a real shop they are incidents.
