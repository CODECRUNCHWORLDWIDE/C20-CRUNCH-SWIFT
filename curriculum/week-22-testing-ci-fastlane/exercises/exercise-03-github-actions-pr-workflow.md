# Exercise 3 — A GitHub Actions PR workflow that gates the merge

**Goal.** Stand up the smallest real iOS CI: a `pull_request` workflow that runs your Swift Testing + XCUITest suite on a `macos` runner, pipes the output through `xcbeautify` so failures are readable, uploads the result bundle, and — via a branch-protection rule — **blocks merging when a test is red.** If a PR that breaks a test can't be merged, the gate works, and everything else this week is shipping on top of it.

**Estimated time.** 50 minutes.

**Prerequisites.** A GitHub repository for your Hello, Notes app (use `gh repo create` if you don't have one). A **shared** scheme (Xcode ▸ Manage Schemes ▸ check Shared, and commit the `.xcscheme`). The tests from exercises 1 and 2. Free macOS-runner minutes cover this (public repos especially).

---

## Step 1 — Share the scheme and commit it

CI can only build schemes that are *shared* and checked into Git. In Xcode: **Product ▸ Scheme ▸ Manage Schemes**, tick **Shared** next to `HelloNotes`, and commit the new file under `HelloNotes.xcodeproj/xcshareddata/xcschemes/`. A missing shared scheme is the first CI error everyone hits.

## Step 2 — Add the workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    name: Test on iOS Simulator
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.2'        # pin it; don't drift with the runner image

      - name: Install xcbeautify
        run: brew install xcbeautify

      - name: Cache SwiftPM
        uses: actions/cache@v4
        with:
          path: .build
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-${{ runner.os }}-

      - name: Run tests
        run: |
          set -o pipefail
          xcodebuild test \
            -scheme HelloNotes \
            -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
            -resultBundlePath TestResults.xcresult \
            | xcbeautify --renderer github-actions

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

The non-obvious lines:

- **`set -o pipefail`** — without it, the pipe to `xcbeautify` masks `xcodebuild`'s exit code and a *failing* test would report the job as green. This one line is the difference between a real gate and a fake one.
- **`-destination ...,OS=18.2`** — pin the simulator OS. A floating destination makes layout/snapshot behaviour drift between runs.
- **Pinned `xcode-version`** — the runner image ships several Xcodes and changes them; pin so "it worked yesterday" stays true.
- **`if: always()` upload** — get the `.xcresult` even when tests fail, so you can open the failure locally.

## Step 3 — Push it and watch a run

```bash
git checkout -b ci-setup
git add .github/workflows/ci.yml HelloNotes.xcodeproj/xcshareddata/xcschemes/
git commit -m "Add iOS CI workflow"
git push -u origin ci-setup
gh pr create --fill
gh run watch          # follow the run live
```

You should see the runner select Xcode, resolve packages, run the tests through `xcbeautify`, and report green. Open the PR's **Checks** tab to see the per-test annotations.

## Step 4 — Make the gate real with branch protection

A green check is advisory until you *require* it. In the repo: **Settings ▸ Branches ▸ Add branch protection rule** for `main`:

- **Require status checks to pass before merging** → select the `Test on iOS Simulator` check.
- **Require branches to be up to date before merging** (optional but good).

Now a PR can't merge until that check is green. (Via CLI: `gh api` against the branch-protection endpoint, or the web UI — the UI is clearest the first time.)

## Step 5 — PROVE the gate blocks a red PR

This is the acceptance bar. Break a test on purpose and watch the merge button go red:

```bash
git checkout -b break-a-test
# Change an expectation so a test fails, e.g. flip an expected value in exercise 1.
git commit -am "Deliberately break a test (do not merge)"
git push -u origin break-a-test
gh pr create --fill
gh run watch
```

The check goes **red**, and on the PR page the **Merge** button is disabled with "Required statuses must pass." That is the gate doing its job. Revert the break (`git revert` or fix the test), push, and watch it go green and become mergeable.

---

## Acceptance criteria

- [ ] The `HelloNotes` scheme is **shared** and committed.
- [ ] `.github/workflows/ci.yml` runs `xcodebuild test` on a `macos` runner, piped through `xcbeautify`, with `set -o pipefail`.
- [ ] The Xcode version and the simulator `-destination` OS are **pinned**.
- [ ] The result bundle is uploaded as an artifact (`if: always()`).
- [ ] A **branch-protection rule** requires the test check before merging `main`.
- [ ] You demonstrated that a PR with a **failing test cannot be merged** (red check, disabled merge), and that fixing it re-enables merging.

## What you just proved

You proved the *gate* exists: a machine you've never logged into runs your tests on every PR, and a red test blocks the merge. This is the half of CI that protects `main` — no broken code lands. The other half, shipping a green `main` to TestFlight, needs code signing on that same runner, which is the challenge and the mini-project. But the gate comes first: you can't safely ship from `main` if `main` can be broken, and now it can't.

---

## Hints (read only if stuck > 10 min)

- **"Scheme HelloNotes not found".** The scheme isn't shared or you didn't commit the `.xcscheme` file. Re-check Step 1 and confirm the file is in Git.
- **Job is green but a test is actually failing.** You're missing `set -o pipefail`. The pipe returned `xcbeautify`'s (success) exit code, hiding the failure. Add it.
- **"Unable to find a destination matching ...".** The named simulator/OS isn't on the runner image. List what's available (`xcrun simctl list devices` in a debug step) and pick one that exists, or relax the OS pin to a major version.
- **The branch-protection check name doesn't appear in the dropdown.** It only appears after the check has run at least once. Push the workflow first, let it run, then add the rule and select it.
- **Runs are slow (10+ min).** Add the SwiftPM cache (Step 2) and consider splitting `build-for-testing` from `test-without-building` once the basics work.
