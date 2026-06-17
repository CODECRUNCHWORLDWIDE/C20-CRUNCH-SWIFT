# Mini-Project — The Capstone Build Sprint

> Assemble every prior-phase artifact — the shared `NotesCore` package and Vapor backend from Phase I, the SwiftUI + SwiftData notes app from Phase II, the networking + Keychain + CloudKit + StoreKit + APNs work from Phase III, and the multi-platform targets, Widgets, App Intents, and Live Activity from Phase IV — into one multi-platform system: the **Offline-First Cross-Device Productivity Suite**. Integrate it, harden it, trace one write through every hop, defend it in a live architecture review, write the four ADRs and the production runbook, and lock a release-candidate build in TestFlight internal testing — so Week 24 ships rather than scrambles.

This is the capstone build sprint. It is **not a new build**; it is the integration of twenty-two weeks of compounding work into one system you can stand up, demonstrate on five Apple platforms, defend, and submit. By the design of this track the mini-projects compound — by Week 10 you extended the Week 8 app, by Week 18 you added push and IAP to the same codebase. Week 23 is where the compounding pays off. If you kept your architecture clean and your tests green every week, this week is assembly and proof. If you took shortcuts, this is where you pay for them.

The full capstone specification — the technical bar, the deliverables, the chaos-drill menu, and the 100-point rubric — is in [`SYLLABUS.md` § Capstone](../../../SYLLABUS.md#capstone). This mini-project covers the **build and defense** half (integration, ADRs, runbook, RC); next week's mini-project covers the **ship** half (App Review, chaos drill, postmortem, demo day).

**Estimated time:** ~15.5 hours of the week's schedule (Monday through Saturday mini-project blocks), on top of the exercises and the Friday review.

---

## What you assemble

You already have, from the prior phases, a set of artifacts. The sprint wires them into one workspace and proves the whole thing works together on five platforms.

### The artifacts you compose (from prior weeks)

- `NotesCore` — Week 6. The shared SwiftPM package of `Codable, Sendable` model DTOs, imported by every client target *and* the Vapor backend.
- `notes-api` — Week 5, deployed in Phase III. The Vapor REST + WebSocket service over Postgres, with structured logging, a `/health` endpoint, and StoreKit receipt validation.
- **Notes v1** — Week 12. The SwiftUI iPhone + iPad + Mac app with SwiftData, value-typed navigation, deep links, search, and tag filtering.
- **Notes Pro v1** — Week 18. The `NotesClient` actor (offline write-replay, retries+jitter, certificate pinning), Keychain credential storage, CloudKit sync with a conflict-resolution policy, the StoreKit 2 subscription, the APNs pipeline, and the Notification Service Extension.
- The **Phase IV additions** — Weeks 19–22. The macOS-native, watchOS, and visionOS targets; the Home Screen and Lock Screen Widgets; the `AddNote` App Intent; the shared-edit Live Activity; and the GitHub Actions CI pipeline with fastlane.

### A note on the product domain

The capstone spec fixes the *technical* bar but leaves the *product* open: you may build a note suite, a focus-timer suite, a journaling suite, a habit tracker, a workout logger, a recipe planner, or any productivity surface you can defend in scope review. This README uses a notes suite as the running example because it is the app you compounded across the track, but if your capstone is a habit tracker, read "note" as "habit entry" throughout — the contracts (local-first write, deterministic conflict resolution, server-validated subscription, push-to-Live-Activity) are identical regardless of the domain. Pick the domain you can demonstrate and defend; the engineering is the same.

### The workspace that ties them together

```text
NotesSuite.xcworkspace
├── NotesCore/                 # SwiftPM package: models + SyncEngine + NotesClient + ConflictResolver
│   ├── Sources/NotesCore/
│   └── Tests/NotesCoreTests/  # the resolver tests (Exercise 2) live here
├── NotesApp/                  # iOS + iPadOS app target  (imports NotesCore)
├── NotesMac/                  # macOS-native app target   (imports NotesCore)
├── NotesWatch/                # watchOS companion         (imports NotesCore)
├── NotesVision/              # visionOS window           (imports NotesCore)
├── NotesWidgets/             # WidgetKit extension        (imports NotesCore)
├── NotesNSE/                 # Notification Service Extension (imports NotesCore)
├── docs/
│   ├── adr/0001-architecture.md … 0004-storekit-validation.md
│   └── trace-one-write.md     # Exercise 1
├── production-runbook.md      # Lecture 2, §2
├── diagram.md                 # one-page Mermaid architecture diagram
├── fastlane/Fastfile          # the release_candidate lane (Lecture 2, §3)
└── README.md                  # overview + known-limitations section
```

The integration discipline the review checks: **shared code lives in `NotesCore`, target-specific code lives in the target.** The `ConflictResolver`, the `NotesClient`, the `SyncEngine`, and the `Note` model are compiled once in the package and imported five times. A watchOS complication or a visionOS `ImmersiveSpace` is target-specific. If the same conflict logic is copy-pasted into two targets, that is an integration bug.

---

## The end-to-end write you must demonstrate

One note edit, traced through every hop. This is the trace-one-write walk from Lecture 1, §5, and Exercise 1, and it is what your Friday review and next week's 5-minute video both show:

1. **Edit.** The user types in a note's body on the iPhone, offline. `@Bindable` mutates the `@Model`; `onChange` stamps `updatedAt`. Re-renders exactly once.
2. **Local durability.** `modelContext.save()` on commit — durable in SwiftData before anything touches the network.
3. **Outbox.** The `SyncEngine` enqueues a pending sync op, deduped by note id.
4. **Connectivity returns.** `NWPathMonitor` fires; the engine drains the outbox.
5. **Remote write.** CloudKit (the sync primary) and the Vapor backend (the fallback, via the `NotesClient` actor) each receive the write, idempotently.
6. **Other device.** CloudKit pushes to the iPad and Mac; their `SyncEngine`s merge into local SwiftData.
7. **Conflict.** If the iPad edited concurrently, the `ConflictResolver` runs the deterministic three-way merge → one converged note (Exercise 2).
8. **Push + Live Activity + Widget.** If the note is shared, the Vapor backend sends an APNs push; the NSE decrypts it; a Live Activity updates its `ContentState`; the Widget timeline reloads.

You demonstrate this live, on two devices, in the review. "It works on my iPhone" is not the bar.

### The evidence you bring

Integration is not just "it runs" — it is "here is the evidence it runs correctly." By the end of the sprint you should have, from prior weeks plus this week:

- **Correctness evidence:** the Swift Testing suite green, including the `ConflictResolver` order-independence test (Exercise 2) and the offline write-replay tests (Week 13).
- **UI evidence:** the XCUITest flows (add, sync, resolve conflict) and the snapshot tests across device classes and Dynamic Type sizes (Week 22).
- **Performance evidence:** the Instruments captures (Week 15) showing no hitches in a 60-second scroll and no hangs in five minutes of use.
- **Operability evidence:** the runbook, the killswitch (Exercise 3), and the trace-one-write document (Exercise 1).

The reviewer reads the evidence to know what "working" means *before* asking whether it works. A capstone with a great demo and no evidence reads as a prototype; one with all four kinds of evidence reads as engineered.

---

## Rules

- **You may** reuse every artifact you built in Weeks 1–22. That is the point — this is integration, not a rewrite.
- **You may NOT** introduce a credential into the repo. The auth token lives in the Keychain; the APNs key and App Store Connect API key live in CI secrets. `grep -ri "BEGIN PRIVATE KEY\|aps.*key\|asc_api_key" .` must return nothing.
- **CloudKit-legal schema:** all SwiftData relationships optional, no `@Attribute(.unique)`, additive-only once in the CloudKit production environment. Enforce tag uniqueness in app code, not the schema.
- **Local-first:** every write is durable in SwiftData before it is acknowledged remotely; the UI never blocks on the network.
- **Deterministic conflict resolution:** the resolver is a pure function of (local, remote, ancestor); Exercise 2's order-independence test must pass.
- **RC discipline:** lock the build through the CI pipeline (Lecture 2, §3), not by hand; tag the commit `v1.0.0-rc1`; the build maps to the tag.
- **Clean history:** squash-merged feature branches with a clean commit history (a capstone deliverable); each commit leaves the workspace building and tests green.
- **GPL-3.0, public repo:** the capstone source is a public GitHub repository under GPL-3.0, per the SYLLABUS deliverables.

---

## Acceptance criteria

The criteria map onto the capstone's 100-point rubric in `SYLLABUS.md`; this week earns the integration-and-defense portion, next week earns the ship-and-survive portion.

### Multi-platform integration (mirrors rubric: multi-platform parity, 15 pts)

- [ ] One Xcode workspace builds and runs on iPhone, iPad, Mac (native), watchOS, and visionOS.
- [ ] Shared code (`Note`, `ConflictResolver`, `NotesClient`, `SyncEngine`) lives in `NotesCore` and is imported, not duplicated, by every target.
- [ ] The watchOS companion shows the three most recent notes; the visionOS target opens a window; the Mac target is SwiftUI-native (not just Catalyst).

### Offline-first sync & conflict resolution (mirrors rubric: 15 pts)

- [ ] A note edited offline is durable in SwiftData immediately and re-renders once.
- [ ] On reconnect, the write replays to CloudKit and the Vapor backend idempotently.
- [ ] A concurrent two-device edit resolves deterministically; Exercise 2's tests pass in `NotesCoreTests`.

### StoreKit 2 + server validation (mirrors rubric: 10 pts)

- [ ] The subscription purchases via StoreKit 2 and the Vapor backend validates the signed `Transaction.jsonRepresentation` server-side; ADR-0004 documents the flow.

### Widgets + App Intents + Live Activity (mirrors rubric: 15 pts)

- [ ] The Home Screen and Lock Screen Widgets render and reload on a real change.
- [ ] The `AddNote` App Intent runs from Shortcuts/Siri.
- [ ] The shared-edit Live Activity updates from an APNs push (the push payload matches `ContentState`).

### Defense artifacts (the week's distinctive deliverables)

- [ ] `docs/trace-one-write.md` (Exercise 1) — the eight-hop trace with failure modes and data-loss windows.
- [ ] `docs/adr/0001`–`0004` — the four ADRs (Lecture 2, §1).
- [ ] `production-runbook.md` — on-call surface, five outages, three rollbacks, comms template, 3 AM walk (Lecture 2, §2).
- [ ] `diagram.md` — one-page Mermaid diagram, every arrow labeled.
- [ ] The killswitch (Exercise 3) is wired to at least one feature gate.
- [ ] The architecture review (Challenge 1) delivered, with a tagged risk list committed as the README's known-limitations section.

### Release candidate

- [ ] The full Swift Testing + XCUITest + snapshot suite is green in CI (zero failures).
- [ ] A Release-configuration, App-Store-signed build is uploaded to **TestFlight internal** testing via the `release_candidate` fastlane lane.
- [ ] The commit is tagged `v1.0.0-rc1`; `ITSAppUsesNonExemptEncryption` is set; the App Store Connect record is prepared (app created, capabilities match, App Privacy label drafted).

---

## Suggested order of work

- **Monday.** Open the workspace; confirm all five targets build against the shared `NotesCore`. Get *one platform* (iPhone) tracing one write end to end by hand; fix the first integration gap. Do not move on until the iPhone trace works. The most common Monday blocker is the App Group — the extensions cannot see the app's store until it is configured; budget time for it.
- **Tuesday.** Trace the write across to the iPad and Mac (CloudKit sync + conflict resolution). Write the four ADRs while the decisions are fresh in the integration.
- **Wednesday.** Write the production runbook and the 3 AM walk. Wire the killswitch (Exercise 3) to a feature gate. Run the daily 30-minute review.
- **Thursday.** Lock the RC: run the full suite green, archive in Release, upload to TestFlight internal via fastlane, tag `v1.0.0-rc1`. Validate the distribution build on a real device.
- **Friday.** Prepare the App Store Connect record (encryption answer, App Privacy label, metadata first pass). Deliver the live architecture review (Challenge 1); capture the risk list.
- **Saturday.** Fix every "fix now" risk. Assemble the interview-prep system-design pack (homework). Final clean `apply` of the RC lane as next week's submission will run it.

---

## The integration risks to watch

These are the gaps the sprint surfaces most often. Watch for them as you assemble — each is invisible on one platform with ten notes and bites at integration with five platforms and real data:

- **The App Group is misconfigured.** The app writes to its default SwiftData store, the Widget reads from *its* default store, and the Widget is always one launch behind. Fix: point the app, the Widget, and the NSE at the same App-Group-scoped `ModelContainer`, and put the auth token in a shared Keychain access group.
- **A `@Attribute(.unique)` slipped into a CloudKit-synced model.** CloudKit forbids it, so sync silently stops. Fix: remove it; enforce uniqueness in app code.
- **The conflict resolver has no ancestor.** Without a persisted last-synced snapshot per note, "field merge" collapses to last-writer-wins. Fix: persist the ancestor; the resolver needs all three of (local, remote, ancestor).
- **A sync leg is not idempotent.** A partial drain (CloudKit succeeds, Vapor fails) plus a retry produces a duplicate or a clobber. Fix: key each write by note ID + `updatedAt` so a retry is safe.
- **The push payload does not match `ContentState`.** The Live Activity silently does nothing. Fix: a test that decodes a sample payload into the `ContentState`.
- **A network call runs on the main thread from a view.** The Week 15 hitch reappears at integration. Fix: every network/heavy-fetch path is on an actor and `await`ed.

If you find one of these, it is a `fix-now` item, not a `fix-later` — these are the contracts the whole system rests on.

## The daily 30-minute review cadence

The SYLLABUS prescribes a daily 30-minute review this week. Use it as an integration checkpoint, not status theatre. A good daily report is specific and demonstrable: "I got the iPhone tracing one write end to end through CloudKit; the conflict path works; I'm blocked on the watch target not seeing the shared store because the App Group isn't set up." That report is actionable — the lead points you at the App Group capability and you are unblocked in five minutes instead of losing a day. The dailies exist so that Friday's sign-off is spent on the *architecture* (the contracts, the failure modes, the risks) and not on "why won't the watch build." Walk into Friday with a system that runs.

## Suggested commit sequence

Keep the history clean (squash-merged feature branches, per the SYLLABUS deliverable). A reasonable sequence:

1. `integrate: compose five targets against shared NotesCore`
2. `sync: wire SyncEngine for CloudKit + Vapor with idempotent legs`
3. `conflict: deterministic three-way resolver + tests (Exercise 2)`
4. `runbook: production-runbook.md + killswitch wired (Exercise 3)`
5. `adr: the four architectural decision records`
6. `docs: trace-one-write.md + one-page diagram`
7. `rc: lock v1.0.0-rc1, upload to TestFlight internal`

Each commit should leave the workspace building and the tests green. A commit that breaks the build is a commit your reviewer (and your future self) cannot bisect against.

---

## What "done" looks like

A reviewer opens your workspace, builds it on five simulators, watches you edit a note offline on one device and see it land — resolved correctly — on another, with the Widget refreshing and the Live Activity updating. They read your one-page diagram and trace a write off it without your narration. They read your four ADRs and find the *why* for every hard choice. They read your runbook and find a one-line first check for the 3 AM push outage. They watch you name your own three biggest risks before they ask. Then they confirm there is a Release-signed build in TestFlight internal, tagged to an exact commit, with a green test suite behind it. Every one of those steps passes. That is the build sprint. That is the capstone, ready to ship.

---

## What this prepares you for

- **Week 24 (the ship)** flips the TestFlight build from internal to external in five regions, submits to App Review, runs the chaos drill against this exact system, writes the postmortem, records the walkthrough, and presents at demo day. Everything next week assumes the build is *locked this week*.
- **The senior-iOS mock interview** that closes the track is the same skill as Friday's review — trace data flow, name failure modes, defend tradeoffs with evidence — applied to a system you design on the spot. The capstone *is* your reference answer for the offline-journaling and multi-device prompts.
- **The portfolio.** The diagram, the ADRs, the runbook, and the known-limitations list become your capstone case study — the artifact a hiring manager reads to decide whether you can think, not just type.
- **Demo day.** The trace-one-write walk you rehearsed for the review becomes the five-minute walkthrough video next week. Rehearsing it well this week means the recording is a re-take, not a first take.

---

## Submission

When the sprint is done:

1. Confirm the workspace builds and runs on all five platforms against the shared `NotesCore`.
2. Confirm the full test suite is green in CI and the RC is in TestFlight internal, tagged `v1.0.0-rc1`.
3. Confirm the four ADRs, the runbook, the trace document, and the one-page diagram are committed.
4. Confirm the architecture review is signed off and the risk list is in the README's known-limitations section.
5. Confirm there are no credentials in the repo.

Then you are ready for Week 24: ship to external beta in five regions, pass App Review, run the chaos drill, and present. The build is locked; next week is delivery, not a sprint.
