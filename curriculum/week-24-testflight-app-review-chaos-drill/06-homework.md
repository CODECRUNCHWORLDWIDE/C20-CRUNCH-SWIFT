# Week 24 Homework

This is the last homework of C20, and it is not "more problems" — it is the set of final-week deliverables that the ship-and-survive mini-project does not already produce on its own. Each is a concrete artifact a hiring manager or a staff reviewer will read. The full set should take about **5 hours** across the week. Work in your capstone repo so each deliverable is a commit you can point to.

Each problem includes a **statement**, **deliverable**, **acceptance criteria**, a **hint**, and an **estimated time**. The rubric at the bottom is how the week is graded.

---

## Problem 1 — The chaos-drill postmortem

**Statement.** Run one chaos drill (offline conflict, subscription edges, or APNs rotation) against your live system, then write `postmortem.md` from the measured timeline, following the Lecture 2, §4 structure.

**Deliverable.** A complete `postmortem.md`.

**Acceptance criteria.**

- [ ] The measured timeline is filled in: t0, t_fault, t_detect, t_recover, recovery_seconds.
- [ ] The "what we expected" and "what actually happened" sections name the measured numbers, not estimates.
- [ ] The "gap" section names a real surprise (the valuable part), even if recovery succeeded.
- [ ] A data-correctness verdict ("no loss," or a documented expected bounded loss).
- [ ] At least two action items, each tagged accept/fix-now/fix-later and owned.
- [ ] The tone is blameless — every action item survives the "replace the person with the component" test.

**Hint.** The strongest postmortems name a surprise. If the rotation recovered but you had no *detection* path without a user report, that gap is the finding, and "add a synthetic prober" is the action item. Run the drill both the safe way and (deliberately) the wrong way if it teaches you the failure — the APNs rotation does. (Lecture 2, §4 and the worked example.)

**Estimated time.** 60 minutes.

---

## Problem 2 — The App Review submission record

**Statement.** Document your submission in `docs/submission.md`: the readiness audit result (link to Exercise 1's committed audit), the review notes you used (with the demo account redacted), the submission date, and the outcome (passed first try, or the rejection citation and your fix).

**Deliverable.** `docs/submission.md`.

**Acceptance criteria.**

- [ ] Links to the committed, all-PASS readiness audit (Exercise 1).
- [ ] The App Review notes are recorded (credentials redacted), including the demo account, the subscription-sandbox note, and the locations of the Pro gate and account deletion.
- [ ] The submission date and the queue outcome are recorded.
- [ ] If rejected, the exact guideline citation and your specific fix are documented.
- [ ] The TestFlight external build links for all five regions are in the README.

**Hint.** If you landed on the first try, say what you did to pre-empt the common rejections — that is a portfolio signal. If you were rejected, the honest write-up of the citation and your fix is *more* valuable for the portfolio than a clean pass with no story, because it shows you can read a rejection and respond. (Lecture 1, §3, §5.)

**Estimated time.** 45 minutes.

---

## Problem 3 — The five-minute walkthrough script

**Statement.** Write the *timed script* for your five-minute walkthrough video — the trace-one-write narration from Lecture 2, §5 — then record the video and link it in the README.

**Deliverable.** `docs/video-script.md` (the timed script) and a link to the recorded video in the README.

**Acceptance criteria.**

- [ ] The script is timed and stays under five minutes read aloud at a normal pace (~750 words).
- [ ] It traces one real write through the app on three platforms, plus the Widget, App Intent, Live Activity, subscription, and offline-first sync.
- [ ] It narrates the *mechanism* at each hop, not just the action.
- [ ] The recorded video is linked and watchable.

**Hint.** Pre-stage the data (devices signed in, sample notes created, sandbox account ready) so you are not typing on camera. Have a fallback recording of the sync step in case live sync stalls. People read ~150 words/minute, so cut to ~750 words. (Lecture 2, §5.)

**Estimated time.** 60 minutes (plus the recording session).

---

## Problem 4 — The three portfolio case studies

**Statement.** Write `portfolio/<app>/case-study.md` for each of the three apps (Notes v1, Notes Pro v1, the capstone). Each covers: problem framing, key architectural decisions, the hardest bug, the production metric, and a screenshot strip.

**Deliverable.** Three `case-study.md` files.

**Acceptance criteria.**

- [ ] Three case studies, one per app, each with all five sections.
- [ ] The "hardest bug" section names a *real* bug and how you found and fixed it (e.g. a re-render storm found in Instruments).
- [ ] The "production metric" section names a measured number (a hitch eliminated, a fetch sped up, a drill recovery time).
- [ ] Each is readable by someone who has never seen the code — they learn what was hard and what you decided.

**Hint.** The hardest-bug and production-metric sections are what read as senior. "The hardest bug was a re-render storm; I found it with the SwiftUI Instruments template and fixed it by correcting state ownership; list scroll went from dropped frames to a clean 120fps" is concrete, measured, and honest. Anyone can list features; few can do that. (Lecture 2, §6.)

**Estimated time.** 75 minutes.

---

## Problem 5 — The mock-interview retrospective

**Statement.** Complete the senior-iOS mock interview (one system-design round, one deep-dive round), then write `interview-prep/mock-interview-retro.md`: the two questions you answered well, the one you fumbled, and what you would say differently.

**Deliverable.** `interview-prep/mock-interview-retro.md`.

**Acceptance criteria.**

- [ ] Names two questions you answered well and why.
- [ ] Names one question you fumbled — honestly.
- [ ] States the concrete better answer to the fumble.
- [ ] Is honest — a retro that says "I nailed everything" fails this problem.

**Hint.** The fumble is the valuable part. The most common mistakes are jumping to a solution before establishing requirements, and bluffing on the deep-dive. If you did either, name it, and write the requirements-first or "I'm not certain, my mental model is X" version you'd give next time. That metacognition is the same skill as turning a review's risk list into a known-limitations section. (Lecture 2, §5.)

**Estimated time.** 45 minutes (plus the interview).

---

## Problem 6 — The course retrospective

**Statement.** Write a one-page `RETROSPECTIVE.md`: what you can do now that you couldn't on day 1, the hardest week, the most valuable skill, and one thing you'd go deeper on next. This is your own postmortem on the whole course.

**Deliverable.** `RETROSPECTIVE.md` in the capstone repo.

**Acceptance criteria.**

- [ ] Names at least three concrete capabilities you have now (e.g. "I can trace one write through five platforms and name the data-loss window at each").
- [ ] Names the hardest week and what made it hard.
- [ ] Names the single most valuable skill the course built.
- [ ] Names one thing you'd go deeper on (and the recommended next track from the README).
- [ ] Is honest and specific, not a victory lap.

**Hint.** Map your capabilities to the twelve from the track README — strict concurrency, SwiftUI state ownership, offline-first SwiftData + CloudKit, Combine vs async/await, navigation, networking, MVVM/TCA, Instruments, CI, WidgetKit/App Intents/ActivityKit, StoreKit, App Review. Which of those can you now do without notes? That is your honest "what I can do now."

**Estimated time.** 35 minutes.

---

## Rubric

Graded out of 100. This homework is the final deliverable scaffolding for the capstone and the career pack, so the weights mirror the capstone's emphasis on surviving and presenting.

| Problem | Artifact | Points | What earns full marks |
|---|---|---:|---|
| 1 | `postmortem.md` | 25 | Measured timeline + blameless prose + named surprise + data verdict + owned, tagged action items. |
| 2 | `docs/submission.md` | 15 | Audit linked + review notes + date + outcome (first-try pass, or citation + fix); five-region links in README. |
| 3 | video script + video | 20 | Timed <5-min script narrating one write by mechanism; the video recorded and linked. |
| 4 | three case studies | 20 | All five sections each; a real hardest bug and a measured production metric per app. |
| 5 | mock-interview retro | 10 | Two strengths, one honest fumble, a concrete better answer. |
| 6 | `RETROSPECTIVE.md` | 10 | Honest, specific; three capabilities, the hardest week, the key skill, the next step. |

**Passing the week** requires ≥70 on this rubric *and* a capstone that is live in TestFlight in five regions *and* a chaos drill survived with a signed-off postmortem (the mini-project / Challenge 1 gate). The three are scored together: a perfect homework with an app that never shipped, or a drill that lost data, does not pass — because the whole point of the final week is a real, shipped, survived launch.

**Deductions.** Any credential found in the repo: −20 and a required fix. Data lost in the drill (beyond a documented, expected, bounded same-field LWW conflict): −20 and a required fix. A postmortem that assigns human blame instead of naming system gaps: −10. A video that exceeds five minutes or narrates actions without mechanisms: −5. These are the production-shop non-negotiables; the deductions are deliberately harsh because in a real launch they are incidents.

---

*This is the last rubric of C20. When these deliverables are committed and your capstone is live, survived, and presented, you have completed the course. Ship it, survive the drill, present it — and welcome to the other side of the launch.*
