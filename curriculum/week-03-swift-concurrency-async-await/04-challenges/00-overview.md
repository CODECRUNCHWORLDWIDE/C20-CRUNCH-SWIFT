# Week 3 — Challenges

The exercises drill the primitives. **Challenges stretch you** and produce something you can commit to your portfolio. Each one takes 90–150 minutes and builds directly on the mini-project.

## Index

1. **[Challenge 1 — `--retry` with bounded concurrency that drains cleanly on Ctrl-C](./challenge-01-retry-with-bounded-concurrency.md)** — add a retry layer to the link-checker that re-runs failed `HEAD` requests under their own concurrency cap, with exponential backoff and jitter, and prove that in-flight retries still cancel and drain when you hit Ctrl-C. (~120 min)

## How to work a challenge

- Do the mini-project first, or at least scaffold it. Challenge 1 is a feature *on top of* the link-checker; it assumes that code exists.
- Read the acceptance criteria before you write anything. They are the spec; the prose is context.
- The hardest part is almost never "make it work once." It is "make it still drain cleanly on Ctrl-C while a retry is mid-backoff." Budget your time accordingly — the happy path is 30 minutes, the cancellation correctness is the other 90.

Challenges are optional for passing the week. If you do them, you will be measurably ahead of someone who didn't — and the bounded-retry pattern here reappears in **Week 13** (URLSession networking layer with retry-and-jitter) almost verbatim. Doing it now in a CLI, where Ctrl-C makes cancellation visceral, means it will be muscle memory when you build the iOS networking client.
