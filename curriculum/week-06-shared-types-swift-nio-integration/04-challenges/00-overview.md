# Week 6 — Challenges

One challenge this week. It is the harder, open-ended cousin of the exercises and it is the test the Phase I gate actually checks: **can you prove your shared `NotesCore` package is correct, with coverage above 70%, using tests a reviewer trusts?**

## Index

1. **[Challenge 1 — `NotesCore` coverage above 70%](./challenge-01-coverage-above-70.md)** — drive Swift Testing line coverage of the shared package above 70% with round-trip `Codable` tests and edge-case decoding tests for malformed payloads. (~90 min)

## How to work the challenge

- This is **not** a fill-in-the-TODO drill. You are given acceptance criteria and a target number, not a skeleton. Design the tests yourself.
- Start by measuring where you are: `swift test --enable-code-coverage`, then read the report. You cannot raise a number you have not measured.
- Write tests that assert *behaviour*, not tests that exist to bump a percentage. A round-trip test that proves `decode(encode(x)) == x` is worth ten tests that touch a line without asserting anything.
- Malformed-payload tests are where the real coverage — and the real bugs — live. A wire type that decodes garbage without complaint is a production incident waiting to happen.
- The challenge is done when `swift test --enable-code-coverage` passes **and** the coverage report shows `NotesCore` above 70% line coverage.

## Why this is the gate

The Phase I gate reads, verbatim: *"with Swift Testing coverage above 70% on the shared package."* This challenge is that line. If you complete it, you have the coverage deliverable for the mini-project and the Phase I demo in hand. Do it on the same `NotesCore` package you build in Exercise 1 and the mini-project — not a throwaway — so the work compounds.
