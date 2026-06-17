# Week 8 — Challenges

The exercises drill one boundary each. **The challenge makes you defend the whole thing.** It takes 90–120 minutes and produces a feature you could ship and a render-count proof you could paste into a PR.

## Index

1. **[Challenge 1 — Edit in a sheet: cancel discards, save commits, list updates exactly once](./challenge-01-edit-in-sheet-cancel-discards-save-commits.md)** — implement a draft-and-commit edit flow and *prove* with `onChange(of:)` and a render counter that the list updates exactly once on save and never on cancel. (~110 min)

Challenges are optional for passing the week, but this one is the dress rehearsal for the mini-project — the mini-project reuses this exact edit-in-a-sheet flow inside the full CRUD app. Doing the challenge first means the mini-project's hardest part is already solved and proven.
