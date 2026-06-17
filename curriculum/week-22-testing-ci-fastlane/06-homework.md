# Week 22 Homework

Six practice problems that revisit the week's topics. The full set should take about **5 hours** in total. Work in your Week 22 Git repository so each problem produces at least one commit you can point to later.

Each problem includes:

- A short **problem statement**.
- **Acceptance criteria** so you know when you're done.
- A **hint** if you get stuck.
- An **estimated time**.

All code targets iOS 17+/macOS 14+, Xcode 16+, Swift 6 strict concurrency, with GitHub Actions `macos` runners for the CI problems. Every problem must build with **0 warnings** and (where it touches CI) produce a **green run**.

---

## Problem 1 — Convert an XCTest suite to Swift Testing

**Problem statement.** Take an existing `XCTestCase` from an earlier week (e.g. the Week 10 SwiftData tests or the Week 1 `wordfreq` tests) and convert it to Swift Testing: `XCTAssertEqual` → `#expect(a == b)`, `XCTUnwrap` → `try #require`, `setUp` → a `@Suite` `init`. Convert at least one repetitive test into a parameterized `@Test(arguments:)`.

**Acceptance criteria.**

- The converted suite uses `@Test`, `#expect`, `try #require`, and a `@Suite` with per-test `init`.
- At least one parameterized test where each input reports independently.
- All tests pass; 0 warnings. Committed alongside (or replacing) the original.

**Hint.** `try #require(optional)` replaces `XCTUnwrap`. A `@Suite struct`'s `init` runs per test (parallel-safe), so build a fresh in-memory store there. Map a `for`-loop test to `arguments:`.

**Estimated time.** 45 minutes.

---

## Problem 2 — A snapshot test with a Dynamic Type variant

**Problem statement.** Add `swift-snapshot-testing` and write a snapshot test for your note row (or empty state) in two variants: default Dynamic Type and `accessibilityExtraExtraExtraLarge`. Record the references, commit them, then deliberately introduce a layout regression (e.g. a fixed-height row) and confirm the XXXL snapshot fails.

**Acceptance criteria.**

- `assertSnapshot(of:as: .image)` for the view in both Dynamic Type sizes; reference images committed under `__Snapshots__`.
- A documented demonstration that the XXXL snapshot fails when you introduce a clipping regression, and passes when you revert.
- The environment is pinned (fixed frame/trait). 0 warnings. Committed.

**Hint.** `.environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)` sets the trait. Run once in record mode to capture references, then in verify mode. Review the failing diff image the framework writes.

**Estimated time.** 50 minutes.

---

## Problem 3 — Slice the suite with tags and a test plan

**Problem statement.** Tag your tests `.fast`/`.slow` (or `.logic`/`.persistence`/`.ui`). Create a test plan (or `xcodebuild` filter) that runs only the fast/logic tests, and document the command. Explain in `notes/test-slicing.md` why PRs should run the fast core and the slow tests run nightly.

**Acceptance criteria.**

- Tests carry tags; a way to run a subset (test plan or `-only-testing`/tag filter) is documented with the exact command.
- `notes/test-slicing.md` explains the PR-fast / nightly-slow split and why.
- 0 warnings. Committed.

**Hint.** Declare tags via `extension Tag { @Tag static var fast: Self }` and apply with `.tags(.fast)`. A test plan can include/exclude by tag for different CI configurations.

**Estimated time.** 40 minutes.

---

## Problem 4 — Make the PR workflow fast and readable

**Problem statement.** Improve your exercise-3 PR workflow: pin Xcode and the simulator OS, add a SwiftPM cache, pipe through `xcbeautify --renderer github-actions`, add `set -o pipefail`, and upload the `.xcresult`. Measure the run time before and after caching and record both in `notes/ci-timing.md`.

**Acceptance criteria.**

- The workflow pins Xcode + destination OS, caches SwiftPM, uses `pipefail` + `xcbeautify`, and uploads the result bundle (`if: always()`).
- `notes/ci-timing.md` records the before/after run times and the speedup.
- A green run on a PR. Committed.

**Hint.** `actions/cache@v4` keyed on `hashFiles('**/Package.resolved')`. The first run populates the cache (no speedup); the second run shows it. `gh run watch` and the run summary give you the timings.

**Estimated time.** 45 minutes.

---

## Problem 5 — A fastlane test lane (run locally and on CI)

**Problem statement.** Add a `Gemfile` pinning fastlane and a `test` lane in the `Fastfile` that runs `scan` (fastlane's test action) with a pinned device and produces a JUnit/HTML report. Run it locally (`bundle exec fastlane test`) and wire the CI workflow to call it instead of raw `xcodebuild`.

**Acceptance criteria.**

- A `Gemfile` + `Fastfile` with a `test` lane using `scan` (pinned `devices`, `result_bundle: true`).
- `bundle exec fastlane test` runs the suite locally; the CI workflow calls the lane.
- A green CI run; the report uploaded as an artifact. 0 warnings. Committed.

**Hint.** `scan(scheme: "HelloNotes", devices: ["iPhone 16"], result_bundle: true)`. Pinning fastlane in the `Gemfile` means CI and your laptop run the same version — no "works on my machine."

**Estimated time.** 50 minutes.

---

## Problem 6 — Store and use a secret safely

**Problem statement.** Add a workflow step that uses a GitHub Actions **secret** (e.g. a dummy `EXAMPLE_TOKEN`, or your real `MATCH_PASSWORD` if you did the challenge) and prove it's masked in logs and unavailable to PRs from forks. Write `notes/secrets.md` documenting: how the secret is set, why it's masked, and why fork PRs don't receive it (and what that means for gating the ship job to `main`).

**Acceptance criteria.**

- A workflow step references a secret via `${{ secrets.NAME }}`; the log shows it masked (`***`).
- `notes/secrets.md` explains setting (`gh secret set`), masking, and the fork-PR restriction, and connects it to gating ship on `main`.
- No secret value committed. Committed.

**Hint.** `gh secret set EXAMPLE_TOKEN`. Echoing it in a step shows `***` (GitHub masks registered secrets). Fork PRs don't get secrets for security, which is exactly why the *ship* job must run on `main`, not on PRs.

**Estimated time.** 40 minutes.

---

## Rubric

Each problem is graded out of the same five points; the week's homework is out of 30.

| Points | Meaning |
|-------:|---------|
| 5 | Meets every acceptance criterion, builds with 0 warnings / green CI, code and YAML are idiomatic, and the written explanation (where asked) is correct and in your own words. |
| 4 | Meets all criteria but with a minor non-idiomatic choice (e.g. an unpinned destination, a missing cache key, a `for`-loop where parameterized was the point). |
| 3 | Works, but misses one criterion (e.g. no `pipefail` so failures are masked, snapshot environment not pinned, secret echoed unmasked). |
| 2 | Compiles/runs but a core idea is wrong (CI "passes" with a failing test; signing/secret committed; UI test queries by label). |
| 1 | Does not build / red CI, or the approach fundamentally misunderstands the topic. |
| 0 | Not attempted. |

**Crosscutting deductions** (apply to any problem): **−2** for any committed credential (`.p8`, password, token); **−2** for a CI job that reports green while a test is actually failing (missing `pipefail`); **−1** for an unpinned Xcode/destination where determinism was the point, or a snapshot test left in record mode.

**Target: 24/30.** Below that, the two ideas to revisit are almost always the same two the quiz grades on — the three-layer test pyramid (problems 1, 2, 3) and the `pipefail`-gated, secret-safe pipeline (problems 4, 5, 6) — so re-run exercises 01 and 03 before resubmitting, and study `match` hardest if you're attempting the challenge.
