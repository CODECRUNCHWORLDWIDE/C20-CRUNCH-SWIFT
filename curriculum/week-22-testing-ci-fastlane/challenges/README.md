# Week 22 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 90–150 minutes and produces the capstone's operational backbone: a green `main` that ships a signed build to TestFlight with no human touching a Mac.

## Index

1. **[Challenge 1 — `match` + TestFlight from `main`](challenge-01-match-and-testflight.md)** — set up fastlane `match` for CI code signing (the one genuinely hard part of iOS CI), then add a `push`-to-`main` workflow that signs with `match`, builds with `gym`, and uploads to TestFlight with `pilot`, authenticating with an App Store Connect API key stored as a GitHub secret. End to end: commit to `main` → build in TestFlight. (~120 min, Apple Developer membership required)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "I ship to TestFlight on every push to `main`, signed with `match`, authenticated by an API key, on a runner I don't own" is the single most useful CI capability for an iOS team, and the exact backbone the capstone (TestFlight in five regions) sits on. The CI-signing instinct you build here is what separates engineers who *can* set up an iOS pipeline from those who fight signing for a week and give up.
