# Mini-Project — The full pipeline: PR gates, `main` ships to TestFlight

This week the notes app gets a net. You will stand up the **complete iOS CI pipeline** around Hello, Notes / the capstone repo: a **GitHub Actions workflow** that runs Swift Testing + XCUITest + snapshot tests on every **pull request** (and *blocks the merge* if any go red), builds a **signed archive**, and **uploads to TestFlight** on every push to **`main`** — authenticating with **App Store Connect API keys** in the workflow secrets and signing with **`match`**. The deliverable is the pipeline the syllabus's "skill earned" line demands: *commit to TestFlight, automatically.*

This is a *compounding* project. It is not a new app. You start from your existing repo — the app, its widget extension (Week 20), its Live Activity (Week 21), and the tests and PR workflow from this week's exercises — and you weld the three layers into one trustworthy pipeline. The point of the week is to feel the conveyor: a commit goes in one end, a reviewed merge and a TestFlight build come out the other, with the machine doing the build and the human doing only the review.

---

## Where you're starting from

Your repo has, roughly:

- The Hello, Notes / capstone app on SwiftData, with a widget extension and a Live Activity.
- Some Swift Testing logic tests (exercise 1) and an XCUITest flow (exercise 2).
- A `pull_request` GitHub Actions workflow that runs the tests and a branch-protection gate (exercise 3).
- An Apple Developer membership (Phase III) and a GitHub repo.

If you don't have all of exercise 3 done, do it first — the gate is the foundation the ship lane stands on.

## What you're building toward

By the end you have:

- A **test suite at three layers**: Swift Testing (logic, parameterized, tagged), XCUITest (critical journeys via page objects), and **snapshot tests** for key SwiftUI views (including a Dynamic Type variant).
- A **PR workflow** that runs the suite on a pinned `macos` runner through `xcbeautify`, uploads the result bundle, and — via branch protection — **blocks merging red PRs.**
- A **`match`** setup storing one signing identity in a private certs repo, consumed `readonly` on CI.
- A **`ship_beta`** fastlane lane (`setup_ci` → `match` → `gym` → `pilot`) authenticated by an App Store Connect API key.
- A **`ship` job** that runs only on `main`, only after the test gate passes, and uploads to TestFlight.
- A passing **"commit to TestFlight, untouched" proof**: push to `main`, a build appears in App Store Connect's TestFlight tab with no manual Xcode step; and a broken PR is provably un-mergeable.

---

## Where each piece lives (repo layout)

The pipeline is files in specific places; here's the map:

```text
.
├── .github/workflows/ci.yml          # the test gate (PR) + ship job (main)
├── Gemfile / Gemfile.lock            # pinned fastlane (committed)
├── fastlane/
│   ├── Appfile                       # app_identifier, team ids
│   ├── Matchfile                     # certs-repo URL, type: appstore
│   └── Fastfile                      # the test + ship_beta lanes
├── HelloNotes.xcodeproj/
│   └── xcshareddata/xcschemes/       # the SHARED scheme (committed) + test plans
├── HelloNotesTests/                  # Swift Testing (logic) + snapshot tests
│   └── __Snapshots__/                # committed reference images
└── HelloNotesUITests/                # XCUITest journeys (page objects)
```

A *separate* private repo holds the `match` certificates (encrypted). The secrets — `MATCH_PASSWORD`, the certs-repo token, the App Store Connect `.p8`/key id/issuer id — live only in **GitHub Actions secrets**, never in any of the files above.

## Build order

Work the milestones in this order — the gate must work before the ship can stand on it:

1. **Tests green locally** (Milestone 1) — three layers, all passing in Xcode.
2. **PR gate** (Milestone 2) — the `pull_request` workflow + branch protection; prove a red PR can't merge.
3. **Signing** (Milestone 3) — `match` set up once on a laptop; this is the hard part, do it carefully.
4. **Ship lane** (Milestone 4) — `ship_beta` + the `main`-only job consuming the signing identity.
5. **The proof** (Milestone 5) — push to `main`, watch a build reach TestFlight untouched.

Don't attempt the ship lane before the gate is proven and signing is set up — a `ship` job that can't sign just produces confusing errors. Gate first, sign second, ship third.

---

## Milestone 1 — Round out the test suite to three layers (≈ 2.5 h)

You have logic and UI tests; add the **snapshot layer** and broaden coverage so the suite is worth gating on.

- **Swift Testing (logic).** Parameterized tests over the input space (title normalisation, predicate filtering, migration upgrade-path), tagged `.logic`/`.persistence`/`.slow` so PR runs can skip the slow ones. Fresh in-memory SwiftData store per test (Week 10). (Lecture 1, §1.)
- **XCUITest (journeys).** The add-note flow and one more critical path (e.g. the deep-link route, or tagging a note), via page objects, launched into deterministic state with `-uitest-reset`. Keep this set *small*. (Lecture 1, §2.)
- **Snapshot (rendering).** Add `swift-snapshot-testing` as a SwiftPM dependency and snapshot the note row, the empty state, and the widget view — each in default and `accessibilityExtraExtraExtraLarge` Dynamic Type, to catch layout regressions. Record references once, commit them. (Lecture 1, §3.)

Decisions you must defend in review:

- **Why three layers and not just more XCUITests?** Permutations belong in fast, parallel Swift Testing; *rendering* belongs in snapshots; only *critical user journeys* justify a slow XCUITest. An inverted pyramid (mostly UI tests) is slow, flaky, and tests the wrong things. (Lecture 1, §4.)
- **Why a Dynamic Type snapshot variant?** "The title truncates at XXXL" is a real, shippable regression invisible to logic tests and to a UI test that only checks text exists. (Lecture 1, §3.)

## Milestone 2 — Harden the PR workflow (≈ 1 h)

Make the gate fast and trustworthy (lecture 2, §1–3):

- Pin the **Xcode version** and the **simulator `-destination` OS**.
- `set -o pipefail` before the `xcodebuild | xcbeautify` pipe so a failure actually fails the job.
- Cache SwiftPM (and DerivedData if it helps) to keep runs under ~6 minutes.
- A **test plan** (or tag filter) that runs the fast core on PRs and the `.slow` tests on a nightly schedule.
- Upload the `.xcresult` (`if: always()`).
- Confirm the **branch-protection rule** requires the check.

## Milestone 3 — Set up `match` for CI signing (≈ 2 h)

The hard part (lecture 2, §4). On your laptop, once:

- A **private certificates repo**.
- A `Matchfile` (`git_url`, `type: appstore`, `app_identifier`), then `bundle exec fastlane match appstore` to create and store the encrypted distribution cert + App Store profile.
- An **App Store Connect API key** (`.p8`, key id, issuer id) for non-interactive auth.

Verify the certs repo contains encrypted artifacts and that `match` installs them locally.

Decisions you must defend:

- **Why `match` instead of hand-installing a `.p12`?** A CI runner is ephemeral and has no keychain; `match` gives every machine the *same* signing identity to fetch on demand, encrypted. (Lecture 2, §4.)
- **Why `readonly: true` on CI?** CI must consume, never create/rotate certs — concurrent runs creating certs would churn your identity. Creation happens once, on a laptop. (Lecture 2, §4.)

## Milestone 4 — The ship lane and the `main` job (≈ 1.5 h)

Write the `ship_beta` lane (`setup_ci` → `match(readonly:true)` → `increment_build_number` from `GITHUB_RUN_NUMBER` → `gym` → `pilot`) authenticated by the API key, and the `ship` GitHub Actions job that runs **only on `main`, only after `test`** (lecture 2, §5). Store `MATCH_PASSWORD`, the certs-repo token, and the three API-key values as **GitHub secrets**. Commit nothing secret.

## Milestone 5 — The "commit to TestFlight, untouched" proof (≈ 0.5 h)

The acceptance bar for the whole week.

1. **The gate:** open a PR that breaks a test. The check goes red and the **Merge** button is disabled. Fix it; it goes green and becomes mergeable.
2. **The ship:** merge a trivial change to `main`. The `ship` job runs: `match` fetches the identity, `gym` builds the signed `.ipa`, `pilot` uploads.
3. **The proof:** open App Store Connect ▸ your app ▸ **TestFlight**. Within minutes, a new build (with the run-number build number) appears for internal testers — **and you never opened Xcode.**

Record this as a short clip or screenshot sequence (the red PR, the green `main` run, the TestFlight build). "A machine I don't own built and shipped it" is the deliverable.

---

## The pipeline, drawn once

Keep this picture in front of you — the whole week is wiring up these two paths:

```text
   A pull request                                A merge to main
   ──────────────                                ───────────────
   git push (PR branch)                          git push / merge → main
        │                                              │
        ▼                                              ▼
   on: pull_request                              on: push, branches:[main]
        │                                              │
   job: test (macos runner)                       job: test  ──passes──┐
     checkout                                                          │
     setup-xcode (pinned)                          job: ship  ◀────────┘ needs: test
     xcodebuild test | xcbeautify  (pipefail)        setup_ci (temp keychain)
        │                                             match(readonly) ← certs repo
        ▼                                             gym  → signed .ipa
   red? ──▶ branch protection blocks merge           pilot → TestFlight upload
   green? ──▶ merge allowed                                  │
                                                             ▼
                                                   App Store Connect ▸ TestFlight
                                                   (internal testers, no review)
```

Two triggers, two responsibilities: **`pull_request` gates** (tests block the merge), **`push` to `main` ships** (signed build to TestFlight, only after the gate). The secrets feed only the `ship` job, which only runs on `main` — the security boundary from lecture 2, §6.

## Common pitfalls (and how to spot them)

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| Job green while a test failed | Pipe masked the exit code | Add `set -o pipefail` before the `xcodebuild` ▸ `xcbeautify` pipe |
| "Scheme not found" on CI | Scheme not shared/committed | Manage Schemes ▸ Shared; commit the `.xcscheme` |
| Passes locally, fails on CI | Unpinned Xcode/simulator drift | Pin `xcode-version` and `-destination` OS; match locally |
| "No profiles were found" | `match` never created the identity, or `readonly` blocks a needed create | Run `match appstore` once on a laptop; CI uses `readonly: true` |
| `pilot` asks for a password | Apple ID auth instead of API key | Pass `app_store_connect_api_key` to `pilot` too |
| Snapshot tests flake on CI | Floating simulator/scale | Pin the destination; run snapshots on one fixed simulator |
| Duplicate build number rejected | Reused build number | `increment_build_number(build_number: ENV["GITHUB_RUN_NUMBER"])` |
| Secret "empty" on a PR | Forks don't get secrets | Gate the ship job to `main`; never expect secrets on a fork PR |

Most failures are *signing* (solved by `match` + `readonly` + the API key) or *environment drift* (solved by pinning). Pin everything and let `match` own signing, and the pipeline becomes boringly reliable — which is the goal.

## Definition of done

You're done when, with no manual Xcode step:

1. A PR with a broken test **cannot be merged** (red required check, disabled merge button).
2. A fixed PR goes **green and merges**.
3. The merge to `main` triggers a `ship` run that signs with `match` and uploads via `pilot`.
4. A build with the run-number build number appears in **App Store Connect ▸ TestFlight** for internal testers.
5. No credential is anywhere in the repo's Git history.

If all five hold, you have built the operational backbone the rest of the course stands on: a machine you don't own builds, signs, and ships your app on every green `main`, and blocks every red PR — the precise definition of an iOS pipeline a senior engineer trusts.

Keep the screen recording of the red PR, the green `main` run, and the TestFlight build together in the repo — that three-part artifact is the proof for both the week's rubric and the capstone's "TestFlight in five regions" milestone, which is this exact lane with region settings layered on top.

---

## Acceptance criteria

- [ ] A **three-layer** test suite: Swift Testing (parameterized, tagged), XCUITest (page-object journeys, deterministic launch), and snapshot tests (including a Dynamic Type variant), all green locally.
- [ ] A **PR workflow** on a pinned `macos` runner: `set -o pipefail`, `xcbeautify`, pinned `-destination` OS, SwiftPM cache, `.xcresult` uploaded.
- [ ] A **branch-protection rule** requiring the test check; a **broken PR is provably un-mergeable**.
- [ ] **`match`** stores an encrypted `appstore` identity in a separate private repo; the `Matchfile` and `Fastfile` are committed (no secrets).
- [ ] An **App Store Connect API key** authenticates `match`/`pilot`; the `.p8`/key id/issuer id and `MATCH_PASSWORD` are GitHub secrets, never committed.
- [ ] A **`ship_beta`** lane (`setup_ci`/`match readonly`/`gym`/`pilot`, unique build number) and a **`ship` job** running only on `main` after the gate.
- [ ] **The "commit to TestFlight, untouched" proof passes:** push to `main`, a build appears in TestFlight with no manual Xcode step.
- [ ] Build with **0 warnings** locally and **green CI**; no credential committed.

## Stretch goals

- **A backend CI job.** Add a Linux job that runs the Vapor backend's Swift Testing suite (Phase I) in the same workflow, so the whole system is gated.
- **Snapshot variants matrix.** Snapshot key views across light/dark × {default, XXXL} and iPhone/iPad, and review the diffs in a PR.
- **A `release` lane.** A separate lane that promotes a TestFlight build to App Store review (metadata + screenshots via `deliver`) — a preview of Week 24, gated behind manual approval.
- **Flaky-test quarantine.** Tag a known-flaky UI test, exclude it from the PR gate, and run it on a nightly job with retries — documenting why quarantine beats deletion.

## What this milestone earns you

You can now ship a complete iOS CI pipeline that goes from commit to TestFlight — the literal "skill earned" line for the week. More than that: you built the net the capstone runs on. A three-layer suite catches regressions cheaply, a `macos` runner gates every PR so `main` stays green, `match` solves the signing problem that defeats most engineers, and a `main` push ships a signed build to TestFlight with no human touching a Mac. Week 23's capstone sprint integrates everything from Phases I–IV at speed — and it can only run at speed *because* this net catches what breaks. The capstone's "TestFlight in five regions" is this exact lane with region settings on top. You built the backbone; now go integrate the whole system on it.
