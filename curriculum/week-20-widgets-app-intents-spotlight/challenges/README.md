# Week 20 — Challenges

The exercises drill basics. **Challenges stretch you.** This one takes 60–120 minutes and produces something you can commit to your portfolio and point at in an interview: an interactive widget that mutates shared state with no app launch, with the change provably visible back in the app.

## Index

1. **[Challenge 1 — An interactive "pin" widget](challenge-01-interactive-widget-pin.md)** — add a `Button(intent:)` to your Home Screen widget that pins/unpins a note *in place*, running an App Intent off-process against the shared App Group store, and prove the change is durable by opening the app and seeing the note pinned. Then trace the full loop: tap → intent → shared store → timeline reload → redraw. (~90 min)

Challenges are optional. If you skip them, you can still pass the week. If you do this one, you'll be measurably ahead — "I shipped an interactive widget that mutates a shared SwiftData store off-process and proved the round-trip" is the kind of concrete, current-to-2026 win that lands in code reviews and interviews. The interactive-intent-plus-shared-store instinct you build here is exactly what the capstone's Widgets-and-App-Intents rubric scores, and it's the same off-process discipline Week 21's Live Activities lean on.
