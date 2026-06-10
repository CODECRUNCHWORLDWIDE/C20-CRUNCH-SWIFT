# Week 22 — Testing at scale, CI on GitHub Actions, fastlane

Welcome to Week 22 of **C20 · Crunch Swift**. For twenty-one weeks you have *built* — Swift, SwiftUI, SwiftData, networking, security, push, widgets, Live Activities. This week you stop adding features and build the thing that keeps all of them working: the **net.** By Friday, every push to a pull request runs your unit tests, your UI tests, and your snapshot tests on a macOS runner in the cloud, and every push to `main` builds a signed archive and uploads it to TestFlight — with no human touching a Mac in between. The deliverable is a pipeline a senior engineer would actually trust: from `git push` to a TestFlight build appearing in the App Store Connect dashboard, automatically, repeatably, on every commit.

Three layers make that real, and they stack. The bottom layer is **tests that are worth running.** This is the year of **Swift Testing** — the `@Test` / `#expect` framework that shipped with Xcode 16 and is now the default for new test targets, with first-class parameterized tests, tagged suites, and parallel execution that XCTest never made easy. You will write Swift Testing for logic, **XCUITest** for the user-facing flows that a unit test can't reach, and **snapshot tests** (via `swift-snapshot-testing`) for the SwiftUI views whose *rendering* is the contract — because "the layout didn't break" is a real regression that no assertion on a view model catches. The middle layer is **`xcodebuild` on CI**: the same build-and-test command Xcode runs for you, invoked from a script, its firehose of output piped through **`xcbeautify`** so a failing test is one readable line, not a thousand. The top layer is **GitHub Actions on `macos` runners** orchestrating it — a `pull_request` workflow that gates merges on green tests, and a `push`-to-`main` workflow that ships.

The piece that turns "CI that runs tests" into "CI that ships" is **fastlane plus the App Store Connect API**, and it is mostly about one genuinely hard problem: **code signing on a machine that is not yours.** A fresh CI runner has no certificates, no provisioning profiles, no keychain — and Apple's signing model was designed for a developer's personal Mac, not a fleet of ephemeral cloud machines. fastlane's **`match`** solves this by storing your certificates and profiles, encrypted, in a Git repo (or cloud storage) that CI can decrypt and install on demand; **`gym`** wraps `xcodebuild archive` into a signed `.ipa`; and **`pilot`** uploads to TestFlight. Authentication to App Store Connect uses an **API key** (`.p8`) you store as a CI secret, not your personal Apple ID with 2FA that no script can satisfy. Get signing right and the rest of the pipeline is plumbing. Get it wrong and you will spend a week fighting "no profiles for team matching" errors — which is exactly why this week teaches it deliberately.

We close the week by standing up the **full pipeline** on the Hello, Notes / capstone repo: a GitHub Actions workflow that runs Swift Testing + XCUITest + snapshot tests on every PR (and *fails the PR* if any go red), builds a signed archive, and uploads to TestFlight on every push to `main`, authenticating with App Store Connect API keys checked into the workflow secrets and signing with `match`. This is the pipeline the syllabus's "skill earned" line demands — *commit to TestFlight, automatically* — and it is the operational backbone the capstone (TestFlight in five regions) sits on top of.

## Learning objectives

By the end of this week, you will be able to:

- **Write** tests in **Swift Testing** — `@Test`, `#expect`, `#require`, parameterized tests with `arguments:`, tagged suites with `@Suite`, and `async`/`throws` tests under Swift 6 — and explain when it beats and when it coexists with XCTest.
- **Build** **XCUITest** flows that drive the real UI via accessibility identifiers, with the page-object pattern, robust waiting (`waitForExistence`), and launch arguments for deterministic state.
- **Add** **snapshot tests** with `swift-snapshot-testing` for SwiftUI views, manage the recorded reference images, and reason about device/trait variants and the record-vs-verify modes.
- **Invoke** the test and build pipeline from the command line with **`xcodebuild test`** / **`archive`**, the right `-destination` and `-scheme`, and pipe output through **`xcbeautify`** for readable CI logs.
- **Author** a **GitHub Actions** workflow for iOS on `macos` runners: select the Xcode version, cache dependencies, run tests on `pull_request`, and gate the merge on the result.
- **Solve CI code signing** with fastlane **`match`** — the encrypted-certs-in-a-repo model, `appstore`/`development` profile types, and the read-only CI keychain — instead of hand-installing certificates.
- **Ship to TestFlight** with **`gym`** (signed archive → `.ipa`) and **`pilot`** (upload), authenticating to App Store Connect with an **API key** (`.p8`) stored as a CI secret, not an Apple ID.
- **Reason** about a trustworthy pipeline — what gates a merge, what ships, how secrets are stored, how to keep CI green and fast — and diagnose the canonical failures (signing, simulator destination, flaky UI test, secret not set).

## Prerequisites

This week assumes you have completed **C20 weeks 1–21**, or have equivalent fluency. Specifically:

- You wrote **Swift Testing** targets as far back as Week 1 (the `wordfreq` CLI) and used `isStoredInMemoryOnly` containers for SwiftData tests in Week 10. This week scales that discipline up and puts it on CI.
- You built the **APNs auth-key pipeline** in Week 18 and minted a `.p8`. The App Store Connect **API key** for CI is the same kind of artifact — a `.p8` with an issuer id and key id — so the mechanics are familiar.
- You can use `git` and the **`gh` CLI**, and you have a GitHub repository for the notes/capstone app. GitHub Actions runs in *that* repo; `match` stores certs in *a* repo (often a private sibling).
- You have the **Hello, Notes / capstone** app in Git with its widget extension (Week 20) and Live Activity (Week 21). This week's mini-project wraps a CI pipeline around it — the tests assert its behaviour, the pipeline builds and ships it.

**Toolchain.** Xcode 16+ on macOS for local development; **GitHub Actions `macos` runners** (currently `macos-14` / `macos-15` images with recent Xcode) for CI. **fastlane** installed via Bundler (`Gemfile` + `bundle exec fastlane`), `xcbeautify` via Homebrew or Mint, and `swift-snapshot-testing` as a SwiftPM dependency. You hold the **Apple Developer membership** from Phase III, which TestFlight upload requires. The local test runs and `match` setup are free; the TestFlight upload needs the membership you already have.

## Topics covered

- **Swift Testing.** `@Test`, `#expect` vs `#require`, expected failures, `@Suite` and tags, `arguments:` parameterized tests, `.serialized`/parallel execution, `async`/`throws` tests, and `withKnownIssue`. The XCTest-coexistence story.
- **XCTest, still.** Where XCTest remains (legacy suites, some performance/UI APIs), and running both frameworks in one scheme.
- **XCUITest.** `XCUIApplication`, launching with arguments/environment for deterministic state, `accessibilityIdentifier`-driven queries, `waitForExistence(timeout:)`, the page-object pattern, and why UI tests are slow and flaky if you let them be.
- **Snapshot testing.** `swift-snapshot-testing`, `assertSnapshot(of:as:)`, `.image` strategies for SwiftUI/UIView, reference-image management in Git, record mode, and per-device/trait variants.
- **`xcodebuild` on CI.** `xcodebuild test` / `build-for-testing` + `test-without-building`, `archive`, `-scheme`, `-destination`, `-resultBundlePath`, and reading the result bundle.
- **`xcbeautify`.** Piping `xcodebuild` through it, the GitHub Actions formatter, and surfacing failures readably.
- **GitHub Actions for iOS.** The `macos` runner, `actions/checkout`, selecting Xcode (`xcode-select` / `maxim-lobanov/setup-xcode`), caching SwiftPM/DerivedData, the `pull_request` vs `push` triggers, and matrix builds.
- **Secrets and the API key.** GitHub Actions secrets, the App Store Connect **API key** (`.p8`, key id, issuer id), and never committing credentials.
- **fastlane fundamentals.** The `Fastfile`, lanes, `Gemfile`-pinned fastlane, `Appfile`/`Matchfile`, and running lanes locally vs on CI.
- **`match` — CI code signing.** The encrypted-certs-in-a-repo model, `git_url`, `type: appstore`/`development`, `readonly: true` on CI, the `MATCH_PASSWORD`, and a temporary CI keychain.
- **`gym` and `pilot`.** `gym` (build the signed `.ipa`), `pilot`/`upload_to_testflight` (upload + manage testers), and `app_store_connect_api_key` for non-interactive auth.
- **A trustworthy pipeline.** What gates a merge, what ships, keeping CI fast and green, flaky-test quarantine, and the from-`git push`-to-TestFlight flow end to end.

## Weekly schedule

The schedule below adds up to approximately **36 hours**. Treat it as a target, not a contract — some days you will move faster, some slower.

| Day       | Focus                                                              | Lectures | Exercises | Challenges | Quiz/Read | Homework | Mini-Project | Self-Study | Daily Total |
|-----------|--------------------------------------------------------------------|---------:|----------:|-----------:|----------:|---------:|-------------:|-----------:|------------:|
| Monday    | Swift Testing; parameterized + tagged; XCTest coexistence          |    2h    |    1.5h   |     0h     |    0.5h   |   1h     |     0h       |    0.5h    |     5.5h    |
| Tuesday   | XCUITest + page objects; snapshot testing; `xcodebuild` + xcbeautify |    2h    |    2h     |     0h     |    0.5h   |   1h     |     0h       |    0h      |     6.5h    |
| Wednesday | GitHub Actions on macos runners; PR gating; secrets; challenge      |    1h    |    2h     |     1h     |    0.5h   |   1h     |     0h       |    0.5h    |     6h      |
| Thursday  | fastlane: `match`, `gym`, `pilot`; App Store Connect API; challenge  |    1h    |    1h     |     1h     |    0.5h   |   1h     |     2h       |    0.5h    |     7h      |
| Friday    | Mini-project — full PR-tests + main-ships-to-TestFlight pipeline    |    0h    |    1h     |     0h     |    0.5h   |   1h     |     3h       |    0h      |     5.5h    |
| Saturday  | Mini-project deep work; signing with match + first TestFlight build  |    0h    |    0h     |     0h     |    0h     |   0h     |     3h       |    0h      |     3h      |
| Sunday    | Quiz, review, polish, push                                          |    0h    |    0h     |     0h     |    1h     |   0h     |     0.5h     |    0h      |     1.5h    |
| **Total** |                                                                    | **6h**   | **7.5h**  | **2h**     | **3.5h**  | **5h**   | **11.5h**    | **1.5h**   | **37h**     |

## How to navigate this week

| File | What's inside |
|------|---------------|
| [README.md](./README.md) | This overview (you are here) |
| [resources.md](./resources.md) | Apple's Swift Testing / XCTest / xcodebuild docs, the fastlane docs, the GitHub Actions iOS guides, and the canonical community writing on CI signing |
| [lecture-notes/01-swift-testing-xcuitest-snapshot.md](./lecture-notes/01-swift-testing-xcuitest-snapshot.md) | Testing at scale: Swift Testing (`@Test`/`#expect`/parameterized/tags), XCUITest with page objects, snapshot testing with `swift-snapshot-testing`, and what each layer is *for* |
| [lecture-notes/02-github-actions-fastlane-testflight.md](./lecture-notes/02-github-actions-fastlane-testflight.md) | The pipeline: `xcodebuild` + `xcbeautify` on `macos` runners, GitHub Actions PR-gating, CI code signing with `match`, and shipping to TestFlight with `gym`/`pilot` + the App Store Connect API key |
| [exercises/README.md](./exercises/README.md) | Index of the three exercises |
| [exercises/exercise-01-swift-testing-parameterized.swift](./exercises/exercise-01-swift-testing-parameterized.swift) | Write Swift Testing suites with `#expect`/`#require`, parameterized `arguments:`, and tags, against the notes logic |
| [exercises/exercise-02-xcuitest-page-object.swift](./exercises/exercise-02-xcuitest-page-object.swift) | Drive the add-note flow with XCUITest via accessibility identifiers and a page object, with deterministic launch state |
| [exercises/exercise-03-github-actions-pr-workflow.md](./exercises/exercise-03-github-actions-pr-workflow.md) | Author a GitHub Actions `pull_request` workflow that runs the tests on a macos runner and gates the merge |
| [challenges/README.md](./challenges/README.md) | Index of the challenge |
| [challenges/challenge-01-match-and-testflight.md](./challenges/challenge-01-match-and-testflight.md) | Set up `match` for CI code signing and ship a signed build to TestFlight from a `push`-to-`main` workflow with the App Store Connect API key |
| [quiz.md](./quiz.md) | 13 questions on Swift Testing, XCUITest, snapshot tests, `xcodebuild`, GitHub Actions, `match`, and the App Store Connect API |
| [homework.md](./homework.md) | Six practice problems for the week |
| [mini-project/README.md](./mini-project/README.md) | Full spec for the complete pipeline: PR runs tests + gates the merge, `main` builds a signed archive and uploads to TestFlight |

## The "commit to TestFlight, untouched" promise

Week 21 gave you "updates while the app is asleep." Week 22 adds the operational contract a senior reviewer checks before they believe your pipeline is real:

> **A green `main` must produce a TestFlight build with no human touching a Mac.** Push a commit to `main`, walk away, and a signed build appears in App Store Connect's TestFlight tab minutes later — built, signed with `match`, uploaded by `pilot`, authenticated by an API key, on a cloud runner you do not own. And a PR with a failing test must be *blocked from merging.* If shipping requires you to open Xcode and click "Archive," the pipeline isn't done — the whole point is that the machine ships and the human reviews.

You will *prove* this by pushing a trivial commit to `main` and watching a build land in TestFlight from the GitHub Actions log alone, and by opening a PR that breaks a test and watching the merge button go red. "It built on my laptop" is not the test — the test is that a machine you've never logged into built and shipped it.

## A note on what's not here

Week 22 is the *testing and CI* week. It deliberately does **not** cover:

- **App Review and App Store submission.** Getting a build *into* TestFlight is this week; getting it *through App Review* to the public store — metadata, screenshots, the guidelines, expedited review — is Week 24. TestFlight internal testing needs no review; that's the line we stop at.
- **Self-hosted runners and fleet CI.** We use GitHub-hosted `macos` runners. Running your own Mac mini fleet, or Xcode Cloud, is a scaling concern beyond this week; the principles (signing, secrets, gating) transfer.
- **Deep performance/load testing of the backend.** The Vapor backend has its own tests (Phase I), run on Linux CI; this week is the *iOS* pipeline. We mention the backend job and move on.

The point of Week 22 is narrow and deep: tests worth trusting at three layers, a `macos` runner that runs them on every PR, the signing problem solved with `match`, and a `push`-to-`main` lane that ships to TestFlight — the pipeline that turns a commit into a build without a human in the loop.

## Up next

Continue to **Week 23 — Capstone build sprint** once you have shipped this week's pipeline and proven a commit reaching TestFlight untouched. Week 23 is the integration sprint: you take everything from Phases I–IV — the Vapor backend, the SwiftData store, the multi-platform SwiftUI app, the StoreKit subscription, the widgets, the Live Activity — and weld it into the single capstone system, with daily reviews. The CI pipeline you built this week is the safety net under that sprint: as you integrate fast and break things, the PR gate catches the regressions and the TestFlight lane keeps the beta build fresh. You cannot run a capstone sprint at speed without this net. Build it well this week.

---

*If you find errors in this material, please open an issue or send a PR. Future learners will thank you.*
