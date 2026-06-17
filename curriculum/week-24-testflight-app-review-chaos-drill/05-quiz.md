# Week 24 — Quiz

Thirteen questions. This is the last quiz of C20; it mixes final-week material (App Review, TestFlight, chaos drills, postmortems) with the synthesis a reviewer or interviewer actually asks. Take it with your notes closed. Aim for 11/13. Answer key at the bottom — don't peek.

---

**Q1.** What is App Review best described as?

- A) A code review of your Swift by an Apple engineer.
- B) A shallow contract-compliance check run by a busy human against a guideline document — it checks observable behaviour and the rules, not your architecture.
- C) A security audit of your backend.
- D) A performance benchmark of your app.

---

**Q2.** Your app supports account creation (to authenticate to your backend). Which App Review requirement is easy to forget and a common rejection?

- A) The app must use SwiftUI.
- B) Guideline 5.1.1(v): if the app supports account creation, it must support in-app account deletion that removes server and local data.
- C) The app must be free.
- D) The app must support iPad.

---

**Q3.** Why submit to App Review early in the week rather than on Friday?

- A) Apple reviews faster on Mondays.
- B) The review queue is an external dependency with variable latency — submitting early means a rejection costs you days you have, not your demo day.
- C) Friday submissions cost more.
- D) It doesn't matter when you submit.

---

**Q4.** A reviewer cannot get past your login screen. What single thing most likely prevents this rejection?

- A) Making the app free.
- B) A working demo account's credentials in the App Review notes field.
- C) Removing the login entirely.
- D) Adding more screenshots.

---

**Q5.** Your App Privacy "nutrition label" must:

- A) Declare as much data as possible to look thorough.
- B) Match what the app actually collects — derived from the code; under-declaring is grounds for rejection and removal, over-declaring scares users.
- C) Only be filled in after launch.
- D) Be identical to every other app in your category.

---

**Q6.** What is a chaos drill, and why run one?

- A) A unit test that simulates a failure in isolation.
- B) Injecting a real failure into a running system on purpose, to learn and prove the recovery behaviour before a user discovers it.
- C) A load test at high traffic.
- D) A code review of error-handling paths.

---

**Q7.** In the offline-edit-conflict drill, what is the contract that makes it reproducible?

- A) The two devices reconnect within 60 seconds.
- B) The conflict resolver is a pure, deterministic function of (local, remote, ancestor), so both devices converge to the same note regardless of merge order.
- C) The resolver always prefers the local device.
- D) The backend resolves all conflicts.

---

**Q8.** In the subscription drill, a user is refunded. When should the paywall return?

- A) The next time the device happens to refresh its local `Transaction`.
- B) Immediately, because the server's entitlement record (driven by the App Store Server Notification) flips to de-entitled, and the client gates on the server's record.
- C) Never — refunds don't affect entitlement.
- D) Only after the user restarts the app.

---

**Q9.** A downgrade (yearly → monthly) takes effect when?

- A) Immediately, revoking the yearly plan.
- B) At the next renewal — the user keeps the higher plan they paid for until the period ends; the downgrade is deferred (`pendingPlan`).
- C) Never; downgrades aren't allowed.
- D) Only if the user re-purchases.

---

**Q10.** In the APNs key-rotation drill, what is the correct rollout order?

- A) Retire the old key first, then deploy the new one.
- B) New key first — deploy the new key and confirm pushes deliver, *then* retire the old key — so there is no window where the backend holds only an invalid key.
- C) Delete both keys and regenerate.
- D) The order does not matter.

---

**Q11.** What makes a postmortem *blameless* and *strong*?

- A) It assigns the failure to whoever made the mistake.
- B) It focuses on system gaps (a missing check, no detection path) rather than human blame, and it names a real surprise — the gap between expected and actual.
- C) It concludes "everything worked."
- D) It is as short as possible with no detail.

---

**Q12.** Your chaos drill recovered successfully, but you discovered you had no way to *detect* the failure without a user report. What is the right framing in the postmortem?

- A) Omit it — recovery succeeded, so there's nothing to report.
- B) Name it as the finding: the detection gap is worth more than the successful recovery, and the action item is to add a synthetic prober/alert.
- C) Blame yourself for not watching.
- D) Conclude the system is unreliable.

---

**Q13.** The five-minute walkthrough video and demo day reward the same skill as the senior-iOS mock interview. What is that skill?

- A) Memorizing Apple documentation.
- B) Tracing data flow, naming failure modes, defending tradeoffs with evidence, and being honest about the edge of your knowledge.
- C) Using the most advanced architecture available.
- D) Having the most features.

---

## Answer key

**Q1 — B.** App Review is a shallow contract check by a busy human against the guidelines — observable behaviour and the rules, not your code, architecture, or backend. You pass it by making the happy path obvious and the contract honest. (Lecture 1, §1.)

**Q2 — B.** Guideline 5.1.1(v) requires in-app account deletion for any app that supports account creation, removing server and local data. It is a frequent rejection because it is easy to forget. (Lecture 1, §2.)

**Q3 — B.** The review queue's latency is outside your control. Submitting Monday means a rejection still leaves you the week to land the resubmission; submitting Friday risks your demo day. (Lecture 1, §3.)

**Q4 — B.** A working demo account in the App Review notes is the single highest-leverage anti-rejection move — a reviewer who cannot log in rejects for "could not review." (Lecture 1, §2–3.)

**Q5 — B.** The App Privacy label must match the code: declare every collected type, declare tracking honestly. Under-declaring risks rejection/removal; over-declaring is needless. (Lecture 1, §2.)

**Q6 — B.** A chaos drill injects a *real* failure into a *running* system on purpose, to learn and prove the recovery before a user finds it. A unit test (A) simulates in isolation; the drill exercises the real system. (Lecture 2, §1.)

**Q7 — B.** Determinism is the contract: a pure resolver over (local, remote, ancestor) with a symmetric tiebreak converges the same way on every device, which is what makes the drill's "both end identical" assertion reproducible. (Lecture 2, §2, Drill A; Exercise 2.)

**Q8 — B.** The server is authoritative: the App Store Server Notification de-entitles the user, and the client gates on the server's record, so the paywall returns immediately — not when a stale local Transaction happens to refresh. (Lecture 2, §2, Drill B; Exercise 3.)

**Q9 — B.** Downgrades are deferred to the next renewal — the user keeps the plan they paid for until the period ends. Model it as `pendingPlan`, applied on `.renewed`. (Exercise 3.)

**Q10 — B.** New key first: deploy and confirm the new key delivers, then retire the old one. Retiring first creates a window where the backend holds only an invalid key and every push is silently rejected. (Lecture 2, §2, Drill C.)

**Q11 — B.** A blameless postmortem focuses on system gaps, not human blame, and a strong one names a real surprise — the gap between what you expected and what happened. (Lecture 2, §4.)

**Q12 — B.** The detection gap is the finding, worth more than the successful recovery; the action item (a synthetic prober/alert) prevents the class of silent failure. Naming it shows maturity. (Lecture 2, §4 and the worked postmortem.)

**Q13 — B.** The walkthrough, demo day, and the mock interview all reward tracing data flow, naming failure modes, defending tradeoffs with evidence, and honesty about the edge of your knowledge — the same competence wearing different hats. (Lecture 2, §5.)

---

*Score 11+? You're ready to ship, survive, and present. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the determinism contract and the server-authoritative entitlement are the two ideas the chaos drill grades on. Then go ship the capstone. This is the last quiz of C20.*
