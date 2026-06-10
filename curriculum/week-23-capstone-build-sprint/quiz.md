# Week 23 — Quiz

Thirteen questions. This is the capstone build-sprint quiz; it mixes integration and architecture-review material with the synthesis questions a reviewer or interviewer actually asks. Take it with your notes closed. Aim for 11/13 before the Friday sign-off. Answer key with explanations at the bottom — don't peek.

---

**Q1.** In an architecture review, what is the *output* of the meeting — the thing that means the review succeeded?

- A) A polished slide deck.
- B) A prioritized risk list, each item tagged accept / fix-now / fix-later, with owners.
- C) Sign-off that the architecture is perfect.
- D) A recording of the presentation.

---

**Q2.** Why does the capstone keep the shared model types in a single `NotesCore` SwiftPM package imported by both the SwiftUI client and the Vapor backend?

- A) It makes the app build faster.
- B) So a schema change is a compile error on both sides, keeping client and server in agreement without a hand-maintained API doc.
- C) Because SwiftData requires it.
- D) To reduce the app's binary size.

---

**Q3.** The capstone syncs over CloudKit as the primary path. Which SwiftData schema constraint does CloudKit impose?

- A) All properties must be `@Attribute(.unique)`.
- B) Relationships must be optional, no `@Attribute(.unique)`, and the schema must be additive-only once in production.
- C) The schema must use Core Data directly, not SwiftData.
- D) There are no constraints; CloudKit accepts any SwiftData schema.

---

**Q4.** What makes the capstone's conflict-resolution policy correct for a chaos drill that asserts two devices end up identical?

- A) It always prefers the local device's edit.
- B) It reads the wall clock to break ties.
- C) It is a pure, deterministic function of (local, remote, ancestor), so any device merging in any order converges to the same result.
- D) It runs on the server only.

---

**Q5.** A user edits five notes offline, then comes back online. What should happen?

- A) The app blocks until the network returns, then submits.
- B) Each edit is durable in SwiftData immediately; an outbox replays them idempotently when connectivity returns; the UI never blocked.
- C) Only the last edit is kept; the others are discarded.
- D) The app shows an error and asks the user to retry each edit.

---

**Q6.** A staff reviewer asks "how does the server know the subscription is real?" Which answer is correct?

- A) The client checks `Transaction.currentEntitlements` and tells the server it paid.
- B) The client sends the signed `Transaction.jsonRepresentation`; the Vapor backend verifies the JWS signature against Apple's keys and records the entitlement — the server fact is authoritative, the client check is a UX hint.
- C) The App Store emails the server a receipt.
- D) StoreKit handles validation entirely on-device; the server is not involved.

---

**Q7.** What is an Architectural Decision Record (ADR), and why write one?

- A) A test report; it proves the code works.
- B) A short, dated, immutable document recording one decision's context, options, choice, and consequences — so the *why* survives, and a decision you can't defend is one you got lucky on.
- C) A performance benchmark.
- D) A list of bugs to fix later.

---

**Q8.** The runbook's "3 AM, the push pipeline is silently broken" walk should begin with what?

- A) "I'd look at the logs."
- B) A single first check that bisects the problem — e.g. `curl /health` to separate a backend outage from a push-path failure — followed by a decision tree.
- C) A full rewrite of the push code.
- D) Paging the entire team.

---

**Q9.** Why does the feature-flag killswitch default a *new, risky* feature to OFF?

- A) Because new features are always broken.
- B) So a backend outage (or a fresh install that can't reach the backend) can only make the app more conservative, never expose users to a feature you might need to kill.
- C) To save bandwidth.
- D) Because Apple requires all features to default off.

---

**Q10.** You upload the release candidate to TestFlight **internal** testing rather than external this week. Why?

- A) Internal testing is cheaper.
- B) Internal testing needs no App Review, so you can validate the real Release-signed distribution build on real devices now; external beta (the five regions) needs a Beta App Review pass, which is next week.
- C) External testing doesn't exist for paid apps.
- D) Internal builds skip code signing.

---

**Q11.** App Store Connect rejects an upload as a duplicate. What is the most likely cause?

- A) The marketing version is too high.
- B) You reused the same `(MARKETING_VERSION, CURRENT_PROJECT_VERSION)` pair — the build number must increment on every upload, even for the same marketing version.
- C) The app is too large.
- D) The bundle ID is wrong.

---

**Q12.** A reviewer asks "where can you lose a write, and how much?" Which answer reads as senior?

- A) "It can't lose data; it's fully synced."
- B) Naming the *window* at each hop: a crash-before-save window of one in-flight edit, a partial-drain window recovered by idempotent retry, and a conflict window resolved to one field by the tiebreak.
- C) "CloudKit handles all of that."
- D) "I haven't thought about data loss."

---

**Q13.** The single highest-leverage move a candidate can make in an architecture review is:

- A) Use the most advanced architecture (TCA) to look sophisticated.
- B) Name their own biggest risk before the reviewer asks, with the cost to fix it.
- C) Avoid mentioning any weaknesses so the design looks flawless.
- D) Bring the most detailed possible diagram with every internal class.

---

## Answer key

**Q1 — B.** A review exists to surface the risks that would otherwise show up in production over six months. The deliverable is a tagged, owned risk list. A review without one failed, no matter how good the slides. (Lecture 1, §3.)

**Q2 — B.** The shared `NotesCore` package is the wire contract: both client and server import the same `Codable, Sendable` struct, so a field change is a compile error on both sides instead of a runtime drift caught in production. (Lecture 1, §1.)

**Q3 — B.** CloudKit requires all relationships optional, forbids `@Attribute(.unique)`, and only allows additive schema changes once the schema is in the CloudKit production environment. Violating these makes sync silently stop. (Lecture 1, §2; ADR-0002.)

**Q4 — C.** Determinism is the contract: the resolver is a pure function of (local, remote, ancestor) with a symmetric, value-based tiebreak, so every device converges to the same note regardless of merge order. A clock read or an order-dependent tiebreak breaks convergence. (Lecture 2, §1; Exercise 2.)

**Q5 — B.** Local-first: the write is durable in SwiftData immediately and the UI reflects it without blocking; an idempotent outbox replays to CloudKit and Vapor when the network returns. This is the Week 13 offline write-replay skill. (Lecture 1, §5.)

**Q6 — B.** Server-side validation: the client sends the signed `Transaction.jsonRepresentation`, the backend verifies the JWS against Apple's keys, and the *server's* record is the authoritative entitlement. A client claim is trivially spoofable. (Lecture 2, §1, ADR-0004.)

**Q7 — B.** An ADR records one decision's context, options, choice, and consequences, dated and immutable, so the reasoning survives. The discipline is that a decision you cannot defend is one you got lucky on. (Lecture 2, §1.)

**Q8 — B.** The 3 AM walk opens with one first check that bisects the failure (e.g. `/health` to separate backend-down from push-path), then a decision tree. "Look at the logs" is too vague; the reviewer reads the first line to judge whether your observability answers "what's wrong" in one look. (Lecture 2, §2.5.)

**Q9 — B.** Fail safe: stable, load-bearing features default ON (the app must work offline); new, risky features default OFF so a backend outage can only make the app more conservative, never turn on a half-baked feature. (Lecture 2, §2.3; Exercise 3.)

**Q10 — B.** Internal TestFlight testing needs no App Review, so you validate the real Release-signed distribution build on devices this week; external beta in five regions needs a Beta App Review pass, which is next week's work. (Lecture 2, §3.3.)

**Q11 — B.** App Store Connect rejects a duplicate `(version, build)` pair. The build number must increment on every upload even within the same marketing version; the CI lane bumps it from the latest TestFlight build number. (Lecture 2, §3.1.)

**Q12 — B.** Naming the data-loss *window* at each hop — in time or in writes, mitigated by explicit save and idempotent retry — is the senior answer. "It can't lose data" is the answer the reviewer disbelieves and digs into. (Lecture 1, §6; Exercise 1.)

**Q13 — B.** Surfacing your own biggest risk before being asked demonstrates that you understand the system's weaknesses and sets the agenda. Juniors think their design is flawless; seniors name the bodies. (Lecture 1, §7.)

---

*Score 11+? You're ready for the Friday sign-off. Below 9? Re-read both lecture notes and re-run exercises 2 and 3 — the deterministic-conflict contract and the fail-safe killswitch are the two ideas this week's review grades on.*
