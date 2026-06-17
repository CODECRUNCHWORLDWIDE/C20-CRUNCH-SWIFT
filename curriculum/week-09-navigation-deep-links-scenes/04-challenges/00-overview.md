# Week 9 — Challenges

One harder, open-ended challenge this week. It takes the custom-scheme deep link you built in Exercise 3 and upgrades it to a *real universal link* — the kind a user taps in Safari or Messages — wired through the Associated Domains entitlement and an `apple-app-site-association` file, and proven from both a warm and a cold launch in the simulator.

## Index

1. **[Challenge 1 — Universal links, end to end](./challenge-01-universal-links.md)** — wire up Associated Domains and a locally-served AASA file so `https://notes.example.com/open/<id>` opens the app to the correct note, proven warm and cold. (~90–120 min)

## How to work the challenge

- The challenge is **open-ended**: it gives you acceptance criteria and a recommended approach, not a fill-in-the-blanks file. Solve it your way; meet the criteria.
- Universal links have more moving parts than any other topic this week — the entitlement, the AASA file's exact serving requirements, the simulator's association behaviour. Budget time for the AASA file to be *almost* right and not work. Read the Apple Developer Forums AASA threads in `resources.md` before you start.
- You do **not** need a paid Apple Developer account, a public domain, or a TLS certificate. The challenge shows the simulator-only path that uses `swcutil` / a local file. Keep the terminal open.
- Write up your proof. The deliverable includes a short `PROOF.md` with the two terminal transcripts (warm and cold) and a sentence on why the cold launch works without special-casing it. "It worked on my machine" is not a senior proof; the transcript is.
