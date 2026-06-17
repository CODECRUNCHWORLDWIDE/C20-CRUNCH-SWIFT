# Week 6 — Exercises

Short, focused drills. Each one should take 30–50 minutes. Do them in order; later ones assume earlier ones. All three run on Linux — no Mac required this week.

## Index

1. **[Exercise 1 — Extract `NotesCore`](./exercise-01-extract-notescore.md)** — lift the request/response models out of the Vapor target into a `NotesCore` SwiftPM package, then import it back from the server via a local `path:` dependency. Guided, with starter and solution. (~45 min)
2. **[Exercise 2 — A `URLSession` CLI client](./exercise-02-cli-client.swift)** — build a runnable Swift CLI that consumes the running `notes-api` using the shared `NotesCore` types: create a note, list notes, fetch one by id. Fill in the four TODOs. (~50 min)
3. **[Exercise 3 — Pick a swift-collections structure](./exercise-03-swift-collections.swift)** — implement a bounded "recently viewed" buffer three times and justify which swift-collections type fits the access pattern. Fill in the three TODOs. (~40 min)

## How to work the exercises

- Read the prompt. Skim, don't memorize.
- **Type the code yourself.** Do not copy-paste from the solution. Muscle memory is the entire point of these drills.
- Run it. See the output. Read the error if it crashed — and for decode failures, read the *coding path*, not just the message.
- If you get stuck for more than 10 minutes, peek at the inline hints at the bottom of each file.
- Every exercise must end with `swift build` and `swift test` printing **0 failures, 0 warnings**. A warning is a bug this week, and under the Swift 6 language mode the compiler is on your side.

There are no solutions checked in beyond the inline hints. The course is open source — solutions live in forks. After you finish, search GitHub for `c20-week-06` to compare.

## Prerequisites for the exercises

- Your Week 5 `notes-api` repository, building and running locally (`swift run` boots it; `docker compose up` brings up Postgres).
- The Swift 6 toolchain (`swift --version` reports 6.x).
- `curl` for sanity-checking the API by hand.
