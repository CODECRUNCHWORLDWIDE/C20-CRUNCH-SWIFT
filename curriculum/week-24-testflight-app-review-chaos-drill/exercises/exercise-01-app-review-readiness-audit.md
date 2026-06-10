# Exercise 1 — The App Review readiness audit

**Goal.** Audit your capstone against the actually-enforced App Review guidelines *before* you submit, fix anything that fails, and write the App Review notes (with a demo account) that land you on the first try. This is the five-minute-check-vs-multi-day-rejection discipline from Lecture 1, turned into a committed `docs/app-review-readiness.md` you gate your submission on. The whole point: walk in clean, so the only thing standing between you and "live in five regions" is the queue, not a fixable mistake.

**Estimated time.** 45 minutes.

**Prerequisites.** Your locked release candidate (Week 23) and a prepared App Store Connect record (the app created, capabilities matching, the App Privacy label drafted). You run this audit against the *actual* build you are about to submit.

---

## Step 1 — Walk the dozen rules with teeth

Open `docs/app-review-readiness.md` and work through the table below for *your* build. For each rule, record PASS/FAIL and, if FAIL, what you fixed. Do not write PASS on faith — actually do the check (launch the app, click the link, complete the purchase).

| Guideline | The check | Your result + fix |
|-----------|-----------|-------------------|
| 2.1 Completeness | Launch on a fresh device; no crash, no placeholder/test content | |
| 2.3 Metadata | Every screenshot is from the current build; description has no unbacked claims | |
| 3.1.1 IAP | No external-purchase links or hints anywhere; a sandbox purchase unlocks Pro | |
| 4.2 Minimum functionality | Core feature reachable on first launch without a login wall | |
| 5.1.1 Privacy label | The App Privacy label matches the code; every collected type declared | |
| 5.1.1(v) Account deletion | In-app Delete Account works and clears server + local data (if accounts exist) | |
| 5.1.2 Privacy policy | The privacy-policy and support URLs resolve (click them) | |
| Encryption | `ITSAppUsesNonExemptEncryption` set; export-compliance answer correct | |

## Step 2 — Test the account-deletion path for real

If your capstone has accounts (it does, to authenticate to the Vapor backend), 5.1.1(v) requires in-app account deletion. Actually run it:

1. Create a test account, add a few notes, confirm they synced to the backend.
2. Tap Delete Account in-app.
3. Confirm: the local SwiftData store is cleared, the Keychain token is gone, the user is signed out, **and** the server-side data is deleted (check the Vapor backend / database).

A "Delete Account" button that signs out locally but leaves the data on your server is *not* compliant and is a common rejection. The deletion must be real, end to end.

## Step 3 — Write the App Review notes

Write the notes field that a reviewer reads before they touch the app. Include the demo account, the subscription-is-sandbox note, where the Pro gate is, and where account deletion lives. Model it on Lecture 1, §3:

```text
Reviewer notes:

Offline-first notes suite (iPhone/iPad/Mac + watchOS + visionOS). Sync via
CloudKit with a Vapor backend fallback. No login wall on first launch — create
and edit notes immediately; the account is only for cross-device sync.

Demo account (pre-loaded with sample notes):
  email:    review@example.com
  password: <password>

Subscription ("Notes Pro") is StoreKit sandbox — purchase with a sandbox Apple
ID, no real charges. Pro gate: the Tags filter screen.

Account deletion: Settings -> Account -> Delete Account (removes server + local).
Privacy policy: https://example.com/privacy
```

## Step 4 — The 1x screenshot test

Open your App Store screenshots and shrink them to thumbnail size (or look at them in App Store Connect's preview). Ask: at this size, does the first screenshot say what the app is? If it is a wall of tiny text, it communicates nothing to a user scanning search results. Note any screenshot that fails the 1x test and what you would change (a cleaner hero shot, larger UI, fewer words).

## Step 5 — Confirm the submission is gated on the audit

The point of the audit is that you do not submit until every row is PASS. Add a one-line gate to your own process: "submit only when `docs/app-review-readiness.md` is all PASS." Commit the completed audit; it is both your gate and a portfolio artifact showing you ship deliberately.

---

## Acceptance criteria

- [ ] `docs/app-review-readiness.md` exists with the dozen-rules table filled in (PASS/FAIL + fixes) for *your* build.
- [ ] The account-deletion path is tested end to end (local + server) and PASSes, or the app genuinely has no accounts and that is noted.
- [ ] The App Review notes are written with a working demo account, the subscription-sandbox note, and the locations of the Pro gate and account deletion.
- [ ] The 1x screenshot test is done and any failing screenshot is noted with a fix.
- [ ] Every row is PASS before you submit (the gate).
- [ ] Committed to your capstone repo.

## What you just proved

You proved your build is App-Review-ready *before* you spent a queue cycle finding out. Every rejection you pre-empted here is days you saved this week — days you now have for the chaos drill and demo day instead of a resubmission scramble. And you produced the App Review notes that are the single highest-leverage anti-rejection move: a reviewer who can log in and find the features does not reject for "could not review."

---

## Hints (read only if stuck > 15 min)

- **You're not sure if your privacy label is accurate.** Walk your code for every place you store or send data: the notes (CloudKit + Vapor), the auth token (Keychain), the subscription state (StoreKit + backend). Declare each. If a type is in the label but not in the code, remove it; if it's in the code but not the label, add it. (Lecture 1, §2.)
- **The account-deletion endpoint doesn't exist yet.** It's a `DELETE /account` on your Vapor backend that removes the user's rows, plus client code that clears SwiftData and the Keychain and signs out. It's a small amount of code and a hard requirement — ship it this week if you have accounts.
- **You don't have screenshots at the right sizes.** App Store Connect lists the required dimensions per device. The Week 22 snapshot-testing setup can generate device-framed captures; otherwise, screenshot the simulator at the right device and resize per Apple's spec.
- **You're tempted to skip the demo account because "the app works without login."** Even so, the *Pro features* and *sync* need an account, and a reviewer who can't see those may reject for minimum functionality. Always provide the demo account.
