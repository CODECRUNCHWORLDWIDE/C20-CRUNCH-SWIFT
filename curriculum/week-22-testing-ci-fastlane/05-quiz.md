# Week 22 — Quiz

Thirteen questions. Take it with your lecture notes closed. Aim for 11/13 before moving to Week 23. Answer key with explanations at the bottom — don't peek.

---

**Q1.** What is the difference between `#expect` and `#require` in Swift Testing?

- A) They're identical.
- B) `#expect` records a failure and continues; `#require` records a failure and stops the test (it `throws`), so it's used for fail-fast unwrapping.
- C) `#require` is for async tests only.
- D) `#expect` only works on Bool.

---

**Q2.** Why is a parameterized `@Test(arguments:)` better than a `for` loop over cases inside one test?

- A) It runs faster because loops are slow.
- B) Each argument reports as a separate, independently-run test case, so a failure names the exact failing input — a loop reports one test and obscures which input failed.
- C) Loops can't use `#expect`.
- D) There's no difference.

---

**Q3.** In 2026, what is the relationship between Swift Testing and XCTest?

- A) Swift Testing replaced XCTest entirely; you must delete XCTest.
- B) Swift Testing is the default for new logic tests; XCTest coexists in the same target for legacy suites, XCUITest, and performance APIs.
- C) XCTest is the default; Swift Testing is experimental.
- D) They can't be in the same scheme.

---

**Q4.** Which is the single most important rule for a *trustworthy* XCUITest?

- A) Run it on every PR.
- B) Query elements by `accessibilityIdentifier` (not visible label) and wait with `waitForExistence` — and launch into deterministic state.
- C) Use as many UI tests as possible.
- D) Avoid page objects.

---

**Q5.** What does a snapshot test catch that neither a Swift Testing logic test nor an XCUITest "the text exists" check can?

- A) Nothing new.
- B) A *rendering/layout* regression — clipped text, misalignment, a Dynamic Type overflow, a dark-mode colour change — where the data is correct but the view looks wrong.
- C) A network failure.
- D) A crash on launch.

---

**Q6.** Why must snapshot tests run on a *fixed* simulator/OS and pin the trait environment?

- A) For speed.
- B) Snapshots are pixel comparisons sensitive to device, scale, OS, and traits; an unpinned environment makes the same view "change" between machines and flakes the test.
- C) Apple requires it.
- D) They don't need to be pinned.

---

**Q7.** You pipe `xcodebuild test | xcbeautify` and a test fails, but the CI job reports success. Why?

- A) `xcbeautify` swallowed the failure.
- B) The pipe returns `xcbeautify`'s exit code, masking `xcodebuild`'s failure; you need `set -o pipefail`.
- C) The test didn't actually fail.
- D) GitHub Actions ignores test failures.

---

**Q8.** CI can't find your scheme ("Scheme not found"). What's the fix?

- A) Rename the scheme.
- B) Mark the scheme **Shared** in Manage Schemes and commit the `.xcscheme` file — CI can only build shared, committed schemes.
- C) Use a different runner.
- D) Add a `Package.swift`.

---

**Q9.** What problem does fastlane `match` solve, and how?

- A) It runs your tests faster.
- B) Code signing on machines that aren't yours — it stores one signing identity (cert + profile), encrypted, in a repo that every machine (your laptop and CI) fetches and decrypts on demand.
- C) It uploads to the App Store.
- D) It generates accessibility identifiers.

---

**Q10.** On CI, you call `match(type: "appstore", readonly: true)`. Why `readonly`?

- A) It's faster.
- B) CI must only *fetch* the existing identity, never create or rotate certs — concurrent runs creating certs would churn your signing identity; creation happens once on a laptop.
- C) `readonly` is required for `appstore` type.
- D) It encrypts the certs.

---

**Q11.** How should a CI script authenticate to App Store Connect to upload to TestFlight?

- A) With your Apple ID and password.
- B) With an **App Store Connect API key** (`.p8` + key id + issuer id) stored as secrets — non-interactive, no 2FA prompt a script can't answer.
- C) With a session cookie.
- D) It doesn't need authentication.

---

**Q12.** In the pipeline, what makes the ship job ship *only a green `main`* and never a PR?

- A) Nothing; it ships everything.
- B) `needs: test` (ship depends on the test gate passing) plus `if: github.ref == 'refs/heads/main'` (run only on `main`).
- C) A branch-protection rule on the ship job.
- D) Running `gym` with `--main-only`.

---

**Q13.** Internal TestFlight distribution (`distribute_external: false`) requires what level of App Review?

- A) Full App Review, same as the App Store.
- B) None — internal TestFlight testers get the build without App Review; only *external* beta testing needs a review (that's Week 24).
- C) Expedited review.
- D) A separate developer account.

---

## Answer key

**Q1 — B.** `#expect` records and continues (check several things in one test); `#require` records and `throws` to stop, ideal for `try #require(optional)` unwrapping that replaces `XCTUnwrap`. (Lecture 1, §1.)

**Q2 — B.** Each `arguments:` case is a separate, parallel, independently-reported test; a failure names the exact input. A `for` loop reports one test and hides which case failed. (Lecture 1, §1.)

**Q3 — B.** Swift Testing is the default for new logic tests; XCTest coexists in the same target/scheme for legacy suites, XCUITest (still XCTest-based), and `measure` performance APIs. You don't rip out XCTest. (Lecture 1, §1.)

**Q4 — B.** Query by stable `accessibilityIdentifier` (not localised labels), wait with `waitForExistence`, and launch into deterministic state. These make the test fail only when the app is actually broken. (Lecture 1, §2.)

**Q5 — B.** A snapshot catches *rendering* regressions — layout, clipping, Dynamic Type overflow, dark-mode colour — where data is correct but the view looks wrong, which logic and "text exists" UI tests miss. (Lecture 1, §3.)

**Q6 — B.** Snapshots are pixel diffs sensitive to device/scale/OS/traits; pin the environment and run on a fixed simulator or the same view "changes" between machines and flakes. (Lecture 1, §3.)

**Q7 — B.** The pipe returns `xcbeautify`'s (success) exit code, masking `xcodebuild`'s failure. `set -o pipefail` makes the pipeline fail if any stage fails. This is the difference between a real gate and a fake one. (Lecture 2, §2; §6.)

**Q8 — B.** CI only builds *shared* schemes that are committed to Git. Mark Shared in Manage Schemes and commit the `.xcscheme`. (Lecture 2, §1; §6.)

**Q9 — B.** `match` solves CI code signing by storing one signing identity, encrypted, in a repo every machine fetches and decrypts — so your laptop and CI sign identically without hand-managing keychains. (Lecture 2, §4.)

**Q10 — B.** `readonly` makes CI fetch the existing identity only; it must never create/rotate certs, or concurrent runs churn your signing identity. Creation happens once, on a laptop. (Lecture 2, §4.)

**Q11 — B.** An App Store Connect API key (`.p8` + key id + issuer id) as secrets authenticates non-interactively — an Apple ID with 2FA can't be answered by a script. (Lecture 2, §5.)

**Q12 — B.** `needs: test` makes the ship depend on the gate; `if: github.ref == 'refs/heads/main'` restricts it to `main`. Together: ship only a green `main`, never a PR. (Lecture 2, §5.)

**Q13 — B.** Internal TestFlight needs no App Review — the build is available to internal testers in minutes. Only external beta testing needs a review (Week 24). (Lecture 2, §5.)

---

*Score 11+? On to Week 23. Below 9? Re-read both lecture notes and re-run exercises 1 and 3 — the three-layer test pyramid and the `pipefail`-gated PR workflow are the two ideas this week is graded on, and `match` is the one to study hardest for the challenge.*
